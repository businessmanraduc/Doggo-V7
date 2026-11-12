// ================================================================================
//  cc_eq3x -- eq = &(a ^ (b & c | d)) on one CCU2C chain:
//  A = w, x = B & C | D, P = A ^ (B & C | D), generate off with INJECT1.
//  With w = ~z, this turns to be the perfect x == z equation.
// ================================================================================

`ifndef FORMAL
(* keep_hierarchy *)
`endif
module cc_eq3x #(
  parameter int G = 1
) (
  input  logic [31:0]   a,
  input  logic [31:0]   b,
  input  logic [G-1:0]  c,
  input  logic [31:0]   d,
  output logic          eq
);

  localparam logic [15:0] P3X = 16'h556A;
  localparam int          B   = 32 / G;

  logic [16:0] cc;
  assign cc[0] = 1'b1;
  for (genvar i = 0; i < 16; i++) begin : g_cc
    CCU2C #(.INIT0(P3X), .INIT1(P3X), .INJECT1_0("YES"), .INJECT1_1("YES")) u_cc (
      .CIN(cc[i]),
      .A0(a[2*i]),   .B0(b[2*i]),   .C0(c[(2*i) / B]),   .D0(d[2*i]),
      .A1(a[2*i+1]), .B1(b[2*i+1]), .C1(c[(2*i+1) / B]), .D1(d[2*i+1]),
      .S0(),         .S1(),
      .COUT(cc[i+1])
    );
  end

  CCU2C #(.INIT0(16'h0000), .INIT1(16'h0000), .INJECT1_0("NO"), .INJECT1_1("NO")) u_out (
    .CIN(cc[16]),
    .A0(1'b0), .B0(1'b0), .C0(1'b0), .D0(1'b0),
    .A1(1'b0), .B1(1'b0), .C1(1'b0), .D1(1'b0),
    .S0(eq),   .S1(),     .COUT()
  );

endmodule

