`ifndef ISA_SVH
`define ISA_SVH
// ================================================================================
//  isa.svh -- RV32IMC + Zicsr encodings and core control codes
// ================================================================================
//  localparam   = fields decoded from raw instruction bits (overlapping values)
//  typedef enum = codes this core produces and only ever assigns by name
// ================================================================================

// ---- RV32I opcodes [6:0] -------------------------------------------------------
localparam logic [6:0] OP_LUI     = 7'b0110111;
localparam logic [6:0] OP_AUIPC   = 7'b0010111;
localparam logic [6:0] OP_JAL     = 7'b1101111;
localparam logic [6:0] OP_JALR    = 7'b1100111;
localparam logic [6:0] OP_BRANCH  = 7'b1100011;
localparam logic [6:0] OP_LOAD    = 7'b0000011;
localparam logic [6:0] OP_STORE   = 7'b0100011;
localparam logic [6:0] OP_ARITH_I = 7'b0010011;
localparam logic [6:0] OP_ARITH_R = 7'b0110011;
localparam logic [6:0] OP_SYSTEM  = 7'b1110011;
localparam logic [6:0] OP_FENCE   = 7'b0001111;

// ---- func3 [14:12] -------------------------------------------------------------
localparam logic [2:0] F3_BEQ     = 3'b000;
localparam logic [2:0] F3_BNE     = 3'b001;
localparam logic [2:0] F3_BLT     = 3'b100;
localparam logic [2:0] F3_BGE     = 3'b101;
localparam logic [2:0] F3_BLTU    = 3'b110;
localparam logic [2:0] F3_BGEU    = 3'b111;

localparam logic [2:0] F3_LB      = 3'b000;
localparam logic [2:0] F3_LH      = 3'b001;
localparam logic [2:0] F3_LW      = 3'b010;
localparam logic [2:0] F3_LBU     = 3'b100;
localparam logic [2:0] F3_LHU     = 3'b101;

localparam logic [2:0] F3_SB      = 3'b000;
localparam logic [2:0] F3_SH      = 3'b001;
localparam logic [2:0] F3_SW      = 3'b010;

localparam logic [2:0] F3_ADD     = 3'b000;
localparam logic [2:0] F3_SLL     = 3'b001;
localparam logic [2:0] F3_SLT     = 3'b010;
localparam logic [2:0] F3_SLTU    = 3'b011;
localparam logic [2:0] F3_XOR     = 3'b100;
localparam logic [2:0] F3_SRL     = 3'b101;
localparam logic [2:0] F3_OR      = 3'b110;
localparam logic [2:0] F3_AND     = 3'b111;

localparam logic [2:0] F3_JALR    = 3'b000;

localparam logic [2:0] F3_PRIV    = 3'b000;       // ECALL / EBREAK / MRET / WFI
localparam logic [2:0] F3_CSRRW   = 3'b001;
localparam logic [2:0] F3_CSRRS   = 3'b010;
localparam logic [2:0] F3_CSRRC   = 3'b011;
localparam logic [2:0] F3_CSRRWI  = 3'b101;
localparam logic [2:0] F3_CSRRSI  = 3'b110;
localparam logic [2:0] F3_CSRRCI  = 3'b111;

// ---- func7 [31:25] -------------------------------------------------------------
localparam logic [6:0] F7_NORMAL  = 7'b0000000;   // ADD, SRL, SLLI, SRLI
localparam logic [6:0] F7_ALT     = 7'b0100000;   // SUB, SRA, SRAI
localparam logic [6:0] F7_MULDIV  = 7'b0000001;   // RV32M

// ---- RV32M func3 [14:12] (opcode OP_ARITH_R + F7_MULDIV) -----------------------
localparam logic [2:0] F3_MUL     = 3'b000;
localparam logic [2:0] F3_MULH    = 3'b001;
localparam logic [2:0] F3_MULHSU  = 3'b010;
localparam logic [2:0] F3_MULHU   = 3'b011;
localparam logic [2:0] F3_DIV     = 3'b100;
localparam logic [2:0] F3_DIVU    = 3'b101;
localparam logic [2:0] F3_REM     = 3'b110;
localparam logic [2:0] F3_REMU    = 3'b111;

// ---- Full 32-bit SYSTEM encodings ----------------------------------------------
localparam logic [31:0] INSTR_ECALL  = 32'h0000_0073;
localparam logic [31:0] INSTR_EBREAK = 32'h0010_0073;
localparam logic [31:0] INSTR_MRET   = 32'h3020_0073;
localparam logic [31:0] INSTR_WFI    = 32'h1050_0073;
localparam logic [31:0] INSTR_FENCEI = 32'h0000_100F;

localparam logic [31:0] NOP_INSTR    = 32'h0000_0013;   // ADDI x0, x0, 0

// ---- RV32C quadrants [1:0] and func3 [15:13] -----------------------------------
localparam logic [1:0] CQ0 = 2'b00;
localparam logic [1:0] CQ1 = 2'b01;
localparam logic [1:0] CQ2 = 2'b10;

