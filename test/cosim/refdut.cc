// ================================================================================
//  refdut.cc -- stand-in DUT: a Spike hart plus the test devices, emitting events
// ================================================================================
//  Not a reference: it plays the core, so the checker, cosim_order and the bench
//  plumbing are tested without core RTL. Faults corrupt chosen events
//  (negative controls, nc_suite.sh).
#include "hart.h"
#include <riscv/encoding.h>
#include <cstdio>
#include <cstring>
#include <memory>
#include <random>
#include <string>

namespace {

enum { EVENT_RETIRE = 0, EVENT_EXCEPTION = 1, EVENT_INTERRUPT = 2 };
enum { MEMORY_NONE = 0, MEMORY_LOAD = 1, MEMORY_STORE = 2 };

const uint32_t IO_BASE = 0x10000000;
const uint32_t MIP_IMPLEMENTED = MIP_MSIP | MIP_MTIP | MIP_MEIP;
const uint32_t DEVICE_SCRATCH = IO_BASE, DEVICE_COUNTER = IO_BASE + 0x100, DEVICE_FIFO = IO_BASE + 0x104,
               DEVICE_IRQ = IO_BASE + 0x108, DEVICE_IRQ_TIMER = IO_BASE + 0x10c,
               DEVICE_CONSOLE = IO_BASE + 0x110, DEVICE_EXIT = IO_BASE + 0x114;

std::unique_ptr<Hart> hart;
std::mt19937 randomSource;

// ---- devices -------------------------------------------------------------------
uint32_t scratch[64];
uint32_t counter = 0, fifo = 0xace1u;
uint32_t lines = 0;                  // interrupt lines raised by the devices
uint64_t lineVisibleAt[32];          // step from which a raised line reaches mip
uint32_t visibleLines = 0;           // lines in mip (reported as rt_mip)
int64_t irqTimerAt = -1;
int interruptRate = 0;               // MEIP pulses per million steps
int mcycleDriftRate = 0;             // mcycle bumps per thousand steps
uint64_t meipOffAt = 0;
int64_t interruptHiddenUntil = -1;
uint32_t lastIoWord = 0;
std::string consoleLine;

uint64_t steps = 0;
uint32_t tohostAddress = 0;
bool programEnded = false;
uint32_t exitCode = 0;

// ---- negative controls ---------------------------------------------------------
int faultKind = 0;
uint64_t faultAtEvent = 0, eventCount = 0;
bool faultInjected = false;
bool interruptNeverTaken = false;    // fault 29
bool mcycleLastWritten = false;      // fault 35
bool linesForged = false;            // a fault forged this event's mip: the device lines follow
uint32_t forgedLines = 0;

uint32_t deviceRead(uint32_t wordAddress) {
  if (wordAddress >= DEVICE_SCRATCH && wordAddress < DEVICE_SCRATCH + 256)
    return scratch[(wordAddress - DEVICE_SCRATCH) >> 2];
  if (wordAddress == DEVICE_COUNTER) return counter += 7;
  if (wordAddress == DEVICE_FIFO) {
    fifo = (fifo >> 1) ^ (-(fifo & 1u) & 0xb400u);
    return fifo * 0x9e3779b1u;
  }
  if (wordAddress == DEVICE_IRQ) return lines;
  return 0;
}

void raiseLine(uint32_t bit) {
  if (!(lines & bit)) lineVisibleAt[__builtin_ctz(bit)] = steps + randomSource() % 11;
  lines |= bit;
}

void deviceWrite(uint32_t address, size_t size, const uint8_t* bytes) {
  uint32_t busWord = 0;              // unwritten lanes 0
  for (size_t i = 0; i < size; i++) busWord |= (uint32_t)bytes[i] << (8 * ((address & 3) + i));
  uint32_t wordAddress = address & ~3u;
  if (wordAddress >= DEVICE_SCRATCH && wordAddress < DEVICE_SCRATCH + 256) {
    uint8_t* word = (uint8_t*)&scratch[(wordAddress - DEVICE_SCRATCH) >> 2];
    for (size_t i = 0; i < size; i++) word[(address & 3) + i] = bytes[i];
  } else if (wordAddress == DEVICE_IRQ) {
    for (uint32_t bit : {MIP_MSIP, MIP_MTIP, MIP_MEIP})
      if (busWord & bit) raiseLine(bit);
    lines &= busWord | ~MIP_IMPLEMENTED;
  } else if (wordAddress == DEVICE_IRQ_TIMER) {
    irqTimerAt = busWord ? (int64_t)(steps + busWord) : -1;
  } else if (wordAddress == DEVICE_CONSOLE) {
    for (size_t i = 0; i < size; i++) {
      char c = (char)bytes[i];
      if (c == '\n') {
        printf("console: %s\n", consoleLine.c_str());
        consoleLine.clear();
      } else {
        consoleLine += c;
      }
    }
  } else if (wordAddress == DEVICE_EXIT) {
    programEnded = true;
    exitCode = busWord;
  }
}

// one step of device time; an enabled pending interrupt is hidden from the hart for 0..20 steps
void advanceDevices() {
  steps++;
  if (irqTimerAt >= 0 && steps >= (uint64_t)irqTimerAt) {
    raiseLine(MIP_MTIP);
    irqTimerAt = -1;
  }
  if (interruptRate && !(lines & MIP_MEIP) && randomSource() % 1000000 < (uint32_t)interruptRate) {
    raiseLine(MIP_MEIP);
    meipOffAt = steps + 1 + randomSource() % 50;
  }
  if (interruptRate && (lines & MIP_MEIP) && steps >= meipOffAt) lines &= ~MIP_MEIP;
  visibleLines = 0;
  for (uint32_t bit : {MIP_MSIP, MIP_MTIP, MIP_MEIP})
    if ((lines & bit) && steps >= lineVisibleAt[__builtin_ctz(bit)]) visibleLines |= bit;
  uint32_t enabled = (hart->csr(CSR_MSTATUS) & MSTATUS_MIE) ? (visibleLines & hart->csr(CSR_MIE)) : 0;
  if (!enabled) interruptHiddenUntil = -1;
  else if (interruptHiddenUntil < 0)
    interruptHiddenUntil = (int64_t)(steps + (interruptNeverTaken ? 1000000 : randomSource() % 21));
  bool hidden = enabled && steps < (uint64_t)interruptHiddenUntil;
  hart->setMip(MIP_IMPLEMENTED, hidden ? visibleLines & ~enabled : visibleLines);
  if (mcycleDriftRate && randomSource() % 1000 < (uint32_t)mcycleDriftRate)
    hart->processor->get_state()->mcycle->bump(1 + randomSource() % 5);
}

bool isCsrReadOf(uint32_t insn, uint32_t csr) {
  uint32_t funct3 = (insn >> 12) & 7;
  return (insn & 0x7f) == 0x73 && funct3 != 0 && funct3 != 4 && (insn >> 20) == csr &&
         ((insn >> 7) & 31);
}

struct StepOut {
  int        kind;
  StepResult result;
  uint32_t   ioWord, mip, cause;
};

StepOut stepOnce() {
  advanceDevices();
  lastIoWord = 0;
  StepOut out;
  out.mip = visibleLines;
  out.result = hart->step();
  out.ioWord = lastIoWord;
  bool isInterrupt = out.result.trapped && (out.result.snapshot[SNAP_MCAUSE] & 0x80000000u);
  out.kind = !out.result.trapped ? EVENT_RETIRE : isInterrupt ? EVENT_INTERRUPT : EVENT_EXCEPTION;
  out.cause = isInterrupt ? (out.result.snapshot[SNAP_MCAUSE] & 0x7fffffffu) : 0;
  if (out.kind == EVENT_RETIRE && isCsrReadOf(out.result.insn, CSR_MIP)) {
    out.result.rdValue = visibleLines;
    hart->setXreg(out.result.rd, visibleLines);
  }
  return out;
}

void markInjected() {
  faultInjected = true;
  fprintf(stderr, "refdut: fault %d injected at event %lu\n", faultKind, (unsigned long)eventCount);
}

struct Fields {
  int kind, pc, insn, rd, rdValue, memoryKind, memoryAddress, memorySize;
  int memoryReadWord, storeData, cause, mip;
  int* snapshot;
};

// corrupt one field of this event; false when the event has no such field
bool corrupt(Fields& f, uint32_t mie, uint32_t originalMip) {
  bool isRetire = f.kind == EVENT_RETIRE;
  uint32_t insn = (uint32_t)f.insn;
  switch (faultKind) {
    case 1: if (!f.rd) return false; f.rdValue ^= 1; break;
    case 2: if (!isRetire) return false; f.pc += 4; break;
    case 3: if (f.memoryKind != MEMORY_STORE) return false; f.storeData ^= 0x100; break;
    case 4: if (f.memoryKind != MEMORY_LOAD) return false; f.memoryAddress += 4; break;
    case 5: if (!isRetire) return false; f.insn ^= 0x80; break;
    case 6: if (!f.rd) return false; f.rd = (f.rd % 31) + 1; break;
    case 7: f.snapshot[SNAP_MSTATUS] ^= MSTATUS_MPIE; break;
    case 8: f.snapshot[SNAP_MINSTRET] += 1; break;
    case 9: if (f.kind != EVENT_EXCEPTION) return false; f.snapshot[SNAP_MCAUSE] ^= 1; break;
    case 10: if (f.kind != EVENT_EXCEPTION) return false; f.snapshot[SNAP_MTVAL] ^= 4; break;
    case 11: if (f.memoryKind != MEMORY_STORE) return false; f.memoryKind = MEMORY_NONE; break;
    case 12:
      if (f.memoryKind != MEMORY_LOAD || hart->inRam(f.memoryAddress, f.memorySize)) return false;
      f.memoryAddress ^= 0x100;
      break;
    case 13: if (f.kind != EVENT_INTERRUPT) return false; f.kind = EVENT_EXCEPTION; break;
    case 14: if (f.kind != EVENT_INTERRUPT) return false; f.cause = f.cause == 3 ? 7 : 3; break;
    case 15: if (f.kind != EVENT_EXCEPTION) return false; f.kind = EVENT_RETIRE; break;
    case 16:
      if (f.memoryKind != MEMORY_STORE) return false;
      f.memorySize = f.memorySize == 4 ? 2 : 4;
      break;
    case 21: f.snapshot[SNAP_MIE] ^= MIP_MTIP; break;
    case 22: f.snapshot[SNAP_MTVEC] ^= 0x40; break;
    case 23: f.snapshot[SNAP_MSCRATCH] ^= 0x10; break;
    case 24: f.snapshot[SNAP_MEPC] ^= 2; break;
    case 25: f.snapshot[SNAP_MINSTRETH] ^= 1; break;
    case 26:                         // a CSR read the checker compares
      if (!isRetire || (insn & 0x7f) != 0x73 || !((insn >> 12) & 3) || !f.rd ||
          (insn >> 20) == CSR_MIP || (insn >> 20) == CSR_MCYCLE || (insn >> 20) == CSR_MCYCLEH)
        return false;
      f.rdValue ^= 0x20;
      break;
    case 27: if (!isRetire || !isCsrReadOf(insn, CSR_MIP)) return false; f.rdValue ^= MIP_MEIP; break;
    case 28: if (!isRetire || !isCsrReadOf(insn, CSR_MCYCLE)) return false; f.rdValue -= 0x1000; break;
    case 30:
      if (f.kind != EVENT_INTERRUPT || f.cause == 11 || !(mie & MIP_MEIP)) return false;
      f.mip |= MIP_MEIP;
      break;
    case 31: f.mip |= 1 << 5; break;
    case 32: f.kind = 3; break;
    case 33:
      if (f.kind != EVENT_INTERRUPT || f.cause != 7 || !(mie & MIP_MSIP)) return false;
      f.mip |= MIP_MSIP;
      break;
    case 34:
      if (!isRetire || !isCsrReadOf(insn, CSR_MCYCLEH) || !f.rdValue) return false;
      f.rdValue -= 1;
      break;
    case 35:
      if (!isRetire || !isCsrReadOf(insn, CSR_MCYCLE) || !mcycleLastWritten) return false;
      f.rdValue -= 0x10;
      break;
    default: return false;           // 29 acts in advanceDevices()
  }
  if ((uint32_t)f.mip != originalMip) {
    linesForged = true;
    forgedLines = (uint32_t)f.mip;
  }
  return true;
}

} // namespace

