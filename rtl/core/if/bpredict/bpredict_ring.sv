// ================================================================================
//  bpredict_ring -- ring-of-regs timing top for the whole predictor (tier-2)
//  BTB 512 (BSRAM) / PHT 8192 (BSRAM); nextPC loop closed through the NextPC mux
// ================================================================================
module bpredict_ring (input logic clk, input logic perturb, output logic q);
  localparam int BTB_W = 9;
  localparam int PHT_W = 13;
  logic [31:0] s0, s1, s2, s3;
  lfsr_src #(.W(32)) u0 (.clk, .perturb(perturb), .q(s0));
  lfsr_src #(.W(32)) u1 (.clk, .perturb(s0[0]),   .q(s1));
  lfsr_src #(.W(32)) u2 (.clk, .perturb(s1[0]),   .q(s2));
  lfsr_src #(.W(32)) u3 (.clk, .perturb(s2[0]),   .q(s3));
  logic [31:0] nextPC;
  bpredict #(.OUT_REG(1'b0), .BTB_INDEX_W(BTB_W), .PHT_INDEX_W(PHT_W)) u_dut (
    .clk, .boot(s0[7]), .redirectValid(s0[3]), .redirectPC(s1),
    .btbWrEnable(s2[0]), .btbWrIndex(s2[BTB_W:1]), .btbWrEntry({s3[21:0], s1}),
    .phtWrEnable(s2[1]), .phtWrIndex(s3[PHT_W:1]), .phtWrCounter(s3[13:12]),
    .nextPC(nextPC)
  );
  xor_sink #(.W(32)) u_sink (.clk, .d(nextPC), .q(q));
endmodule

