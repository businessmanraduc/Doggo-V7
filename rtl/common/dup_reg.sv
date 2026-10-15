// ================================================================================
//  dup_reg: register copy for splitting huge fanouts
// ================================================================================
//  Custom properties:
//   - keep_hierarchy used such that yosys doesn't fold identical circuits
//     into one.
// ================================================================================
`ifndef FORMAL
(* keep_hierarchy *)
`endif
module dup_reg #(
  parameter int           W   = 8,
  parameter logic [W-1:0] RST = '0
) (
  input  logic         clk,
  input  logic         resetn,
  input  logic [W-1:0] d,
  output logic [W-1:0] q
);

  always_ff @(posedge clk) begin
    if (!resetn) q <= RST;
    else         q <= d;
  end

endmodule

