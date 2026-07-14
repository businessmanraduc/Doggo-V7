// ==============================================================================
//  add_smoke_ring -- ring wrapper: every DUT port register-bounded
//  ports are the ring convention: clk, perturb (in), q (out)
// ==============================================================================

module add_smoke_ring #(parameter int W = 32) (
  input  logic clk,
  input  logic perturb,
  output logic q
);

  logic [W-1:0] a, b, out;

  lfsr_src  #(.W(W)) u_srcA (.clk, .perturb(perturb), .q(a));
  lfsr_src  #(.W(W)) u_srcB (.clk, .perturb(a[0]),    .q(b));
  add_smoke #(.W(W)) u_dut  (.clk, .a, .b, .out);
  xor_sink  #(.W(W)) u_sink (.clk, .d(out), .q(q));

endmodule
