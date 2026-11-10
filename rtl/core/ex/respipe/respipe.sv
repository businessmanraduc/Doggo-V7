// ================================================================================
//  Result pipe: uop control from grant to WB, result chain from EX1 to CM
// ================================================================================
//  IS/PR grant ──► RF ──► RR ──► EX0 ──► EX1 ──► EX2 ──► EX3 ──► WB ─┬─► CM
//                  valid, branch mask, rd tag, rob index             │   (data)
//                                                                    ├─► rf write
//                                                                    └─► wb_* (ROB)
// ================================================================================
//  Mechanisms:
//   - Valid from the grant one cycle late, aligned with payload read.
//   - Kill: commit flush/mispredict whose snapshot bit is in the mask clears
//   every stage & every cycle. A resolve clears its bit in every mask.
//   - Results: each functional unit joins the chain at its own position in
//   the conveyor belt based on its target latency.
// ================================================================================
module respipe (
  input  logic        clk,
  input  logic        resetn,
  // ---- Issue/Payload-Read inter-stage pipeline register ------------------------
  input  logic [7:0]  is_pr_grant,
  input  logic [3:0]  iq_grantBranchMask,
  // ---- Payload-Read/Register-File inter-stage pipeline register ----------------
  input  logic [5:0]  pr_rf_rdTag,
  input  logic        pr_rf_rdWriteEnable,
  input  logic [3:0]  pr_rf_robIndex,
  // ---- kill --------------------------------------------------------------------
  input  logic        ex0_resolveValid,
  input  logic [1:0]  ex0_resolveSnapshot,
  input  logic        ex0_resolveMispredict,
  input  logic        cm_flush,
  // ---- producers, for the forward compares in rr -------------------------------
  output logic        rf_rr_producer,
  output logic [5:0]  rf_rr_rdTag,
  output logic        rr_ex0_producer,
  output logic [5:0]  rr_ex0_rdTag,
  output logic        ex0_ex1_producer,
  output logic [5:0]  ex0_ex1_rdTag,
  output logic        ex1_ex2_producer,
  output logic [5:0]  ex1_ex2_rdTag,
  output logic        ex2_ex3_producer,
  output logic [5:0]  ex2_ex3_rdTag,
  output logic        ex3_wb_producer,
  output logic [5:0]  ex3_wb_rdTag,
  // ---- results -----------------------------------------------------------------
  input  logic [31:0] ex0_ex1_result,
  output logic [31:0] ex1_ex2_result,
  output logic [31:0] ex2_ex3_result,
  output logic [31:0] ex3_wb_result,
  output logic [31:0] wb_cm_result,
  // ---- completion (s+8) --------------------------------------------------------
  output logic        wb_valid,
  output logic [3:0]  wb_robIndex
);

  // ---- kill and resolve clear --------------------------------------------------
  logic       rp_mispredict;   assign rp_mispredict   = ex0_resolveValid & ex0_resolveMispredict;
  logic [3:0] rp_resolveClear; assign rp_resolveClear = ex0_resolveValid
    ? 4'(1) << ex0_resolveSnapshot : 4'b0;

  function automatic logic rp_kill(input logic [3:0] mask);
    rp_kill = cm_flush | (rp_mispredict & mask[ex0_resolveSnapshot]);
  endfunction

  // ---- PR/RF -------------------------------------------------------------------
  logic       pr_rf_valid;
  logic [3:0] pr_rf_branchMask;
  always_ff @(posedge clk) begin
    if (!resetn) pr_rf_valid <= 1'b0;
    else         pr_rf_valid <= |is_pr_grant & !rp_kill(iq_grantBranchMask);
    pr_rf_branchMask <= iq_grantBranchMask & ~rp_resolveClear;
  end

  // ---- RF/RR -------------------------------------------------------------------
  logic       rf_rr_valid;
  logic [3:0] rf_rr_branchMask, rf_rr_robIndex;
  logic       rf_rr_live;
  assign rf_rr_live = pr_rf_valid & !rp_kill(pr_rf_branchMask);
  always_ff @(posedge clk) begin
    if (!resetn) {rf_rr_valid, rf_rr_producer} <= 2'b00;
    else         {rf_rr_valid, rf_rr_producer} <= {rf_rr_live, rf_rr_live & pr_rf_rdWriteEnable};
    rf_rr_branchMask <= pr_rf_branchMask & ~rp_resolveClear;
    rf_rr_rdTag      <= pr_rf_rdTag;
    rf_rr_robIndex   <= pr_rf_robIndex;
  end

  // ---- RR/EX0 ------------------------------------------------------------------
  logic       rr_ex0_valid;
  logic [3:0] rr_ex0_branchMask, rr_ex0_robIndex;
  logic       rr_ex0_live;
  assign rr_ex0_live = rf_rr_valid & !rp_kill(rf_rr_branchMask);
  always_ff @(posedge clk) begin
    if (!resetn) {rr_ex0_valid, rr_ex0_producer} <= 2'b00;
    else         {rr_ex0_valid, rr_ex0_producer} <= {rr_ex0_live, rr_ex0_live & rf_rr_producer};
    rr_ex0_branchMask <= rf_rr_branchMask & ~rp_resolveClear;
    rr_ex0_rdTag      <= rf_rr_rdTag;
    rr_ex0_robIndex   <= rf_rr_robIndex;
  end

  // ---- EX0/EX1 -----------------------------------------------------------------
  logic       ex0_ex1_valid;
  logic [3:0] ex0_ex1_branchMask, ex0_ex1_robIndex;
  logic       ex0_ex1_live;
  assign ex0_ex1_live = rr_ex0_valid & !rp_kill(rr_ex0_branchMask);
  always_ff @(posedge clk) begin
    if (!resetn) {ex0_ex1_valid, ex0_ex1_producer} <= 2'b00;
    else         {ex0_ex1_valid, ex0_ex1_producer} <= {ex0_ex1_live, ex0_ex1_live & rr_ex0_producer};
    ex0_ex1_branchMask <= rr_ex0_branchMask & ~rp_resolveClear;
    ex0_ex1_rdTag      <= rr_ex0_rdTag;
    ex0_ex1_robIndex   <= rr_ex0_robIndex;
  end

  // ---- EX1/EX2 -----------------------------------------------------------------
  logic       ex1_ex2_valid;
  logic [3:0] ex1_ex2_branchMask, ex1_ex2_robIndex;
  logic       ex1_ex2_live;
  assign ex1_ex2_live = ex0_ex1_valid & !rp_kill(ex0_ex1_branchMask);
  always_ff @(posedge clk) begin
    if (!resetn) {ex1_ex2_valid, ex1_ex2_producer} <= 2'b00;
    else         {ex1_ex2_valid, ex1_ex2_producer} <= {ex1_ex2_live, ex1_ex2_live & ex0_ex1_producer};
    ex1_ex2_branchMask <= ex0_ex1_branchMask & ~rp_resolveClear;
    ex1_ex2_rdTag      <= ex0_ex1_rdTag;
    ex1_ex2_robIndex   <= ex0_ex1_robIndex;
    ex1_ex2_result     <= ex0_ex1_result;
  end

  // ---- EX2/EX3 -----------------------------------------------------------------
  logic       ex2_ex3_valid;
  logic [3:0] ex2_ex3_branchMask, ex2_ex3_robIndex;
  logic       ex2_ex3_live;
  assign ex2_ex3_live = ex1_ex2_valid & !rp_kill(ex1_ex2_branchMask);
  always_ff @(posedge clk) begin
    if (!resetn) {ex2_ex3_valid, ex2_ex3_producer} <= 2'b00;
    else         {ex2_ex3_valid, ex2_ex3_producer} <= {ex2_ex3_live, ex2_ex3_live & ex1_ex2_producer};
    ex2_ex3_branchMask <= ex1_ex2_branchMask & ~rp_resolveClear;
    ex2_ex3_rdTag      <= ex1_ex2_rdTag;
    ex2_ex3_robIndex   <= ex1_ex2_robIndex;
    ex2_ex3_result     <= ex1_ex2_result;
  end

  // ---- EX3/WB ------------------------------------------------------------------
  logic       ex3_wb_valid;
  logic [3:0] ex3_wb_robIndex;
  logic       ex3_wb_live;
  assign ex3_wb_live = ex2_ex3_valid & !rp_kill(ex2_ex3_branchMask);
  always_ff @(posedge clk) begin
    if (!resetn) {ex3_wb_valid, ex3_wb_producer} <= 2'b00;
    else         {ex3_wb_valid, ex3_wb_producer} <= {ex3_wb_live, ex3_wb_live & ex2_ex3_producer};
    ex3_wb_rdTag    <= ex2_ex3_rdTag;
    ex3_wb_robIndex <= ex2_ex3_robIndex;
    ex3_wb_result   <= ex2_ex3_result;
  end

  // ---- WB/CM: data only, for the forward in the cycle of the RF write ----------
  always_ff @(posedge clk) wb_cm_result <= ex3_wb_result;
  assign wb_valid    = ex3_wb_valid;
  assign wb_robIndex = ex3_wb_robIndex;

endmodule

