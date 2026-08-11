// ================================================================================
//  ras_ring -- ring-of-regs timing top for the return address stack
//  8 entries in LUTRAM, top of stack in a flop
// ================================================================================
module ras_ring (input logic clk, input logic perturb, output logic q);
  localparam int DEPTH = 8;
  localparam int PTR_W = 3;
  logic [31:0] s0, s1, s2;
  lfsr_src #(.W(32)) u0 (.clk, .perturb(perturb), .q(s0));
  lfsr_src #(.W(32)) u1 (.clk, .perturb(s0[0]),   .q(s1));
  lfsr_src #(.W(32)) u2 (.clk, .perturb(s1[0]),   .q(s2));
  logic [31:0]      top;
  logic [PTR_W-1:0] ptr;
  ras #(.DEPTH(DEPTH), .PTR_W(PTR_W)) u_dut (
    .clk,
    .boot(s0[7]), .restore(s0[3]), .restorePtr(s2[PTR_W+3:4]),
    .enable(s0[5]), .push(s1[0]), .pop(s1[1] && !s1[0]), .pushAddr(s2),
    .top, .ptr
  );
  xor_sink #(.W(32+PTR_W)) u_sink (.clk, .d({top, ptr}), .q(q));
endmodule
