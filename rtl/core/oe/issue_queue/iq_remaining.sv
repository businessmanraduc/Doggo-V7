// ================================================================================
//  iq_remaining: one source of the row being written still waiting
// ================================================================================
//  Properties:
//   - one cc_pmux, every input a flop.
//   - slot cells pass unless their wake lands now, in which case they return 0,
//   similar with the divider and pending-word cells for a source waiting.
//   - a pass cell at the bottom keeps the chain even, so output cells are not
//   folded.
//   - keep_hierarchy, such that the copies are kept apart.
// ================================================================================
`ifndef FORMAL
(* keep_hierarchy *)
`endif
module iq_remaining #(
  parameter int N = 8
) (
  input  logic         waitFlag,
  input  logic         fromDiv,
  input  logic         fromMiss,
  input  logic [N-1:0] slot,
  input  logic [N-1:0] wakeNow,
  input  logic         divWakeNow,
  input  logic         missWakeNow,
  output logic         remaining
);

  cc_pmux #(.M(N + 4)) u_chain (
    .a({{(N + 2){1'b0}}, waitFlag, 1'b0}),
    .b({slot, fromDiv, fromMiss, 2'b10}),
    .d({wakeNow, divWakeNow, missWakeNow, 2'b10}),
    .co(remaining)
  );

endmodule

