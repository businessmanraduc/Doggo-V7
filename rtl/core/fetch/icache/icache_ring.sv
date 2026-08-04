// ================================================================================
//  icache_ring -- ring-of-regs timing top for the instruction cache
// ================================================================================
module icache_ring (input logic clk, input logic perturb, output logic q);
  logic [31:0] s0, s1, s2, s3;
  lfsr_src #(.W(32)) u0 (.clk, .perturb(perturb), .q(s0));
  lfsr_src #(.W(32)) u1 (.clk, .perturb(s0[0]),   .q(s1));
  lfsr_src #(.W(32)) u2 (.clk, .perturb(s1[0]),   .q(s2));
  lfsr_src #(.W(32)) u3 (.clk, .perturb(s2[0]),   .q(s3));

  logic [31:0] instrWord;
  logic        hit;
  logic        fillBusy;
  logic [31:0] fillAddr;
  logic        fillReq;

  icache u_dut (
    .clk, .resetn(s0[31]),
    .lookupAddr(s1), .lookupValid(s2[0]), .lookupKill(s2[1]),
    .instrWord, .hit, .fillBusy,
    .fillAddr, .fillReq, .fillRData(s3), .fillRValid(s2[31])
  );

  xor_sink #(.W(67)) u_sink (
    .clk, .d({instrWord, hit, fillBusy, fillAddr, fillReq}), .q(q)
  );
endmodule

