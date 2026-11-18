# =================================================================================
# dv_basic: every checker path once (IO, interrupts, traps, CSR profile, fence.i)
# =================================================================================
# Devices (refdut.cc): scratch 0x10000000, counter +0x100, fifo +0x104,
# irq lines +0x108 (bits 3/7/11), irq timer +0x10c, console +0x110, exit +0x114.
# Trap handler owns t5, t6, s10, s11; main code never uses them.
  .section .text.init
  .globl _start
_start:
  la    t0, handler
  csrw  mtvec, t0
  li    s0, 0x10000000          # device base
  la    s1, buf                 # RAM buffer
  li    s2, 0                   # checksum
  li    s11, 0                  # interrupt count (handler)
  li    s10, 0                  # exception count (handler)

# ---- RAM loads and stores, every size -------------------------------------------
  li    t0, 0x8899aabb
  sw    t0, 0(s1)
  sh    t0, 6(s1)
  sb    t0, 9(s1)
  lw    t1, 0(s1)
  lh    t2, 6(s1)
  lhu   t3, 6(s1)
  lb    t4, 9(s1)
  lbu   a0, 9(s1)
  add   s2, s2, t1
  add   s2, s2, t2
  add   s2, s2, t3
  add   s2, s2, t4
  add   s2, s2, a0

# ---- IO: scratch, non-idempotent counter and fifo -------------------------------
  li    t0, 0x12345678
  sw    t0, 0(s0)
  sb    t0, 5(s0)
  sh    t0, 10(s0)
  lw    t1, 0(s0)
  lb    t2, 1(s0)
  lbu   t3, 5(s0)
  lh    t4, 10(s0)
  lhu   a0, 2(s0)
  lw    a1, 0x100(s0)
  lw    a2, 0x100(s0)
  lw    a3, 0x104(s0)
  lh    a4, 0x106(s0)
  lw    a5, 0x200(s0)           # unmapped: reads 0
  sw    t0, 0x204(s0)           # unmapped: dropped
  add   s2, s2, t1
  add   s2, s2, t2
  add   s2, s2, t3
  add   s2, s2, t4
  add   s2, s2, a0
  sub   a6, a2, a1
  add   s2, s2, a6
  add   s2, s2, a3
  add   s2, s2, a4
  add   s2, s2, a5

# ---- CSR profile ----------------------------------------------------------------
  csrr  t0, mcycle
  csrr  t1, mcycleh
  csrr  t2, mip
  csrr  t3, misa
  li    t4, -1
  csrw  misa, t4                # read-only
  csrr  t4, misa
  sub   t4, t4, t3
  add   s2, s2, t4
  la    t0, handler
  ori   t0, t0, 1
  csrw  mtvec, t0               # MODE stays direct
  csrr  t1, mtvec
  add   s2, s2, t1
  csrr  t0, marchid
  csrr  t1, mhartid
  csrr  t2, mhpmcounter3
  csrw  mhpmevent3, t4
  csrr  t3, mhpmevent3
  csrr  t4, mstatush
  add   s2, s2, t0
  add   s2, s2, t1
  add   s2, s2, t2
  add   s2, s2, t3
  add   s2, s2, t4
  csrw  mscratch, s2
  csrr  t0, mscratch
  csrw  mcountinhibit, x0       # absent: illegal
  csrr  t0, tselect             # absent: illegal
  csrr  t0, pmpaddr0            # absent: illegal
  li    t0, 0xffffffff
  csrw  minstret, t0
  csrw  minstreth, t0
  nop
  csrr  t1, minstret
  csrr  t2, minstreth
  add   s2, s2, t1
  add   s2, s2, t2
  li    t0, 0x1000              # mcycle writes: csrrw, csrrc, csrrs, x0-destination merge
  csrw  mcycle, t0
  csrr  a0, mcycle
  csrrc a1, mcycle, t0
  csrr  a2, mcycle
  csrrs a3, mcycle, t0
  csrr  a4, mcycle
  li    t0, 5
  csrw  mcycleh, t0
  csrr  a5, mcycleh
  csrsi mcycle, 1
  csrr  a6, mcycle
  csrr  a7, mcycleh

