// ================================================================================
//  btb_ring -- ring-of-regs timing top for the BTB (tier-2, NOREG)
// ================================================================================
module btb_ring (input logic clk, input logic perturb, output logic q);
  localparam int INDEX_W = 9;
  logic [31:0] s0, s1, s2, s3;
  lfsr_src #(.W(32)) u0 (.clk, .perturb(perturb), .q(s0));
  lfsr_src #(.W(32)) u1 (.clk, .perturb(s0[0]),   .q(s1));
  lfsr_src #(.W(32)) u2 (.clk, .perturb(s1[0]),   .q(s2));
  lfsr_src #(.W(32)) u3 (.clk, .perturb(s2[0]),   .q(s3));
  logic        hit, isBranch, isConditional, isStraddle;
  logic [31:0] target;
  btb #(.OUT_REG(1'b0), .INDEX_W(INDEX_W)) u_dut (
    .clk, .lookupPC(s1),
    .wrEnable(s2[0]), .wrIndex(s2[INDEX_W:1]), .wrEntry({s3[21:0], s0}),
    .hit, .isBranch, .isConditional, .isStraddle, .target
  );
  xor_sink #(.W(36)) u_sink (.clk, .d({target, hit, isBranch, isConditional, isStraddle}), .q(q));
endmodule
