// ================================================================================
//  predisp_tb -- predisp inside a behavioural rename, IQ and ROB
// ================================================================================
//  The bench plays rename (8 architectural registers, 64 tags, free FIFO,
//  committed map), the IQ (8 slots, circular tail, one grant per cycle, wakes
//  by slot per latency group, post-grant hold and reuse windows of 0052) and an
//  in-order ROB (commit once granted and complete, mispredict kills the younger
//  ones, flush kills all). Every uop records its producers by tag at rename.
//  Checks:
//   - chk_ready: every IQ row is ready exactly when all its producers are
//   granted and their latency has passed (tag scoreboard, no PreDS model).
//   - chk_vector, chk_count: at dispatch, the vectors and rs1Wait + rs2Wait
//   equal the 0052/0053 contract from producer grant cycles and the PreDS
//   cycle. staleVectors (0053): held vectors keep bits whose wake fired, the
//   flags do not.
//   The IQ model clears a slot's column on reuse and never sets a row's own.
//   - chk_slot: a waiting source names its producer's slot (0055).
//   - chk_valid, chk_pass, chk_bmask, chk_stall: register and control.
//  Phases: realistic, stall-heavy (held upkeep), kill-heavy; reset each phase.
// ================================================================================

`include "uop_defs.svh"

/* verilator lint_off WIDTHEXPAND */
/* verilator lint_off WIDTHTRUNC */
module predisp_tb;

  logic                 clk = 1'b0;
  logic                 resetn = 1'b0;
  logic                 r2_pds_valid = 1'b0;
  logic [5:0]           r2_pds_rs1Tag = '0, r2_pds_rs2Tag = '0, r2_pds_rdTag = '0, r2_pds_rdOldTag = '0;
  logic                 r2_pds_rs1Use = 1'b0, r2_pds_rs2Use = 1'b0, r2_pds_rdWriteEnable = 1'b0;
  logic [4:0]           r2_pds_rdIndex = '0;
  logic [3:0]           r2_pds_branchMask = '0;
  logic [1:0]           r2_pds_snapshot = '0;
  logic [LATENCY_W-1:0] r2_pds_latency = '0;
  logic                 stall_pds_ds = 1'b0;
  logic                 stall_r2_pds;
  logic                 ex_resolveValid = 1'b0;
  logic [1:0]           ex_resolveSnapshot = '0;
  logic                 ex_resolveMispredict = 1'b0;
  logic                 cm_flush = 1'b0;
  logic [7:0]           iq_tailSlot = '0, iq_visible = '0, iq_grantPrevious = '0;
  logic [7:0]           iq_wakeL3 = '0, iq_wakeL4 = '0, iq_wakeL5 = '0;
  logic                 pds_ds_valid;
  logic [5:0]           pds_ds_rs1Tag, pds_ds_rs2Tag, pds_ds_rdTag, pds_ds_rdOldTag;
  logic                 pds_ds_rs1Use, pds_ds_rs2Use, pds_ds_rdWriteEnable;
  logic [4:0]           pds_ds_rdIndex;
  logic [3:0]           pds_ds_branchMask;
  logic [1:0]           pds_ds_snapshot;
  logic [LATENCY_W-1:0] pds_ds_latency;
  logic [7:0]           pds_ds_depL1, pds_ds_depL3, pds_ds_depL4, pds_ds_depL5;
  logic                 pds_ds_rs1Wait, pds_ds_rs2Wait;
  logic [7:0]           pds_ds_rs1Slot, pds_ds_rs2Slot;
  logic [1:0]           pds_ds_waitCount;
  assign pds_ds_waitCount = 2'(pds_ds_rs1Wait) + 2'(pds_ds_rs2Wait);

  predisp u_dut (.*);

  always #5 clk = ~clk;

  // ---- uops --------------------------------------------------------------------
  typedef struct {
    bit       killed, committed, rdWE, use1, use2;
    int       tag1, tag2, rdTag, oldTag, rd, lat;     // lat 0 = no result group
    int       prod1, prod2;                           // producer ids, -1 = ready
    int       slot;
    longint   c0, disp, grant;                        // PreDS cycle, dispatch, grant
    bit [3:0] mask;
    bit [1:0] snap;
    bit [LATENCY_W-1:0] latVec;
  } uop_t;

  uop_t   u [int];
  int     nextId;
  int     inflight [$];                               // uncommitted, program order

  // ---- rename model ------------------------------------------------------------
  int     amap [8], cmap [8];
  int     lastWriter [64];
  int     freeQ [$];

  // ---- IQ model ----------------------------------------------------------------
  bit       occ [8];
  int       rowId [8], cnt [8];
  bit [7:0] d1 [8], d3 [8], d4 [8], d5 [8];
  longint   lastGrant [8];
  int       lastLat [8];
  bit       holdLive [8];
  int       tail;

  // ---- pipeline shadows --------------------------------------------------------
  int       r2Id, dsId;                               // -1 = empty
  bit [3:0] dsMask;

  longint   t;
  int       errors;
  int       bp, killRate;                             // percent per cycle, per mille
  int       cov [string];
  bit       staleVectors = 1'b1;                      // 1: held vectors keep woken bits

  int       shown [string];

  task automatic fail(string chk, string msg);
    if (shown[chk] < 5) $display("ERROR %s @%0d: %s", chk, t, msg);
    shown[chk]++;
    errors++;
  endtask

  function automatic int latOf(int id);
    return u[id].rdWE ? u[id].lat : 0;
  endfunction

  function automatic bit [7:0] visibleAt(longint c);
    bit [7:0] v;
    for (int k = 0; k < 8; k++)
      v[k] = occ[k] || (holdLive[k] && ((lastLat[k] == 4 && c <= lastGrant[k] + 1)
                                     || (lastLat[k] == 5 && c <= lastGrant[k] + 2)));
    return v;
  endfunction

  function automatic bit slotFree(int k);
    longint from;
    from = lastGrant[k] + (lastLat[k] == 4 ? 3 : lastLat[k] == 5 ? 4 : 2);
    return !occ[k] && t >= from;
  endfunction

  function automatic bit [7:0] grantedAt(longint c, int lat);
    bit [7:0] v;
    for (int k = 0; k < 8; k++) v[k] = lastGrant[k] == c && (lat < 0 || lastLat[k] == lat);
    return v;
  endfunction

  // ---- producer readiness by tag scoreboard ------------------------------------
  function automatic bit srcReady(int p, longint c);
    if (p < 0) return 1'b1;
    if (u[p].grant < 0) return 1'b0;
    return c >= u[p].grant + u[p].lat;
  endfunction

  // ---- 0052 contract: is producer p's bit present at fire cycle c? -------------
  function automatic bit expectBit(int p, longint c0, longint c, ref int why);
    bit     vis;
    longint g, wakeAt;
    why = 0;
    if (p < 0) return 1'b0;
    g = u[p].grant;
    if (u[p].disp == c0) vis = 1'b1;                  // in DS at c0: bypass
    else if (u[p].disp < c0) begin
      if (g < 0 || g >= c0)                       vis = 1'b1;
      else if (u[p].lat == 4 && c0 <= g + 1)      begin vis = 1'b1; why = 2; end
      else if (u[p].lat == 5 && c0 <= g + 2)      begin vis = 1'b1; why = 2; end
      else                                        vis = 1'b0;
    end else vis = 1'b0;                              // cannot happen (older)
    if (!vis) return 1'b0;
    if (g < 0) return 1'b1;
    wakeAt = g + (u[p].lat == 1 ? 1 : u[p].lat - 1);
    if (wakeAt <= c - 1) begin why = 1; return staleVectors; end
    return 1'b1;
  endfunction

  // ---- reset of the whole model ------------------------------------------------
  task automatic modelReset();
    u.delete();
    inflight.delete();
    freeQ.delete();
    nextId = 0;
    for (int r = 0; r < 8; r++) begin amap[r] = r; cmap[r] = r; end
    for (int g = 0; g < 64; g++) lastWriter[g] = -1;
    for (int g = 8; g < 64; g++) freeQ.push_back(g);
    for (int k = 0; k < 8; k++) begin
      occ[k] = 0; cnt[k] = 0; d1[k] = 0; d3[k] = 0; d4[k] = 0; d5[k] = 0;
      lastGrant[k] = -100; lastLat[k] = 0; holdLive[k] = 0;
    end
    tail = 0;
    r2Id = -1;
    dsId = -1;
    dsMask = '0;
  endtask

  // ---- rename one uop into the R2 register -------------------------------------
  task automatic renameOne();
    uop_t x;
    int   r1, r2s, rp;
    if (freeQ.size() == 0 || inflight.size() >= 24 || $urandom_range(99) < 15) begin
      r2Id = -1;
      return;
    end
    r1 = $urandom_range(7);
    r2s = $urandom_range(99) < 15 ? r1 : $urandom_range(7);
    x.killed = 0; x.committed = 0;
    x.use1 = $urandom_range(99) < 85;
    x.use2 = $urandom_range(99) < 70;
    x.tag1 = amap[r1];
    x.tag2 = amap[r2s];
    rp = $urandom_range(99);
    x.lat = rp < 45 ? 1 : rp < 65 ? 3 : rp < 82 ? 4 : 5;
    x.rdWE = $urandom_range(99) < 85;
    x.latVec = '0;
    if (x.rdWE || $urandom_range(1)) begin
      case (x.lat)
        1: x.latVec[LATENCY_1] = 1'b1;
        3: x.latVec[LATENCY_3] = 1'b1;
        4: x.latVec[LATENCY_4] = 1'b1;
        5: x.latVec[LATENCY_5] = 1'b1;
      endcase
    end
    if (!x.rdWE && x.latVec == 0) x.lat = 1;          // complete one cycle after issue
    x.rd = $urandom_range(7);
    x.prod1 = x.use1 ? lastWriter[x.tag1] : -1;
    x.prod2 = x.use2 ? lastWriter[x.tag2] : -1;
    if (x.prod1 >= 0 && u[x.prod1].committed) x.prod1 = -1;
    if (x.prod2 >= 0 && u[x.prod2].committed) x.prod2 = -1;
    x.oldTag = amap[x.rd];
    x.rdTag = x.rdWE ? freeQ.pop_front() : $urandom_range(63);
    if (x.rdWE) begin amap[x.rd] = x.rdTag; lastWriter[x.rdTag] = nextId; end
    x.slot = -1; x.c0 = -1; x.disp = -1; x.grant = -1;
    x.mask = $urandom; x.snap = $urandom;
    u[nextId] = x;
    inflight.push_back(nextId);
    r2Id = nextId;
    nextId++;
  endtask

  // ---- kill everything younger than keep (keep = -1: flush all uncommitted) ----
  task automatic killYounger(int keep);
    int n [$];
    foreach (inflight[i]) begin
      int id = inflight[i];
      if (id > keep) begin
        u[id].killed = 1;
        if (u[id].rdWE) begin freeQ.push_back(u[id].rdTag); lastWriter[u[id].rdTag] = -1; end
        if (u[id].slot >= 0 && occ[u[id].slot] && rowId[u[id].slot] == id) occ[u[id].slot] = 0;
        if (u[id].grant >= 0 && lastGrant[u[id].slot] == u[id].grant) holdLive[u[id].slot] = 0;
      end else n.push_back(id);
    end
    inflight = n;
    for (int r = 0; r < 8; r++) amap[r] = cmap[r];
    foreach (inflight[i]) if (u[inflight[i]].rdWE) amap[u[inflight[i]].rd] = u[inflight[i]].rdTag;
    r2Id = -1;
    dsId = -1;
  endtask

  // ---- one cycle ---------------------------------------------------------------
  task automatic step();
    bit       fire, kill, flush, mis;
    int       keep, gslot;
    bit [7:0] vis, gPrev, w3, w4, w5, gNow, clr;
    bit [3:0] clear;
    int       rdy [$];

    @(posedge clk); #1;
    t++;

    // ---- registered outputs against the shadows --------------------------------
    if (pds_ds_valid !== (dsId >= 0)) fail("chk_valid", $sformatf("valid %0d exp %0d", pds_ds_valid, dsId >= 0));
    if (dsId >= 0) begin
      uop_t x = u[dsId];
      if (pds_ds_rs1Tag != x.tag1 || pds_ds_rs2Tag != x.tag2 || pds_ds_rdTag != x.rdTag
          || pds_ds_rdOldTag != x.oldTag || pds_ds_rs1Use != x.use1 || pds_ds_rs2Use != x.use2
          || pds_ds_rdIndex != x.rd || pds_ds_rdWriteEnable != x.rdWE
          || pds_ds_snapshot != x.snap || pds_ds_latency != x.latVec)
        fail("chk_pass", $sformatf("uop %0d fields", dsId));
      if (pds_ds_branchMask != dsMask) fail("chk_bmask", $sformatf("mask %b exp %b", pds_ds_branchMask, dsMask));
    end

    // ---- drive cycle t ---------------------------------------------------------
    vis   = visibleAt(t);
    gPrev = grantedAt(t - 1, -1);
    w3    = grantedAt(t - 2, 3);
    w4    = grantedAt(t - 3, 4);
    w5    = grantedAt(t - 4, 5);
    if (r2Id >= 0) begin
      uop_t x = u[r2Id];
      r2_pds_valid = 1'b1;
      r2_pds_rs1Tag = x.tag1; r2_pds_rs2Tag = x.tag2; r2_pds_rdTag = x.rdTag; r2_pds_rdOldTag = x.oldTag;
      r2_pds_rs1Use = x.use1; r2_pds_rs2Use = x.use2; r2_pds_rdWriteEnable = x.rdWE;
      r2_pds_rdIndex = x.rd; r2_pds_branchMask = x.mask; r2_pds_snapshot = x.snap;
      r2_pds_latency = x.latVec;
    end else begin
      r2_pds_valid = 1'b0;
      r2_pds_rs1Tag = $urandom; r2_pds_rs2Tag = $urandom; r2_pds_rs1Use = $urandom; r2_pds_rs2Use = $urandom;
    end
    iq_tailSlot      = 8'(1) << tail;
    iq_visible       = vis;
    iq_grantPrevious = gPrev;
    iq_wakeL3        = w3;
    iq_wakeL4        = w4;
    iq_wakeL5        = w5;
    stall_pds_ds     = (dsId >= 0) && (!slotFree(tail) || $urandom_range(99) < bp);
    fire             = (dsId >= 0) && !stall_pds_ds;

    kill = 0; flush = 0; mis = 0; keep = -1;
    ex_resolveValid = $urandom_range(99) < 10;
    ex_resolveSnapshot = $urandom;
    ex_resolveMispredict = 1'b0;
    cm_flush = 1'b0;
    if ($urandom_range(999) < killRate && inflight.size() > 0) begin
      if ($urandom_range(3) == 0) begin flush = 1; keep = inflight[0] - 1; cm_flush = 1'b1; end
      else begin
        int cand [$];
        foreach (inflight[i]) if (u[inflight[i]].disp >= 0 && u[inflight[i]].disp < t) cand.push_back(inflight[i]);
        if (cand.size() > 0) begin
          mis = 1; keep = cand[$urandom_range(cand.size() - 1)];
          ex_resolveValid = 1'b1; ex_resolveMispredict = 1'b1;
        end
      end
      kill = flush | mis;
    end
    clear = ex_resolveValid ? 4'(1) << ex_resolveSnapshot : 4'b0;
    #1;

    if (stall_r2_pds !== (stall_pds_ds && r2Id >= 0)) fail("chk_stall", $sformatf("stall_r2_pds %0d", stall_r2_pds));

    // ---- readiness of every row, from the tag scoreboard -----------------------
    for (int k = 0; k < 8; k++)
      if (occ[k]) begin
        int  id = rowId[k];
        bit  exp = srcReady(u[id].prod1, t) && srcReady(u[id].prod2, t);
        if ((cnt[k] == 0) != exp)
          fail("chk_ready", $sformatf("slot %0d uop %0d cnt %0d exp ready %0d", k, id, cnt[k], exp));
        if (cnt[k] == 0) rdy.push_back(k);
      end

    // ---- grant -----------------------------------------------------------------
    gslot = -1;
    if (rdy.size() > 0) begin
      if ($urandom_range(99) < 70) begin
        gslot = rdy[0];
        foreach (rdy[i]) if (rowId[rdy[i]] < rowId[gslot]) gslot = rdy[i];
      end else gslot = rdy[$urandom_range(rdy.size() - 1)];
    end
    gNow = gslot >= 0 ? 8'(1) << gslot : 8'b0;

    // ---- dispatch: contract check, then the row as the IQ writes it ------------
    if (fire) begin
      uop_t     x = u[dsId];
      bit [7:0] e1, e3, e4, e5;
      int       ecnt, why;
      int       ps [2];
      ps[0] = x.prod1; ps[1] = x.prod2;
      e1 = 0; e3 = 0; e4 = 0; e5 = 0; ecnt = 0;
      for (int s = 0; s < 2; s++) begin
        int p = ps[s];
        if (s == 1 && p >= 0 && p == ps[0]) begin cov["same"]++; continue; end
        if (expectBit(p, x.c0, t, why)) begin
          bit live = why != 1;
          int k = u[p].slot;
          int l = u[p].lat;
          if (u[p].disp == x.c0) cov["bypass"]++;
          if (why == 2) cov["holdVisible"]++;
          case (l)
            1: e1[k] = 1;
            3: e3[k] = 1;
            4: e4[k] = 1;
            5: e5[k] = 1;
          endcase
          if (live) ecnt++;
          else cov[$sformatf("upkeepL%0d", l)]++;
        end else if (why == 1) cov[$sformatf("upkeepL%0d", u[p].lat)]++;
      end
      if (ecnt == 2) cov["count2"]++;
      if (pds_ds_depL1 != e1 || pds_ds_depL3 != e3 || pds_ds_depL4 != e4 || pds_ds_depL5 != e5)
        fail("chk_vector", $sformatf("uop %0d L1 %b/%b L3 %b/%b L4 %b/%b L5 %b/%b", dsId,
             pds_ds_depL1, e1, pds_ds_depL3, e3, pds_ds_depL4, e4, pds_ds_depL5, e5));
      if (pds_ds_waitCount != ecnt) fail("chk_count", $sformatf("uop %0d count %0d exp %0d", dsId, pds_ds_waitCount, ecnt));
      if (pds_ds_rs1Wait && (ps[0] < 0 || pds_ds_rs1Slot != 8'(1) << u[ps[0]].slot))
        fail("chk_slot", $sformatf("uop %0d rs1Slot %b", dsId, pds_ds_rs1Slot));
      if (pds_ds_rs2Wait && (ps[1] < 0 || pds_ds_rs2Slot != 8'(1) << u[ps[1]].slot))
        fail("chk_slot", $sformatf("uop %0d rs2Slot %b", dsId, pds_ds_rs2Slot));
      if (vis[tail]) fail("chk_bench", "tail slot visible");

      clr = (pds_ds_depL1 & (gPrev | gNow)) | (pds_ds_depL3 & w3) | (pds_ds_depL4 & w4) | (pds_ds_depL5 & w5);
      if (clr != 0) cov["dispatchCorrection"]++;
      occ[tail] = 1;
      rowId[tail] = dsId;
      d1[tail] = pds_ds_depL1 & ~(gPrev | gNow) & ~iq_tailSlot;
      d3[tail] = pds_ds_depL3 & ~w3 & ~iq_tailSlot;
      d4[tail] = pds_ds_depL4 & ~w4 & ~iq_tailSlot;
      d5[tail] = pds_ds_depL5 & ~w5 & ~iq_tailSlot;
      cnt[tail] = int'(pds_ds_waitCount) - $countones(clr);
      if (cnt[tail] < 0) begin fail("chk_count", "negative after dispatch"); cnt[tail] = 0; end
      u[dsId].slot = tail;
      u[dsId].disp = t;
      tail = (tail + 1) % 8;
    end
    if (stall_pds_ds && dsId >= 0) cov["stall"]++;

    // ---- wakes into the existing rows, then the grant leaves -------------------
    for (int k = 0; k < 8; k++)
      if (occ[k] && !(fire && k == u[dsId].slot) && k != gslot) begin
        bit [7:0] c = (d1[k] & gNow) | (d3[k] & w3) | (d4[k] & w4) | (d5[k] & w5);
        cnt[k] -= $countones(c);
        d1[k] &= ~gNow; d3[k] &= ~w3; d4[k] &= ~w4; d5[k] &= ~w5;
        if (cnt[k] < 0) begin fail("chk_count", $sformatf("slot %0d negative", k)); cnt[k] = 0; end
      end
    if (fire)                                         // reuse clears the column, after the wakes
      for (int k = 0; k < 8; k++)
        if (k != u[dsId].slot) begin
          int c = u[dsId].slot;
          d1[k][c] = 1'b0; d3[k][c] = 1'b0; d4[k][c] = 1'b0; d5[k][c] = 1'b0;
        end
    if (gslot >= 0) begin
      int id = rowId[gslot];
      occ[gslot] = 0;
      lastGrant[gslot] = t;
      lastLat[gslot] = latOf(id);
      holdLive[gslot] = 1;
      u[id].grant = t;
    end

    // ---- commit: oldest, granted and complete ----------------------------------
    if (inflight.size() > 0) begin
      int id = inflight[0];
      if (u[id].grant >= 0 && t >= u[id].grant + u[id].lat) begin
        u[id].committed = 1;
        if (u[id].rdWE) begin cmap[u[id].rd] = u[id].rdTag; freeQ.push_back(u[id].oldTag); end
        if (u[id].rdWE && lastWriter[u[id].rdTag] == id) lastWriter[u[id].rdTag] = -1;
        void'(inflight.pop_front());
      end
    end

    // ---- pipeline registers ----------------------------------------------------
    if (kill) begin
      if (flush) cov["flush"]++; else cov["mispredict"]++;
      killYounger(keep);
    end else begin
      if (!stall_pds_ds) begin
        dsMask = (r2Id >= 0 ? u[r2Id].mask : 4'b0) & ~clear;
        dsId = r2Id;
        if (dsId >= 0) u[dsId].c0 = t;
        renameOne();
      end else begin
        dsMask = dsMask & ~clear;
        if (r2Id < 0) renameOne();
      end
    end
  endtask

  // ---- phases ------------------------------------------------------------------
  task automatic phase(string name, int cycles, int bpIn, int killIn);
    bp = bpIn;
    killRate = killIn;
    resetn = 1'b0;
    modelReset();
    r2_pds_valid = 1'b0;
    repeat (3) @(posedge clk);
    #1 resetn = 1'b1;
    renameOne();
    repeat (cycles) step();
    $display("  phase %-9s %0d cycles, %0d uops", name, cycles, nextId);
  endtask

  int unsigned seed = 1;
  int          cycles = 100000;

  initial begin
    void'($value$plusargs("seed=%d", seed));
    void'($value$plusargs("cycles=%d", cycles));
    if ($test$plusargs("stale")) staleVectors = 1'b1;
    void'($urandom(seed));
    errors = 0;
    t = 0;
    phase("realistic", cycles, 15, 8);
    phase("stall", cycles, 70, 4);
    phase("kill", cycles, 25, 60);
    foreach (cov[k]) $display("  cov %-20s %0d", k, cov[k]);
    begin
      string need [12] = '{"same", "bypass", "holdVisible", "count2", "upkeepL1", "upkeepL3",
                           "upkeepL4", "upkeepL5", "dispatchCorrection", "stall", "flush", "mispredict"};
      foreach (need[i]) if (!cov.exists(need[i]) || cov[need[i]] == 0) begin
        $display("ERROR chk_cov: stimulus misses %s", need[i]);
        errors++;
      end
    end
    if (errors == 0) $display("PASS  predisp");
    else             $fatal(1, "FAIL  predisp (%0d errors)", errors);
    $finish;
  end

endmodule
