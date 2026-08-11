// ================================================================================
//  bpredict_ring -- ring-of-regs timing top for the whole predict engine
//  banked BTB (6 DP16KD) + two-word PHT + RAS + FTQ, P0..P3
// ================================================================================
module bpredict_ring (input logic clk, input logic perturb, output logic q);
  localparam int BTB_W = 9;
  localparam int PHT_W = 13;
  localparam int RAS_W = 3;
  localparam int BHR_W = 24;
  logic [31:0] s0, s1, s2, s3;
  lfsr_src #(.W(32)) u0 (.clk, .perturb(perturb), .q(s0));
  lfsr_src #(.W(32)) u1 (.clk, .perturb(s0[0]),   .q(s1));
  lfsr_src #(.W(32)) u2 (.clk, .perturb(s1[0]),   .q(s2));
  lfsr_src #(.W(32)) u3 (.clk, .perturb(s2[0]),   .q(s3));

  logic             issueValid;
  logic [31:2]      issuePC, headPC;
  logic [1:0]       headHwValid;
  logic [PHT_W-1:0] headGshare;
  logic [RAS_W-1:0] headRasPtr;

  bpredict #(.BTB_INDEX_W(BTB_W), .PHT_INDEX_W(PHT_W), .BHR_W(BHR_W),
             .RAS_PTR_W(RAS_W)) u_dut (
    .clk, .resetn(s0[9]),
    .redirectValid(s0[3]), .redirectPC(s1),
    .redirectBHR(s2[BHR_W:1]), .redirectRasPtr(s3[RAS_W+3:4]),
    .btbWrEnable(s2[0]), .btbWrBank(s2[8]), .btbWrIndex(s2[BTB_W:1]),
    .btbWrEntry({s3[21:0], s1}),
    .phtWrEnable(s2[1]), .phtWrIndex(s3[PHT_W:1]), .phtWrCounter(s3[13:12]),
    .issueValid(issueValid), .issuePC(issuePC), .issue(s0[2]),
    .headPC(headPC), .headHwValid(headHwValid), .headGshare(headGshare),
    .headRasPtr(headRasPtr), .retire(s0[4]), .replay(s0[5] && !s0[4])
  );

  xor_sink #(.W(1+30+30+2+PHT_W+RAS_W)) u_sink (
    .clk, .d({issueValid, issuePC, headPC, headHwValid, headGshare, headRasPtr}),
    .q(q)
  );
endmodule
