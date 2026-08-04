// ================================================================================
//  rvc_expand_ring -- ring wrapper: every DUT port register-bounded
//  ports are the ring convention: clk, perturb (in), q (out)
// ================================================================================

module rvc_expand_ring (
  input  logic clk,
  input  logic perturb,
  output logic q
);

  logic [15:0] instr16;
  logic [31:0] instr32;
  logic        illegal;

  lfsr_src #(.W(16)) u_src (.clk, .perturb(perturb), .q(instr16));

  rvc_expand u_dut (.instr16, .instr32, .illegal);

  xor_sink #(.W(33)) u_sink (.clk, .d({illegal, instr32}), .q(q));

endmodule
