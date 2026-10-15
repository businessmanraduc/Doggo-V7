// ================================================================================
//  dup_reg_clear: register copy for fanouts + per-bit synchronous clear
// ================================================================================
//  Custom properties:
//   - dup_reg variant which also permits per-bit data clear.
//   - keep_hierarchy used such that yosys doesn't fold identical circuits
//     into one.
// ================================================================================
`ifndef FORMAL
(* keep_hierarchy *)
`endif
module dup_reg_clear #(
  parameter int           W   = 8,
  parameter logic [W-1:0] RST = '0
) (
  input  logic         clk,
  input  logic         resetn,
  input  logic [W-1:0] clear,
  input  logic [W-1:0] d,
  output logic [W-1:0] q
);

  always_ff @(posedge clk) begin
    for (int i = 0; i < W; i++)
      q[i] <= (!resetn || clear[i]) ? RST[i] : d[i];
  end

endmodule

