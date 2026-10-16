// ================================================================================
//  Pre-Dispatcher: source tags to IQ slot vectors
// ================================================================================
//  RD2             PreDS                        DS
//  rename R2  ───► predisp (tag -> slot) ───┬─► dispatch (IQ/ROB write)
//  decoder R2 ───► predisp_payload (hold) ──┘
// ================================================================================
//  Turns each source tag into a one-hot slot split by producer's latency
//  group, plug a per-source wait flag. DS copies both into the IQ row.
//
//  Mechanisms:
//   - Slot mirror: destination tag & latency group per IQ slot, written when
//   DS dispatches into the tail slot.
//   - Match: used source against every visible slot & the uop in DS that is
//   preparing to be written this cycle into IQ.
//   - Hold: while DS stalls, the vectors hold. A wait flag drops when its
//   producer's wake fires.
//   - Kill: mispredict/flush clears the register.
// ================================================================================
`include "uop_defs.svh"

module predisp (
  input  logic                 clk,
  input  logic                 resetn,
  // ---- Rename-2/Dispatch-1 inter-stage pipeline register -----------------------
  input  logic                 r2_pds_valid,
  input  logic [5:0]           r2_pds_rs1Tag,
  input  logic [5:0]           r2_pds_rs2Tag,
  input  logic [5:0]           r2_pds_rdTag,
  input  logic [5:0]           r2_pds_rdOldTag,
  input  logic                 r2_pds_rs1Use,
  input  logic                 r2_pds_rs2Use,
  input  logic [4:0]           r2_pds_rdIndex,
  input  logic                 r2_pds_rdWriteEnable,
  input  logic [3:0]           r2_pds_branchMask,
  input  logic [1:0]           r2_pds_snapshot,
  input  logic [LATENCY_W-1:0] r2_pds_latency,
  // ---- inter-stage pipeline register controls ----------------------------------
  input  logic                 stall_pds_ds,        // DS cannot take the register
  output logic                 stall_r2_pds,        // to rename and the decoder
  // ---- branch resolve (EX), commit flush ---------------------------------------
  input  logic                 ex_resolveValid,
  input  logic [1:0]           ex_resolveSnapshot,
  input  logic                 ex_resolveMispredict,
  input  logic                 cm_flush,
  // ---- IQ ----------------------------------------------------------------------
  input  logic [7:0]           iq_tailSlot,         // one-hot
  input  logic [7:0]           iq_visible,          // occupied/post-grant hold
  input  logic [7:0]           iq_grantPrevious,    // last cycle's grant
  input  logic [7:0]           iq_wakeL3,           // registered wakes firing this cycle
  input  logic [7:0]           iq_wakeL4,
  input  logic [7:0]           iq_wakeL5,
  // ---- Dispatch-1/Dispatch inter-stage pipeline register -----------------------
  output logic                 pds_ds_valid,
  output logic [5:0]           pds_ds_rs1Tag,
  output logic [5:0]           pds_ds_rs2Tag,
  output logic [5:0]           pds_ds_rdTag,
  output logic [5:0]           pds_ds_rdOldTag,
  output logic                 pds_ds_rs1Use,
  output logic                 pds_ds_rs2Use,
  output logic [4:0]           pds_ds_rdIndex,
  output logic                 pds_ds_rdWriteEnable,
  output logic [3:0]           pds_ds_branchMask,
  output logic [1:0]           pds_ds_snapshot,
  output logic [LATENCY_W-1:0] pds_ds_latency,
  output logic [7:0]           pds_ds_depL1,        // producer slots, by latency group
  output logic [7:0]           pds_ds_depL3,
  output logic [7:0]           pds_ds_depL4,
  output logic [7:0]           pds_ds_depL5,
  output logic                 pds_ds_rs1Wait,      // producers outstanding
  output logic                 pds_ds_rs2Wait,
  output logic [7:0]           pds_ds_rs1Slot,      // one-hot producer slot per-source
  output logic [7:0]           pds_ds_rs2Slot
);

  // ---- kill & resolve ----------------------------------------------------------
  logic ex_kill; assign ex_kill = (ex_resolveValid & ex_resolveMispredict) | cm_flush;
  logic [3:0] ex_resolveClear; assign ex_resolveClear =
    ex_resolveValid ? 4'(1) << ex_resolveSnapshot : 4'b0;

  // ---- stall & dispatch fire ---------------------------------------------------
  assign stall_r2_pds = stall_pds_ds & r2_pds_valid;
  logic pds_fire; assign pds_fire = pds_ds_valid & !stall_pds_ds;

  // ---- slot mirror {L5, L4, L3, L1} one-hot, 0 -> no result --------------------
  logic [5:0] pds_slotTag [8];
  logic [3:0] pds_slotLatency [8];
  logic [7:0] pds_slotProducer;
  logic [3:0] pds_dsLatency, pds_r2Latency;
  logic       pds_dsProducer;

  assign pds_r2Latency =
    {r2_pds_latency[LATENCY_5], r2_pds_latency[LATENCY_4],
     r2_pds_latency[LATENCY_3], r2_pds_latency[LATENCY_1]}
  & {4{r2_pds_rdWriteEnable}};

  always_ff @(posedge clk) begin
    if (!resetn || ex_kill) pds_dsProducer <= 1'b0;
    else if (!stall_pds_ds) pds_dsProducer <= r2_pds_valid & (pds_r2Latency != 4'b0);
    if (!stall_pds_ds)      pds_dsLatency  <= pds_r2Latency;
  end

  always_ff @(posedge clk) begin
    for (int k = 0; k < 8; k++)
      if (pds_fire && iq_tailSlot[k]) begin
        pds_slotTag[k]      <= pds_ds_rdTag;
        pds_slotLatency[k]  <= pds_dsLatency;
        pds_slotProducer[k] <= pds_dsLatency != 4'd0;
      end
  end

  // ---- producers: visible slots with a result ----------------------------------
  logic [7:0] pds_producer; assign pds_producer = iq_visible & pds_slotProducer;

  // ---- match: mirror slots, plus uop in DS at tail slot ------------------------
  logic [7:0] pds_match1,  pds_match2;
  logic       pds_bypass1, pds_bypass2;
  logic       pds_same;

  assign pds_bypass1 = r2_pds_rs1Use & pds_dsProducer & (pds_ds_rdTag  == r2_pds_rs1Tag);
  assign pds_bypass2 = r2_pds_rs2Use & pds_dsProducer & (pds_ds_rdTag  == r2_pds_rs2Tag);
  assign pds_same    = r2_pds_rs1Use & r2_pds_rs2Use  & (r2_pds_rs1Tag == r2_pds_rs2Tag);

  for (genvar k = 0; k < 8; k++) begin : g_match
    assign pds_match1[k] = r2_pds_rs1Use & pds_producer[k] & (pds_slotTag[k] == r2_pds_rs1Tag);
    assign pds_match2[k] = r2_pds_rs2Use & pds_producer[k] & (pds_slotTag[k] == r2_pds_rs2Tag);
  end

  // ---- fresh vectors -----------------------------------------------------------
  logic [7:0] pds_freshL1, pds_freshL3, pds_freshL4, pds_freshL5;
  logic       pds_bypass; assign pds_bypass = pds_bypass1 | pds_bypass2;

  for (genvar k = 0; k < 8; k++) begin : g_fresh
    logic pds_slotHit; assign pds_slotHit = pds_match1[k] | pds_match2[k];
    logic pds_tailHit; assign pds_tailHit = pds_bypass    & iq_tailSlot[k];
    assign pds_freshL1[k] = (pds_slotHit & pds_slotLatency[k][0]) | (pds_tailHit & pds_dsLatency[0]);
    assign pds_freshL3[k] = (pds_slotHit & pds_slotLatency[k][1]) | (pds_tailHit & pds_dsLatency[1]);
    assign pds_freshL4[k] = (pds_slotHit & pds_slotLatency[k][2]) | (pds_tailHit & pds_dsLatency[2]);
    assign pds_freshL5[k] = (pds_slotHit & pds_slotLatency[k][3]) | (pds_tailHit & pds_dsLatency[3]);
  end

  // ---- wait flags --------------------------------------------------------------
  logic [7:0] pds_slot1;  assign pds_slot1  = pds_match1 | (pds_bypass1 ? iq_tailSlot : 8'b0);
  logic [7:0] pds_slot2;  assign pds_slot2  = pds_match2 | (pds_bypass2 ? iq_tailSlot : 8'b0);
  logic       pds_fresh1; assign pds_fresh1 = (|pds_match1) | pds_bypass1;
  logic       pds_fresh2; assign pds_fresh2 = ((|pds_match2) | pds_bypass2) & !pds_same;

  // ---- held flags --------------------------------------------------------------
  logic [7:0] pds_rs1Slot, pds_rs2Slot, pds_woken;
  logic       pds_woken1,  pds_woken2;

  assign pds_woken  = (pds_ds_depL1 & iq_grantPrevious) | (pds_ds_depL3 & iq_wakeL3)
                    | (pds_ds_depL4 & iq_wakeL4)        | (pds_ds_depL5 & iq_wakeL5);
  assign pds_woken1 = |(pds_rs1Slot & pds_woken);
  assign pds_woken2 = |(pds_rs2Slot & pds_woken);
  assign pds_ds_rs1Slot = pds_rs1Slot;
  assign pds_ds_rs2Slot = pds_rs2Slot;

  // ---- Dispatch-1/Dispatch inter-stage pipeline regsiter -----------------------
  always_ff @(posedge clk) begin
    if (!resetn || ex_kill) pds_ds_valid <= 1'b0;
    else if (!stall_pds_ds) pds_ds_valid <= r2_pds_valid;
  end

  always_ff @(posedge clk) begin
    if (!stall_pds_ds) begin
      pds_ds_rs1Tag        <= r2_pds_rs1Tag;
      pds_ds_rs2Tag        <= r2_pds_rs2Tag;
      pds_ds_rdTag         <= r2_pds_rdTag;
      pds_ds_rdOldTag      <= r2_pds_rdOldTag;
      pds_ds_rs1Use        <= r2_pds_rs1Use;
      pds_ds_rs2Use        <= r2_pds_rs2Use;
      pds_ds_rdIndex       <= r2_pds_rdIndex;
      pds_ds_rdWriteEnable <= r2_pds_rdWriteEnable;
      pds_ds_snapshot      <= r2_pds_snapshot;
      pds_ds_latency       <= r2_pds_latency;
      pds_ds_depL1         <= pds_freshL1;
      pds_ds_depL3         <= pds_freshL3;
      pds_ds_depL4         <= pds_freshL4;
      pds_ds_depL5         <= pds_freshL5;
      pds_rs1Slot          <= pds_slot1;
      pds_rs2Slot          <= pds_slot2;
    end
    pds_ds_branchMask <= (stall_pds_ds ? pds_ds_branchMask : r2_pds_branchMask) & ~ex_resolveClear;
  end

  // ---- wait flags --------------------------------------------------------------
  always_ff @(posedge clk) begin
    if (!stall_pds_ds || pds_woken1) pds_ds_rs1Wait <= pds_fresh1 & !stall_pds_ds;
    if (!stall_pds_ds || pds_woken2) pds_ds_rs2Wait <= pds_fresh2 & !stall_pds_ds;
  end

endmodule

