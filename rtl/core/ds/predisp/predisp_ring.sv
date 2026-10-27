// ================================================================================
//  predisp_ring -- ring wrapper: every DUT port register-bounded
//  ports are the ring convention: clk, perturb (in), q (out)
// ================================================================================
//  stall_pds_ds and ds_iqFire are one LUT each on pds_ds_valid and flops, as
//  DS makes them (IQ tail ready, ROB credit and skipIq, all registered).
// ================================================================================

`include "uop_defs.svh"

module predisp_ring (
  input  logic clk,
  input  logic perturb,
  output logic q
);

  logic [31:0] s0, s1, s2, s3;

  lfsr_src #(.W(32)) u_s0 (.clk, .perturb(perturb), .q(s0));
  lfsr_src #(.W(32)) u_s1 (.clk, .perturb(s0[0]),   .q(s1));
  lfsr_src #(.W(32)) u_s2 (.clk, .perturb(s1[0]),   .q(s2));
  lfsr_src #(.W(32)) u_s3 (.clk, .perturb(s2[0]),   .q(s3));

  logic                 stall_r2_pds;
  logic                 pds_ds_valid;
  logic [5:0]           pds_ds_rs1Tag, pds_ds_rs2Tag, pds_ds_rdTag, pds_ds_rdOldTag;
  logic                 pds_ds_rs1Use, pds_ds_rs2Use, pds_ds_rdWriteEnable;
  logic [4:0]           pds_ds_rdIndex;
  logic [3:0]           pds_ds_branchMask;
  logic [1:0]           pds_ds_snapshot;
  logic [LATENCY_W-1:0] pds_ds_latency;
  logic [7:0]           pds_ds_depL1, pds_ds_depL3, pds_ds_depL4, pds_ds_depL5;
  logic                 pds_ds_rs1Wait, pds_ds_rs2Wait;
  logic                 stall_pds_ds, ds_iqFire;

  assign stall_pds_ds = pds_ds_valid & (s3[30] | s3[31]);
  assign ds_iqFire    = pds_ds_valid & !(s3[30] | s3[31]) & !s3[28];

  predisp u_dut (
    .clk,
    .resetn               (s3[29]),
    .r2_pds_valid         (s0[0]),
    .r2_pds_rs1Tag        (s0[6:1]),
    .r2_pds_rs2Tag        (s0[12:7]),
    .r2_pds_rdTag         (s0[18:13]),
    .r2_pds_rdOldTag      (s0[24:19]),
    .r2_pds_rs1Use        (s0[25]),
    .r2_pds_rs2Use        (s0[26]),
    .r2_pds_rdIndex       (s0[31:27]),
    .r2_pds_rdWriteEnable (s1[0]),
    .r2_pds_branchMask    (s1[4:1]),
    .r2_pds_snapshot      (s1[6:5]),
    .r2_pds_latency       (s1[11:7]),
    .stall_pds_ds,
    .ds_iqFire,
    .ex_resolveValid      (s1[12]),
    .ex_resolveSnapshot   (s1[14:13]),
    .ex_resolveMispredict (s1[15]),
    .cm_flush             (s1[16]),
    .iq_tailSlot          (s1[24:17]),
    .iq_visible           ({s1[31:25], s2[0]}),
    .iq_grantPrevious     (s2[8:1]),
    .iq_wakeL3            (s2[16:9]),
    .iq_wakeL4            (s2[24:17]),
    .iq_wakeL5            ({s2[31:25], s3[0]}),
    .stall_r2_pds,
    .pds_ds_valid, .pds_ds_rs1Tag, .pds_ds_rs2Tag, .pds_ds_rdTag, .pds_ds_rdOldTag,
    .pds_ds_rs1Use, .pds_ds_rs2Use, .pds_ds_rdIndex, .pds_ds_rdWriteEnable,
    .pds_ds_branchMask, .pds_ds_snapshot, .pds_ds_latency,
    .pds_ds_depL1, .pds_ds_depL3, .pds_ds_depL4, .pds_ds_depL5, .pds_ds_rs1Wait, .pds_ds_rs2Wait
  );

  xor_sink #(.W(79)) u_snk (.clk, .q, .d({
    stall_r2_pds,
    pds_ds_valid, pds_ds_rs1Tag, pds_ds_rs2Tag, pds_ds_rdTag, pds_ds_rdOldTag,
    pds_ds_rs1Use, pds_ds_rs2Use, pds_ds_rdIndex, pds_ds_rdWriteEnable,
    pds_ds_branchMask, pds_ds_snapshot, pds_ds_latency,
    pds_ds_depL1, pds_ds_depL3, pds_ds_depL4, pds_ds_depL5, pds_ds_rs1Wait, pds_ds_rs2Wait}));

endmodule
