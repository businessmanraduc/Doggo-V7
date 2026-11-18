// ================================================================================
//  phantooom_core_ring -- ring wrapper: every top port register-bounded
//  ports are the ring convention: clk, perturb (in), q (out)
// ================================================================================
`include "uop_defs.svh"

module phantooom_core_ring (
  input  logic clk,
  input  logic perturb,
  output logic q
);

  logic [95:0] s;
  lfsr_src #(.W(32)) u_s0 (.clk, .perturb(perturb), .q(s[31:0]));
  lfsr_src #(.W(32)) u_s1 (.clk, .perturb(s[0]),    .q(s[63:32]));
  lfsr_src #(.W(32)) u_s2 (.clk, .perturb(s[32]),   .q(s[95:64]));

  logic                stall_d_r1, cm_valid, cm_exception, cm_refetch, cm_flush;
  logic [4:0]          cm_rdIndex;
  logic [5:0]          cm_rdTag, cm_rdOldTag;
  logic                cm_rdWriteEnable, cm_rvc, cm_illegal, cm_serialising, cm_isLoad, cm_isStore;
  logic [30:0]         cm_pc;
  logic [SYSTEM_W-1:0] cm_system;
  logic [31:0]         cm_badAddress;

  phantooom_core u_dut (
    .clk,
    .resetn     (s[0]),
    .f5_d_valid (s[1]),
    .f5_d_instr (s[33:2]),
    .f5_d_rvc   (s[34]),
    .f5_d_pc    (s[65:35]),
    .f5_d_meta  (s[66]),
    .stall_d_r1,
    .cm_valid, .cm_exception, .cm_refetch, .cm_flush, .cm_rdIndex, .cm_rdTag, .cm_rdOldTag,
    .cm_rdWriteEnable, .cm_pc, .cm_rvc, .cm_system, .cm_illegal, .cm_serialising,
    .cm_isLoad, .cm_isStore, .cm_badAddress
  );

  xor_sink #(.W(91 + SYSTEM_W)) u_snk (.clk, .q, .d({stall_d_r1, cm_valid, cm_exception,
    cm_refetch, cm_flush, cm_rdIndex, cm_rdTag, cm_rdOldTag, cm_rdWriteEnable, cm_pc, cm_rvc,
    cm_system, cm_illegal, cm_serialising, cm_isLoad, cm_isStore, cm_badAddress}));

endmodule
