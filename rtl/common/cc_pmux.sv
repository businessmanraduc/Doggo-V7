// ================================================================================
//  cc_pmux: 1-bit priority mux on one CCU2C carry chain
// ================================================================================
//  Custom properties:
//   - co = a[i] of highest i with b[i] & d[i], else 0.
//   - Cell M-1 has top priority.
//   - COUT = P ? CIN : G; where P = ~(B & D), G = A.
//   - keep_hierarchy used such that yosys doesn't fold the hand-built CCU2C
//     chain to a constant 0.
// ================================================================================
`ifndef FORMAL
(* keep_hierarchy *)
`endif
module cc_pmux #(parameter int M = 8) (
  input  logic [M-1:0] a,
  input  logic [M-1:0] b,
  input  logic [M-1:0] d,
  output logic         co
);

  localparam int          H    = (M + 1) / 2;
  localparam logic [15:0] PMUX = 16'h30FA;

  logic [2*H-1:0] ca, cb, cd;
  logic [H:0]     cc;

  // ---- pad to even cell count with propagate cell ------------------------------
  always_comb begin
    ca = '0;
    cb = '0;
    cd = '0;
    ca[M-1:0] = a;
    cb[M-1:0] = b;
    cd[M-1:0] = d;
  end

  assign cc[0] = 1'b0;
  for (genvar k = 0; k < H; k++) begin : g_cc
    CCU2C #(.INIT0(PMUX), .INIT1(PMUX), .INJECT1_0("NO"), .INJECT1_1("NO")) u_cc (
      .CIN(cc[k]),
      .A0(ca[2*k]),   .B0(cb[2*k]),   .C0(1'b1), .D0(cd[2*k]),
      .A1(ca[2*k+1]), .B1(cb[2*k+1]), .C1(1'b1), .D1(cd[2*k+1]),
      .S0(),          .S1(),          .COUT(cc[k+1])
    );
  end

  // ---- carry out through zero cell onto S0 -------------------------------------
  CCU2C #(.INIT0(16'h0000), .INIT1(16'h0000), .INJECT1_0("NO"), .INJECT1_1("NO")) u_out (
    .CIN(cc[H]),
    .A0(1'b0), .B0(1'b0), .C0(1'b0), .D0(1'b0),
    .A1(1'b0), .B1(1'b0), .C1(1'b0), .D1(1'b0),
    .S0(co),   .S1(),     .COUT()
  );

endmodule