extern "C" {

int refdut_init(const char* image, int ramBase, int ramSize, int entry, int tohost, int seed, int rate,
                int drift, const char* logPath) {
  hart.reset(new Hart((uint32_t)ramBase, (uint32_t)ramSize, logPath));
  if (!hart->loadImage(image)) {
    fprintf(stderr, "refdut: cannot load %s\n", image);
    return 1;
  }
  hart->reset((uint32_t)entry);
  randomSource.seed((uint32_t)seed);
  memset(scratch, 0, sizeof scratch);
  mcycleLastWritten = false;
  interruptNeverTaken = false;
  counter = 0; fifo = 0xace1u; lines = 0; visibleLines = 0;
  interruptHiddenUntil = -1; irqTimerAt = -1; steps = 0;
  programEnded = false; exitCode = 0;
  tohostAddress = (uint32_t)tohost; interruptRate = rate; mcycleDriftRate = drift;
  eventCount = 0; faultInjected = false;
  consoleLine.clear();
  hart->onIoLoad = [](uint32_t address, size_t size, uint8_t* bytes) {
    lastIoWord = deviceRead(address & ~3u);
    uint32_t value = lastIoWord >> (8 * (address & 3));
    for (size_t i = 0; i < size; i++) bytes[i] = (uint8_t)(value >> (8 * i));
    return true;
  };
  hart->onIoStore = [](uint32_t address, size_t size, const uint8_t* bytes) {
    deviceWrite(address, size, bytes);
    return true;
  };
  return 0;
}

void refdut_fault(int kind, int atEvent) {
  faultKind = kind;
  faultAtEvent = (uint64_t)atEvent;
  faultInjected = false;
}

// the next event; returns 1 with the event that ends the program (tohost or exit device)
int refdut_next(int* kind, int* pc, int* insn, int* rd, int* rdValue, int* memoryKind,
                int* memoryAddress, int* memorySize, int* memoryReadWord, int* storeData, int* cause,
                int* mip, int* snapshot) {
  static StepOut repeated;
  static bool haveRepeated = false;
  StepOut out;
  bool faultArmed = faultKind && !faultInjected && eventCount >= faultAtEvent;
  uint32_t mstatus = hart->csr(CSR_MSTATUS), mie = hart->csr(CSR_MIE);
  bool forgedInterrupt = false;
  if (haveRepeated) {
    out = repeated;
    haveRepeated = false;
  } else if (faultArmed && faultKind == 17 && !(mstatus & MSTATUS_MIE)) {
    forgedInterrupt = true; out.cause = 11; out.mip = MIP_MEIP;           // while MIE = 0
  } else if (faultArmed && faultKind == 20 && (mstatus & MSTATUS_MIE) && !(mie & MIP_MSIP)) {
    forgedInterrupt = true; out.cause = 3; out.mip = MIP_MSIP;            // while its mie bit = 0
  } else {
    if (faultArmed && faultKind == 29) interruptNeverTaken = true;
    out = stepOnce();
    if (faultArmed && faultKind == 18 && out.kind == EVENT_RETIRE) {     // drop this retire
      markInjected();
      out = stepOnce();
    } else if (faultArmed && faultKind == 19 && out.kind == EVENT_RETIRE && !out.result.memory.isLoad &&
               !out.result.memory.isStore) {                              // report it twice
      markInjected();
      repeated = out;
      haveRepeated = true;
    }
  }
  if (forgedInterrupt) {
    markInjected();
    *kind = EVENT_INTERRUPT;
    *pc = hart->pc();
    *insn = *rd = *rdValue = 0;
    *memoryKind = MEMORY_NONE;
    *memoryAddress = *memorySize = *memoryReadWord = *storeData = 0;
    *cause = out.cause;
    *mip = out.mip;
    linesForged = true;
    forgedLines = out.mip;
    hart->readSnapshot((uint32_t*)snapshot);
    eventCount++;
    return 0;
  }
  StepResult& result = out.result;
  uint32_t ramWord = 0;
  if (result.memory.isLoad && hart->inRam(result.memory.address & ~3u, 4))
    memcpy(&ramWord, hart->ramPointer(result.memory.address & ~3u), 4);
  Fields f;
  f.kind = out.kind;
  f.pc = result.pc;
  f.insn = result.trapped ? 0 : result.insn;
  f.rd = result.rd;
  f.rdValue = result.rdValue;
  f.memoryKind = result.memory.isLoad ? MEMORY_LOAD : result.memory.isStore ? MEMORY_STORE : MEMORY_NONE;
  f.memoryAddress = result.memory.address;
  f.memorySize = result.memory.size;
  f.storeData = result.memory.storeData;
  bool loadInRam = hart->inRam(result.memory.address, result.memory.size);
  f.memoryReadWord = result.memory.isLoad ? (loadInRam ? ramWord : out.ioWord) : 0;
  f.cause = out.cause;
  f.mip = out.mip;
  f.snapshot = snapshot;
  for (int i = 0; i < SNAP_COUNT; i++) snapshot[i] = (int)result.snapshot[i];
  if (result.memory.isStore && result.memory.address == tohostAddress && tohostAddress) {
    programEnded = true;
    exitCode = result.memory.storeData;
  }
  linesForged = false;
  if (faultKind && !faultInjected && eventCount >= faultAtEvent && corrupt(f, mie, out.mip))
    markInjected();
  uint32_t reported = (uint32_t)f.insn, funct3 = (reported >> 12) & 3;
  if (f.kind == EVENT_RETIRE && (reported & 0x7f) == 0x73 && (reported >> 20) == CSR_MCYCLE && funct3)
    mcycleLastWritten = funct3 == 1 || ((reported >> 15) & 31) != 0;
  *kind = f.kind;
  *pc = f.pc;
  *insn = f.insn;
  *rd = f.rd;
  *rdValue = f.rdValue;
  *memoryKind = f.memoryKind;
  *memoryAddress = f.memoryAddress;
  *memorySize = f.memorySize;
  *memoryReadWord = f.memoryReadWord;
  *storeData = f.storeData;
  *cause = f.cause;
  *mip = f.mip;
  eventCount++;
  return programEnded ? 1 : 0;
}

int refdut_faultHit() { return faultInjected ? 1 : 0; }
int refdut_exitCode() { return (int)exitCode; }
int refdut_pc() { return (int)hart->pc(); }
// a fault that forges rt_mip forges the device lines too, so the checker's own mip checks fire
int refdut_lines() { return (int)(linesForged ? forgedLines : visibleLines); }

}
