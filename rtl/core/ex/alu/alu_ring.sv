// ================================================================================
//  alu_ring -- ring wrapper: every DUT port register-bounded
//  ports are the ring convention: clk, perturb (in), q (out)
// ================================================================================
module alu_ring (
  input  logic clk,
  input  logic perturb,
  output logic q
);

  logic [95:0] s;
  lfsr_src #(.W(32)) u_s0 (.clk, .perturb(perturb), .q(s[31:0]));
  lfsr_src #(.W(32)) u_s1 (.clk, .perturb(s[0]),    .q(s[63:32]));
  lfsr_src #(.W(32)) u_s2 (.clk, .perturb(s[32]),   .q(s[95:64]));

  logic [31:0] ex0_ex1_result;
  logic        ex0_ex1_taken;

  alu u_dut (
    .clk,
    .rf_rr_selfX        (s[0]),
    .rf_rr_selfZ        (s[1]),
    .rf_rr_sub          (s[2]),
    .rf_rr_selArith     (s[3]),
    .rf_rr_selAnd       (s[4]),
    .rf_rr_selOr        (s[5]),
    .rf_rr_selXor       (s[6]),
    .rf_rr_sltUnsigned  (s[7]),
    .rf_rr_branchUseLt  (s[8]),
    .rf_rr_branchInvert (s[9]),
    .rr_ex0_x           (s[41:10]),
    .rr_ex0_z           (s[73:42]),
    .ex0_ex1_result,
    .ex0_ex1_taken
  );

  xor_sink #(.W(33)) u_snk (.clk, .q, .d({ex0_ex1_result, ex0_ex1_taken}));

endmodule
