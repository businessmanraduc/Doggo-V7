`include "isa.svh"
// =================================================================================
//  rob_ring -- ring wrapper: every DUT port register-bounded
//  ports are the ring convention: clk, perturb (in), q (out)
// =================================================================================

module rob_ring (
  input  logic clk,
  input  logic perturb,
  output logic q
);

  logic [31:0] rndA, rndB;

  logic        disp_ready;
  logic [3:0]  disp_idx;
  logic [31:0] fwd_dataA, fwd_dataB;
  logic        fwd_doneA, fwd_doneB;
  logic        cmt_valid, cmt_regWrite, cmt_exception, cmt_isStore;
  logic [31:0] cmt_pc, cmt_result;
  logic [4:0]  cmt_archDestReg;
  trapCause_t  cmt_cause;

  lfsr_src #(.W(32)) u_srcA (.clk, .perturb(perturb),  .q(rndA));
  lfsr_src #(.W(32)) u_srcB (.clk, .perturb(rndA[0]),  .q(rndB));

  rob #(.DEPTH(16)) u_dut (
    .clk,
    .resetn           (rndA[31]),
    .flush            (rndA[30]),

    .disp_valid       (rndA[29]),
    .disp_pc          (rndA),
    .disp_regWrite    (rndA[28]),
    .disp_archDestReg (rndA[4:0]),
    .disp_isStore     (rndA[27]),
    .disp_ready       (disp_ready),
    .disp_idx         (disp_idx),

    .cmpl_valid       (rndA[26]),
    .cmpl_idx         (rndB[3:0]),
    .cmpl_result      (rndB),
    .cmpl_exception   (rndA[25]),
    .cmpl_cause       (trapCause_t'(rndB[7:4])),

    .fwd_idxA         (rndB[11:8]),
    .fwd_dataA        (fwd_dataA),
    .fwd_doneA        (fwd_doneA),
    .fwd_idxB         (rndB[15:12]),
    .fwd_dataB        (fwd_dataB),
    .fwd_doneB        (fwd_doneB),

    .cmt_valid        (cmt_valid),
    .cmt_pc           (cmt_pc),
    .cmt_regWrite     (cmt_regWrite),
    .cmt_archDestReg  (cmt_archDestReg),
    .cmt_result       (cmt_result),
    .cmt_exception    (cmt_exception),
    .cmt_cause        (cmt_cause),
    .cmt_isStore      (cmt_isStore),
    .cmt_accept       (rndA[24])
  );

  xor_sink #(.W(148)) u_sink (
    .clk,
    .d ({disp_ready, disp_idx,
         fwd_dataA, fwd_doneA, fwd_dataB, fwd_doneB,
         cmt_valid, cmt_pc, cmt_regWrite, cmt_archDestReg,
         cmt_result, cmt_exception, cmt_cause, cmt_isStore}),
    .q (q)
  );

endmodule

