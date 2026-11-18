// ================================================================================
//  hart.cc -- Spike hart with the Doggo-V7 core profile (decision 0048)
// ================================================================================
#include "hart.h"
#include <riscv/encoding.h>
#include <riscv/mmu.h>
#include <riscv/trap.h>
#include <iostream>

const uint16_t snapshotCsr[SNAP_COUNT] = {CSR_MSTATUS, CSR_MIE, CSR_MTVEC, CSR_MSCRATCH, CSR_MEPC,
                                          CSR_MCAUSE, CSR_MTVAL, CSR_MINSTRET, CSR_MINSTRETH};
const char* const snapshotName[SNAP_COUNT] = {"mstatus", "mie", "mtvec", "mscratch", "mepc",
                                              "mcause", "mtval", "minstret", "minstreth"};

// ---- mtvec MODE hard-wired to direct -------------------------------------------
class MtvecDirect : public csr_t {
public:
  MtvecDirect(processor_t* processor, csr_t_p inner) : csr_t(processor, CSR_MTVEC), inner(inner) {}
  reg_t read() const noexcept override { return inner->read(); }
protected:
  bool unlogged_write(const reg_t value) noexcept override {
    inner->write(value & ~(reg_t)3);
    return true;
  }
private:
  csr_t_p inner;
};

// ---- RV32 counter halves -------------------------------------------------------
// The pinned Spike merges a half write with the counter plus one, so csrw
// minstret then csrw minstreth loses the low word (rv32mi/instret_overflow).
class CounterHalf : public csr_t {
public:
  CounterHalf(processor_t* processor, reg_t address, csr_t_p counter, bool isHigh)
    : csr_t(processor, address), counter(counter), isHigh(isHigh) {}
  reg_t read() const noexcept override {
    return isHigh ? (counter->read() >> 32) & 0xffffffffu : counter->read() & 0xffffffffu;
  }
  void verify_permissions(insn_t insn, bool write) const override {
    counter->verify_permissions(insn, write);
  }
protected:
  bool unlogged_write(const reg_t value) noexcept override {
    reg_t current = counter->read();
    reg_t half = value & 0xffffffffu;
    counter->write(isHigh ? (current & 0xffffffffu) | (half << 32)
                          : (current & ~(reg_t)0xffffffffu) | half);
    return true;
  }
private:
  csr_t_p counter;
  bool isHigh;
};

Hart::Hart(uint32_t ramBase, uint32_t ramSize, const char* logPath, bool useProfile)
  : useProfile(useProfile), ram(ramSize, 0), ramBase(ramBase) {
  config.isa = "rv32imc_zba_zbb_zbs_zicond_zicsr_zifencei";
  config.priv = "m";
  config.misaligned = false;
  config.pmpregions = 0;
  config.trigger_count = 0;
  config.hartids = {0};
  log = fopen(logPath && *logPath ? logPath : "/dev/null", "w");
  processor = new processor_t(config.isa, config.priv, &config, this, 0, false, log, std::cerr);
  harts[0] = processor;
  processor->enable_log_commits();
  disassembler = new disassembler_t(&processor->get_isa());
  applyProfile();
}

Hart::~Hart() {
  delete disassembler;
  delete processor;
  if (log) fclose(log);
}

// ---- Core profile: the CSR set of 0048 -----------------------------------------
void Hart::applyProfile() {
  if (!useProfile) return;
  auto& csrs = processor->get_state()->csrmap;
  auto drop = [&](reg_t first, reg_t last) {
    for (reg_t address = first; address <= last; address++) csrs.erase(address);
  };
  drop(0x001, 0x003);                // fflags, frm, fcsr
  drop(0x320, 0x320);                // mcountinhibit
  drop(0x3a0, 0x3ef);                // PMP
  drop(0x747, 0x747);                // mseccfg
  drop(0x7a0, 0x7bf);                // triggers, debug
  for (reg_t address = 0x323; address <= 0x33f; address++)
    csrs[address] = std::make_shared<const_csr_t>(processor, address, 0);
  csrs[CSR_MISA] = std::make_shared<const_csr_t>(processor, CSR_MISA, csrs.at(CSR_MISA)->read());
  csrs[CSR_MVENDORID] = std::make_shared<const_csr_t>(processor, CSR_MVENDORID, 0);
  csrs[CSR_MARCHID] = std::make_shared<const_csr_t>(processor, CSR_MARCHID, 0);
  csrs[CSR_MIMPID] = std::make_shared<const_csr_t>(processor, CSR_MIMPID, 0);
  csrs[CSR_MTVEC] = std::make_shared<MtvecDirect>(processor, csrs.at(CSR_MTVEC));
  state_t* state = processor->get_state();
  csrs[CSR_MINSTRET] = std::make_shared<CounterHalf>(processor, CSR_MINSTRET, state->minstret, false);
  csrs[CSR_MINSTRETH] = std::make_shared<CounterHalf>(processor, CSR_MINSTRETH, state->minstret, true);
  csrs[CSR_MCYCLE] = std::make_shared<CounterHalf>(processor, CSR_MCYCLE, state->mcycle, false);
  csrs[CSR_MCYCLEH] = std::make_shared<CounterHalf>(processor, CSR_MCYCLEH, state->mcycle, true);
}

