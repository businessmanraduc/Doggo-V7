`include "isa.svh"
// ===============================================================================
//  shifter_ring -- ring wrapper: every DUT port register-bounded
//  ports are the ring convention: clk, perturb (in), q (out)
// ===============================================================================

module shifter_ring (
  input  logic clk,
  input  logic perturb,
  output logic q
);

  logic [31:0] operand, result;
  logic [4:0]  amount;
  logic [1:0]  opBits;

  lfsr_src #(.W(32)) u_srcV  (.clk, .perturb(perturb),   .q(operand));
  lfsr_src #(.W(5))  u_srcA  (.clk, .perturb(operand[0]),.q(amount));
  lfsr_src #(.W(2))  u_srcOp (.clk, .perturb(amount[0]), .q(opBits));

  shifter u_dut (.clk, .operand, .amount, .op(shiftOp_t'(opBits)), .result);

  xor_sink #(.W(32)) u_sink (.clk, .d(result), .q(q));

endmodule

