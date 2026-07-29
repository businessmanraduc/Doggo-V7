// ================================================================================
//  icache_ring -- ring-of-regs timing top for the instruction cache hit path
// ================================================================================
module icache_ring (input logic clk, input logic perturb, output logic q);
  localparam int SET_IDX_W = 7;
  localparam int WORDIDX_W = 10;
  localparam int TAG_W     = 13;

  logic [31:0] s0, s1, s2, s3;
  lfsr_src #(.W(32)) u0 (.clk, .perturb(perturb), .q(s0));
  lfsr_src #(.W(32)) u1 (.clk, .perturb(s0[0]),   .q(s1));
  lfsr_src #(.W(32)) u2 (.clk, .perturb(s1[0]),   .q(s2));
  lfsr_src #(.W(32)) u3 (.clk, .perturb(s2[0]),   .q(s3));

  logic [31:0] instrWord;
  logic        hit;
  logic [1:0]  victimWay;

  icache u_dut (
    .clk, .lookupAddr(s1),
    .dataWrEnable(s2[3:0]), .dataWrIndex(s2[WORDIDX_W+3:4]), .dataWrWord(s3),
    .tagWrEnable(s0[3:0]),  .tagWrSet(s0[SET_IDX_W+3:4]),
    .tagWrTag(s0[TAG_W+10:11]), .tagWrValid(s2[31]),
    .instrWord, .hit, .victimWay
  );

  xor_sink #(.W(35)) u_sink (.clk, .d({instrWord, hit, victimWay}), .q(q));
endmodule

