// ================================================================================
//  regread_ring -- ring wrapper: every DUT port register-bounded
//  ports are the ring convention: clk, perturb (in), q (out)
// ================================================================================
`include "uop_defs.svh"

module regread_ring (
  input  logic clk,
  input  logic perturb,
  output logic q
);

  logic [415:0] s;
  lfsr_src #(.W(32)) u_s0  (.clk, .perturb(perturb), .q(s[31:0]));
  for (genvar k = 1; k < 13; k++) begin : g_src
    lfsr_src #(.W(32)) u_s (.clk, .perturb(s[32*k-32]), .q(s[32*k +: 32]));
  end

  logic        rf_rr_selfX, rf_rr_selfZ, rf_rr_sub, rf_rr_selArith, rf_rr_selAnd;
  logic        rf_rr_selOr, rf_rr_selXor, rf_rr_sltUnsigned;
  logic        rf_rr_branchUseLt, rf_rr_branchInvert;
  logic [31:0] rr_ex0_x, rr_ex0_z;

  regread u_dut (
    .clk,
    .pr_rf_rs1Tag       (s[5:0]),
    .pr_rf_rs2Tag       (s[11:6]),
    .pr_rf_pc           (s[42:12]),
    .pr_rf_seq          (s[73:43]),
    .pr_rf_class        (s[74 +: CLASS_W]),
    .pr_rf_sub          (s[86]),
    .pr_rf_selArith     (s[87]),
    .pr_rf_selAnd       (s[88]),
    .pr_rf_selOr        (s[89]),
    .pr_rf_selXor       (s[90]),
    .pr_rf_sltUnsigned  (s[91]),
    .pr_rf_xIsPC        (s[92]),
    .pr_rf_xIsZero      (s[93]),
    .pr_rf_zIsImm       (s[94]),
    .pr_rf_zIsZero      (s[95]),
    .pr_rf_branchUseLt  (s[96]),
    .pr_rf_branchInvert (s[97]),
    .pr_rf_immediate    (s[129:98]),
    .rf_rs1Data         (s[161:130]),
    .rf_rs2Data         (s[193:162]),
    .rf_rr_producer     (s[194]),
    .rf_rr_rdTag        (s[200:195]),
    .rr_ex0_producer    (s[201]),
    .rr_ex0_rdTag       (s[207:202]),
    .ex0_ex1_producer   (s[208]),
    .ex0_ex1_rdTag      (s[214:209]),
    .ex1_ex2_producer   (s[215]),
    .ex1_ex2_rdTag      (s[221:216]),
    .ex2_ex3_producer   (s[222]),
    .ex2_ex3_rdTag      (s[228:223]),
    .ex3_wb_producer    (s[229]),
    .ex3_wb_rdTag       (s[235:230]),
    .ex0_ex1_result     (s[267:236]),
    .ex1_ex2_result     (s[299:268]),
    .ex2_ex3_result     (s[331:300]),
    .ex3_wb_result      (s[363:332]),
    .wb_cm_result       (s[395:364]),
    .rf_rr_selfX, .rf_rr_selfZ, .rf_rr_sub, .rf_rr_selArith, .rf_rr_selAnd,
    .rf_rr_selOr, .rf_rr_selXor, .rf_rr_sltUnsigned,
    .rf_rr_branchUseLt, .rf_rr_branchInvert,
    .rr_ex0_x, .rr_ex0_z
  );

  xor_sink #(.W(74)) u_snk (.clk, .q, .d({
    rf_rr_selfX, rf_rr_selfZ, rf_rr_sub, rf_rr_selArith, rf_rr_selAnd,
    rf_rr_selOr, rf_rr_selXor, rf_rr_sltUnsigned,
    rf_rr_branchUseLt, rf_rr_branchInvert,
    rr_ex0_x, rr_ex0_z
  }));

endmodule
