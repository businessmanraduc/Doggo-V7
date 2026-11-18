// ================================================================================
//  hart.h -- one Spike hart with the Doggo-V7 core profile, flat RAM, IO callbacks
// ================================================================================
#ifndef COSIM_HART_H
#define COSIM_HART_H

#include <riscv/processor.h>
#include <riscv/simif.h>
#include <riscv/cfg.h>
#include <riscv/disasm.h>
#include <cstdint>
#include <cstdio>
#include <functional>
#include <map>
#include <string>
#include <vector>

// ---- CSR snapshot compared after every event (order fixed, see README.md) ------
enum {
  SNAP_MSTATUS, SNAP_MIE, SNAP_MTVEC, SNAP_MSCRATCH, SNAP_MEPC, SNAP_MCAUSE, SNAP_MTVAL,
  SNAP_MINSTRET, SNAP_MINSTRETH, SNAP_COUNT
};
extern const uint16_t snapshotCsr[SNAP_COUNT];
extern const char* const snapshotName[SNAP_COUNT];

struct MemoryAccess {
  bool     isLoad = false, isStore = false;
  uint32_t address = 0, size = 0, storeData = 0;
};

struct StepResult {
  bool         trapped = false;       // exception or interrupt entry, nothing retired
  uint32_t     pc = 0, insn = 0;      // insn: low 16 bits for compressed
  bool         fetchOk = true;
  int          rd = 0;                // 0: no x register written
  uint32_t     rdValue = 0;
  MemoryAccess memory;
  uint32_t     snapshot[SNAP_COUNT];
};

class Hart : public simif_t {
public:
  Hart(uint32_t ramBase, uint32_t ramSize, const char* logPath, bool useProfile = true);
  ~Hart();

  bool loadImage(const char* path);
  void reset(uint32_t pc);
  StepResult step();                 // one retire, one exception or one interrupt entry
  void readSnapshot(uint32_t* snapshot);
  uint32_t pc() { return (uint32_t)processor->get_state()->pc; }
  uint32_t xreg(int index) { return (uint32_t)processor->get_state()->XPR[index]; }
  void setXreg(int index, uint32_t value) {
    if (index) processor->get_state()->XPR.write(index, (int32_t)value);
  }
  uint32_t csr(uint16_t address);
  void setMip(uint32_t mask, uint32_t value);
  bool fetch(uint32_t pc, uint32_t& insn);
  std::string disassemble(uint32_t insn);
  bool inRam(uint32_t address, uint32_t size) {
    return address >= ramBase && (uint64_t)address - ramBase + size <= ram.size();
  }
  uint8_t* ramPointer(uint32_t address) { return &ram[address - ramBase]; }

  bool mtvalZeroOnIllegal = true;

  std::function<bool(uint32_t, size_t, uint8_t*)> onIoLoad;
  std::function<bool(uint32_t, size_t, const uint8_t*)> onIoStore;

  // ---- simif_t -----------------------------------------------------------------
  char* addr_to_mem(reg_t address) override;
  bool mmio_fetch(reg_t, size_t, uint8_t*) override { return false; }
  bool mmio_load(reg_t address, size_t size, uint8_t* bytes) override;
  bool mmio_store(reg_t address, size_t size, const uint8_t* bytes) override;
  void proc_reset(unsigned) override {}
  const cfg_t& get_cfg() const override { return config; }
  const std::map<size_t, processor_t*>& get_harts() const override { return harts; }
  const char* get_symbol(uint64_t) override { return nullptr; }

  processor_t* processor = nullptr;

private:
  void applyProfile();
  bool useProfile;
  cfg_t config;
  std::map<size_t, processor_t*> harts;
  std::vector<uint8_t> ram;
  uint32_t ramBase;
  FILE* log = nullptr;
  disassembler_t* disassembler = nullptr;
};

#endif
