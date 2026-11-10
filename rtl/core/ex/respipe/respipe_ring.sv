// ================================================================================
//  respipe_ring -- ring wrapper: every DUT port register-bounded
//  ports are the ring convention: clk, perturb (in), q (out)
// ================================================================================

module respipe_ring (
  input  logic clk,
  input  logic perturb,
  output logic q
);

  logic [31:0] s0, s1;

  lfsr_src #(.W(32)) u_s0 (.clk, .perturb(perturb), .q(s0));
  lfsr_src #(.W(32)) u_s1 (.clk, .perturb(s0[0]),   .q(s1));

  logic        rf_rr_producer, rr_ex0_producer, ex0_ex1_producer;
  logic        ex1_ex2_producer, ex2_ex3_producer, ex3_wb_producer;
  logic [5:0]  rf_rr_rdTag, rr_ex0_rdTag, ex0_ex1_rdTag, ex1_ex2_rdTag, ex2_ex3_rdTag, ex3_wb_rdTag;
  logic [31:0] ex1_ex2_result, ex2_ex3_result, ex3_wb_result, wb_cm_result;
  logic        wb_valid;
  logic [3:0]  wb_robIndex;

  respipe u_dut (
    .clk,
    .resetn                (s1[0]),
    .is_pr_grant           (s1[8:1]),
    .iq_grantBranchMask    (s1[12:9]),
    .pr_rf_rdTag           (s1[18:13]),
    .pr_rf_rdWriteEnable   (s1[19]),
    .pr_rf_robIndex        (s1[23:20]),
    .ex0_resolveValid      (s1[24]),
    .ex0_resolveSnapshot   (s1[26:25]),
    .ex0_resolveMispredict (s1[27]),
    .cm_flush              (s1[28]),
    .ex0_ex1_result        (s0),
    .rf_rr_producer,   .rf_rr_rdTag,   .rr_ex0_producer,  .rr_ex0_rdTag,
    .ex0_ex1_producer, .ex0_ex1_rdTag, .ex1_ex2_producer, .ex1_ex2_rdTag,
    .ex2_ex3_producer, .ex2_ex3_rdTag, .ex3_wb_producer,  .ex3_wb_rdTag,
    .ex1_ex2_result,   .ex2_ex3_result, .ex3_wb_result,   .wb_cm_result,
    .wb_valid,         .wb_robIndex
  );

  xor_sink #(.W(175)) u_snk (.clk, .q, .d({
    rf_rr_producer,   rf_rr_rdTag,   rr_ex0_producer,  rr_ex0_rdTag,
    ex0_ex1_producer, ex0_ex1_rdTag, ex1_ex2_producer, ex1_ex2_rdTag,
    ex2_ex3_producer, ex2_ex3_rdTag, ex3_wb_producer,  ex3_wb_rdTag,
    ex1_ex2_result,   ex2_ex3_result, ex3_wb_result,   wb_cm_result,
    wb_valid,         wb_robIndex
  }));

endmodule