bool Hart::loadImage(const char* path) {
  FILE* file = fopen(path, "rb");
  if (!file) return false;
  size_t loaded = fread(ram.data(), 1, ram.size(), file);
  bool tooLarge = fgetc(file) != EOF;
  fclose(file);
  return loaded > 0 && !tooLarge;
}

void Hart::reset(uint32_t pc) {
  processor->reset();
  applyProfile();                    // reset() rebuilds the CSR map
  processor->get_state()->pc = pc;
}

char* Hart::addr_to_mem(reg_t address) {
  if (address >= ramBase && address - ramBase < ram.size()) return (char*)&ram[address - ramBase];
  return nullptr;
}

bool Hart::mmio_load(reg_t address, size_t size, uint8_t* bytes) {
  return onIoLoad ? onIoLoad((uint32_t)address, size, bytes) : false;
}

bool Hart::mmio_store(reg_t address, size_t size, const uint8_t* bytes) {
  return onIoStore ? onIoStore((uint32_t)address, size, bytes) : false;
}

uint32_t Hart::csr(uint16_t address) {
  auto& csrs = processor->get_state()->csrmap;
  auto found = csrs.find(address);
  return found == csrs.end() ? 0 : (uint32_t)found->second->read();
}

void Hart::readSnapshot(uint32_t* snapshot) {
  for (int i = 0; i < SNAP_COUNT; i++) snapshot[i] = csr(snapshotCsr[i]);
}

void Hart::setMip(uint32_t mask, uint32_t value) {
  processor->get_state()->mip->backdoor_write_with_mask(mask, value);
}

bool Hart::fetch(uint32_t pc, uint32_t& insn) {
  try {
    insn_fetch_t fetched = processor->get_mmu()->load_insn(pc);
    insn = (uint32_t)fetched.insn.bits();
    if ((insn & 3) != 3) insn &= 0xffff;
    return true;
  } catch (trap_t&) {
    insn = 0;
    return false;
  }
}

std::string Hart::disassemble(uint32_t insn) { return disassembler->disassemble(insn_t(insn)); }

StepResult Hart::step() {
  StepResult result;
  state_t* state = processor->get_state();
  state->log_reg_write.clear();
  state->log_mem_read.clear();
  state->log_mem_write.clear();
  result.pc = (uint32_t)state->pc;
  result.fetchOk = fetch(result.pc, result.insn);
  processor->clear_waiting_for_interrupt();      // the core treats wfi as a nop
  processor->step(1);
  const auto& written = state->log_reg_write;    // key: register << 4 | type (0 = x)
  result.trapped = written.count(((reg_t)CSR_MCAUSE << 4) | 4) &&
                   written.count(((reg_t)CSR_MEPC << 4) | 4);
  if (result.trapped) {
    if (useProfile && mtvalZeroOnIllegal && csr(CSR_MCAUSE) == CAUSE_ILLEGAL_INSTRUCTION)
      state->csrmap.at(CSR_MTVAL)->write(0);
  } else {
    for (auto& entry : written) {
      if ((entry.first & 0xf) == 0 && (entry.first >> 4) != 0) {
        result.rd = (int)(entry.first >> 4);
        result.rdValue = (uint32_t)entry.second.v[0];
      }
    }
    if (!state->log_mem_read.empty()) {
      auto& read = state->log_mem_read.back();
      result.memory.isLoad = true;
      result.memory.address = (uint32_t)std::get<0>(read);
      result.memory.size = std::get<2>(read);
    }
    if (!state->log_mem_write.empty()) {
      auto& write = state->log_mem_write.back();
      result.memory.isStore = true;
      result.memory.address = (uint32_t)std::get<0>(write);
      result.memory.size = std::get<2>(write);
      result.memory.storeData = (uint32_t)std::get<1>(write);
    }
  }
  readSnapshot(result.snapshot);
  return result;
}
