// ================================================================================
//  rf_ring -- ring wrapper: every DUT port register-bounded
//  ports are the ring convention: clk, perturb (in), q (out)
// ================================================================================

module rf_ring (
  input  logic clk,
  input  logic perturb,
  output logic q
);

  logic [31:0] s0, s1;

  lfsr_src #(.W(32)) u_s0 (.clk, .perturb(perturb), .q(s0));
  lfsr_src #(.W(32)) u_s1 (.clk, .perturb(s0[0]),   .q(s1));

  logic [31:0] rf_rs1Data, rf_rs2Data;

  rf u_dut (
    .clk,
    .ex7_wb_producer (s1[0]),
    .ex7_wb_rdTag    (s1[6:1]),
    .ex7_wb_result   (s0),
    .pr_rf_rs1Tag    (s1[12:7]),
    .pr_rf_rs2Tag    (s1[18:13]),
    .rf_rs1Data, .rf_rs2Data
  );

  xor_sink #(.W(64)) u_snk (.clk, .q, .d({rf_rs1Data, rf_rs2Data}));

endmodule
