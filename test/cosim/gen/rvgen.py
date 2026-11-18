#!/usr/bin/env python3
# =================================================================================
#  rvgen.py -- seeded random programs for the lockstep checker
# =================================================================================
#  usage: rvgen.py <seed> <out.S> [--len N] [--profile full|m2]
#  full: RV32IMC + Zicsr + Zifencei for an OoO core: short RAW/WAW distances,
#  store/load aliasing, D$ conflict sets, mul/div edge operands, forward
#  branches, calls, indirect jumps, traps, CSRs, IO, interrupts, fence.i.
#  Terminates by construction; ends on the exit device. Registers: gp data, sp
#  stack, tp IO, x27/x28 loop counters, t5/t6 trap handler only.
#  m2: what the M2 core executes (ALU, jumps onto the next instruction), ends
#  at the _end label.
# =================================================================================
import argparse
import random

POOL = [1] + list(range(5, 27)) + [29]
DATA_BASE = 0x80200000
DCACHE_WAY_SIZE = 16384
IO_BASE = 0x10000000

REG_ALU = ["add", "sub", "and", "or", "xor", "sll", "srl", "sra", "slt", "sltu"]
IMM_ALU = ["addi", "andi", "ori", "xori", "slti", "sltiu"]
IMM_SHIFT = ["slli", "srli", "srai"]
MUL_OPS = ["mul", "mulh", "mulhsu", "mulhu"]
DIV_OPS = ["div", "divu", "rem", "remu"]
LOADS = [("lb", 1), ("lbu", 1), ("lh", 2), ("lhu", 2), ("lw", 4)]
STORES = [("sb", 1), ("sh", 2), ("sw", 4)]
READ_CSRS = ["mscratch", "mstatus", "mie", "mip", "mcycle", "mcycleh", "minstret", "minstreth",
             "misa", "mtvec", "mepc", "mcause", "mtval", "mhartid", "marchid", "mhpmcounter3"]
PATCH_ADDI = 0x00000013 | 26 << 15 | 26 << 7        # addi s10, s10, imm


