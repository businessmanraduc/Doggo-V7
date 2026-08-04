// ================================================================================
//  legal32_ring -- ring wrapper: every DUT port register-bounded
//  ports are the ring convention: clk, perturb (in), q (out)
// ================================================================================

module legal32_ring (
  input  logic clk,
  input  logic perturb,
  output logic q
);

  logic [31:0] instr;
  logic        illegal;

  lfsr_src #(.W(32)) u_src (.clk, .perturb(perturb), .q(instr));

  legal32 u_dut (.instr, .illegal);

  xor_sink #(.W(1)) u_sink (.clk, .d(illegal), .q(q));

endmodule

