// ===============================================================================
//  ring_harness -- standalone-timing primitives
//  lfsr_src: registered pseudo-random stimulus
//  xor_sink: registers DUT outputs, folds to one pin
// ===============================================================================

module lfsr_src #(parameter int W = 32) (
  input  logic          clk,
  input  logic          perturb,
  output logic [W-1:0]  q
);

  logic [W-1:0] r = '1;
  always_ff @(posedge clk) begin
    r <= {r[W-2:0], r[W-1] ^ r[W-2] ^ perturb};
  end
  assign q = r;

endmodule


module xor_sink #(parameter int W = 32) (
  input  logic          clk,
  input  logic [W-1:0]  d,
  output logic          q
);

  logic [W-1:0] dq;
  always_ff @(posedge clk) begin
    dq <= d;
  end
  assign q = ^dq;

endmodule

