// ================================================================================
//  Issue Queue: 8 slots, circular, fused wakeup + select
// ================================================================================
//  PreDS          DS                  IS           PR
//  predisp ────►  dispatch ──fire──►  iq ──grant─► payload read by slot
// ================================================================================
//  Row state:
//   - count (0 ready, 1..2 waiting, 3 empty)
//   - L1 & late dependency bits by slot
//   - producer latency group
//   - branch mask
//
//  Mechanisms:
//   - Chain: 1 cc_pmux/row returns the row's bit at the oldest ready slot ->
//   a ready row is granted, a waiting row is woken up.
//   - Late wakes: grant one-hot runs down a delay line per latency group and
//   meets the late bits a cycle before it lands.
//   - Dispatch: per-source, carry chain clears the wait flag when its
//   producer's wake lands this cycle. The row cell takes both flags minus newHit.
//   - Grant & row cells are hand-mapped so each flop sits one LUT after the
//   chain. A hill reaches the count & ready flops through set/reset.
//   - Windows: a slot is reused only after its last wake lands, such that it
//   stays visible to PreDS either one or two cycles after its grant.
//   - Kill: branch mask per row; a kill empties rows and closes the visible window.
// ================================================================================
`include "uop_defs.svh"

module issue_queue #(
  parameter int N = 8
) (
  input  logic                 clk,
  input  logic                 resetn,
  // ---- dispatch: the Dispatch-1/Dispatch register and the fire -----------------
  input  logic                 ds_iqGo,               // DS uop goes to IQ if tail free
  input  logic [N-1:0]         pds_ds_depL1,
  input  logic [N-1:0]         pds_ds_depL3,
  input  logic [N-1:0]         pds_ds_depL4,
  input  logic [N-1:0]         pds_ds_depL5,
  input  logic                 pds_ds_rs1Wait,
  input  logic                 pds_ds_rs2Wait,
  input  logic [N-1:0]         pds_ds_rs1Slot,
  input  logic [N-1:0]         pds_ds_rs2Slot,
  input  logic                 pds_ds_rs1FromDiv,     // source waiting for divider
  input  logic                 pds_ds_rs1FromMiss,    // source waiting for pending word
  input  logic                 pds_ds_rs2FromDiv,
  input  logic                 pds_ds_rs2FromMiss,
  input  logic [LATENCY_W-1:0] pds_ds_latency,
  input  logic                 pds_ds_rdWriteEnable,
  input  logic [3:0]           pds_ds_branchMask,
  output logic                 iq_dispatchReady,      // tail slot free
  // ---- sd slot, one cycle ahead of empty select cycle --------------------------
  input  logic                 sd_steal,
  input  logic                 sd_divWake,
  input  logic                 sd_missWake,
  // ---- branch resolve (EX), commit flush ---------------------------------------
  input  logic                 ex_resolveValid,
  input  logic [1:0]           ex_resolveSnapshot,
  input  logic                 ex_resolveMispredict,
  input  logic                 cm_flush,
  // ---- to predisp --------------------------------------------------------------
  output logic [N-1:0]         iq_tailSlot,           // one-hot
  output logic [N-1:0]         iq_visible,            // occupied/post-grant hold
  output logic [N-1:0]         iq_grantPrevious,      // last cycle's grant
  output logic [N-1:0]         iq_wakeL3,             // registered wakes landing this cycle
  output logic [N-1:0]         iq_wakeL4,
  output logic [N-1:0]         iq_wakeL5,
  // ---- Issue/Payload-Read inter-stage pipeline register ------------------------
  output logic [N-1:0]         is_pr_grant,           // one-hot, killed grants removed
  output logic [3:0]           iq_grantBranchMask     // mask of granted row, in PR
);

  localparam int RDUP = 2;

  // ---- kill & resolve ----------------------------------------------------------
  logic         iq_mispredict;
  logic [3:0]   iq_resolveClear;
  logic [N-1:0] iq_kill;
  logic [N-1:0] iq_tailOneHot;
  logic         iq_dispatchReadyQ;
  logic [N-1:0] iq_tailFree;
  logic         iq_fire;
  logic [3:0]   iq_branchMask [N];

  assign iq_mispredict   = ex_resolveValid & ex_resolveMispredict;
  assign iq_resolveClear = ex_resolveValid ? 4'(1) << ex_resolveSnapshot : 4'b0;
  for (genvar k = 0; k < N; k++) begin : g_kill
    assign iq_kill[k] = cm_flush | (iq_mispredict & (
      iq_branchMask[k][ex_resolveSnapshot] | iq_tailFree[k]
    ));
  end

  // ---- row state ---------------------------------------------------------------
  logic [1:0]   iq_count [N];
  logic [N-1:0] iq_occupied, iq_waiting;
  logic [N-1:0] iq_ready;
  logic [N-1:0] iq_depL1 [N];
  logic [N-1:0] iq_isL1,     iq_isL3,      iq_isL4, iq_isL5;
  logic [N-1:0] iq_depDiv,   iq_depMiss;
  logic [N-1:0] iq_lateWake, iq_lateWake2;

  for (genvar k = 0; k < N; k++) begin : g_state
    assign iq_occupied[k] = iq_count[k] != 2'd3;
    assign iq_waiting[k]  = iq_count[k] == 2'd1 || iq_count[k] == 2'd2;
  end

  // ---- tail, dispatch select ---------------------------------------------------
  logic [N-1:0] iq_tailOneHotNext;
  logic [N-1:0] iq_tailMask,   iq_tailMaskNext;
  logic [N-1:0] iq_dispatchSelect;

  assign iq_fire           = ds_iqGo & iq_dispatchReadyQ;
  assign iq_tailOneHotNext = iq_fire ? {iq_tailOneHot[N-2:0], iq_tailOneHot[N-1]}             : iq_tailOneHot;
  assign iq_tailMaskNext   = iq_fire ? (iq_tailOneHot[N-1] ? '1 : {iq_tailMask[N-2:0], 1'b0}) : iq_tailMask;
  assign iq_dispatchSelect = {N{ds_iqGo}} & iq_tailFree;
  assign iq_tailSlot       = iq_tailOneHot;

  // ---- chain inputs: ready, tail mask (upper copy), open (lower copy) ----------
  logic [N-1:0] iq_readyNext;
  logic [N-1:0] iq_readyCopy [RDUP];
  logic [N-1:0] iq_maskCopy  [RDUP];
  logic [N-1:0] iq_openCopy  [RDUP];

  for (genvar g = 0; g < RDUP; g++) begin : g_dup
    dup_reg_clear #(.W(N), .RST('0)) u_ready (
      .clk, .resetn, .clear(iq_kill), .d(iq_readyNext),    .q(iq_readyCopy[g])
    );
    dup_reg #(.W(N), .RST('1)) u_mask (
      .clk, .resetn, .d(iq_tailMaskNext & {N{!sd_steal}}), .q(iq_maskCopy[g])
    );
    dup_reg #(.W(N), .RST('1)) u_open (
      .clk, .resetn, .d({N{!sd_steal}}),                   .q(iq_openCopy[g])
    );
  end

  // ---- fused wakeup + select ---------------------------------------------------
  logic [2*N-1:0] iq_cellReady [RDUP];
  logic [2*N-1:0] iq_cellOpen  [RDUP];
  for (genvar g = 0; g < RDUP; g++) begin : g_cells
    for (genvar c = 0; c < 2 * N; c++) begin : g_cell
      localparam int K = (c < N) ? N - 1 - c : 2 * N - 1 - c;
      assign iq_cellReady[g][c] = iq_readyCopy[g][K];
      assign iq_cellOpen[g][c]  = (c < N) ? iq_openCopy[g][K] : iq_maskCopy[g][K];
    end
  end

  logic [N-1:0] iq_chainHit;
  logic         iq_newHit;

  for (genvar j = 0; j < N; j++) begin : g_row
    localparam int G = j * RDUP / (N + 1);
    logic [2*N-1:0] iq_offer;
    for (genvar c = 0; c < 2 * N; c++) begin: g_offer
      localparam int K = (c < N) ? N - 1 - c : 2 * N - 1 - c;
      assign iq_offer[c] = (K == j) ? 1'b1 : iq_depL1[j][K];
    end
    cc_pmux #(.M(2 * N)) u_chain (
      .a(iq_offer), .b(iq_cellReady[G]), .d(iq_cellOpen[G]), .co(iq_chainHit[j])
    );
  end

  logic [2*N-1:0] iq_dispatchOffer;
  for (genvar c = 0; c < 2 * N; c++) begin : g_dispatchOffer
    localparam int K = (c < N) ? N - 1 - c : 2 * N - 1 - c;
    assign iq_dispatchOffer[c] = pds_ds_depL1[K];
  end
  cc_pmux #(.M(2 * N)) u_dispatchChain (
    .a(iq_dispatchOffer),                .b(iq_cellReady[N * RDUP / (N + 1)]),
    .d(iq_cellOpen[N * RDUP / (N + 1)]), .co(iq_newHit)
  );

  // ---- grant: ready & chain ----------------------------------------------------
  logic [N-1:0] iq_grantLive, iq_grantL3, iq_grantL4, iq_grantL5, iq_grantHold, iq_wakeNowNext;
  logic [N-1:0] iq_wakeNow, iq_wakeNext;

  for (genvar k = 0; k < N; k++) begin : g_grant
    iq_grantcell u_grant (
      .ready(iq_ready[k]), .chainHit(iq_chainHit[k]), .live(!iq_kill[k]),
      .liveL1(iq_isL1[k] & !iq_kill[k]), .liveL3(iq_isL3[k] & !iq_kill[k]),
      .liveL4(iq_isL4[k] & !iq_kill[k]), .liveL5(iq_isL5[k] & !iq_kill[k]),
      .liveHold((iq_isL4[k] | iq_isL5[k]) & !iq_kill[k]),
      .wakeNext(iq_wakeNext[k]),         .grantLive(iq_grantLive[k]),
      .grantL3(iq_grantL3[k]),           .grantL4(iq_grantL4[k]),
      .grantL5(iq_grantL5[k]),           .grantHold(iq_grantHold[k]),
      .wakeNowNext(iq_wakeNowNext[k])
    );
  end

  // ---- delay lines: L3 -> s+2; L4 -> s+3; L5 -> s+4 ----------------------------
  logic [N-1:0] iq_delayL3, iq_delayL4a, iq_delayL4b, iq_delayL5a, iq_delayL5b, iq_delayL5c;
  logic         iq_divWakeNow, iq_missWakeNow;
  assign iq_wakeNext = iq_delayL3 | iq_delayL4b | iq_delayL5c;

  always_ff @(posedge clk) begin
    if (!resetn) begin
      iq_delayL3       <= '0;
      iq_delayL4a      <= '0;
      iq_delayL4b      <= '0;
      iq_delayL5a      <= '0;
      iq_delayL5b      <= '0;
      iq_delayL5c      <= '0;
      iq_wakeL3        <= '0;
      iq_wakeL4        <= '0;
      iq_wakeL5        <= '0;
      iq_grantPrevious <= '0;
      iq_wakeNow       <= '0;
      iq_divWakeNow    <= 1'b0;
      iq_missWakeNow   <= 1'b0;
    end else begin
      iq_delayL3       <= iq_grantL3;
      iq_delayL4a      <= iq_grantL4;
      iq_delayL4b      <= iq_delayL4a;
      iq_delayL5a      <= iq_grantL5;
      iq_delayL5b      <= iq_delayL5a;
      iq_delayL5c      <= iq_delayL5b;
      iq_wakeL3        <= iq_delayL3;
      iq_wakeL4        <= iq_delayL4b;
      iq_wakeL5        <= iq_delayL5c;
      iq_grantPrevious <= iq_grantLive;
      iq_wakeNow       <= iq_wakeNowNext;
      iq_divWakeNow    <= sd_divWake;
      iq_missWakeNow   <= sd_missWake;
    end
  end
  assign is_pr_grant = iq_grantPrevious;

  always_comb begin
    iq_grantBranchMask = 4'b0;
    for (int k = 0; k < N; k++)
      if (iq_grantPrevious[k]) iq_grantBranchMask = iq_grantBranchMask | iq_branchMask[k];
  end

  // ---- at least one / at least two set bits ------------------------------------
  function automatic logic [1:0] upToTwo(input logic [N+1:0] v);
    logic seenTwo;
    seenTwo = 1'b0;
    for (int i = 0; i < N + 2; i++)
      for (int k = i + 1; k < N + 2; k++) seenTwo = seenTwo | (v[i] & v[k]);
    upToTwo = {seenTwo, |v};
  endfunction

  // ---- per-source, still waiting after wakes landing now, two copies each ------
  logic [1:0] iq_remaining1, iq_remaining2;
  logic       iq_next1,      iq_next2;

  for (genvar h = 0; h < 2; h++) begin : g_remaining
    iq_remaining #(.N(N)) u_rs1 (
      .waitFlag(pds_ds_rs1Wait),     .fromDiv(pds_ds_rs1FromDiv),
      .fromMiss(pds_ds_rs1FromMiss), .slot(pds_ds_rs1Slot),
      .wakeNow(iq_wakeNow),          .divWakeNow(iq_divWakeNow),
      .missWakeNow(iq_missWakeNow),  .remaining(iq_remaining1[h])
    );
    iq_remaining #(.N(N)) u_rs2 (
      .waitFlag(pds_ds_rs2Wait),     .fromDiv(pds_ds_rs2FromDiv),
      .fromMiss(pds_ds_rs2FromMiss), .slot(pds_ds_rs2Slot),
      .wakeNow(iq_wakeNow),          .divWakeNow(iq_divWakeNow),
      .missWakeNow(iq_missWakeNow),  .remaining(iq_remaining2[h])
    );
  end

  // ---- per-source, landing next cycle ------------------------------------------
  assign iq_next1 = pds_ds_rs1Wait & (
    |(pds_ds_rs1Slot      & iq_wakeNext)
    | (pds_ds_rs1FromDiv  & sd_divWake)
    | (pds_ds_rs1FromMiss & sd_missWake)
  );
  assign iq_next2 = pds_ds_rs2Wait & (
    |(pds_ds_rs2Slot      & iq_wakeNext)
    | (pds_ds_rs2FromDiv  & sd_divWake)
    | (pds_ds_rs2FromMiss & sd_missWake)
  );

  // ---- late wakes landing next cycle from the row's late bits ------------------
  logic [N-1:0] iq_rowLateNext,   iq_rowLateNext2;
  logic [N-1:0] iq_rowLate,       iq_rowLate2,     iq_dispatched;
  logic         iq_dispatchLate1, iq_dispatchLate2;
  logic [N-1:0] iq_dispatchLate;
  assign iq_dispatchLate = pds_ds_depL3 | pds_ds_depL4 | pds_ds_depL5;

  for (genvar j = 0; j < N; j++) begin : g_late
    logic [N-1:0] iq_depLate;
    logic [1:0]   iq_rowHits;
    assign iq_rowHits = upToTwo(
      {iq_depDiv[j] & sd_divWake, iq_depMiss[j] & sd_missWake, iq_depLate & iq_wakeNext}
    );

    always_ff @(posedge clk) begin
      for (int k = 0; k < N; k++) begin
        iq_depLate[k] <= iq_dispatchSelect[j]
          ? iq_dispatchLate[k] & (k != j)
          : iq_depLate[k] & ~iq_dispatchSelect[k];
      end
    end

    assign iq_rowLateNext[j]  = iq_rowHits[0];
    assign iq_rowLateNext2[j] = iq_rowHits[1];
  end

  // ---- registered apart - the row written last cycle takes dispatch term -------
  always_ff @(posedge clk) begin
    if (!resetn) begin
      iq_rowLate        <= '0;
      iq_rowLate2       <= '0;
      iq_dispatched     <= '0;
      iq_dispatchLate1  <= 1'b0;
      iq_dispatchLate2  <= 1'b0;
    end else begin
      iq_rowLate        <= iq_rowLateNext;
      iq_rowLate2       <= iq_rowLateNext2;
      iq_dispatched     <= iq_dispatchSelect;
      iq_dispatchLate1  <= iq_next1 | iq_next2;
      iq_dispatchLate2  <= iq_next1 & iq_next2;
    end
  end

  assign iq_lateWake = (
    (iq_dispatched & {N{iq_dispatchLate1}}) | (~iq_dispatched & iq_rowLate)
  );
  assign iq_lateWake2 = (
    ((iq_dispatched & {N{iq_dispatchLate2}}) | (~iq_dispatched & iq_rowLate2)) & iq_waiting
  );

  // ---- next state: 1 dispatch/2 late wakes use the override half ---------------
  logic [1:0] iq_countNext [N];
  for (genvar j = 0; j < N; j++) begin : g_cell
    iq_rowcell u_cell (
      .count(iq_count[j]), .chainHit(iq_chainHit[j]), .lateWake(iq_lateWake[j]),
      .override(iq_dispatchSelect[j] | iq_lateWake2[j]),
      .remaining1(iq_remaining1[2 * j / N]),
      .remaining2(iq_remaining2[2 * j / N]),
      .dispatch(iq_dispatchSelect[j]), .newHit(iq_newHit),
      .countNext(iq_countNext[j]),     .readyNext(iq_readyNext[j])
    );
  end

  // ---- windows: reuse after last wake, visible for 1-2 more cycles -------------
  logic [N-1:0] iq_reuseHold1, iq_reuseHold2, iq_visibleHold2;
  always_ff @(posedge clk) begin
    if (!resetn) begin
      iq_reuseHold1   <= '0;
      iq_reuseHold2   <= '0;
      iq_visibleHold2 <= '0;
    end else begin
      iq_reuseHold1   <= iq_grantHold;
      iq_reuseHold2   <= iq_reuseHold1 & iq_isL5;
      iq_visibleHold2 <= iq_reuseHold1 & iq_isL5 & ~iq_kill;
    end
  end
  assign iq_visible = iq_occupied | iq_reuseHold1 | iq_visibleHold2;

  // ---- state registers ---------------------------------------------------------
  assign iq_dispatchReady = iq_dispatchReadyQ;

  always_ff @(posedge clk) begin
    if (!resetn) begin
      for (int k = 0; k < N; k++) iq_count[k] <= 2'd3;
      iq_ready          <= '0;
      iq_tailOneHot     <= N'(1);
      iq_tailMask       <= '1;
      iq_dispatchReadyQ <= 1'b1;
      iq_tailFree       <= N'(1);
    end else begin
      for (int k = 0; k < N; k++) begin
        iq_count[k] <= iq_kill[k] ? 2'd3 : iq_countNext[k];
        iq_ready[k] <= iq_kill[k] ? 1'b0 : iq_readyNext[k];
      end
      iq_tailOneHot     <= iq_tailOneHotNext;
      iq_tailMask       <= iq_tailMaskNext;
      iq_dispatchReadyQ <= ~|(iq_tailOneHotNext &  (iq_occupied | iq_reuseHold1 | iq_reuseHold2));
      iq_tailFree       <= iq_tailOneHotNext    & ~(iq_occupied | iq_reuseHold1 | iq_reuseHold2);
    end
  end

  // ---- row contents ------------------------------------------------------------
  logic [N-1:0] iq_latencyL1, iq_latencyL3, iq_latencyL4, iq_latencyL5;
  assign iq_latencyL1 = {N{pds_ds_latency[LATENCY_1] & pds_ds_rdWriteEnable}};
  assign iq_latencyL3 = {N{pds_ds_latency[LATENCY_3] & pds_ds_rdWriteEnable}};
  assign iq_latencyL4 = {N{pds_ds_latency[LATENCY_4] & pds_ds_rdWriteEnable}};
  assign iq_latencyL5 = {N{pds_ds_latency[LATENCY_5] & pds_ds_rdWriteEnable}};

  always_ff @(posedge clk) begin
    for (int i = 0; i < N; i++) begin
      for (int k = 0; k < N; k++) begin
        iq_depL1[i][k] <= iq_dispatchSelect[i]
          ? pds_ds_depL1[k] & (k != i)
          : iq_depL1[i][k] & ~iq_dispatchSelect[k];
      end
      iq_branchMask[i] <= (
        (iq_dispatchSelect[i] ? pds_ds_branchMask : iq_branchMask[i]) & ~iq_resolveClear
      );

      if (iq_dispatchSelect[i]) begin
        iq_isL1[i] <= iq_latencyL1[i];
        iq_isL3[i] <= iq_latencyL3[i];
        iq_isL4[i] <= iq_latencyL4[i];
        iq_isL5[i] <= iq_latencyL5[i];
      end
    end
  end

  always_ff @(posedge clk) begin
    for (int i = 0; i < N; i++) begin
      iq_depDiv[i]  <= iq_dispatchSelect[i]
        ? ((pds_ds_rs1Wait & pds_ds_rs1FromDiv)  | (pds_ds_rs2Wait & pds_ds_rs2FromDiv))
          & !iq_divWakeNow & !sd_divWake
        : iq_depDiv[i] & !sd_divWake;
      iq_depMiss[i] <= iq_dispatchSelect[i]
        ? ((pds_ds_rs1Wait & pds_ds_rs1FromMiss) | (pds_ds_rs2Wait & pds_ds_rs2FromMiss))
          & !iq_missWakeNow & !sd_missWake
        : iq_depMiss[i] & !sd_missWake;
    end
  end

endmodule

