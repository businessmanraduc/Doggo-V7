// ================================================================================
//  cosim.cc -- lockstep checker: one Spike step per DUT event (README.md)
// ================================================================================
#include "hart.h"
#include <riscv/encoding.h>
#include <cinttypes>
#include <cstdio>
#include <cstring>
#include <deque>
#include <map>
#include <memory>
#include <sstream>

namespace {

enum { EVENT_RETIRE = 0, EVENT_EXCEPTION = 1, EVENT_INTERRUPT = 2 };
enum { MEMORY_NONE = 0, MEMORY_LOAD = 1, MEMORY_STORE = 2 };

const uint32_t MIP_IMPLEMENTED = MIP_MSIP | MIP_MTIP | MIP_MEIP;
const size_t HISTORY_LENGTH = 24;

struct Event {
  int      kind;
  uint32_t pc, insn;
  int      rd;
  uint32_t rdValue;
  int      memoryKind;
  uint32_t memoryAddress, memorySize, memoryReadWord, storeData, cause;
  uint32_t mip;
  uint32_t snapshot[SNAP_COUNT];
};

struct Stats {
  uint64_t events = 0, retires = 0, exceptions = 0, interrupts = 0;
  uint64_t ioLoads = 0, ioStores = 0, dutValuedReads = 0;
};

struct Coverage {
  std::map<std::string, uint64_t> mnemonics, causes, csrs;
  uint64_t rawDistance[6] = {}, aliasDistance[6] = {};
  uint64_t lastWriteEvent[32] = {};
  struct Store { uint32_t address, size; uint64_t event; };
  std::deque<Store> recentStores;
};

std::unique_ptr<Hart> hart;
Stats stats;
Coverage coverage;
std::deque<std::string> history;
bool failed = false;

bool dutValuedReadsOn = true, profileOn = true;   // off only in negative controls
int maxInterruptDelay = 64;
int interruptDelay = 0;
uint32_t lastMcycle = 0, lastMcycleh = 0;
bool mcycleKnown = true, mcyclehKnown = true;

bool ioLoadExpected = false, ioLoadSeen = false;
std::string ioError;
uint32_t ioAddress, ioSize, ioReadWord;

int distanceBucket(uint64_t distance) {
  if (distance <= 1) return 0;
  if (distance == 2) return 1;
  if (distance <= 4) return 2;
  if (distance <= 8) return 3;
  return distance <= 16 ? 4 : 5;
}

std::string hex(uint32_t value) {
  char text[16];
  snprintf(text, sizeof text, "0x%08x", value);
  return text;
}

void coverRetire(const Event& event) {
  std::string mnemonic = hart->disassemble(event.insn);
  coverage.mnemonics[mnemonic.substr(0, mnemonic.find_first_of(" \t"))]++;
  uint32_t insn = event.insn;
  if ((insn & 3) == 3) {
    uint32_t opcode = insn & 0x7f, rs1 = (insn >> 15) & 31, rs2 = (insn >> 20) & 31;
    bool readsRs1 = opcode != 0x37 && opcode != 0x17 && opcode != 0x6f &&
                    !(opcode == 0x73 && ((insn >> 12) & 4));
    bool readsRs2 = opcode == 0x33 || opcode == 0x23 || opcode == 0x63;
    if (readsRs1 && rs1 && coverage.lastWriteEvent[rs1])
      coverage.rawDistance[distanceBucket(stats.events - coverage.lastWriteEvent[rs1])]++;
    if (readsRs2 && rs2 && coverage.lastWriteEvent[rs2])
      coverage.rawDistance[distanceBucket(stats.events - coverage.lastWriteEvent[rs2])]++;
    if (opcode == 0x73 && ((insn >> 12) & 3)) {
      char address[8];
      snprintf(address, sizeof address, "%03x", insn >> 20);
      coverage.csrs[address]++;
    }
  }
  if (event.memoryKind == MEMORY_LOAD) {
    for (auto store = coverage.recentStores.rbegin(); store != coverage.recentStores.rend(); ++store)
      if (store->address < event.memoryAddress + event.memorySize &&
          event.memoryAddress < store->address + store->size) {
        coverage.aliasDistance[distanceBucket(stats.events - store->event)]++;
        break;
      }
  }
  if (event.memoryKind == MEMORY_STORE) {
    coverage.recentStores.push_back({event.memoryAddress, event.memorySize, stats.events});
    if (coverage.recentStores.size() > 64) coverage.recentStores.pop_front();
  }
  if (event.rd) coverage.lastWriteEvent[event.rd] = stats.events;
}

std::string eventText(const Event& event) {
  std::ostringstream text;
  const char* kind = event.kind == EVENT_RETIRE ? "ret" : event.kind == EVENT_EXCEPTION ? "exc" : "irq";
  text << kind << " pc " << hex(event.pc);
  if (event.kind == EVENT_RETIRE) {
    text << " (" << hex(event.insn) << ") " << hart->disassemble(event.insn);
    if (event.rd) text << "  x" << event.rd << "=" << hex(event.rdValue);
    if (event.memoryKind == MEMORY_LOAD)
      text << "  ld " << hex(event.memoryAddress) << "/" << event.memorySize;
    if (event.memoryKind == MEMORY_STORE)
      text << "  st " << hex(event.memoryAddress) << "/" << event.memorySize << "="
           << hex(event.storeData);
  } else if (event.kind == EVENT_INTERRUPT) {
    text << " cause " << event.cause;
  }
  return text.str();
}

int fail(const Event& event, const std::string& what) {
  failed = true;
  fprintf(stderr, "COSIM MISMATCH at event %" PRIu64 ": %s\n", stats.events, what.c_str());
  fprintf(stderr, "  last events (DUT view, oldest first):\n");
  for (auto& line : history) fprintf(stderr, "    %s\n", line.c_str());
  fprintf(stderr, "  this: %s\n", eventText(event).c_str());
  return 1;
}

bool isCsrRead(uint32_t insn, uint32_t& csr, int& rd) {
  if ((insn & 0x7f) != 0x73) return false;
  uint32_t funct3 = (insn >> 12) & 7;
  if (funct3 == 0 || funct3 == 4) return false;
  csr = insn >> 20;
  rd = (insn >> 7) & 31;
  return rd != 0;
}

bool isCsrWrite(uint32_t insn) {
  uint32_t funct3 = (insn >> 12) & 7, rs1 = (insn >> 15) & 31;
  return (insn & 0x7f) == 0x73 && funct3 != 0 && funct3 != 4 && ((funct3 & 3) == 1 || rs1 != 0);
}

// mcycle(h) are timing, not architecture; mip reads equal the event's lines
bool takesDutValue(uint32_t csr) { return csr == CSR_MIP || csr == CSR_MCYCLE || csr == CSR_MCYCLEH; }

int checkSnapshot(const Event& event, const uint32_t* reference) {
  for (int i = 0; i < SNAP_COUNT; i++)
    if (event.snapshot[i] != reference[i])
      return fail(event, std::string(snapshotName[i]) + ": DUT " + hex(event.snapshot[i]) + " ref " +
                         hex(reference[i]));
  return 0;
}

int checkInterrupt(const Event& event, uint32_t enabled) {
  uint32_t bit = event.cause < 32 ? 1u << event.cause : 0;
  if (!(bit & MIP_IMPLEMENTED))
    return fail(event, "interrupt cause " + std::to_string(event.cause) + " not implemented");
  if (!(bit & enabled))
    return fail(event, "interrupt taken while not pending and enabled in the reference");
  hart->setMip(MIP_IMPLEMENTED, event.mip);
  StepResult reference = hart->step();
  hart->setMip(MIP_IMPLEMENTED, 0);
  if (!reference.trapped || reference.snapshot[SNAP_MCAUSE] != (0x80000000u | event.cause))
    return fail(event, "interrupt priority: reference takes mcause " +
                       hex(reference.snapshot[SNAP_MCAUSE]));
  interruptDelay = 0;
  stats.interrupts++;
  coverage.causes["irq" + std::to_string(event.cause)]++;
  return checkSnapshot(event, reference.snapshot);
}

// a DUT-valued read: mip equals the lines, mcycle(h) never goes back
int checkDutValuedRead(const Event& event, uint32_t csr, int rd) {
  if (csr == CSR_MIP && event.rdValue != event.mip)
    return fail(event, "mip read: DUT " + hex(event.rdValue) + ", pending lines " + hex(event.mip));
  if (csr == CSR_MCYCLE && mcycleKnown && (uint32_t)(event.rdValue - lastMcycle) >= 0x80000000u)
    return fail(event, "mcycle went back: " + hex(lastMcycle) + " -> " + hex(event.rdValue));
  if (csr == CSR_MCYCLEH && mcyclehKnown && (uint32_t)(event.rdValue - lastMcycleh) >= 0x80000000u)
    return fail(event, "mcycleh went back: " + hex(lastMcycleh) + " -> " + hex(event.rdValue));
  if (csr == CSR_MCYCLE) { lastMcycle = event.rdValue; mcycleKnown = true; }
  if (csr == CSR_MCYCLEH) { lastMcycleh = event.rdValue; mcyclehKnown = true; }
  hart->setXreg(rd, event.rdValue);
  stats.dutValuedReads++;
  return 0;
}

// a write restarts the half from the value written into the DUT's counter;
// csrrs/csrrc merge with the DUT's old value, known only when rd is not x0
void trackMcycleWrite(const Event& event, uint32_t operand) {
  bool isHigh = (event.insn >> 20) == CSR_MCYCLEH;
  uint32_t funct3 = (event.insn >> 12) & 3;
  bool known = funct3 == 1 || event.rd != 0;
  uint32_t value = funct3 == 1   ? operand
                 : funct3 == 2 ? (event.rdValue | operand)
                               : (event.rdValue & ~operand);
  (isHigh ? lastMcycleh : lastMcycle) = value;
  (isHigh ? mcyclehKnown : mcycleKnown) = known;
}

int checkMemory(const Event& event, const StepResult& reference) {
  int referenceKind = reference.memory.isLoad    ? MEMORY_LOAD
                    : reference.memory.isStore ? MEMORY_STORE
                                               : MEMORY_NONE;
  if (referenceKind != event.memoryKind)
    return fail(event, "memory access kind: DUT " + std::to_string(event.memoryKind) + " ref " +
                       std::to_string(referenceKind));
  if (referenceKind == MEMORY_NONE) return 0;
  if (reference.memory.address != event.memoryAddress || reference.memory.size != event.memorySize)
    return fail(event, "memory address/size: DUT " + hex(event.memoryAddress) + "/" +
                       std::to_string(event.memorySize) + " ref " + hex(reference.memory.address) + "/" +
                       std::to_string(reference.memory.size));
  if (referenceKind == MEMORY_STORE && reference.memory.storeData != event.storeData)
    return fail(event, "store data: DUT " + hex(event.storeData) + " ref " +
                       hex(reference.memory.storeData));
  bool isIo = !hart->inRam(reference.memory.address, reference.memory.size);
  if (referenceKind == MEMORY_LOAD && isIo) stats.ioLoads++;
  if (referenceKind == MEMORY_STORE && isIo) stats.ioStores++;
  return 0;
}

int checkEvent(const Event& event) {
  if (failed) return 1;
  if (event.kind < 0 || event.kind > EVENT_INTERRUPT)
    return fail(event, "event kind " + std::to_string(event.kind));
  if (hart->pc() != event.pc) return fail(event, "pc: DUT " + hex(event.pc) + " ref " + hex(hart->pc()));
  if (event.mip & ~MIP_IMPLEMENTED) return fail(event, "mip: unimplemented bits " + hex(event.mip));

  uint32_t enabled = (hart->csr(CSR_MSTATUS) & MSTATUS_MIE) ? (event.mip & hart->csr(CSR_MIE)) : 0;
  if (event.kind == EVENT_INTERRUPT) return checkInterrupt(event, enabled);

  // the DUT may take an enabled interrupt up to maxInterruptDelay events late:
  // hide it from the reference on this step
  if (!enabled) interruptDelay = 0;
  else if (++interruptDelay > maxInterruptDelay)
    return fail(event, "interrupt pending and enabled for " + std::to_string(interruptDelay) +
                       " events, not taken");
  hart->setMip(MIP_IMPLEMENTED, event.mip & ~enabled);
  ioLoadExpected = event.kind == EVENT_RETIRE && event.memoryKind == MEMORY_LOAD;
  ioLoadSeen = false;
  ioError.clear();
  ioAddress = event.memoryAddress;
  ioSize = event.memorySize;
  ioReadWord = event.memoryReadWord;
  uint32_t rs1 = (event.insn >> 15) & 31;
  uint32_t csrOperand = (event.insn >> 12) & 4 ? rs1 : hart->xreg(rs1);
  StepResult reference = hart->step();
  ioLoadExpected = false;
  hart->setMip(MIP_IMPLEMENTED, 0);
  if (!ioError.empty()) return fail(event, ioError);

  if (event.kind == EVENT_EXCEPTION) {
    if (!reference.trapped)
      return fail(event, "DUT trapped, reference retired " + hart->disassemble(reference.insn));
    stats.exceptions++;
    coverage.causes["exc" + std::to_string(reference.snapshot[SNAP_MCAUSE])]++;
    return checkSnapshot(event, reference.snapshot);
  }
  if (reference.trapped)
    return fail(event, "DUT retired, reference trapped: mcause " + hex(reference.snapshot[SNAP_MCAUSE]) +
                       " mtval " + hex(reference.snapshot[SNAP_MTVAL]));
  if (reference.insn != event.insn)
    return fail(event, "insn: DUT " + hex(event.insn) + " ref " + hex(reference.insn));
  if (reference.rd != event.rd)
    return fail(event, "rd: DUT x" + std::to_string(event.rd) + " ref x" + std::to_string(reference.rd));

  uint32_t csr = 0;
  int csrRd = 0;
  if (dutValuedReadsOn && isCsrRead(event.insn, csr, csrRd) && takesDutValue(csr)) {
    if (checkDutValuedRead(event, csr, csrRd)) return 1;
  } else if (event.rd && reference.rdValue != event.rdValue) {
    return fail(event, "x" + std::to_string(event.rd) + ": DUT " + hex(event.rdValue) + " ref " +
                       hex(reference.rdValue));
  }
  if (isCsrWrite(event.insn) && ((event.insn >> 20) == CSR_MCYCLE || (event.insn >> 20) == CSR_MCYCLEH))
    trackMcycleWrite(event, csrOperand);
  if (checkMemory(event, reference)) return 1;
  stats.retires++;
  coverRetire(event);
  return checkSnapshot(event, reference.snapshot);
}

// an IO load reads the word the DUT read: the access must match it, once
bool referenceIoLoad(uint32_t address, size_t size, uint8_t* bytes) {
  if (!ioLoadExpected) {
    ioError = "reference IO load " + hex(address) + " without a DUT load";
    return false;
  }
  if (ioLoadSeen || address != ioAddress || size != ioSize) {
    ioError = "reference IO load " + hex(address) + "/" + std::to_string(size) + ", DUT " +
              hex(ioAddress) + "/" + std::to_string(ioSize);
    return false;
  }
  ioLoadSeen = true;
  uint32_t value = ioReadWord >> (8 * (address & 3));
  for (size_t i = 0; i < size; i++) bytes[i] = (uint8_t)(value >> (8 * i));
  return true;
}

} // namespace

