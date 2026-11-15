// ================================================================================
//  ex_ring -- ring wrapper: every DUT port register-bounded
//  ports are the ring convention: clk, perturb (in), q (out)
// ================================================================================
`include "uop_defs.svh"

module ex_ring (
  input  logic clk,
  input  logic perturb,
  output logic q
);

  logic [159:0] src;
  lfsr_src #(.W(32)) u_s0 (.clk, .perturb(perturb), .q(src[31:0]));
  lfsr_src #(.W(32)) u_s1 (.clk, .perturb(src[0]), .q(src[63:32]));
  lfsr_src #(.W(32)) u_s2 (.clk, .perturb(src[32]), .q(src[95:64]));
  lfsr_src #(.W(32)) u_s3 (.clk, .perturb(src[64]), .q(src[127:96]));
  lfsr_src #(.W(32)) u_s4 (.clk, .perturb(src[96]), .q(src[159:128]));

  logic ex0_ex1_taken;
  logic wb_valid;
  logic [3:0] wb_robIndex;
  logic wb_exception;
  logic wb_refetch;
  logic [31:0] wb_badAddress;

  ex u_dut (
    .clk,
    .resetn (src[0]),
    .is_pr_grant (src[8:1]),
    .iq_grantBranchMask (src[12:9]),
    .pr_rf_robIndex (src[16:13]),
    .pr_rf_rs1Tag (src[22:17]),
    .pr_rf_rs2Tag (src[28:23]),
    .pr_rf_rdTag (src[34:29]),
    .pr_rf_rdWriteEnable (src[35]),
    .pr_rf_pc (src[66:36]),
    .pr_rf_seq (src[97:67]),
    .pr_rf_class (src[109:98]),
    .pr_rf_sub (src[110]),
    .pr_rf_selArith (src[111]),
    .pr_rf_selAnd (src[112]),
    .pr_rf_selOr (src[113]),
    .pr_rf_selXor (src[114]),
    .pr_rf_sltUnsigned (src[115]),
    .pr_rf_xIsPC (src[116]),
    .pr_rf_xIsZero (src[117]),
    .pr_rf_zIsImm (src[118]),
    .pr_rf_zIsZero (src[119]),
    .pr_rf_branchUseLt (src[120]),
    .pr_rf_branchInvert (src[121]),
    .pr_rf_immediate (src[153:122]),
    .ex0_resolveValid (src[154]),
    .ex0_resolveSnapshot (src[156:155]),
    .ex0_resolveMispredict (src[157]),
    .cm_flush (src[158]),
    .ex0_ex1_taken,
    .wb_valid,
    .wb_robIndex,
    .wb_exception,
    .wb_refetch,
    .wb_badAddress
  );

  xor_sink #(.W(40)) u_snk (.clk, .q, .d({ex0_ex1_taken, wb_valid, wb_robIndex, wb_exception, wb_refetch, wb_badAddress}));

endmodule
