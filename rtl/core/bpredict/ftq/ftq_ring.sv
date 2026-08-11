// ================================================================================
//  ftq_ring -- ring-of-regs timing top for the fetch target queue
//  16 pair-entries in LUTRAM, split issue and retire read ports
// ================================================================================
module ftq_ring (input logic clk, input logic perturb, output logic q);
  localparam int PHT_W = 13;
  localparam int RAS_W = 3;
  logic [31:0] s0, s1, s2, s3;
  lfsr_src #(.W(32)) u0 (.clk, .perturb(perturb), .q(s0));
  lfsr_src #(.W(32)) u1 (.clk, .perturb(s0[0]),   .q(s1));
  lfsr_src #(.W(32)) u2 (.clk, .perturb(s1[0]),   .q(s2));
  lfsr_src #(.W(32)) u3 (.clk, .perturb(s2[0]),   .q(s3));

  logic             canPush, issueValid;
  logic [31:2]      issuePC, headPC;
  logic [1:0]       headHwValid;
  logic [PHT_W-1:0] headGshare;
  logic [RAS_W-1:0] headRasPtr;

  ftq #(.DEPTH(16), .PHT_INDEX_W(PHT_W), .RAS_PTR_W(RAS_W)) u_dut (
    .clk, .resetn(1'b1), .flush(s0[7]),
    .push(s0[0]),           .push_pcA(s1[31:2]),   .push_pcB(s2[31:2]),
    .push_hwValidA(s1[1:0]), .push_hwValidB(s2[1:0]),
    .push_gshareA(s3[PHT_W-1:0]), .push_gshareB(s3[PHT_W+12:13]),
    .push_rasPtr(s1[RAS_W+3:4]),  .push_validB(s0[1]),
    .canPush(canPush),
    .issueValid(issueValid), .issuePC(issuePC), .issue(s0[2]),
    .headPC(headPC), .headHwValid(headHwValid), .headGshare(headGshare),
    .headRasPtr(headRasPtr), .retire(s0[3]), .replay(s0[4] && !s0[3])
  );

  xor_sink #(.W(2+30+30+2+PHT_W+RAS_W)) u_sink (
    .clk, .d({canPush, issueValid, issuePC, headPC, headHwValid,
              headGshare, headRasPtr}), .q(q)
  );
endmodule
