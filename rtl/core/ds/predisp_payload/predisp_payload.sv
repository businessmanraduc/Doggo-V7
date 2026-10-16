// ================================================================================
//  PreDS payload: decoder fields from R2 to DS
// ================================================================================
//  RD2             PreDS                        DS
//  rename R2  ───► predisp (tag -> slot) ───┬─► dispatch (IQ/ROB write)
//  decoder R2 ───► predisp_payload (hold) ──┘
// ================================================================================
//  Payload only: predisp owns valid, stall and kill. Holds while DS stalls.
// ================================================================================
`include "uop_defs.svh"

module predisp_payload #(
  parameter int MW = 1
) (
  input  logic                 clk,
  // ---- Rename-2/Dispatch-1 inter-stage pipeline register -----------------------
  input  logic [30:0]          r2_pds_pc,
  input  logic [MW-1:0]        r2_pds_meta,
  input  logic                 r2_pds_isCall,
  input  logic                 r2_pds_isRet,
  input  logic [30:0]          r2_pds_branchTarget,
  input  logic [30:0]          r2_pds_seq,
  input  logic [CLASS_W-1:0]   r2_pds_class,
  input  logic                 r2_pds_sub,          // sub, slt, sltu, branch
  input  logic                 r2_pds_selArith,
  input  logic                 r2_pds_selAnd,
  input  logic                 r2_pds_selOr,
  input  logic                 r2_pds_selXor,
  input  logic                 r2_pds_selSlt,
  input  logic                 r2_pds_sltUnsigned,  // sltu, sltiu, bltu, bgeu
  input  logic                 r2_pds_shiftRight,
  input  logic                 r2_pds_shiftArith,
  input  logic                 r2_pds_xIsPC,
  input  logic                 r2_pds_xIsZero,
  input  logic                 r2_pds_zIsImm,
  input  logic                 r2_pds_zIsZero,
  input  logic                 r2_pds_branchUseLt,  // lt, else eq
  input  logic                 r2_pds_branchInvert,
  input  logic                 r2_pds_mulSignedA,
  input  logic                 r2_pds_mulSignedB,
  input  logic                 r2_pds_mulHigh,
  input  logic                 r2_pds_divSigned,
  input  logic                 r2_pds_divRemainder,
  input  logic [2:0]           r2_pds_func3,
  input  logic [SYSTEM_W-1:0]  r2_pds_system,
  input  logic                 r2_pds_serialising,  // csr/system wait for the head
  input  logic [31:0]          r2_pds_immediate,    // csr: {zimm, addr} in [16:0]
  input  logic                 r2_pds_illegal,
  // ---- inter-stage pipeline register controls ----------------------------------
  input  logic                 stall_pds_ds,
  // ---- Dispatch-1/Dispatch inter-stage pipeline register -----------------------
  output logic [30:0]          pds_ds_pc,
  output logic [MW-1:0]        pds_ds_meta,
  output logic                 pds_ds_isCall,
  output logic                 pds_ds_isRet,
  output logic [30:0]          pds_ds_branchTarget,
  output logic [30:0]          pds_ds_seq,
  output logic [CLASS_W-1:0]   pds_ds_class,
  output logic                 pds_ds_sub,          // sub, slt, sltu, branch
  output logic                 pds_ds_selArith,
  output logic                 pds_ds_selAnd,
  output logic                 pds_ds_selOr,
  output logic                 pds_ds_selXor,
  output logic                 pds_ds_selSlt,
  output logic                 pds_ds_sltUnsigned,  // sltu, sltiu, bltu, bgeu
  output logic                 pds_ds_shiftRight,
  output logic                 pds_ds_shiftArith,
  output logic                 pds_ds_xIsPC,
  output logic                 pds_ds_xIsZero,
  output logic                 pds_ds_zIsImm,
  output logic                 pds_ds_zIsZero,
  output logic                 pds_ds_branchUseLt,  // lt, else eq
  output logic                 pds_ds_branchInvert,
  output logic                 pds_ds_mulSignedA,
  output logic                 pds_ds_mulSignedB,
  output logic                 pds_ds_mulHigh,
  output logic                 pds_ds_divSigned,
  output logic                 pds_ds_divRemainder,
  output logic [2:0]           pds_ds_func3,
  output logic [SYSTEM_W-1:0]  pds_ds_system,
  output logic                 pds_ds_serialising,  // csr/system wait for the head
  output logic [31:0]          pds_ds_immediate,    // csr: {zimm, addr} in [16:0]
  output logic                 pds_ds_illegal
);

  always_ff @(posedge clk) begin
    if (!stall_pds_ds) begin
      pds_ds_pc           <= r2_pds_pc;
      pds_ds_meta         <= r2_pds_meta;
      pds_ds_isCall       <= r2_pds_isCall;
      pds_ds_isRet        <= r2_pds_isRet;
      pds_ds_branchTarget <= r2_pds_branchTarget;
      pds_ds_seq          <= r2_pds_seq;
      pds_ds_class        <= r2_pds_class;
      pds_ds_sub          <= r2_pds_sub;
      pds_ds_selArith     <= r2_pds_selArith;
      pds_ds_selAnd       <= r2_pds_selAnd;
      pds_ds_selOr        <= r2_pds_selOr;
      pds_ds_selXor       <= r2_pds_selXor;
      pds_ds_selSlt       <= r2_pds_selSlt;
      pds_ds_sltUnsigned  <= r2_pds_sltUnsigned;
      pds_ds_shiftRight   <= r2_pds_shiftRight;
      pds_ds_shiftArith   <= r2_pds_shiftArith;
      pds_ds_xIsPC        <= r2_pds_xIsPC;
      pds_ds_xIsZero      <= r2_pds_xIsZero;
      pds_ds_zIsImm       <= r2_pds_zIsImm;
      pds_ds_zIsZero      <= r2_pds_zIsZero;
      pds_ds_branchUseLt  <= r2_pds_branchUseLt;
      pds_ds_branchInvert <= r2_pds_branchInvert;
      pds_ds_mulSignedA   <= r2_pds_mulSignedA;
      pds_ds_mulSignedB   <= r2_pds_mulSignedB;
      pds_ds_mulHigh      <= r2_pds_mulHigh;
      pds_ds_divSigned    <= r2_pds_divSigned;
      pds_ds_divRemainder <= r2_pds_divRemainder;
      pds_ds_func3        <= r2_pds_func3;
      pds_ds_system       <= r2_pds_system;
      pds_ds_serialising  <= r2_pds_serialising;
      pds_ds_immediate    <= r2_pds_immediate;
      pds_ds_illegal      <= r2_pds_illegal;
    end
  end

endmodule

