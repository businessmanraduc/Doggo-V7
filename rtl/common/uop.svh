`ifndef UOP_SVH
`define UOP_SVH
`include "isa.svh"
// ================================================================================
//  uop.svh -- the decoded micro-op: ID's output, the dispatch FIFO payload
// ================================================================================
//  Obe instruction's worth of decisions. subOp is read through the
//  fu-specific type: aluOp_t / shiftOp_t / memWidth_t / muldiv f3 / csr f3.
//
//  Exception contract: when excValid is set, every use/write/effect flag is
//  0 and only pc, isCompressed, rs1/rs2/rd, excCause are defined.
// ================================================================================

// ---- functional-unit class -----------------------------------------------------
typedef enum logic [2:0] {
  FU_ALU     = 3'd0,
  FU_SHIFTER = 3'd1,
  FU_MULDIV  = 3'd2,
  FU_LSU     = 3'd3,
  FU_BRANCH  = 3'd4,
  FU_SYS     = 3'd5
} fu_t;

// ---- FU_BRANCH subOp -----------------------------------------------------------
localparam logic [2:0] SUBOP_JAL  = 3'b010;
localparam logic [2:0] SUBOP_JALR = 3'b011;

typedef struct packed {
  logic [31:0] pc;
  logic        isCompressed;
  fu_t         fu;
  logic [2:0]  subOp;
  logic [4:0]  rs1Index;
  logic [4:0]  rs2Index;
  logic [4:0]  rdIndex;
  logic        rs1Used;
  logic        rs2Used;
  logic        regWrite;
  logic        pcUsed;
  logic        immUsed;
  logic [31:0] imm;
  logic        isStore;
  logic        csrUseZimm;
  logic        isMret;
  logic        isWfi;
  logic        isFenceI;
  logic        excValid;
  trapCause_t  excCause;
} uop_t;

`endif

