// ================================================================================
//  iq_grantcell: the grant destinations of one IQ slot
// ================================================================================
//  grant = ready & chainHit.
//
//  Custom properties:
//   - every destination is one LUT on ready, chainHit and a per-slot bit which
//     holds the kill + latency group, so each flop sits one LUT after the chain.
//   - keep_hierarchy used such that abc9 doesn't compute ready & chainHit
//     once then share it across all destinations.
// ================================================================================
`ifndef FORMAL
(* keep_hierarchy *)
`endif
module iq_grantcell (
  input  logic ready,
  input  logic chainHit,
  input  logic live,            // not killed
  input  logic liveL1,          // not killed - L1 producer
  input  logic liveL3,
  input  logic liveL4,
  input  logic liveL5,
  input  logic liveHold,        // not killed - L4/L5 producer
  input  logic wakeNext,        // a late wake of this slot landing next cycle
  output logic grantLive,
  output logic grantL3,
  output logic grantL4,
  output logic grantL5,
  output logic grantHold,
  output logic wakeNowNext      // L1 grant now OR late wake next cycle
);

  // ---- A=ready B=chainHit C=live bit D=wakeNext --------------------------------
  localparam logic [15:0] GRANT_AND  = 16'h8080;
  localparam logic [15:0] GRANT_WAKE = 16'hFF80;

  LUT4 #(.INIT(GRANT_AND))  u_live (.A(ready), .B(chainHit), .C(live),     .D(1'b0),     .Z(grantLive));
  LUT4 #(.INIT(GRANT_AND))  u_l3   (.A(ready), .B(chainHit), .C(liveL3),   .D(1'b0),     .Z(grantL3));
  LUT4 #(.INIT(GRANT_AND))  u_l4   (.A(ready), .B(chainHit), .C(liveL4),   .D(1'b0),     .Z(grantL4));
  LUT4 #(.INIT(GRANT_AND))  u_l5   (.A(ready), .B(chainHit), .C(liveL5),   .D(1'b0),     .Z(grantL5));
  LUT4 #(.INIT(GRANT_AND))  u_hold (.A(ready), .B(chainHit), .C(liveHold), .D(1'b0),     .Z(grantHold));
  LUT4 #(.INIT(GRANT_WAKE)) u_wake (.A(ready), .B(chainHit), .C(liveL1),   .D(wakeNext), .Z(wakeNowNext));

endmodule

