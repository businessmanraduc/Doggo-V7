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

  logic [30:0]          r2_pds_pc, r2_pds_branchTarget, r2_pds_seq;
  logic [MW-1:0]        r2_pds_meta;
  logic                 r2_pds_isCall, r2_pds_isRet;
  logic [CLASS_W-1:0]   r2_pds_class;
  logic [LATENCY_W-1:0] r2_pds_latency;
  logic                 r2_pds_sub, r2_pds_selArith, r2_pds_selAnd, r2_pds_selOr, r2_pds_selXor;
  logic                 r2_pds_selSlt, r2_pds_sltUnsigned, r2_pds_shiftRight, r2_pds_shiftArith;
  logic                 r2_pds_xIsPC, r2_pds_xIsZero, r2_pds_zIsImm, r2_pds_zIsZero;
  logic                 r2_pds_branchUseLt, r2_pds_branchInvert;
  logic                 r2_pds_mulSignedA, r2_pds_mulSignedB, r2_pds_mulHigh;
  logic                 r2_pds_divSigned, r2_pds_divRemainder;
  logic [2:0]           r2_pds_func3;
  logic [SYSTEM_W-1:0]  r2_pds_system;
  logic                 r2_pds_serialising;
  logic [31:0]          r2_pds_immediate;
  logic                 r2_pds_illegal;

  decoder #(.MW(MW)) u_dut (
    .clk,
    .d_r1_instr        (s0),
    .d_r1_rvc          (ctl[0]),
    .d_r1_pc           (s1[30:0]),
    .d_r1_meta         (ctl[10:7]),
    .d_r1_rs1Use       (ctl[1]),
    .d_r1_rs2Use       (ctl[2]),
    .d_r1_isCall       (ctl[3]),
    .d_r1_isRet        (ctl[4]),
    .d_r1_branchTarget (s2[30:0]),
    .d_r1_seq          (s3[30:0]),
    .stall_r1_r2       (ctl[5]),
    .stall_r2_pds      (ctl[6]),
    .r2_pds_pc, .r2_pds_meta, .r2_pds_isCall, .r2_pds_isRet, .r2_pds_branchTarget, .r2_pds_seq,
    .r2_pds_class, .r2_pds_latency, .r2_pds_sub, .r2_pds_selArith, .r2_pds_selAnd,
    .r2_pds_selOr, .r2_pds_selXor, .r2_pds_selSlt, .r2_pds_sltUnsigned, .r2_pds_shiftRight,
    .r2_pds_shiftArith, .r2_pds_xIsPC, .r2_pds_xIsZero, .r2_pds_zIsImm, .r2_pds_zIsZero,
    .r2_pds_branchUseLt, .r2_pds_branchInvert, .r2_pds_mulSignedA, .r2_pds_mulSignedB,
    .r2_pds_mulHigh, .r2_pds_divSigned, .r2_pds_divRemainder, .r2_pds_func3, .r2_pds_system,
    .r2_pds_serialising, .r2_pds_immediate, .r2_pds_illegal
  );

  xor_sink #(.W(179)) u_snk (.clk, .q, .d({
    r2_pds_pc, r2_pds_meta, r2_pds_isCall, r2_pds_isRet, r2_pds_branchTarget, r2_pds_seq,
    r2_pds_class, r2_pds_latency, r2_pds_sub, r2_pds_selArith, r2_pds_selAnd,
    r2_pds_selOr, r2_pds_selXor, r2_pds_selSlt, r2_pds_sltUnsigned, r2_pds_shiftRight,
    r2_pds_shiftArith, r2_pds_xIsPC, r2_pds_xIsZero, r2_pds_zIsImm, r2_pds_zIsZero,
    r2_pds_branchUseLt, r2_pds_branchInvert, r2_pds_mulSignedA, r2_pds_mulSignedB,
    r2_pds_mulHigh, r2_pds_divSigned, r2_pds_divRemainder, r2_pds_func3, r2_pds_system,
    r2_pds_serialising, r2_pds_immediate, r2_pds_illegal}));

endmodule
