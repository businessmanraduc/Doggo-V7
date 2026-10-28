// ================================================================================
//  Rename: register rename over R1 and R2, beside the decoder
// ================================================================================
//  D               RD1           RD2             PreDS
//  predecoder ─┬─► rename R1 ──► rename R2 ──┬─► predisp
//              └─► decoder D1 ─► decoder D2 ─┘
// ================================================================================
//  32 architectural -> 64 physical registers (6-bit tags), 1 uop/cycle.
//
//  Purpose:
//   - R1: map read 1 (4 registerd groups of 8 per port), free-list pop, map
//   write, snapshot allocation.
//   - R2: map read 2 (group select).
//
//  Mechanisms:
//   - Snapshots: 4, taken by branches and jalr, written 1 cycle late from the
//   registered map and head.
//   - Free list: 32-entry FIFO in LUTRAM, pop at the head in R1, push the old
//   tag at the tail as instructions commit.
//   - R2 skid: catches R1/R2 while PreDS stalls; R2/PreDS loads from it first.
//   - Retirement map: written at commit, copied into the map on a flush.
//   - Valid/Flush: a flush wins over a mispredict.
//   - Recovery: from flops only, a cycle after the kill, R1 blocked for
//   2 cycles after said kill.
// ================================================================================
module rename (
  input  logic        clk,
  input  logic        resetn,
  // ---- Decode/Rename-1 inter-stage pipeline register ---------------------------
  input  logic        d_r1_valid,
  input  logic [4:0]  d_r1_rs1Index,
  input  logic [4:0]  d_r1_rs2Index,
  input  logic [4:0]  d_r1_rdIndex,
  input  logic        d_r1_rs1Use,
  input  logic        d_r1_rs2Use,
  input  logic        d_r1_rdWriteEnable,
  input  logic        d_r1_isBranch,
  input  logic        d_r1_isJalr,
  // ---- inter-stage pipeline register controls ----------------------------------
  input  logic        stall_r2_pds,         // PreDS cannot take the register
  output logic        stall_r1_r2,          // to the decoder
  output logic        rd2_skidValid,        // to the decoder
  output logic        stall_d_r1,           // to the predecoder
  // ---- branch resolve (EX) -----------------------------------------------------
  input  logic        ex_resolveValid,
  input  logic [1:0]  ex_resolveSnapshot,
  input  logic        ex_resolveMispredict,
  // ---- commit (ROB head) -------------------------------------------------------
  input  logic        cm_commitRd,
  input  logic [4:0]  cm_rdIndex,
  input  logic [5:0]  cm_rdTag,
  input  logic [5:0]  cm_rdOldTag,
  input  logic        cm_flush,             // flush all + map from retirement map
  // ---- Rename-2/Dispatch-1 inter-stage pipeline register -----------------------
  output logic        r2_pds_valid,
  output logic [5:0]  r2_pds_rs1Tag,
  output logic [5:0]  r2_pds_rs2Tag,
  output logic [5:0]  r2_pds_rdTag,
  output logic [5:0]  r2_pds_rdOldTag,
  output logic        r2_pds_rs1Use,
  output logic        r2_pds_rs2Use,
  output logic [4:0]  r2_pds_rdIndex,
  output logic        r2_pds_rdWriteEnable,
  output logic [3:0]  r2_pds_branchMask,    // older unresolved branches
  output logic [1:0]  r2_pds_snapshot       // own snapshot (branch, jalr)
);

  // ---- state -------------------------------------------------------------------
  logic [5:0] rn_map [32];                  // speculative map
  logic [5:0] rn_retireMap [32];            // committed map
  logic [5:0] fl_ram [32];                  // free tags circular FIFO
  logic [5:0] fl_ramNext [32];              // copy shifted by one
  logic [5:0] fl_head, fl_tail, fl_commitHead, fl_headTag;
  logic       fl_init;                      // fill walk after reset
  logic       rn_hold;                      // registered: init, recovery
  logic [3:0] sn_live;                      // snapshot busy <=> branch unresolved
  logic       sn_full;                      // &sn_live, registered
  logic [5:0] sn_map [4][32];
  logic [5:0] sn_head [4];
  logic [3:0] sn_mask [4];                  // older unresolved branches, cleared on resolve
  logic       sn_take;                      // write a snapshot this cycle
  logic [1:0] sn_takeIndex;
  logic       rc_flush, rc_mispredict;      // registered kill -> restore now
  logic [1:0] rc_index;

  // ---- recovery ----------------------------------------------------------------
  logic       ex_mispredict;   assign ex_mispredict   = ex_resolveValid & ex_resolveMispredict;
  logic       rn_kill;         assign rn_kill         = ex_mispredict | cm_flush;
  logic [3:0] ex_resolveClear; assign ex_resolveClear =
    ex_resolveValid ? 4'(1) << ex_resolveSnapshot : 4'b0;

  // ---- R1: stall, go, pop, snapshot allocation ---------------------------------
  logic r1_needSnapshot, r1_block, r1_go, r1_write, r1_take;
  logic [1:0] r1_freeSnapshot;
  logic [5:0] r1_rdTag;
  logic [3:0] r1_mask;
  logic r1_r2_valid;

  assign r1_needSnapshot = d_r1_isBranch | d_r1_isJalr;
  assign r1_block        = rn_hold | (r1_needSnapshot & sn_full);
  assign stall_r1_r2     = rd2_skidValid & r1_r2_valid;
  assign stall_d_r1      = stall_r1_r2 | (d_r1_valid & r1_block);
  assign r1_go           = d_r1_valid & !stall_d_r1;
  assign r1_write        = r1_go & d_r1_rdWriteEnable;
  assign r1_take         = r1_go & r1_needSnapshot;
  assign r1_rdTag        = fl_headTag;
  assign r1_mask         = sn_live & ~ex_resolveClear;

  logic        r1_mapBlock;
  logic [31:0] r1_mapWrite;
  assign r1_mapBlock = r1_block | stall_r1_r2;
  always_comb
    for (int r = 0; r < 32; r++)
      r1_mapWrite[r] = d_r1_valid & d_r1_rdWriteEnable & (d_r1_rdIndex == 5'(r)) & !r1_mapBlock;

  always_comb begin
    r1_freeSnapshot = 2'd0;
    for (int i = 3; i >= 0; i--) if (!sn_live[i]) r1_freeSnapshot = 2'(i);
  end

  // ---- registered kill ---------------------------------------------------------
  always_ff @(posedge clk) begin
    if (!resetn) begin
      rc_flush      <= 1'b0;
      rc_mispredict <= 1'b0;
    end else begin
      rc_flush      <= cm_flush;
      rc_mispredict <= ex_mispredict & !cm_flush;
    end
    rc_index <= ex_resolveSnapshot;
  end

  // ---- map, retirement map, snapshots ------------------------------------------
  always_ff @(posedge clk) begin
    if (!resetn) begin
      for (int r = 0; r < 32; r++) begin
        rn_map[r]       <= 6'(r);
        rn_retireMap[r] <= 6'(r);
      end
    end else begin
      for (int r = 0; r < 32; r++) begin
        if (r1_mapWrite[r] || rc_flush || rc_mispredict) begin
          rn_map[r] <= rc_flush ? rn_retireMap[r] : rc_mispredict ? sn_map[rc_index][r] : r1_rdTag;
        end
      end
      if (cm_commitRd) rn_retireMap[cm_rdIndex] <= cm_rdTag;
    end
  end

  logic [3:0] sn_liveNext;
  always_comb begin
    if (rc_flush)           sn_liveNext = 4'b0;
    else if (rc_mispredict) sn_liveNext = r1_mask & sn_mask[rc_index];
    else                    sn_liveNext = r1_mask | (r1_take ? 4'(1) << r1_freeSnapshot : 4'b0);
  end

  always_ff @(posedge clk) begin
    if (!resetn) begin
      sn_live <= 4'b0;
      sn_full <= 1'b0;
      sn_take <= 1'b0;
    end else begin
      sn_live <= sn_liveNext;
      sn_full <= &sn_liveNext;
      sn_take <= r1_take;
    end
    sn_takeIndex <= r1_freeSnapshot;
    for (int k = 0; k < 4; k++)
      sn_mask[k]                <= sn_mask[k] & ~ex_resolveClear;
    if (r1_take)
      sn_mask[r1_freeSnapshot]  <= r1_mask;
    if (sn_take) begin
      for (int r = 0; r < 32; r++)
        sn_map[sn_takeIndex][r] <= rn_map[r];
      sn_head[sn_takeIndex]     <= fl_head;
    end
  end

  // ---- free list ---------------------------------------------------------------
  logic       fl_write;      assign fl_write      = fl_init | cm_commitRd;
  logic [4:0] fl_writeIndex; assign fl_writeIndex = fl_tail[4:0];
  logic [5:0] fl_writeTag;   assign fl_writeTag   = fl_init ? {1'b1, fl_tail[4:0]} : cm_rdOldTag;

  always_ff @(posedge clk) if (fl_write) fl_ram[fl_writeIndex]            <= fl_writeTag;
  always_ff @(posedge clk) if (fl_write) fl_ramNext[fl_writeIndex - 5'd1] <= fl_writeTag;

  // ---- head tag, read a cycle ahead --------------------------------------------
  logic [5:0] fl_headPlus;
  assign fl_headPlus = fl_head + 6'd1;
  always_ff @(posedge clk)
    fl_headTag <= r1_write ? fl_ramNext[fl_head[4:0]] : fl_ram[fl_head[4:0]];

  always_ff @(posedge clk) begin
    if (!resetn) begin
      fl_head       <= 6'd0;
      fl_tail       <= 6'd0;
      fl_commitHead <= 6'd0;
      fl_init       <= 1'b1;
      rn_hold       <= 1'b1;
    end else begin
      if      (rc_flush)      fl_head <= fl_commitHead;
      else if (rc_mispredict) fl_head <= sn_head[rc_index];
      else if (r1_write)      fl_head <= fl_headPlus;

      if (fl_write)           fl_tail <= fl_tail + 6'd1;
      if (fl_tail == 6'd31)   fl_init <= 1'b0;

      fl_commitHead <= fl_commitHead + 6'(cm_commitRd);
      rn_hold       <= fl_init | rn_kill | rc_flush | rc_mispredict;
    end
  end

  // ---- Rename-1/Rename-2 register: map read 1 ----------------------------------
  logic [5:0] r1_r2_rs1Part [4], r1_r2_rs2Part [4], r1_r2_rdPart [4];
  logic [1:0] r1_r2_rs1Group,    r1_r2_rs2Group,    r1_r2_rdGroup;
  logic [5:0] r1_r2_rdTag;
  logic       r1_r2_rs1Use,      r1_r2_rs2Use,      r1_r2_rdWriteEnable;
  logic [4:0] r1_r2_rdIndex;
  logic [3:0] r1_r2_branchMask;
  logic [1:0] r1_r2_snapshot;

  always_ff @(posedge clk) begin
    if (!resetn || rn_kill) r1_r2_valid <= 1'b0;
    else if (!stall_r1_r2)  r1_r2_valid <= r1_go;

    if (!stall_r1_r2) begin
      for (int g = 0; g < 4; g++) begin
        r1_r2_rs1Part[g]  <= rn_map[{2'(g), d_r1_rs1Index[2:0]}];
        r1_r2_rs2Part[g]  <= rn_map[{2'(g), d_r1_rs2Index[2:0]}];
        r1_r2_rdPart[g]   <= rn_map[{2'(g), d_r1_rdIndex[2:0]}];
      end
      r1_r2_rs1Group      <= d_r1_rs1Index[4:3];
      r1_r2_rs2Group      <= d_r1_rs2Index[4:3];
      r1_r2_rdGroup       <= d_r1_rdIndex[4:3];
      r1_r2_rdTag         <= r1_rdTag;
      r1_r2_rs1Use        <= d_r1_rs1Use;
      r1_r2_rs2Use        <= d_r1_rs2Use;
      r1_r2_rdIndex       <= d_r1_rdIndex;
      r1_r2_rdWriteEnable <= d_r1_rdWriteEnable;
      r1_r2_snapshot      <= r1_freeSnapshot;
    end

    r1_r2_branchMask <= (stall_r1_r2 ? r1_r2_branchMask : r1_mask) & ~ex_resolveClear;
  end

  // ---- R2: map read 2 ----------------------------------------------------------
  logic [5:0] r2_rs1Tag;   assign r2_rs1Tag   = r1_r2_rs1Part[r1_r2_rs1Group];
  logic [5:0] r2_rs2Tag;   assign r2_rs2Tag   = r1_r2_rs2Part[r1_r2_rs2Group];
  logic [5:0] r2_rdOldTag; assign r2_rdOldTag = r1_r2_rdPart[r1_r2_rdGroup];

  // ---- R2 skid: catches R1/R2 while PreDS stalls -------------------------------
  logic       r2_skidLoad; assign r2_skidLoad = stall_r2_pds & !rd2_skidValid;
  logic [5:0] r2_skidRs1Tag, r2_skidRs2Tag, r2_skidRdTag, r2_skidRdOldTag;
  logic       r2_skidRs1Use, r2_skidRs2Use, r2_skidRdWriteEnable;
  logic [4:0] r2_skidRdIndex;
  logic [3:0] r2_skidBranchMask;
  logic [1:0] r2_skidSnapshot;

  always_ff @(posedge clk) begin
    if (!resetn || rn_kill) rd2_skidValid <= 1'b0;
    else if (r2_skidLoad)   rd2_skidValid <= r1_r2_valid;
    else if (!stall_r2_pds) rd2_skidValid <= 1'b0;

    if (!rd2_skidValid) begin
      r2_skidRs1Tag        <= r2_rs1Tag;
      r2_skidRs2Tag        <= r2_rs2Tag;
      r2_skidRdOldTag      <= r2_rdOldTag;
      r2_skidRdTag         <= r1_r2_rdTag;
      r2_skidRs1Use        <= r1_r2_rs1Use;
      r2_skidRs2Use        <= r1_r2_rs2Use;
      r2_skidRdIndex       <= r1_r2_rdIndex;
      r2_skidRdWriteEnable <= r1_r2_rdWriteEnable;
      r2_skidSnapshot      <= r1_r2_snapshot;
    end

    r2_skidBranchMask <= (!rd2_skidValid ? r1_r2_branchMask : r2_skidBranchMask) & ~ex_resolveClear;
  end

  // ---- Rename-2/Dispatch-1 register --------------------------------------------
  always_ff @(posedge clk) begin
    if (!resetn || rn_kill) r2_pds_valid <= 1'b0;
    else if (!stall_r2_pds) r2_pds_valid <= rd2_skidValid | r1_r2_valid;

    if (!stall_r2_pds) begin
      r2_pds_rs1Tag        <= rd2_skidValid ? r2_skidRs1Tag        : r2_rs1Tag;
      r2_pds_rs2Tag        <= rd2_skidValid ? r2_skidRs2Tag        : r2_rs2Tag;
      r2_pds_rdOldTag      <= rd2_skidValid ? r2_skidRdOldTag      : r2_rdOldTag;
      r2_pds_rdTag         <= rd2_skidValid ? r2_skidRdTag         : r1_r2_rdTag;
      r2_pds_rs1Use        <= rd2_skidValid ? r2_skidRs1Use        : r1_r2_rs1Use;
      r2_pds_rs2Use        <= rd2_skidValid ? r2_skidRs2Use        : r1_r2_rs2Use;
      r2_pds_rdIndex       <= rd2_skidValid ? r2_skidRdIndex       : r1_r2_rdIndex;
      r2_pds_rdWriteEnable <= rd2_skidValid ? r2_skidRdWriteEnable : r1_r2_rdWriteEnable;
      r2_pds_snapshot      <= rd2_skidValid ? r2_skidSnapshot      : r1_r2_snapshot;
    end

    r2_pds_branchMask <= (
      stall_r2_pds  ? r2_pds_branchMask :
      rd2_skidValid ? r2_skidBranchMask :
      r1_r2_branchMask
    ) & ~ex_resolveClear;
  end

endmodule