class Generator:
    def __init__(self, seed, length):
        self.random = random.Random(seed)
        self.length = length
        self.lines = []
        self.label_count = 0
        self.recent = []
        self.pool = POOL
        self.function_count = self.random.randint(2, 5)
        weight = lambda: self.random.choice([0, 1, 2, 4, 8])
        self.weights = {
            "ralu": 6, "ialu": 6, "shift": 2, "lui": 1, "mul": weight(), "div": weight(),
            "load": 3 + weight(), "store": 2 + weight(), "alias": weight(), "conflict": weight(),
            "branch": 2 + weight(), "call": weight() // 2, "ijump": weight() // 2, "csr": weight() // 2,
            "trap": weight() // 4, "io": weight() // 2, "fencei": weight() // 4, "fence": 1,
            "irqpoke": weight() // 4, "chain": weight(), "sp": 1 + weight() // 2,
            "jump": 1 + weight() // 2,
            "near": weight() // 4, "smc": weight() // 4, "waw": weight(), "ctl": weight() // 4,
        }
        self.raw_chance = self.random.choice([0.2, 0.5, 0.8])

    def emit(self, text):
        self.lines.append("  " + text)

    def new_label(self):
        self.label_count += 1
        return "L%d" % self.label_count

    def dest(self):
        reg = self.random.choice(self.pool) if self.random.random() > 0.03 else 0
        if reg:
            self.recent.append(reg)
            self.recent = self.recent[-6:]
        return reg

    def source(self):
        if self.recent and self.random.random() < self.raw_chance:
            return self.random.choice(self.recent[-3:])
        return self.random.choice(POOL + [0])

    def imm(self, bits):
        low, high = -(1 << (bits - 1)), (1 << (bits - 1)) - 1
        return self.random.choice([0, 1, -1, low, high, self.random.randint(low, high),
                                   self.random.randint(-8, 8)])

    @staticmethod
    def reg(index):
        return "x%d" % index

    def emit_reg_op(self, ops):
        op = self.random.choice(ops)
        rd = self.dest()
        rs1 = self.source()
        self.emit("%s %s, %s, %s" % (op, self.reg(rd), self.reg(rs1), self.reg(self.source())))

    # ---- instruction kinds ------------------------------------------------------
    def kind_ralu(self):
        self.emit_reg_op(REG_ALU)

    def kind_ialu(self):
        op = self.random.choice(IMM_ALU)
        self.emit("%s %s, %s, %d" % (op, self.reg(self.dest()), self.reg(self.source()), self.imm(12)))

    def kind_shift(self):
        op = self.random.choice(IMM_SHIFT)
        rd = self.dest()
        rs1 = self.source()
        self.emit("%s %s, %s, %d" % (op, self.reg(rd), self.reg(rs1), self.random.randint(0, 31)))

    def kind_lui(self):
        op = self.random.choice(["lui", "auipc"])
        self.emit("%s %s, %d" % (op, self.reg(self.dest()), self.random.randint(0, 0xfffff)))

    def kind_mul(self):
        self.emit_reg_op(MUL_OPS)

    def kind_div(self):
        a, b = self.source(), self.source()
        roll = self.random.random()
        if roll < 0.3:
            a, b = self.random.choice(self.pool), self.random.choice(self.pool)
        if roll < 0.15 and b:
            self.emit("li %s, 0" % self.reg(b))
        elif roll < 0.3 and a and b and a != b:
            self.emit("li %s, 0x80000000" % self.reg(a))
            self.emit("li %s, -1" % self.reg(b))
        op = self.random.choice(DIV_OPS)
        self.emit("%s %s, %s, %s" % (op, self.reg(self.dest()), self.reg(a), self.reg(b)))
        if self.random.random() < 0.3:
            op = self.random.choice(DIV_OPS)
            self.emit("%s %s, %s, %s" % (op, self.reg(self.dest()), self.reg(a), self.reg(b)))

    def address(self, size):
        roll = self.random.random()
        if roll < 0.6:
            return "gp", self.random.randrange(0, 256, size)
        base = self.random.choice(self.pool)
        if roll < 0.8:
            mask = 0xfc & ~(size - 1) & 0xff
            self.emit("andi %s, %s, %d" % (self.reg(base), self.reg(self.source()), mask))
            self.emit("add %s, %s, gp" % (self.reg(base), self.reg(base)))
            self.recent.append(base)
            return self.reg(base), 0
        conflict = DATA_BASE + self.random.randrange(1, 9) * DCACHE_WAY_SIZE
        self.emit("li %s, %d" % (self.reg(base), conflict))
        return self.reg(base), self.random.randrange(0, 64, size)

    def kind_load(self):
        op, size = self.random.choice(LOADS)
        base, offset = self.address(size)
        if self.random.random() < 0.03 and size > 1:
            offset += 1
        self.emit("%s %s, %d(%s)" % (op, self.reg(self.dest()), offset, base))

    def kind_store(self):
        op, size = self.random.choice(STORES)
        base, offset = self.address(size)
        if self.random.random() < 0.03 and size > 1:
            offset += 1
        self.emit("%s %s, %d(%s)" % (op, self.reg(self.source()), offset, base))

    def kind_alias(self):
        store, store_size = self.random.choice(STORES)
        load, load_size = self.random.choice(LOADS)
        offset = self.random.randrange(0, 248, 4)
        rs = self.source()
        store_offset = offset + self.random.randrange(0, 4, store_size)
        self.emit("%s %s, %d(gp)" % (store, self.reg(rs), store_offset))
        for _ in range(self.random.randint(0, 5)):
            self.one(["ralu", "ialu", "mul", "store"])
        rd = self.dest()
        load_offset = offset + self.random.randrange(0, 4, load_size)
        self.emit("%s %s, %d(gp)" % (load, self.reg(rd), load_offset))

    def kind_conflict(self):
        base = self.random.choice(self.pool)
        lines = self.random.randint(5, 9)
        line = self.random.randrange(0, 64, 4)
        for i in range(lines):
            self.emit("li %s, %d" % (self.reg(base), DATA_BASE + (i + 1) * DCACHE_WAY_SIZE + line))
            if self.random.random() < 0.5:
                self.emit("sw %s, 0(%s)" % (self.reg(self.source()), self.reg(base)))
            else:
                self.emit("lw %s, 0(%s)" % (self.reg(self.dest()), self.reg(base)))

    def kind_chain(self):
        reg = self.random.choice(self.pool)
        for _ in range(self.random.randint(3, 8)):
            step = self.random.choice(["addi", "mul", "xor", "ld"])
            if step == "addi":
                self.emit("addi %s, %s, %d" % (self.reg(reg), self.reg(reg), self.imm(12)))
            elif step == "mul":
                self.emit("mul %s, %s, %s" % (self.reg(reg), self.reg(reg), self.reg(self.source())))
            elif step == "xor":
                self.emit("xor %s, %s, %s" % (self.reg(reg), self.reg(reg), self.reg(self.source())))
            else:
                self.emit("andi %s, %s, 0xfc" % (self.reg(reg), self.reg(reg)))
                self.emit("add %s, %s, gp" % (self.reg(reg), self.reg(reg)))
                self.emit("lw %s, 0(%s)" % (self.reg(reg), self.reg(reg)))
        self.recent.append(reg)

    def kind_branch(self):
        op = self.random.choice(["beq", "bne", "blt", "bge", "bltu", "bgeu", "beqz", "bnez"])
        target = self.new_label()
        if op in ("beqz", "bnez"):
            self.emit("%s %s, %s" % (op, self.reg(self.source()), target))
        else:
            self.emit("%s %s, %s, %s" % (op, self.reg(self.source()), self.reg(self.source()), target))
        for _ in range(self.random.randint(0, 6)):
            self.one(["ralu", "ialu", "load", "store", "mul", "shift", "io", "csr", "trap", "div",
                      "waw"])
        self.lines.append(target + ":")

    def kind_sp(self):
        roll = self.random.random()
        if roll < 0.4:
            self.emit("lw %s, %d(sp)" % (self.reg(self.dest()), self.random.randrange(0, 256, 4)))
        elif roll < 0.8:
            self.emit("sw %s, %d(sp)" % (self.reg(self.source()), self.random.randrange(0, 256, 4)))
        elif roll < 0.9:
            reg = self.random.choice([8, 9, 10, 11, 12, 13, 14, 15])
            self.emit("addi %s, sp, %d" % (self.reg(reg), self.random.randrange(4, 1020, 4)))
        else:
            step = self.random.randrange(16, 496, 16)
            self.emit("addi sp, sp, %d" % step)
            self.emit("lw %s, 0(sp)" % self.reg(self.dest()))
            self.emit("addi sp, sp, -%d" % step)

    def kind_jump(self):
        target = self.new_label()
        self.emit("j %s" % target)
        for _ in range(self.random.randint(0, 3)):
            self.one(["ralu", "ialu"])
        self.lines.append(target + ":")

    def kind_near(self):
        function, after = self.new_label(), self.new_label()
        self.emit("jal ra, %s" % function)
        self.emit("j %s" % after)
        self.lines.append(function + ":")
        saved, self.pool = self.pool, [reg for reg in self.pool if reg != 1]
        for _ in range(self.random.randint(1, 4)):
            self.one(["ralu", "ialu", "load", "mul"])
        self.pool = saved
        self.emit("ret")
        self.lines.append(after + ":")

    def kind_smc(self):
        base, word = self.random.sample(self.pool, 2)
        target = self.new_label()
        insn = PATCH_ADDI | (self.random.randint(-2048, 2047) & 0xfff) << 20
        self.emit("la %s, %s" % (self.reg(base), target))
        self.emit("li %s, 0x%08x" % (self.reg(word), insn))
        self.emit("sw %s, 0(%s)" % (self.reg(word), self.reg(base)))
        self.emit("fence.i")
        self.lines += ["  .balign 4", "  .option push", "  .option norvc", target + ":",
                       "  addi s10, s10, 1", "  .option pop"]

    def kind_waw(self):
        reg = self.random.choice(self.pool)
        roll = self.random.random()
        if roll < 0.4:
            op = self.random.choice(DIV_OPS)
            rs1 = self.source()
            self.emit("%s %s, %s, %s" % (op, self.reg(reg), self.reg(rs1), self.reg(self.source())))
        elif roll < 0.7:
            address = DATA_BASE + self.random.randrange(1, 9) * DCACHE_WAY_SIZE
            address += self.random.randrange(0, 64, 4)
            self.emit("li %s, %d" % (self.reg(reg), address))
            self.emit("lw %s, 0(%s)" % (self.reg(reg), self.reg(reg)))
        else:
            rs1 = self.source()
            self.emit("mulh %s, %s, %s" % (self.reg(reg), self.reg(rs1), self.reg(self.source())))
        for _ in range(self.random.randint(0, 2)):
            self.one(["ralu", "ialu"])
        self.emit("addi %s, %s, %d" % (self.reg(reg), self.reg(self.source()), self.imm(12)))
        self.recent.append(reg)

    def kind_ctl(self):
        reg = self.random.choice(self.pool)
        roll = self.random.randrange(4)
        if roll == 0:
            self.emit(self.random.choice(["csrsi mstatus, 8", "csrci mstatus, 8"]))
        elif roll == 1:
            self.emit("la %s, handler" % self.reg(reg))
            self.emit("ori %s, %s, %d" % (self.reg(reg), self.reg(reg), self.random.randrange(4)))
            self.emit("csrw mtvec, %s" % self.reg(reg))
        elif roll == 2:
            op = self.random.choice(["csrrw", "csrrs", "csrrc"])
            rd = self.dest()
            counter = self.random.choice(["mcycle", "mcycleh"])
            self.emit("%s %s, %s, %s" % (op, self.reg(rd), counter, self.reg(self.source())))
        else:
            op = self.random.choice(["csrrwi", "csrrsi", "csrrci"])
            self.emit("%s %s, mcycle, %d" % (op, self.reg(self.dest()), self.random.randrange(32)))

    def kind_call(self):
        self.emit("jal ra, F%d" % self.random.randrange(self.function_count))

    def kind_ijump(self):
        base = self.random.choice(self.pool)
        target = self.new_label()
        if self.random.random() < 0.5:
            self.emit("la %s, F%d" % (self.reg(base), self.random.randrange(self.function_count)))
            self.emit("jalr ra, %s" % self.reg(base))
        else:
            self.emit("la %s, %s" % (self.reg(base), target))
            self.emit("jr %s" % self.reg(base))
            for _ in range(self.random.randint(1, 4)):
                self.one(["ralu", "load", "store", "io", "csr", "trap", "div"])
            self.lines.append(target + ":")

    def kind_csr(self):
        roll = self.random.random()
        if roll < 0.6:
            rd = self.dest()
            self.emit("csrr %s, %s" % (self.reg(rd), self.random.choice(READ_CSRS)))
        elif roll < 0.8:
            rd = self.dest()
            self.emit("csrrw %s, mscratch, %s" % (self.reg(rd), self.reg(self.source())))
        elif roll < 0.9:
            rd = self.dest()
            self.emit("csrrs %s, mie, %s" % (self.reg(rd), self.reg(self.source())))
        else:
            self.emit("csrw minstret, %s" % self.reg(self.source()))

    def kind_trap(self):
        roll = self.random.randrange(5)
        if roll == 0:
            self.emit("ecall")
        elif roll == 1:
            self.emit("ebreak")
        elif roll == 2:
            self.emit(".word 0")
        elif roll == 3:
            self.emit("csrr %s, mcountinhibit" % self.reg(self.dest()))
        else:
            base = self.random.choice(self.pool)
            self.emit("li %s, 0x20000000" % self.reg(base))
            self.emit("jalr ra, %s" % self.reg(base))

    def kind_io(self):
        roll = self.random.random()
        if roll < 0.4:
            op, size = self.random.choice(LOADS)
            rd = self.dest()
            self.emit("%s %s, %d(tp)" % (op, self.reg(rd), self.random.randrange(0, 256, size)))
        elif roll < 0.7:
            op, size = self.random.choice(STORES)
            rs = self.source()
            self.emit("%s %s, %d(tp)" % (op, self.reg(rs), self.random.randrange(0, 256, size)))
        else:
            rd = self.dest()
            self.emit("lw %s, %d(tp)" % (self.reg(rd), self.random.choice([0x100, 0x104])))

    def kind_fencei(self):
        base, word = self.random.sample(self.pool, 2)
        insn = PATCH_ADDI | (self.random.randint(-2048, 2047) & 0xfff) << 20
        self.emit("la %s, PATCH" % self.reg(base))
        self.emit("li %s, 0x%08x" % (self.reg(word), insn))
        self.emit("sw %s, 0(%s)" % (self.reg(word), self.reg(base)))
        self.emit("fence.i")
        self.emit("jal ra, PATCH")

    def kind_fence(self):
        self.emit("fence")

    def kind_irqpoke(self):
        reg = self.random.choice(self.pool)
        roll = self.random.random()
        if roll < 0.4:
            self.emit("li %s, %d" % (self.reg(reg), self.random.choice([8, 0x800, 0x808])))
            self.emit("sw %s, 0x108(tp)" % self.reg(reg))
        elif roll < 0.8:
            self.emit("li %s, %d" % (self.reg(reg), self.random.randint(1, 60)))
            self.emit("sw %s, 0x10c(tp)" % self.reg(reg))
        else:
            self.emit("wfi")

    # ---- program ----------------------------------------------------------------
    def one(self, kinds=None):
        kinds = [kind for kind in (kinds or self.weights) if self.weights.get(kind, 1) > 0] or ["ialu"]
        weights = [self.weights.get(kind, 1) for kind in kinds]
        getattr(self, "kind_" + self.random.choices(kinds, weights)[0])()

    def block(self, count):
        for _ in range(count):
            self.one()

    def program(self):
        self.lines += ["# rvgen seed program", "  .section .text.init", "  .globl _start", "_start:"]
        self.emit("la t5, handler")
        self.emit("csrw mtvec, t5")
        self.emit("li gp, 0x%08x" % DATA_BASE)
        self.emit("li tp, 0x%08x" % IO_BASE)
        self.emit("li sp, 0x%08x" % (DATA_BASE + 0x1000))
        for reg in POOL:
            self.emit("li %s, %d" % (self.reg(reg), self.random.randint(-2**31, 2**31 - 1)))
        if self.random.random() < 0.6:
            self.emit("li t5, 0x%x" % self.random.choice([0x888, 0x800, 0x80, 0x8, 0x880]))
            self.emit("csrw mie, t5")
            self.emit("csrsi mstatus, 8")
        done = 0
        while done < self.length:
            if self.random.random() < 0.3:
                counter = self.random.choice([27, 28])
                count = self.random.randint(3, 25)
                self.emit("li %s, %d" % (self.reg(counter), self.random.randint(2, 12)))
                top = self.new_label()
                self.lines.append(top + ":")
                self.block(count)
                self.emit("addi %s, %s, -1" % (self.reg(counter), self.reg(counter)))
                self.emit("bnez %s, %s" % (self.reg(counter), top))
                done += count
            else:
                count = self.random.randint(5, 40)
                self.block(count)
                done += count
        self.emit("li t5, 0x%08x" % (IO_BASE + 0x114))
        self.emit("sw zero, 0(t5)")
        self.lines.append("1:")
        self.emit("j 1b")
        saved = dict(self.weights)                       # leaf functions
        for kind in ("call", "ijump", "fencei", "trap", "near", "smc"):
            self.weights[kind] = 0
        self.pool = [reg for reg in POOL if reg != 1]
        self.recent = []
        for function in range(self.function_count):
            self.lines.append("  .balign %d" % self.random.choice([2, 4, 64]))
            self.lines.append("F%d:" % function)
            self.block(self.random.randint(2, 12))
            self.emit("ret")
        self.weights = saved
        self.lines += ["  .balign 4", "PATCH:", "  .option push", "  .option norvc",
                       "  addi s10, s10, 1", "  ret", "  .option pop"]
        self.lines += TRAP_HANDLER.splitlines()
        self.lines += ["  .section .data", "  .balign 64", "  .space 64"]
        return "\n".join(self.lines) + "\n"