localparam logic [2:0] CF3_ADDI4SPN   = 3'b000;   // Q0
localparam logic [2:0] CF3_LW         = 3'b010;
localparam logic [2:0] CF3_SW         = 3'b110;

localparam logic [2:0] CF3_ADDI       = 3'b000;   // Q1, C.NOP when rd=0 and imm=0
localparam logic [2:0] CF3_JAL        = 3'b001;
localparam logic [2:0] CF3_LI         = 3'b010;
localparam logic [2:0] CF3_LUI        = 3'b011;   // C.ADDI16SP when rd == x2
localparam logic [2:0] CF3_ARITH      = 3'b100;
localparam logic [2:0] CF3_J          = 3'b101;
localparam logic [2:0] CF3_BEQZ       = 3'b110;
localparam logic [2:0] CF3_BNEZ       = 3'b111;

localparam logic [2:0] CF3_SLLI       = 3'b000;   // Q2
localparam logic [2:0] CF3_LWSP       = 3'b010;
localparam logic [2:0] CF3_MISC       = 3'b100;   // C.JR / C.MV / C.EBREAK / C.JALR / C.ADD
localparam logic [2:0] CF3_SWSP       = 3'b110;

// ---- CSR addresses [11:0] ------------------------------------------------------
localparam logic [11:0] CSR_MSTATUS   = 12'h300;
localparam logic [11:0] CSR_MISA      = 12'h301;
localparam logic [11:0] CSR_MIE       = 12'h304;
localparam logic [11:0] CSR_MTVEC     = 12'h305;
localparam logic [11:0] CSR_MSCRATCH  = 12'h340;
localparam logic [11:0] CSR_MEPC      = 12'h341;
localparam logic [11:0] CSR_MCAUSE    = 12'h342;
localparam logic [11:0] CSR_MTVAL     = 12'h343;
localparam logic [11:0] CSR_MIP       = 12'h344;
localparam logic [11:0] CSR_MVENDORID = 12'hF11;
localparam logic [11:0] CSR_MARCHID   = 12'hF12;
localparam logic [11:0] CSR_MIMPID    = 12'hF13;
localparam logic [11:0] CSR_MHARTID   = 12'hF14;

// ---- Hardwired CSR values ------------------------------------------------------
localparam logic [31:0] CSR_VAL_MVENDORID = 32'h0000_0000;   // non-commercial
localparam logic [31:0] CSR_VAL_MARCHID   = 32'h0000_0000;
localparam logic [31:0] CSR_VAL_MIMPID    = 32'h0000_0007;
localparam logic [31:0] CSR_VAL_MHARTID   = 32'h0000_0000;   // single hart
localparam logic [31:0] CSR_VAL_MISA      = 32'h4000_1104;   // MXL=32, I + M + C

// ---- mie / mip bit positions (interrupt cause shares the number) ---------------
localparam int IRQ_MSI = 3;
localparam int IRQ_MTI = 7;
localparam int IRQ_MEI = 11;

// ---- ALU operation -------------------------------------------------------------
typedef enum logic [3:0] {
  ALU_ADD   = 4'h0,
  ALU_SUB   = 4'h1,
  ALU_AND   = 4'h2,
  ALU_OR    = 4'h3,
  ALU_XOR   = 4'h4,
  ALU_SLL   = 4'h5,
  ALU_SRL   = 4'h6,
  ALU_SRA   = 4'h7,
  ALU_SLT   = 4'h8,
  ALU_SLTU  = 4'h9,
  ALU_PASSB = 4'hA
} aluOp_t;

// ---- CSR operation (from func3[1:0]) -------------------------------------------
typedef enum logic [1:0] {
  CSR_OP_NONE = 2'b00,
  CSR_OP_RW   = 2'b01,
  CSR_OP_RS   = 2'b10,
  CSR_OP_RC   = 2'b11
} csrOp_t;

// ---- Load / store width (mirrors load func3) -----------------------------------
typedef enum logic [2:0] {
  WIDTH_B  = 3'b000,
  WIDTH_H  = 3'b001,
  WIDTH_W  = 3'b010,
  WIDTH_BU = 3'b100,
  WIDTH_HU = 3'b101
} memWidth_t;

// ---- Synchronous trap causes (mcause[3:0], mcause[31] = 0) ---------------------
typedef enum logic [3:0] {
  TRAP_INSTR_MISALIGN = 4'd0,
  TRAP_INSTR_FAULT    = 4'd1,
  TRAP_ILLEGAL_INSTR  = 4'd2,
  TRAP_BREAKPOINT     = 4'd3,
  TRAP_LOAD_MISALIGN  = 4'd4,
  TRAP_LOAD_FAULT     = 4'd5,
  TRAP_STORE_MISALIGN = 4'd6,
  TRAP_STORE_FAULT    = 4'd7,
  TRAP_ECALL_M        = 4'd11
} trapCause_t;

`endif

