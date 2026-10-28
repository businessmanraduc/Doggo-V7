// ================================================================================
//  rob_ring: ring wrapper, every DUT port register-bounded
// ================================================================================
//  ds_fire closes the core loop: valid & iqReady (ring flops) & rob_dispatchReady
//  & !cm_flush & !mispredict.
// ================================================================================
`include "uop_defs.svh"

module rob_ring (
  input  logic clk,
  input  logic perturb,
  output logic q
);

  logic [31:0] s0, s1, s2, s3, s4;

  lfsr_src #(.W(32)) u_s0 (.clk, .perturb(perturb), .q(s0));
  lfsr_src #(.W(32)) u_s1 (.clk, .perturb(s0[0]),   .q(s1));
  lfsr_src #(.W(32)) u_s2 (.clk, .perturb(s1[0]),   .q(s2));
  lfsr_src #(.W(32)) u_s3 (.clk, .perturb(s2[0]),   .q(s3));
  lfsr_src #(.W(32)) u_s4 (.clk, .perturb(s3[0]),   .q(s4));

  logic [159:0] src; assign src = {s4, s3, s2, s1, s0};

  logic                rob_dispatchReady, rob_empty, cm_valid, cm_exception, cm_refetch, cm_flush;
  logic [3:0]          ds_robIndex;
  logic [4:0]          cm_rdIndex;
  logic [5:0]          cm_rdTag, cm_rdOldTag;
  logic                cm_rdWriteEnable, cm_rvc, cm_illegal, cm_serialising, cm_isLoad, cm_isStore;
  logic [30:0]         cm_pc;
  logic [SYSTEM_W-1:0] cm_system;
  logic [31:0]         cm_badAddress;
  logic                ds_fire;

  assign ds_fire = src[60] & src[61] & rob_dispatchReady & !cm_flush & !(src[80] & src[81]);

  rob u_dut (
    .clk,
    .resetn               (src[62] | src[63]),
    .ds_fire,
    .pds_ds_rdIndex       (src[4:0]),
    .pds_ds_rdTag         (src[10:5]),
    .pds_ds_rdOldTag      (src[16:11]),
    .pds_ds_rdWriteEnable (src[17]),
    .pds_ds_pc            (src[48:18]),
    .pds_ds_rvc           (src[49]),
    .pds_ds_class         (src[97:86]),
    .pds_ds_system        (src[55:50]),
    .pds_ds_illegal       (src[56]),
    .pds_ds_serialising   (src[57]),
    .rob_dispatchReady,
    .rob_empty,
    .ds_robIndex,
    .wb_valid             (src[66]),
    .wb_robIndex          (src[70:67]),
    .wb_exception         (src[71]),
    .wb_refetch           (src[72]),
    .wb_badAddress        (src[129:98]),
    .lq_violationValid    (src[73]),
    .lq_violationRobIndex (src[77:74]),
    .ex_resolveValid      (src[80]),
    .ex_resolveMispredict (src[81]),
    .ex_resolveRobIndex   (src[85:82]),
    .cm_valid, .cm_exception, .cm_refetch, .cm_flush,
    .cm_rdIndex, .cm_rdTag, .cm_rdOldTag, .cm_rdWriteEnable, .cm_pc, .cm_rvc,
    .cm_system, .cm_illegal, .cm_serialising, .cm_isLoad, .cm_isStore,
    .cm_badAddress
  );

  xor_sink #(.W(70 + 32)) u_snk (.clk, .q,
    .d({cm_badAddress, cm_rdIndex, cm_rdTag, cm_rdOldTag, cm_rdWriteEnable, cm_pc, cm_rvc, cm_system,
        cm_illegal, cm_serialising, cm_isLoad, cm_isStore,
        cm_valid, cm_exception, cm_refetch, cm_flush, rob_dispatchReady, rob_empty, ds_robIndex}));

endmodule
