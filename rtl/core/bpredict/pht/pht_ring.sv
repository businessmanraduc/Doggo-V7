// ================================================================================
//  pht_ring -- ring-of-regs timing top for the two-word PHT
//  4 x 8192 2-bit counters: two slots, two precompute-both candidates each
// ================================================================================
module pht_ring (input logic clk, input logic perturb, output logic q);
  localparam int INDEX_W = 13;
  logic [31:0] s0, s1, s2, s3;
  lfsr_src #(.W(32)) u0 (.clk, .perturb(perturb), .q(s0));
  lfsr_src #(.W(32)) u1 (.clk, .perturb(s0[0]),   .q(s1));
  lfsr_src #(.W(32)) u2 (.clk, .perturb(s1[0]),   .q(s2));
  lfsr_src #(.W(32)) u3 (.clk, .perturb(s2[0]),   .q(s3));

  logic takenA, takenB;

  pht #(.INDEX_W(INDEX_W)) u_dut (
    .clk, .readEnable(s2[7]),
    .indexA(s1[INDEX_W-1:0]), .indexB(s1[INDEX_W+12:13]),
    .resolveA(s0[5]), .resolveB(s0[6]),
    .wrEnable(s2[0]), .wrIndex(s3[INDEX_W:1]), .wrCounter(s3[13:12]),
    .takenA(takenA), .takenB(takenB)
  );

  xor_sink #(.W(2)) u_sink (.clk, .d({takenA, takenB}), .q(q));
endmodule
