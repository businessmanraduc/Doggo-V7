// =============================================================================
//  add_smoke -- throwaway DUT (registered 32-bit adder)
// =============================================================================

module add_smoke #(parameter int W = 32) (
  input  logic         clk,
  input  logic [W-1:0] a,
  input  logic [W-1:0] b,
  output logic [W-1:0] out
);

  always_ff @(posedge clk) begin
    out <= a + b;
  end

endmodule

