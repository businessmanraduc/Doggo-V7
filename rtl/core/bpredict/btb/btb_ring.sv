// ================================================================================
//  btb_ring -- ring-of-regs timing top for the banked BTB
//  2 banks x 512 entries, three 18-bit blocks each, packed read register
// ================================================================================
module btb_ring (input logic clk, input logic perturb, output logic q);
  localparam int INDEX_W = 9;
  logic [31:0] s0, s1, s2, s3;
  lfsr_src #(.W(32)) u0 (.clk, .perturb(perturb), .q(s0));
  lfsr_src #(.W(32)) u1 (.clk, .perturb(s0[0]),   .q(s1));
  lfsr_src #(.W(32)) u2 (.clk, .perturb(s1[0]),   .q(s2));
  lfsr_src #(.W(32)) u3 (.clk, .perturb(s2[0]),   .q(s3));

  logic        tagMatchA, takenOnHitA, condOnHitA, isStraddleA;
  logic        exitAfterLowA, isCallA, isReturnA;
  logic [31:0] targetA;
  logic        tagMatchB, takenOnHitB, condOnHitB, isStraddleB;
  logic        exitAfterLowB, isCallB, isReturnB;
  logic [31:0] targetB;

  btb #(.INDEX_W(INDEX_W)) u_dut (
    .clk, .readEnable(s2[7]),
    .lookupPcA(s1), .lookupPcB(s1 + 32'd4),
    .wrEnable(s2[0]), .wrBank(s2[8]), .wrIndex(s2[INDEX_W:1]),
    .wrEntry({s3[21:0], s0}),
    .tagMatchA, .takenOnHitA, .condOnHitA, .isStraddleA,
    .exitAfterLowA, .isCallA, .isReturnA, .targetA,
    .tagMatchB, .takenOnHitB, .condOnHitB, .isStraddleB,
    .exitAfterLowB, .isCallB, .isReturnB, .targetB
  );

  xor_sink #(.W(78)) u_sink (
    .clk,
    .d({targetA, tagMatchA, takenOnHitA, condOnHitA, isStraddleA,
        exitAfterLowA, isCallA, isReturnA,
        targetB, tagMatchB, takenOnHitB, condOnHitB, isStraddleB,
        exitAfterLowB, isCallB, isReturnB}),
    .q(q)
  );
endmodule
