// ================================================================================
//  predisp_payload_ring -- ring wrapper: every DUT port register-bounded
//  ports are the ring convention: clk, perturb (in), q (out)
// ================================================================================
//  stall_pds_ds is one LUT on two flops, as in predisp_ring, so the CE net
//  fans out from a LUT as it will from DS.
// ================================================================================

`include "uop_defs.svh"

module predisp_payload_ring (
  input  logic clk,
  input  logic perturb,
  output logic q
);

  localparam int MW = 1;
  localparam int W  = 170 + MW;

  logic [31:0] s0, s1, s2, s3, s4, s5;

  lfsr_src #(.W(32)) u_s0 (.clk, .perturb(perturb), .q(s0));
  lfsr_src #(.W(32)) u_s1 (.clk, .perturb(s0[0]),   .q(s1));
  lfsr_src #(.W(32)) u_s2 (.clk, .perturb(s1[0]),   .q(s2));
  lfsr_src #(.W(32)) u_s3 (.clk, .perturb(s2[0]),   .q(s3));
  lfsr_src #(.W(32)) u_s4 (.clk, .perturb(s3[0]),   .q(s4));
  lfsr_src #(.W(32)) u_s5 (.clk, .perturb(s4[0]),   .q(s5));

  logic [191:0] src; assign src = {s5, s4, s3, s2, s1, s0};
  logic [W-1:0] in, out;
  logic         stall_pds_ds;

  assign in           = src[W-1:0];
  assign stall_pds_ds = src[190] | src[191];

  predisp_payload #(.MW(MW)) u_dut (
    .clk,
    .r2_pds_pc           (in[30:0]),
    .r2_pds_meta         (in[31 +: MW]),
    .r2_pds_isCall       (in[MW+31]),
    .r2_pds_isRet        (in[MW+32]),
    .r2_pds_branchTarget (in[MW+33 +: 31]),
    .r2_pds_seq          (in[MW+64 +: 31]),
    .r2_pds_class        (in[MW+95 +: CLASS_W]),
    .r2_pds_sub          (in[MW+107]),
    .r2_pds_selArith     (in[MW+108]),
    .r2_pds_selAnd       (in[MW+109]),
    .r2_pds_selOr        (in[MW+110]),
    .r2_pds_selXor       (in[MW+111]),
    .r2_pds_selSlt       (in[MW+112]),
    .r2_pds_sltUnsigned  (in[MW+113]),
    .r2_pds_shiftRight   (in[MW+114]),
    .r2_pds_shiftArith   (in[MW+115]),
    .r2_pds_xIsPC        (in[MW+116]),
    .r2_pds_xIsZero      (in[MW+117]),
    .r2_pds_zIsImm       (in[MW+118]),
    .r2_pds_zIsZero      (in[MW+119]),
    .r2_pds_branchUseLt  (in[MW+120]),
    .r2_pds_branchInvert (in[MW+121]),
    .r2_pds_mulSignedA   (in[MW+122]),
    .r2_pds_mulSignedB   (in[MW+123]),
    .r2_pds_mulHigh      (in[MW+124]),
    .r2_pds_divSigned    (in[MW+125]),
    .r2_pds_divRemainder (in[MW+126]),
    .r2_pds_func3        (in[MW+127 +: 3]),
    .r2_pds_system       (in[MW+130 +: SYSTEM_W]),
    .r2_pds_serialising  (in[MW+136]),
    .r2_pds_immediate    (in[MW+137 +: 32]),
    .r2_pds_illegal      (in[MW+169]),
    .stall_pds_ds,
    .pds_ds_pc           (out[30:0]),
    .pds_ds_meta         (out[31 +: MW]),
    .pds_ds_isCall       (out[MW+31]),
    .pds_ds_isRet        (out[MW+32]),
    .pds_ds_branchTarget (out[MW+33 +: 31]),
    .pds_ds_seq          (out[MW+64 +: 31]),
    .pds_ds_class        (out[MW+95 +: CLASS_W]),
    .pds_ds_sub          (out[MW+107]),
    .pds_ds_selArith     (out[MW+108]),
    .pds_ds_selAnd       (out[MW+109]),
    .pds_ds_selOr        (out[MW+110]),
    .pds_ds_selXor       (out[MW+111]),
    .pds_ds_selSlt       (out[MW+112]),
    .pds_ds_sltUnsigned  (out[MW+113]),
    .pds_ds_shiftRight   (out[MW+114]),
    .pds_ds_shiftArith   (out[MW+115]),
    .pds_ds_xIsPC        (out[MW+116]),
    .pds_ds_xIsZero      (out[MW+117]),
    .pds_ds_zIsImm       (out[MW+118]),
    .pds_ds_zIsZero      (out[MW+119]),
    .pds_ds_branchUseLt  (out[MW+120]),
    .pds_ds_branchInvert (out[MW+121]),
    .pds_ds_mulSignedA   (out[MW+122]),
    .pds_ds_mulSignedB   (out[MW+123]),
    .pds_ds_mulHigh      (out[MW+124]),
    .pds_ds_divSigned    (out[MW+125]),
    .pds_ds_divRemainder (out[MW+126]),
    .pds_ds_func3        (out[MW+127 +: 3]),
    .pds_ds_system       (out[MW+130 +: SYSTEM_W]),
    .pds_ds_serialising  (out[MW+136]),
    .pds_ds_immediate    (out[MW+137 +: 32]),
    .pds_ds_illegal      (out[MW+169])
  );

  xor_sink #(.W(W)) u_snk (.clk, .q, .d(out));

endmodule
