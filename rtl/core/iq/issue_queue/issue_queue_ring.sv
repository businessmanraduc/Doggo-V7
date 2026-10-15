// ================================================================================
//  issue_queue_ring -- ring wrapper: every DUT port register-bounded
//  ports are the ring convention: clk, perturb (in), q (out)
// ================================================================================
//  ds_fire is one LUT on two flops and iq_dispatchReady, as DS makes it
//  (pds_ds_valid and ROB credit registered, kill folded into the credit).
// ================================================================================

`include "uop_defs.svh"

module issue_queue_ring (
  input  logic clk,
  input  logic perturb,
  output logic q
);

  logic [31:0] s0, s1;

  lfsr_src #(.W(32)) u_s0 (.clk, .perturb(perturb), .q(s0));
  lfsr_src #(.W(32)) u_s1 (.clk, .perturb(s0[0]),   .q(s1));

  logic                 ds_fire, iq_dispatchReady;
  logic [7:0]           iq_tailSlot, iq_visible, iq_grantPrevious, iq_wakeL3, iq_wakeL4, iq_wakeL5;
  logic [7:0]           is_pr_grant;
  logic [3:0]           iq_grantBranchMask;
  logic [31:0]          s2, s3;

  lfsr_src #(.W(32)) u_s2 (.clk, .perturb(s1[0]), .q(s2));
  lfsr_src #(.W(32)) u_s3 (.clk, .perturb(s2[0]), .q(s3));

  assign ds_fire = s2[30] & s2[31] & iq_dispatchReady;

  issue_queue #(.N(8)) u_dut (
    .clk,
    .resetn               (s2[29]),
    .ds_fire,
    .pds_ds_depL1         (s0[7:0]),
    .pds_ds_depL3         (s0[15:8]),
    .pds_ds_depL4         (s0[23:16]),
    .pds_ds_depL5         (s0[31:24]),
    .pds_ds_rs1Wait       (s1[0]),
    .pds_ds_rs2Wait       (s1[1]),
    .pds_ds_rs1Slot       (s3[7:0]),
    .pds_ds_rs2Slot       (s3[15:8]),
    .pds_ds_rs1FromDiv    (s1[2]),
    .pds_ds_rs1FromMiss   (s1[3]),
    .pds_ds_rs2FromDiv    (s3[16]),
    .pds_ds_rs2FromMiss   (s3[17]),
    .pds_ds_latency       (s1[8:4]),
    .pds_ds_rdWriteEnable (s1[9]),
    .pds_ds_branchMask    (s1[13:10]),
    .iq_dispatchReady,
    .sd_steal             (s1[14]),
    .sd_divWake           (s1[15]),
    .sd_missWake          (s1[16]),
    .ex_resolveValid      (s1[17]),
    .ex_resolveSnapshot   (s1[19:18]),
    .ex_resolveMispredict (s1[20]),
    .cm_flush             (s1[21]),
    .iq_tailSlot, .iq_visible, .iq_grantPrevious, .iq_wakeL3, .iq_wakeL4, .iq_wakeL5,
    .is_pr_grant, .iq_grantBranchMask
  );

  xor_sink #(.W(61)) u_snk (.clk, .q, .d({
    iq_dispatchReady, iq_tailSlot, iq_visible, iq_grantPrevious, iq_wakeL3, iq_wakeL4, iq_wakeL5,
    is_pr_grant, iq_grantBranchMask}));

endmodule
