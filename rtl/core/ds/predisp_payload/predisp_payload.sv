// ================================================================================
//  PreDS payload: decoder fields from D2 to DS
// ================================================================================
//  RD2             PreDS                        DS
//  rename R2  ───► predisp (tag -> slot) ───┬─► dispatch (IQ/ROB write)
//  decoder D2 ───► predisp_payload (hold) ──┘
// ================================================================================
//  Payload only: predisp owns valid, stall and kill. Holds while DS stalls.
// ================================================================================
`include "uop_defs.svh"

module predisp_payload #(
  parameter int MW = 1
) (
  input  logic                 clk,
  // ---- Decode-2/Dispatch-1 inter-stage pipeline register -----------------------
  input  logic [30:0]          d2_pds_pc,
  input  logic [MW-1:0]        d2_pds_meta,
  input  logic                 d2_pds_isCall,
  input  logic                 d2_pds_isRet,
  input  logic [30:0]          d2_pds_branchTarget,
  input  logic [30:0]          d2_pds_seq,
  input  logic                 d2_pds_rvc,
  input  logic [CLASS_W-1:0]   d2_pds_class,
  input  logic                 d2_pds_sub,          // sub, slt, sltu, branch
  input  logic                 d2_pds_selArith,
  input  logic                 d2_pds_selAnd,
  input  logic                 d2_pds_selOr,
  input  logic                 d2_pds_selXor,
  input  logic                 d2_pds_selSlt,
  input  logic                 d2_pds_sltUnsigned,  // sltu, sltiu, bltu, bgeu
  input  logic                 d2_pds_shiftRight,
  input  logic                 d2_pds_shiftArith,
  input  logic                 d2_pds_xIsPC,
  input  logic                 d2_pds_xIsZero,
  input  logic                 d2_pds_zIsImm,
  input  logic                 d2_pds_zIsZero,
  input  logic                 d2_pds_branchUseLt,  // lt, else eq
  input  logic                 d2_pds_branchInvert,
  input  logic                 d2_pds_mulSignedA,
  input  logic                 d2_pds_mulSignedB,
  input  logic                 d2_pds_mulHigh,
  input  logic                 d2_pds_divSigned,
  input  logic                 d2_pds_divRemainder,
  input  logic [2:0]           d2_pds_func3,
  input  logic [SYSTEM_W-1:0]  d2_pds_system,
  input  logic                 d2_pds_serialising,  // csr/system wait for the head
  input  logic [31:0]          d2_pds_immediate,    // csr: {zimm, addr} in [16:0]
  input  logic                 d2_pds_illegal,
  // ---- inter-stage pipeline register controls ----------------------------------
  input  logic                 stall_pds_ds,
  // ---- Dispatch-1/Dispatch inter-stage pipeline register -----------------------
  output logic [30:0]          pds_ds_pc,
  output logic [MW-1:0]        pds_ds_meta,
  output logic                 pds_ds_isCall,
  output logic                 pds_ds_isRet,
  output logic [30:0]          pds_ds_branchTarget,
  output logic [30:0]          pds_ds_seq,
  output logic                 pds_ds_rvc,
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
      pds_ds_pc           <= d2_pds_pc;
      pds_ds_meta         <= d2_pds_meta;
      pds_ds_isCall       <= d2_pds_isCall;
      pds_ds_isRet        <= d2_pds_isRet;
      pds_ds_branchTarget <= d2_pds_branchTarget;
      pds_ds_seq          <= d2_pds_seq;
      pds_ds_rvc          <= d2_pds_rvc;
      pds_ds_class        <= d2_pds_class;
      pds_ds_sub          <= d2_pds_sub;
      pds_ds_selArith     <= d2_pds_selArith;
      pds_ds_selAnd       <= d2_pds_selAnd;
      pds_ds_selOr        <= d2_pds_selOr;
      pds_ds_selXor       <= d2_pds_selXor;
      pds_ds_selSlt       <= d2_pds_selSlt;
      pds_ds_sltUnsigned  <= d2_pds_sltUnsigned;
      pds_ds_shiftRight   <= d2_pds_shiftRight;
      pds_ds_shiftArith   <= d2_pds_shiftArith;
      pds_ds_xIsPC        <= d2_pds_xIsPC;
      pds_ds_xIsZero      <= d2_pds_xIsZero;
      pds_ds_zIsImm       <= d2_pds_zIsImm;
      pds_ds_zIsZero      <= d2_pds_zIsZero;
      pds_ds_branchUseLt  <= d2_pds_branchUseLt;
      pds_ds_branchInvert <= d2_pds_branchInvert;
      pds_ds_mulSignedA   <= d2_pds_mulSignedA;
      pds_ds_mulSignedB   <= d2_pds_mulSignedB;
      pds_ds_mulHigh      <= d2_pds_mulHigh;
      pds_ds_divSigned    <= d2_pds_divSigned;
      pds_ds_divRemainder <= d2_pds_divRemainder;
      pds_ds_func3        <= d2_pds_func3;
      pds_ds_system       <= d2_pds_system;
      pds_ds_serialising  <= d2_pds_serialising;
      pds_ds_immediate    <= d2_pds_immediate;
      pds_ds_illegal      <= d2_pds_illegal;
    end
  end

endmodule