# ---- synchronous exceptions -----------------------------------------------------
  ecall
  ebreak
  .word 0                       # illegal, 32-bit
  .half 0                       # illegal, compressed
  addi  t0, s1, 1
  lw    t1, 0(t0)               # misaligned load
  sw    t1, 2(s1)               # misaligned store
  lh    t1, 1(s1)
  li    t0, 0x20000000
  jalr  ra, t0                  # fetch from IO: access fault, handler returns to ra
  add   s2, s2, s10

# ---- interrupts -----------------------------------------------------------------
  li    t0, 0x888               # MEIE | MTIE | MSIE
  csrw  mie, t0
  csrr  t1, mip                 # nothing pending yet
  csrsi mstatus, 8
  li    t0, 8
  sw    t0, 0x108(s0)           # software interrupt
5:
  beqz  s11, 5b
  li    t0, 0x800
  sw    t0, 0x108(s0)           # external interrupt
  li    t2, 2
6:
  blt   s11, t2, 6b
  li    t0, 40
  sw    t0, 0x10c(s0)           # timer in 40 steps
1:
  addi  t1, t1, 1
  li    t2, 3
  blt   s11, t2, 1b
  csrci mstatus, 8              # disabled: pending line visible in mip only
  li    t0, 0x80
  sw    t0, 0x108(s0)
  li    t2, 20
2:
  addi  t2, t2, -1
  bnez  t2, 2b
  csrr  t3, mip
  wfi                           # pending (disabled): wfi falls through
  sw    zero, 0x108(s0)
  csrsi mstatus, 8
  li    t0, 30
  sw    t0, 0x10c(s0)
  wfi                           # wakes on the timer
3:
  li    t2, 4
  blt   s11, t2, 3b
  add   s2, s2, s11
  li    t0, 0x880               # MSIE clear, MIE set: a software interrupt is not enabled
  csrw  mie, t0
  li    t2, 20
7:
  addi  t2, t2, -1
  bnez  t2, 7b
  csrci mstatus, 8

# ---- fence.i: run code written by stores ----------------------------------------
  la    t0, code
  li    t1, 0x00150513          # addi a0, a0, 1
  sw    t1, 0(t0)
  sw    t1, 4(t0)
  li    t1, 0x00008067          # ret
  sw    t1, 8(t0)
  fence.i
  li    a0, 5
  jalr  ra, t0
  add   s2, s2, a0
  li    t1, 0x00350513          # addi a0, a0, 3
  sw    t1, 4(t0)
  fence.i
  jalr  ra, t0
  add   s2, s2, a0

# ---- end: checksum to RAM and console, exit 0 -----------------------------------
  sw    s2, 12(s1)
  li    t0, 'o'
  sb    t0, 0x110(s0)
  li    t0, 'k'
  sb    t0, 0x110(s0)
  li    t0, '\n'
  sb    t0, 0x110(s0)
  sw    zero, 0x114(s0)
4:
  j     4b

# ---- trap handler: count interrupts, skip faulting instructions -----------------
  .balign 4
handler:
  csrr  t6, mcause
  bltz  t6, irq
  li    t5, 1
  beq   t6, t5, fetchfault
  csrr  t5, mepc
  lhu   t6, 0(t5)
  andi  t6, t6, 3
  addi  t5, t5, 2
  addi  t6, t6, -3
  bnez  t6, 1f
  addi  t5, t5, 2
1:
  csrw  mepc, t5
  addi  s10, s10, 1
  mret
fetchfault:
  csrw  mepc, ra
  addi  s10, s10, 16
  mret
irq:
  li    t5, 0x10000000
  sw    zero, 0x108(t5)         # drop all lines
  addi  s11, s11, 1
  mret

  .section .data
  .balign 64
buf:
  .space 64
  .balign 64
code:
  .space 64