extern "C" {

// before cosim_init: "irqlate" (events an enabled interrupt may wait, 64);
// negative controls only: "override" (DUT-valued reads), "profile"
void cosim_knob(const char* name, int value) {
  if (!strcmp(name, "override")) dutValuedReadsOn = value;
  if (!strcmp(name, "irqlate")) maxInterruptDelay = value;
  if (!strcmp(name, "profile")) profileOn = value;
}

int cosim_init(const char* image, int ramBase, int ramSize, int entry, const char* logPath) {
  hart.reset(new Hart((uint32_t)ramBase, (uint32_t)ramSize, logPath, profileOn));
  if (!hart->loadImage(image)) {
    fprintf(stderr, "cosim: cannot load %s\n", image);
    return 1;
  }
  hart->reset((uint32_t)entry);
  hart->onIoLoad = referenceIoLoad;
  hart->onIoStore = [](uint32_t, size_t, const uint8_t*) { return true; };
  stats = Stats();
  coverage = Coverage();
  history.clear();
  failed = false;
  interruptDelay = 0;
  lastMcycle = lastMcycleh = 0;
  mcycleKnown = mcyclehKnown = true;
  return 0;
}

int cosim_event(int kind, int pc, int insn, int rd, int rdValue, int memoryKind, int memoryAddress,
                int memorySize, int memoryReadWord, int storeData, int cause, int mip,
                const int* snapshot) {
  Event event;
  event.kind = kind;
  event.pc = pc;
  event.insn = insn;
  event.rd = rd;
  event.rdValue = rdValue;
  event.memoryKind = memoryKind;
  event.memoryAddress = memoryAddress;
  event.memorySize = memorySize;
  event.memoryReadWord = memoryReadWord;
  event.storeData = storeData;
  event.cause = cause;
  event.mip = mip;
  for (int i = 0; i < SNAP_COUNT; i++) event.snapshot[i] = (uint32_t)snapshot[i];
  int mismatch = checkEvent(event);
  if (!mismatch) {
    history.push_back(eventText(event));
    if (history.size() > HISTORY_LENGTH) history.pop_front();
  }
  stats.events++;
  return mismatch;
}

// "key count" lines: m:<mnemonic> c:<cause> csr:<address> raw:<distance> alias:<distance>
void cosim_report(const char* path) {
  FILE* file = fopen(path, "w");
  if (!file) return;
  const char* bucket[6] = {"1", "2", "3-4", "5-8", "9-16", "17+"};
  auto print = [&](const char* group, const std::string& key, uint64_t count) {
    fprintf(file, "%s:%s %" PRIu64 "\n", group, key.c_str(), count);
  };
  for (auto& entry : coverage.mnemonics) print("m", entry.first, entry.second);
  for (auto& entry : coverage.causes) print("c", entry.first, entry.second);
  for (auto& entry : coverage.csrs) print("csr", entry.first, entry.second);
  for (int i = 0; i < 6; i++) print("raw", bucket[i], coverage.rawDistance[i]);
  for (int i = 0; i < 6; i++) print("alias", bucket[i], coverage.aliasDistance[i]);
  fclose(file);
}

// nextPc: where the DUT would fetch next (checked if checkPc); returns 1 on any mismatch
int cosim_finish(int nextPc, int checkPc) {
  if (!failed && checkPc && hart->pc() != (uint32_t)nextPc) {
    failed = true;
    fprintf(stderr, "COSIM MISMATCH at finish: next pc DUT %s ref %s\n", hex(nextPc).c_str(),
            hex(hart->pc()).c_str());
  }
  printf("cosim: %" PRIu64 " events, %" PRIu64 " retired, %" PRIu64 " exceptions, %" PRIu64
         " interrupts, %" PRIu64 " IO loads, %" PRIu64 " IO stores, %" PRIu64
         " DUT-valued CSR reads%s\n",
         stats.events, stats.retires, stats.exceptions, stats.interrupts, stats.ioLoads, stats.ioStores,
         stats.dutValuedReads, failed ? ", FAILED" : "");
  return failed ? 1 : 0;
}

}
