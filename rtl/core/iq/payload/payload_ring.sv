// ================================================================================
//  payload_ring -- ring wrapper: every DUT port register-bounded
//  ports are the ring convention: clk, perturb (in), q (out)
// ================================================================================
//  ds_fire is one LUT on two flops (dispatch fire from registered state).
// ================================================================================

`include "uop_defs.svh"

module payload_ring (
  input  logic clk,
  input  logic perturb,
  output logic q
);

  logic [31:0] s0, s1, s2, s3, s4, s5, s6;

  lfsr_src #(.W(32)) u_s0 (.clk, .perturb(perturb), .q(s0));
  lfsr_src #(.W(32)) u_s1 (.clk, .perturb(s0[0]), .q(s1));
  lfsr_src #(.W(32)) u_s2 (.clk, .perturb(s1[0]), .q(s2));
  lfsr_src #(.W(32)) u_s3 (.clk, .perturb(s2[0]), .q(s3));
  lfsr_src #(.W(32)) u_s4 (.clk, .perturb(s3[0]), .q(s4));
  lfsr_src #(.W(32)) u_s5 (.clk, .perturb(s4[0]), .q(s5));
  lfsr_src #(.W(32)) u_s6 (.clk, .perturb(s5[0]), .q(s6));

  logic [223:0] src; assign src = {s6, s5, s4, s3, s2, s1, s0};
  logic [187:0] sinkData;

  payload #(.MW(1)) u_dut (
    .clk,
    .ds_fire               (src[204] & src[205]),
    .iq_tailSlot           (src[7:0]),
    .ds_robIndex           (src[11:8]),
    .pds_ds_rs1Tag         (src[17:12]),
    .pds_ds_rs2Tag         (src[23:18]),
    .pds_ds_rdTag          (src[29:24]),
    .pds_ds_rdWriteEnable  (src[30:30]),
    .pds_ds_snapshot       (src[32:31]),
    .pds_ds_pc             (src[63:33]),
    .pds_ds_meta           (src[64:64]),
    .pds_ds_isCall         (src[65:65]),
    .pds_ds_isRet          (src[66:66]),
    .pds_ds_branchTarget   (src[97:67]),
    .pds_ds_seq            (src[128:98]),
    .pds_ds_class          (src[140:129]),
    .pds_ds_sub            (src[141:141]),
    .pds_ds_selArith       (src[142:142]),
    .pds_ds_selAnd         (src[143:143]),
    .pds_ds_selOr          (src[144:144]),
    .pds_ds_selXor         (src[145:145]),
    .pds_ds_selSlt         (src[146:146]),
    .pds_ds_sltUnsigned    (src[147:147]),
    .pds_ds_shiftRight     (src[148:148]),
    .pds_ds_shiftArith     (src[149:149]),
    .pds_ds_xIsPC          (src[150:150]),
    .pds_ds_xIsZero        (src[151:151]),
    .pds_ds_zIsImm         (src[152:152]),
    .pds_ds_zIsZero        (src[153:153]),
    .pds_ds_branchUseLt    (src[154:154]),
    .pds_ds_branchInvert   (src[155:155]),
    .pds_ds_mulSignedA     (src[156:156]),
    .pds_ds_mulSignedB     (src[157:157]),
    .pds_ds_mulHigh        (src[158:158]),
    .pds_ds_divSigned      (src[159:159]),
    .pds_ds_divRemainder   (src[160:160]),
    .pds_ds_func3          (src[163:161]),
    .pds_ds_immediate      (src[195:164]),
    .is_pr_grant           (src[203:196]),
    .pr_rf_robIndex        (sinkData[3:0]),
    .pr_rf_rs1Tag          (sinkData[9:4]),
    .pr_rf_rs2Tag          (sinkData[15:10]),
    .pr_rf_rdTag           (sinkData[21:16]),
    .pr_rf_rdWriteEnable   (sinkData[22:22]),
    .pr_rf_snapshot        (sinkData[24:23]),
    .pr_rf_pc              (sinkData[55:25]),
    .pr_rf_meta            (sinkData[56:56]),
    .pr_rf_isCall          (sinkData[57:57]),
    .pr_rf_isRet           (sinkData[58:58]),
    .pr_rf_branchTarget    (sinkData[89:59]),
    .pr_rf_seq             (sinkData[120:90]),
    .pr_rf_class           (sinkData[132:121]),
    .pr_rf_sub             (sinkData[133:133]),
    .pr_rf_selArith        (sinkData[134:134]),
    .pr_rf_selAnd          (sinkData[135:135]),
    .pr_rf_selOr           (sinkData[136:136]),
    .pr_rf_selXor          (sinkData[137:137]),
    .pr_rf_selSlt          (sinkData[138:138]),
    .pr_rf_sltUnsigned     (sinkData[139:139]),
    .pr_rf_shiftRight      (sinkData[140:140]),
    .pr_rf_shiftArith      (sinkData[141:141]),
    .pr_rf_xIsPC           (sinkData[142:142]),
    .pr_rf_xIsZero         (sinkData[143:143]),
    .pr_rf_zIsImm          (sinkData[144:144]),
    .pr_rf_zIsZero         (sinkData[145:145]),
    .pr_rf_branchUseLt     (sinkData[146:146]),
    .pr_rf_branchInvert    (sinkData[147:147]),
    .pr_rf_mulSignedA      (sinkData[148:148]),
    .pr_rf_mulSignedB      (sinkData[149:149]),
    .pr_rf_mulHigh         (sinkData[150:150]),
    .pr_rf_divSigned       (sinkData[151:151]),
    .pr_rf_divRemainder    (sinkData[152:152]),
    .pr_rf_func3           (sinkData[155:153]),
    .pr_rf_immediate       (sinkData[187:156])
  );

  xor_sink #(.W(188)) u_snk (.clk, .q, .d(sinkData));

endmodule
