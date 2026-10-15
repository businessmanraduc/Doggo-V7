// ================================================================================
//  ecp5_models: ECP5 primitive behaviour for simulation and formal only
// ================================================================================
//  Logic copied from yosys 0.62 share/ecp5/common_sim.vh and ccu2c_sim.vh.
//  Never passed to synthesis: synth_ecp5 maps real cells.
// ================================================================================

/* verilator lint_off WIDTHEXPAND */
module LUT4 (input A, B, C, D, output Z);
  parameter [15:0] INIT = 16'h0000;
  assign Z = INIT[{D, C, B, A}];
endmodule

module PFUMX (input ALUT, BLUT, C0, output Z);
  assign Z = C0 ? ALUT : BLUT;
endmodule

module L6MUX21 (input D0, D1, SD, output Z);
  assign Z = SD ? D1 : D0;
endmodule

module CCU2C (input CIN, A0, B0, C0, D0, A1, B1, C1, D1, output S0, S1, COUT);
  parameter [15:0] INIT0 = 16'h0000;
  parameter [15:0] INIT1 = 16'h0000;
  parameter INJECT1_0 = "YES";
  parameter INJECT1_1 = "YES";
  wire p0 = INIT0[{D0, C0, B0, A0}];
  wire g0 = (INJECT1_0 == "YES") ? 1'b0 : INIT0[{B0, A0}];
  wire ci0 = (INJECT1_0 == "YES") ? 1'b0 : CIN;
  wire c1 = p0 ? CIN : g0;
  wire p1 = INIT1[{D1, C1, B1, A1}];
  wire g1 = (INJECT1_1 == "YES") ? 1'b0 : INIT1[{B1, A1}];
  wire ci1 = (INJECT1_1 == "YES") ? 1'b0 : c1;
  assign S0 = p0 ^ ci0;
  assign S1 = p1 ^ ci1;
  assign COUT = p1 ? c1 : g1;
endmodule
/* verilator lint_on WIDTHEXPAND */

