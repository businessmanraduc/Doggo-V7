// ================================================================================
//  decoder_ring -- ring wrapper: every DUT port register-bounded
//  ports are the ring convention: clk, perturb (in), q (out)
// ================================================================================

`include "uop_defs.svh"

module decoder_ring (
  input  logic clk,
  input  logic perturb,
  output logic q
);

  localparam int MW = 4;

  logic [31:0] s0, s1, s2, s3;
  logic [10:0] ctl;

  lfsr_src #(.W(32)) u_s0 (.clk, .perturb(perturb), .q(s0));
  lfsr_src #(.W(32)) u_s1 (.clk, .perturb(s0[0]),   .q(s1));
  lfsr_src #(.W(32)) u_s2 (.clk, .perturb(s1[0]),   .q(s2));
  lfsr_src #(.W(32)) u_s3 (.clk, .perturb(s2[0]),   .q(s3));
  lfsr_src #(.W(11)) u_sc (.clk, .perturb(s3[0]),   .q(ctl));

  logic [30:0]          d2_pds_pc, d2_pds_branchTarget, d2_pds_seq;
  logic [MW-1:0]        d2_pds_meta;
  logic                 d2_pds_isCall, d2_pds_isRet, d2_pds_rvc;
  logic [CLASS_W-1:0]   d2_pds_class;
  logic [LATENCY_W-1:0] d2_pds_latency;
  logic                 d2_pds_sub, d2_pds_selArith, d2_pds_selAnd, d2_pds_selOr, d2_pds_selXor;
  logic                 d2_pds_selSlt, d2_pds_sltUnsigned, d2_pds_shiftRight, d2_pds_shiftArith;
  logic                 d2_pds_xIsPC, d2_pds_xIsZero, d2_pds_zIsImm, d2_pds_zIsZero;
  logic                 d2_pds_branchUseLt, d2_pds_branchInvert;
  logic                 d2_pds_mulSignedA, d2_pds_mulSignedB, d2_pds_mulHigh;
  logic                 d2_pds_divSigned, d2_pds_divRemainder;
  logic [2:0]           d2_pds_func3;
  logic [SYSTEM_W-1:0]  d2_pds_system;
  logic                 d2_pds_serialising;
  logic [31:0]          d2_pds_immediate;
  logic                 d2_pds_illegal;

  decoder #(.MW(MW)) u_dut (
    .clk,
    .d_d1_instr        (s0),
    .d_d1_rvc          (ctl[0]),
    .d_d1_pc           (s1[30:0]),
    .d_d1_meta         (ctl[10:7]),
    .d_d1_rs1Use       (ctl[1]),
    .d_d1_rs2Use       (ctl[2]),
    .d_d1_isCall       (ctl[3]),
    .d_d1_isRet        (ctl[4]),
    .d_d1_branchTarget (s2[30:0]),
    .d_d1_seq          (s3[30:0]),
    .stall_d1_d2       (ctl[5]),
    .stall_d2_pds      (ctl[6]),
    .rd2_skidValid      (s1[31]),
    .d2_pds_pc, .d2_pds_meta, .d2_pds_isCall, .d2_pds_isRet, .d2_pds_branchTarget, .d2_pds_seq,
    .d2_pds_rvc, .d2_pds_class, .d2_pds_latency, .d2_pds_sub, .d2_pds_selArith, .d2_pds_selAnd,
    .d2_pds_selOr, .d2_pds_selXor, .d2_pds_selSlt, .d2_pds_sltUnsigned, .d2_pds_shiftRight,
    .d2_pds_shiftArith, .d2_pds_xIsPC, .d2_pds_xIsZero, .d2_pds_zIsImm, .d2_pds_zIsZero,
    .d2_pds_branchUseLt, .d2_pds_branchInvert, .d2_pds_mulSignedA, .d2_pds_mulSignedB,
    .d2_pds_mulHigh, .d2_pds_divSigned, .d2_pds_divRemainder, .d2_pds_func3, .d2_pds_system,
    .d2_pds_serialising, .d2_pds_immediate, .d2_pds_illegal
  );

  xor_sink #(.W(180)) u_snk (.clk, .q, .d({
    d2_pds_pc, d2_pds_meta, d2_pds_isCall, d2_pds_isRet, d2_pds_branchTarget, d2_pds_seq,
    d2_pds_rvc, d2_pds_class, d2_pds_latency, d2_pds_sub, d2_pds_selArith, d2_pds_selAnd,
    d2_pds_selOr, d2_pds_selXor, d2_pds_selSlt, d2_pds_sltUnsigned, d2_pds_shiftRight,
    d2_pds_shiftArith, d2_pds_xIsPC, d2_pds_xIsZero, d2_pds_zIsImm, d2_pds_zIsZero,
    d2_pds_branchUseLt, d2_pds_branchInvert, d2_pds_mulSignedA, d2_pds_mulSignedB,
    d2_pds_mulHigh, d2_pds_divSigned, d2_pds_divRemainder, d2_pds_func3, d2_pds_system,
    d2_pds_serialising, d2_pds_immediate, d2_pds_illegal}));

endmodule
