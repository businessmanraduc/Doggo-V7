# cosim

Lockstep checking against Spike. Every event the core retires
steps Spike once and is compared: pc, encoding, rd, memory access, CSR
snapshot.

## Files

| file | role |
|---|---|
| hart.h, hart.cc | Spike hart with the core profile (0048), flat RAM, IO callbacks |
| cosim.cc | the checker, called through DPI-C |
| cosim_order.sv | puts pending loads (0035) back in program order |
| iodev.sv, iodev_tb.sv | test devices on the IO bus (0042) |
| refdut.cc, refdut_tb.sv | stand-in core: Spike plus the devices, with fault injection |
| gen/rvgen.py | random programs, profiles full and m2 |
| prog/ | directed programs, link.ld |

| suite | runs |
|---|---|
| build.sh | builds refdut_tb |
| rt_suite.sh | riscv-tests on refdut |
| act_suite.sh | riscv-arch-test on refdut |
| nc_suite.sh | 44 negative controls of the checker and cosim_order |
| gen_suite.sh | rvgen programs on refdut, coverage |
| iodev_suite.sh | iodev against its model, 8 mutants |
| core_suite.sh | the M2 core (rtl/core) on rvgen m2 programs |
| prog_run.sh | one ELF on refdut |

All run inside nix-shell from Doggo-V7-dev/.

## Retire port (one event per cycle, program order)

| field | meaning |
|---|---|
| rt_kind | 0 retire, 1 exception, 2 interrupt entry |
| rt_pend | load retired without data (0035, every IO load 0042) |
| rt_pc | pc of the instruction; for an interrupt, mepc |
| rt_insn | encoding, low 16 bits for compressed |
| rt_rd, rt_rdVal | x register written (rd 0: none) |
| rt_memKind | 0 none, 1 load, 2 store |
| rt_memAddr, rt_memSize | byte address, 1/2/4 |
| rt_memWdata | store data, size-masked, not shifted |
| rt_memRdata | IO loads: the 32-bit word holding the access |
| rt_cause | interrupt entry: 3, 7 or 11 |
| rt_mip | pending lines (MSIP, MTIP, MEIP) seen for this event |
| rt_snap[9] | after the event: mstatus mie mtvec mscratch mepc mcause mtval minstret minstreth |

Late port: lv_valid, lv_rdVal (aligned, extended), lv_word (raw word). One
pending load at a time; it may complete in its own retire cycle. Ports are
sampled at posedge. At the end the bench passes its next pc to cosim_finish.

## Checker rules

- Every field above is compared on every event; a trap on one side only fails.
- IO load: Spike reads rt_memRdata and must issue exactly that access, once.
- Interrupts: Spike takes the cause from the DUT's lines (priority and enable
  checked by Spike). An enabled pending interrupt may wait 64 events.
- mcycle, mcycleh, mip reads take the DUT value. mcycle(h) must not go back;
  a mip read equals rt_mip, no bits outside 0x888.
- cosim_order: rt_mip equals the device lines SYNC_MIN..SYNC_MAX cycles back.
- wfi is a nop on both sides (0048).

## Core profile on the reference (0048)

Absent (illegal): fflags/frm/fcsr, mcountinhibit, PMP, mseccfg, triggers,
debug CSRs, user counters. Constant: misa, mvendorid, marchid, mimpid, mhartid,
mconfigptr 0, mhpmcounter3..31(h), mhpmevent3..31 0. mtvec MODE direct. mtval 0
on an illegal instruction. RV32 counter halves fixed against a pinned-Spike bug.
