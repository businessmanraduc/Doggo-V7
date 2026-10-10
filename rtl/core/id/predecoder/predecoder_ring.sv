// ================================================================================
//  predecoder_ring -- ring wrapper: every DUT port register-bounded
//  ports are the ring convention: clk, perturb (in), q (out)
// ================================================================================

module predecoder_ring (
  input  logic clk,
  input  logic perturb,
  output logic q
);

  localparam int MW = 4;

  logic [31:0] s0, s1, s2;
  logic [7:0]  ctl;

  lfsr_src #(.W(32)) u_s0 (.clk, .perturb(perturb), .q(s0));
  lfsr_src #(.W(32)) u_s1 (.clk, .perturb(s0[0]),   .q(s1));
  lfsr_src #(.W(32)) u_s2 (.clk, .perturb(s1[0]),   .q(s2));
  lfsr_src #(.W(8))  u_sc (.clk, .perturb(s2[0]),   .q(ctl));

  logic          d_r1_valid, d_r1_rvc;
  logic [31:0]   d_r1_instr;
  logic [30:0]   d_r1_pc, d_r1_branchTarget, d_r1_seq;
  logic [MW-1:0] d_r1_meta;
  logic [4:0]    d_r1_rs1Index, d_r1_rs2Index, d_r1_rdIndex;
  logic          d_r1_rs1Use, d_r1_rs2Use, d_r1_rdWriteEnable;
  logic          d_r1_isBranch, d_r1_isJal, d_r1_isJalr, d_r1_isCall, d_r1_isRet;

  predecoder #(.MW(MW)) u_dut (
    .clk,
    .resetn     (ctl[7]),
    .f5_d_valid (ctl[6]),
    .f5_d_instr (s0),
    .f5_d_rvc   (ctl[5]),
    .f5_d_pc    (s1[30:0]),
    .f5_d_meta  (s2[MW-1:0]),
    .stall_d_r1 (ctl[4]),
    .flush_d_r1 (ctl[3]),
    .d_r1_valid, .d_r1_instr, .d_r1_rvc, .d_r1_pc, .d_r1_meta,
    .d_r1_rs1Index, .d_r1_rs2Index, .d_r1_rdIndex, .d_r1_rs1Use, .d_r1_rs2Use, .d_r1_rdWriteEnable,
    .d_r1_isBranch, .d_r1_isJal, .d_r1_isJalr, .d_r1_isCall, .d_r1_isRet,
    .d_r1_branchTarget, .d_r1_seq
  );

  xor_sink #(.W(154)) u_snk (.clk, .q, .d({
    d_r1_valid, d_r1_instr, d_r1_rvc, d_r1_pc, d_r1_meta,
    d_r1_rs1Index, d_r1_rs2Index, d_r1_rdIndex, d_r1_rs1Use, d_r1_rs2Use, d_r1_rdWriteEnable,
    d_r1_isBranch, d_r1_isJal, d_r1_isJalr, d_r1_isCall, d_r1_isRet,
    d_r1_branchTarget, d_r1_seq}));

endmodule
