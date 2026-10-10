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

  logic [30:0]          r2_ds1_pc, r2_ds1_branchTarget, r2_ds1_seq;
  logic [MW-1:0]        r2_ds1_meta;
  logic                 r2_ds1_isCall, r2_ds1_isRet;
  logic [CLASS_W-1:0]   r2_ds1_class;
  logic [LATENCY_W-1:0] r2_ds1_latency;
  logic                 r2_ds1_sub, r2_ds1_selArith, r2_ds1_selAnd, r2_ds1_selOr, r2_ds1_selXor;
  logic                 r2_ds1_selSlt, r2_ds1_sltUnsigned, r2_ds1_shiftRight, r2_ds1_shiftArith;
  logic                 r2_ds1_xIsPC, r2_ds1_xIsZero, r2_ds1_zIsImm, r2_ds1_zIsZero;
  logic                 r2_ds1_branchUseLt, r2_ds1_branchInvert;
  logic                 r2_ds1_mulSignedA, r2_ds1_mulSignedB, r2_ds1_mulHigh;
  logic                 r2_ds1_divSigned, r2_ds1_divRemainder;
  logic [2:0]           r2_ds1_func3;
  logic [SYSTEM_W-1:0]  r2_ds1_system;
  logic                 r2_ds1_serialising;
  logic [31:0]          r2_ds1_immediate;
  logic                 r2_ds1_illegal;

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
    .stall_r2_ds1      (ctl[6]),
    .r2_ds1_pc, .r2_ds1_meta, .r2_ds1_isCall, .r2_ds1_isRet, .r2_ds1_branchTarget, .r2_ds1_seq,
    .r2_ds1_class, .r2_ds1_latency, .r2_ds1_sub, .r2_ds1_selArith, .r2_ds1_selAnd,
    .r2_ds1_selOr, .r2_ds1_selXor, .r2_ds1_selSlt, .r2_ds1_sltUnsigned, .r2_ds1_shiftRight,
    .r2_ds1_shiftArith, .r2_ds1_xIsPC, .r2_ds1_xIsZero, .r2_ds1_zIsImm, .r2_ds1_zIsZero,
    .r2_ds1_branchUseLt, .r2_ds1_branchInvert, .r2_ds1_mulSignedA, .r2_ds1_mulSignedB,
    .r2_ds1_mulHigh, .r2_ds1_divSigned, .r2_ds1_divRemainder, .r2_ds1_func3, .r2_ds1_system,
    .r2_ds1_serialising, .r2_ds1_immediate, .r2_ds1_illegal
  );

  xor_sink #(.W(179)) u_snk (.clk, .q, .d({
    r2_ds1_pc, r2_ds1_meta, r2_ds1_isCall, r2_ds1_isRet, r2_ds1_branchTarget, r2_ds1_seq,
    r2_ds1_class, r2_ds1_latency, r2_ds1_sub, r2_ds1_selArith, r2_ds1_selAnd,
    r2_ds1_selOr, r2_ds1_selXor, r2_ds1_selSlt, r2_ds1_sltUnsigned, r2_ds1_shiftRight,
    r2_ds1_shiftArith, r2_ds1_xIsPC, r2_ds1_xIsZero, r2_ds1_zIsImm, r2_ds1_zIsZero,
    r2_ds1_branchUseLt, r2_ds1_branchInvert, r2_ds1_mulSignedA, r2_ds1_mulSignedB,
    r2_ds1_mulHigh, r2_ds1_divSigned, r2_ds1_divRemainder, r2_ds1_func3, r2_ds1_system,
    r2_ds1_serialising, r2_ds1_immediate, r2_ds1_illegal}));

endmodule
