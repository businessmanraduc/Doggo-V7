// ================================================================================
//  iq_rowcell: next state of one IQ slot
// ================================================================================
//  count = 0 ready, 1..2 sources outstanding, 3 empty.
//
//  Custom properties:
//   - normal half: the row's chain output grants a ready row/wakes a waiting one;
//     lateWake wakes one more source.
//   - override half: a row being written takes remaining1 + remaining2 - newHit;
//     saturating at 0.
//     Otherwise it becomes ready (because of two late wakes).
//   - keep_hierarchy used such that abc9 doesn't restructure hand mapping.
// ================================================================================
`ifndef FORMAL
(* keep_hierarchy *)
`endif
module iq_rowcell (
  input  logic [1:0]  count,
  input  logic        chainHit,
  input  logic        lateWake,
  input  logic        override,
  input  logic        remaining1,
  input  logic        remaining2,
  input  logic        dispatch,
  input  logic        newHit,
  output logic [1:0]  countNext,
  output logic        readyNext
);

  // ---- normal: A=chainHit B=lateWake C=count[0] D=count[1] ---------------------
  localparam logic [15:0] NORMAL_READY    = 16'h08E5;
  localparam logic [15:0] NORMAL_COUNT0   = 16'hF61A;
  localparam logic [15:0] NORMAL_COUNT1   = 16'hF10A;
  // ---- override: A=newHit B=remaining1 C=remaining2 D=dispatch -----------------
  localparam logic [15:0] OVERRIDE_READY  = 16'h2BFF;
  localparam logic [15:0] OVERRIDE_COUNT0 = 16'h9400;
  localparam logic [15:0] OVERRIDE_COUNT1 = 16'h4000;

  logic [2:0] normal, overridden, result;

  LUT4 #(.INIT(NORMAL_READY)) u_n0 (
    .A(chainHit), .B(lateWake),   .C(count[0]),   .D(count[1]), .Z(normal[0])
  );
  LUT4 #(.INIT(NORMAL_COUNT0)) u_n1 (
    .A(chainHit), .B(lateWake),   .C(count[0]),   .D(count[1]), .Z(normal[1])
  );
  LUT4 #(.INIT(NORMAL_COUNT1)) u_n2 (
    .A(chainHit), .B(lateWake),   .C(count[0]),   .D(count[1]), .Z(normal[2])
  );
  LUT4 #(.INIT(OVERRIDE_READY)) u_o0 (
    .A(newHit),   .B(remaining1), .C(remaining2), .D(dispatch), .Z(overridden[0])
  );
  LUT4 #(.INIT(OVERRIDE_COUNT0)) u_o1 (
    .A(newHit),   .B(remaining1), .C(remaining2), .D(dispatch), .Z(overridden[1])
  );
  LUT4 #(.INIT(OVERRIDE_COUNT1)) u_o2 (
    .A(newHit),   .B(remaining1), .C(remaining2), .D(dispatch), .Z(overridden[2])
  );

  for (genvar k = 0; k < 3; k++) begin : g_mux
    PFUMX u_mux (.ALUT(overridden[k]), .BLUT(normal[k]), .C0(override), .Z(result[k]));
  end

  assign readyNext = result[0];
  assign countNext = result[2:1];

endmodule

