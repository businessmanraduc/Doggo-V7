// ================================================================================
//  pht_ring -- ring-of-regs timing top for the PHT (BSRAM, 8192 deep)
// ================================================================================
module pht_ring (input logic clk, input logic perturb, output logic q);
  localparam int INDEX_W = 13;
  logic [31:0] s0, s1, s2, s3;
  lfsr_src #(.W(32)) u0 (.clk, .perturb(perturb), .q(s0));
  lfsr_src #(.W(32)) u1 (.clk, .perturb(s0[0]),   .q(s1));
  lfsr_src #(.W(32)) u2 (.clk, .perturb(s1[0]),   .q(s2));
  lfsr_src #(.W(32)) u3 (.clk, .perturb(s2[0]),   .q(s3));
  logic taken;
  pht #(.OUT_REG(1'b0), .INDEX_W(INDEX_W)) u_dut (
    .clk, .gshareIndex(s0[INDEX_W-1:0]), .resolveBit(s1[0]),
    .wrEnable(s2[0]), .wrIndex(s2[INDEX_W:1]), .wrCounter(s3[1:0]),
    .takenPrediction(taken)
  );
  xor_sink #(.W(1)) u_sink (.clk, .d(taken), .q(q));
endmodule