TRAP_HANDLER = """
# trap handler: t5, t6 only
  .balign 4
handler:
  csrr  t6, mcause
  bltz  t6, 3f
  addi  t6, t6, -1
  beqz  t6, 2f
  csrr  t6, mepc
  lhu   t5, 0(t6)
  andi  t5, t5, 3
  addi  t6, t6, 2
  addi  t5, t5, -3
  bnez  t5, 1f
  addi  t6, t6, 2
1:
  csrw  mepc, t6
  mret
2:
  csrw  mepc, ra
  mret
3:
  li    t6, 0x10000000
  sw    zero, 0x108(t6)
  mret
"""


# ---- profile m2 -----------------------------------------------------------------
M2_POOL = list(range(1, 32))
M2_REG_OPS = ["add", "sub", "and", "or", "xor", "andn", "orn", "xnor"]
M2_IMM_OPS = ["addi", "andi", "ori", "xori"]


class GeneratorM2(Generator):
    def __init__(self, seed, length):
        super().__init__(seed, length)
        self.pool = M2_POOL
        weight = lambda: self.random.choice([0, 1, 2, 4, 8])
        self.weights = {
            "ralu": 6, "ialu": 6, "lui": 1 + weight() // 2, "cform": 2 + weight(), "link": weight() // 2,
            "zero": weight() // 4, "chain": weight(), "waw": weight(), "self": weight() // 2,
        }
        self.distance_weights = self.random.choice([[8, 4, 2, 2, 1, 1, 1, 1], [1] * 8,
                                                    [1, 1, 2, 2, 4, 4, 8, 8]])

    def remember(self, reg):
        self.recent = (self.recent + [reg])[-8:]

    def source(self):
        if self.recent and self.random.random() < self.raw_chance:
            distance = self.random.choices(range(1, 9), self.distance_weights)[0]
            return self.recent[-min(distance, len(self.recent))]
        return self.random.choice(M2_POOL + [0])

    def dest(self):
        reg = self.random.choice(M2_POOL)
        self.remember(reg)
        return reg

    def kind_ralu(self):
        a, b = self.source(), self.source()
        op = self.random.choice(M2_REG_OPS)
        self.emit("%s %s, %s, %s" % (op, self.reg(self.dest()), self.reg(a), self.reg(b)))

    def kind_ialu(self):
        a = self.source()
        op = self.random.choice(M2_IMM_OPS)
        self.emit("%s %s, %s, %d" % (op, self.reg(self.dest()), self.reg(a), self.imm(12)))

    def kind_lui(self):
        op = self.random.choice(["lui", "auipc"])
        rd = self.dest()
        value = self.random.choice([0, 1, 0xfffff, self.random.randint(0, 0xfffff)])
        self.emit("%s %s, %d" % (op, self.reg(rd), value))

    def kind_cform(self):
        p, q = self.random.randrange(8, 16), self.random.randrange(8, 16)
        if self.recent and self.random.random() < self.raw_chance:
            q = self.random.choice([reg for reg in self.recent if 8 <= reg < 16] or [q])
        shape = self.random.randrange(12)
        forms = ["addi x{p}, x{p}, %d" % (self.random.randint(-32, 31) or 1),
                 "li x{p}, %d" % self.random.randint(-32, 31),
                 "mv x{p}, x{q}", "add x{p}, x{p}, x{q}", "and x{p}, x{p}, x{q}", "or x{p}, x{p}, x{q}",
                 "xor x{p}, x{p}, x{q}", "sub x{p}, x{p}, x{q}",
                 "andi x{p}, x{p}, %d" % self.random.randint(-32, 31),
                 "lui x{p}, %d" % self.random.randint(1, 31),
                 "addi x{p}, sp, %d" % self.random.randrange(4, 1020, 4),
                 "addi sp, sp, %d" % (self.random.choice([-1, 1]) * self.random.randrange(16, 496, 16))]
        self.emit(forms[shape].format(p=p, q=q))
        self.remember(2 if shape == 11 else p)

    def kind_link(self):
        target = self.new_label()
        shape = self.random.randrange(4)
        if shape == 0:
            self.emit("%s %s" % (self.random.choice(["c.jal", "jal ra,"]), target))   # no relaxation
            self.remember(1)
        elif shape == 1:
            self.emit("j %s" % target)
        else:
            self.lines += ["  .option push", "  .option norvc"]
            self.emit("jal %s, %s" % (self.reg(self.dest() if shape == 2 else 0), target))
            self.lines.append("  .option pop")
        self.lines.append(target + ":")

    def kind_zero(self):
        a, b = self.source(), self.source()
        forms = ["add x0, %s, %s" % (self.reg(a), self.reg(b)), "nop",
                 "lui x0, %d" % self.random.randint(0, 0xfffff), "xori x0, %s, -1" % self.reg(a)]
        self.emit(self.random.choice(forms))

    def kind_chain(self):
        reg = self.random.choice(M2_POOL)
        for _ in range(self.random.randint(3, 10)):
            if self.random.randrange(3) == 0:
                self.emit("addi %s, %s, %d" % (self.reg(reg), self.reg(reg), self.imm(12)))
            else:
                op = self.random.choice(M2_REG_OPS)
                self.emit("%s %s, %s, %s" % (op, self.reg(reg), self.reg(reg), self.reg(self.source())))
        self.remember(reg)

    def kind_waw(self):
        reg = self.random.choice(M2_POOL)
        for _ in range(self.random.randint(2, 4)):
            op = self.random.choice(M2_REG_OPS)
            rs1 = self.source()
            self.emit("%s %s, %s, %s" % (op, self.reg(reg), self.reg(rs1), self.reg(self.source())))
        self.remember(reg)
        self.kind_ralu()

    def kind_self(self):
        a = self.recent[-1] if self.recent else 1
        op = self.random.choice(M2_REG_OPS)
        self.emit("%s %s, %s, %s" % (op, self.reg(self.dest()), self.reg(a), self.reg(a)))

    def program(self):
        self.lines += ["# rvgen m2 seed program", "  .section .text.init", "  .globl _start", "_start:"]
        for reg in M2_POOL:
            self.emit("li %s, %d" % (self.reg(reg), self.random.randint(-2**31, 2**31 - 1)))
        done = 0
        while done < self.length:
            count = self.random.randint(5, 40)
            self.block(count)
            done += count
        self.lines += ["  .globl _end", "_end:", "  .word 0"]
        return "\n".join(self.lines) + "\n"


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("seed", type=int)
    parser.add_argument("out")
    parser.add_argument("--len", type=int, default=3000)
    parser.add_argument("--profile", choices=["full", "m2"], default="full")
    args = parser.parse_args()
    generator = GeneratorM2 if args.profile == "m2" else Generator
    with open(args.out, "w") as out:
        out.write(generator(args.seed, args.len).program())


if __name__ == "__main__":
    main()
