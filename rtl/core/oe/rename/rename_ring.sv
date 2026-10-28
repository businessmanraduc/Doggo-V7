// ================================================================================
//  rename_ring -- ring wrapper: every DUT port register-bounded
//  ports are the ring convention: clk, perturb (in), q (out)
// ================================================================================

module rename_ring (
  input  logic clk,
  input  logic perturb,
  output logic q
);

  logic [31:0] s0;
  logic [13:0] s1;

  lfsr_src #(.W(32)) u_s0 (.clk, .perturb(perturb), .q(s0));
  lfsr_src #(.W(14)) u_s1 (.clk, .perturb(s0[0]),   .q(s1));

  logic       stall_r1_r2, stall_d_r1, rd2_skidValid;
  logic       r2_pds_valid;
  logic [5:0] r2_pds_rs1Tag, r2_pds_rs2Tag, r2_pds_rdTag, r2_pds_rdOldTag;
  logic       r2_pds_rs1Use, r2_pds_rs2Use, r2_pds_rdWriteEnable;
  logic [4:0] r2_pds_rdIndex;
  logic [3:0] r2_pds_branchMask;
  logic [1:0] r2_pds_snapshot;

  rename u_dut (
    .clk,
    .resetn               (s1[13]),
    .d_r1_valid           (s0[0]),
    .d_r1_rs1Index        (s0[5:1]),
    .d_r1_rs2Index        (s0[10:6]),
    .d_r1_rdIndex         (s0[15:11]),
    .d_r1_rs1Use          (s0[16]),
    .d_r1_rs2Use          (s0[17]),
    .d_r1_rdWriteEnable   (s0[18]),
    .d_r1_isBranch        (s0[19]),
    .d_r1_isJalr          (s0[20]),
    .stall_r2_pds         (s0[21]),
    .ex_resolveValid      (s0[22]),
    .ex_resolveSnapshot   (s0[24:23]),
    .ex_resolveMispredict (s0[25]),
    .cm_commitRd          (s0[26]),
    .cm_rdIndex           (s0[31:27]),
    .cm_rdTag             (s1[5:0]),
    .cm_rdOldTag          (s1[11:6]),
    .cm_flush             (s1[12]),
    .stall_r1_r2, .stall_d_r1, .rd2_skidValid,
    .r2_pds_valid, .r2_pds_rs1Tag, .r2_pds_rs2Tag, .r2_pds_rdTag, .r2_pds_rdOldTag,
    .r2_pds_rs1Use, .r2_pds_rs2Use, .r2_pds_rdIndex, .r2_pds_rdWriteEnable,
    .r2_pds_branchMask, .r2_pds_snapshot
  );

  xor_sink #(.W(42)) u_snk (.clk, .q, .d({
    stall_r1_r2, stall_d_r1, rd2_skidValid,
    r2_pds_valid, r2_pds_rs1Tag, r2_pds_rs2Tag, r2_pds_rdTag, r2_pds_rdOldTag,
    r2_pds_rs1Use, r2_pds_rs2Use, r2_pds_rdIndex, r2_pds_rdWriteEnable,
    r2_pds_branchMask, r2_pds_snapshot}));

endmodule
