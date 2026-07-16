`include "isa.svh"
// ==================================================================================
//  alu_ring -- ring wrapper: every DUT port register-bounded
//  ports are the ring convention: clk, perturb (in), q (out)
// ==================================================================================

module alu_ring (
  input  logic clk,
  input  logic perturb,
  output logic q
);

  logic [31:0] lhs, rhs, result;
  logic [2:0]  opBits;

  lfsr_src #(.W(32)) u_srcL  (.clk, .perturb(perturb), .q(lhs));
  lfsr_src #(.W(32)) u_srcR  (.clk, .perturb(lhs[0]),  .q(rhs));
  lfsr_src #(.W(3))  u_srcOp (.clk, .perturb(rhs[0]),  .q(opBits));

  alu u_dut (.lhs, .rhs, .op(aluOp_t'(opBits)), .result);

  xor_sink #(.W(32)) u_sink (.clk, .d(result), .q(q));

endmodule

