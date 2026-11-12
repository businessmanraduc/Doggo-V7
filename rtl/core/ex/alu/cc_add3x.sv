// ================================================================================
//  cc_add3x -- (b & c | d) + a + cin on one CCU2C chain, slt in the last cell.
//  P = A ^ (B & C | D), G = A (INIT 16'h556A; INIT[3:0] = A).
//  Out cell: slt = sltSel ? sltP ^ cout : 0.
// ================================================================================

`ifndef FORMAL
(* keep_hierarchy *)
`endif
module cc_add3x #(
  parameter int G = 1
) (
  input  logic [31:0]   a,
  input  logic [31:0]   b,
  input  logic [G-1:0]  c,
  input  logic [31:0]   d,
  input  logic          cin,
  input  logic          sltSel,
  input  logic          sltP,
  output logic [31:0]   s,
  output logic          slt
);

  localparam logic [15:0] ADD3X = 16'h556A;
  localparam logic [15:0] GATE  = 16'h0200;
  localparam logic [15:0] SLTX  = 16'h0800;
  localparam int          B     = 32 / G;

  logic [16:0] cc;
  assign cc[0] = cin;
  for (genvar i = 0; i < 16; i++) begin : g_cc
    CCU2C #(.INIT0(ADD3X), .INIT1(ADD3X), .INJECT1_0("NO"), .INJECT1_1("NO")) u_cc (
      .CIN(cc[i]),
      .A0(a[2*i]),   .B0(b[2*i]),   .C0(c[(2*i)   / B]), .D0(d[2*i]),
      .A1(a[2*i+1]), .B1(b[2*i+1]), .C1(c[(2*i+1) / B]), .D1(d[2*i+1]),
      .S0(s[2*i]),   .S1(s[2*i+1]),
      .COUT(cc[i+1])
    );
  end

  CCU2C #(.INIT0(GATE), .INIT1(SLTX), .INJECT1_0("NO"), .INJECT1_1("NO")) u_out (
    .CIN(cc[16]),
    .A0(sltSel), .B0(1'b0),   .C0(1'b0), .D0(1'b1),
    .A1(sltP),   .B1(sltSel), .C1(1'b0), .D1(1'b1),
    .S0(),       .S1(slt),    .COUT()
  );

endmodule

