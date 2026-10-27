// ================================================================================
//  issue_queue_tb -- predisp + issue_queue inside a behavioural rename, branch unit, ROB and
//  slot-sd units
// ================================================================================
//  The bench plays rename (8 architectural registers, 64 tags, free FIFO,
//  4 branch snapshots with masks), DS (ds_iqGo = valid, ROB credit; fire =
//  ds_iqGo and IQ ready, also in kill cycles: the row is written and dies), branch resolve at grant + 4, an in-order ROB of 16, and two
//  slot-sd producers (divide, pending word: one outstanding each, delivered
//  through steal + wake). Every uop records its producers by tag at rename.
//  Checks:
//   - chk_grant: each cycle the IQ grants exactly the oldest row whose
//   producers are done by the tag scoreboard (none after a steal, none if
//   that row dies in the same cycle).
//   - chk_mask: the granted row's branch mask, resolves applied.
//   - chk_tail, chk_visible, chk_grantPrevious, chk_wake, chk_ready: the
//   exports to predisp and DS against the 0054 windows.
//   - chk_drain: with no new uops, everything commits.
//   - chk_slotsd: IQ boundary contract for the slot-sd flags (one divide and
//   one pending word in flight): never both sources from the same unit, and
//   a source from a unit is a waiting source.
//  Skip uops (system, illegal) fire with no IQ row, also past a full IQ; the
//  predisp slot mirror is written on ds_iqFire only.
//  Phases: realistic, stall-heavy, kill-heavy, slot-sd heavy, dense
//  mispredicts (rows die as they are written); reset each.
// ================================================================================

`include "uop_defs.svh"

/* verilator lint_off WIDTHEXPAND */
/* verilator lint_off WIDTHTRUNC */
module issue_queue_tb;

  localparam int N = 8;

  logic                 clk = 1'b0;
  logic                 resetn = 1'b0;
  logic                 r2_pds_valid = 1'b0;
  logic [5:0]           r2_pds_rs1Tag = '0, r2_pds_rs2Tag = '0, r2_pds_rdTag = '0, r2_pds_rdOldTag = '0;
  logic                 r2_pds_rs1Use = 1'b0, r2_pds_rs2Use = 1'b0, r2_pds_rdWriteEnable = 1'b0;
  logic [4:0]           r2_pds_rdIndex = '0;
  logic [3:0]           r2_pds_branchMask = '0;
  logic [1:0]           r2_pds_snapshot = '0;
  logic [LATENCY_W-1:0] d2_pds_latency = '0;
  logic                 stall_pds_ds, stall_r2_pds;
  logic                 ex_resolveValid = 1'b0;
  logic [1:0]           ex_resolveSnapshot = '0;
  logic                 ex_resolveMispredict = 1'b0;
  logic                 cm_flush = 1'b0;
  logic [N-1:0]         iq_tailSlot, iq_visible, iq_grantPrevious, iq_wakeL3, iq_wakeL4, iq_wakeL5;
  logic                 pds_ds_valid;
  logic [5:0]           pds_ds_rs1Tag, pds_ds_rs2Tag, pds_ds_rdTag, pds_ds_rdOldTag;
  logic                 pds_ds_rs1Use, pds_ds_rs2Use, pds_ds_rdWriteEnable;
  logic [4:0]           pds_ds_rdIndex;
  logic [3:0]           pds_ds_branchMask;
  logic [1:0]           pds_ds_snapshot;
  logic [LATENCY_W-1:0] pds_ds_latency;
  logic [N-1:0]         pds_ds_depL1, pds_ds_depL3, pds_ds_depL4, pds_ds_depL5;
  logic                 pds_ds_rs1Wait, pds_ds_rs2Wait;
  logic [N-1:0]         pds_ds_rs1Slot, pds_ds_rs2Slot;
  logic                 pds_ds_rs1FromDiv = 1'b0, pds_ds_rs1FromMiss = 1'b0;
  logic                 pds_ds_rs2FromDiv = 1'b0, pds_ds_rs2FromMiss = 1'b0;
  logic                 iqRs1Wait, iqRs2Wait;
  logic                 ds_fire, ds_iqGo, ds_iqFire, iq_dispatchReady;
  logic                 sd_steal = 1'b0, sd_divWake = 1'b0, sd_missWake = 1'b0;
  logic [N-1:0]         is_pr_grant;
  logic [3:0]           iq_grantBranchMask;
  logic                 robCredit = 1'b0, killNow = 1'b0, dsSkip = 1'b0;
  int                   skipRate = 5;

  assign stall_pds_ds = pds_ds_valid & !((iq_dispatchReady | dsSkip) & robCredit);
  assign ds_iqGo      = pds_ds_valid & robCredit & !dsSkip;
  assign ds_fire      = pds_ds_valid & robCredit & (dsSkip | iq_dispatchReady);
  assign ds_iqFire    = ds_iqGo & iq_dispatchReady;

  predisp u_pds (.*);
  assign iqRs1Wait = pds_ds_rs1Wait | pds_ds_rs1FromDiv | pds_ds_rs1FromMiss;
  assign iqRs2Wait = pds_ds_rs2Wait | pds_ds_rs2FromDiv | pds_ds_rs2FromMiss;

  issue_queue #(.N(N)) u_iq (.pds_ds_rs1Wait(iqRs1Wait), .pds_ds_rs2Wait(iqRs2Wait), .*);

  // ---- slot-sd contract at the IQ boundary, checked on the uop the IQ sees -----
  int slotsdErrors = 0;
  always @(negedge clk) if (resetn && pds_ds_valid && !dsSkip) begin
    if ((u_iq.pds_ds_rs1FromDiv && u_iq.pds_ds_rs2FromDiv)
        || (u_iq.pds_ds_rs1FromMiss && u_iq.pds_ds_rs2FromMiss)
        || ((u_iq.pds_ds_rs1FromDiv || u_iq.pds_ds_rs1FromMiss) && !u_iq.pds_ds_rs1Wait)
        || ((u_iq.pds_ds_rs2FromDiv || u_iq.pds_ds_rs2FromMiss) && !u_iq.pds_ds_rs2Wait)) begin
      if (slotsdErrors < 5)
        $display("ERROR chk_slotsd: div %b miss %b wait %b",
                 {u_iq.pds_ds_rs1FromDiv, u_iq.pds_ds_rs2FromDiv},
                 {u_iq.pds_ds_rs1FromMiss, u_iq.pds_ds_rs2FromMiss},
                 {u_iq.pds_ds_rs1Wait, u_iq.pds_ds_rs2Wait});
      slotsdErrors++;
    end
  end

  always #5 clk = ~clk;

  // ---- uops --------------------------------------------------------------------
  localparam int GROUP_DIV  = 6;                      // slot-sd producers
  localparam int GROUP_MISS = 7;

  typedef struct {
    bit       killed, committed, rdWE, use1, use2, isBranch, store, skip;
    int       group;                                  // 1/3/4/5, 0 none, 6 div, 7 miss
    int       tag1, tag2, rdTag, oldTag, rd;
    int       prod1, prod2;                           // producer ids, -1 = ready
    int       slot, snap;
    bit [3:0] mask;
    longint   disp, grant, land, resolveAt, killAt;
  } uop_t;

  uop_t   u [int];
  int     nextId;
  int     inflight [$];                               // renamed, uncommitted, program order

  // ---- rename model ------------------------------------------------------------
  int       amap [8], cmap [8];
  int       lastWriter [64];
  int       freeQ [$];
  bit [3:0] liveMask;                                 // unresolved branches renamed
  int       extBusy [8];                              // [6] div, [7] miss: id or -1

  // ---- IQ model ----------------------------------------------------------------
  bit       occ [N];
  int       rowId [N];
  int       tail;
  bit       occHist [8][N];                           // occupancy at the start of cycle c%8
  int       grantHist [8];                            // live grant id of cycle c%8, -1 none
  bit       stealHist [8];                            // sd_steal driven in cycle c%8
  int       expGrant;                                 // expected live grant id, last cycle

  // ---- pipeline shadows --------------------------------------------------------
  int       r2Id, dsId;                               // -1 = empty

  longint   t;
  int       errors;
  int       bubble, bp, misRate, flushRate, extRate, stealRate;   // percent, per mille
  int       landMax;                                  // slot-sd delivery delay, 2..landMax
  bit       renameOn;
  int       cov [string];
  int       shown [string];

  task automatic fail(string chk, string msg);
    if (shown[chk] < 5) $display("ERROR %s @%0d: %s", chk, t, msg);
    shown[chk]++;
    errors++;
  endtask

  function automatic bit [N-1:0] oneHot(int k);
    return k >= 0 ? N'(1) << k : '0;
  endfunction

  // ---- producer p's result usable by a consumer granted at c -------------------
  function automatic bit avail(int p, longint c);
    if (p < 0) return 1;
    if (u[p].committed || u[p].killed) return 1;
    if (u[p].group == GROUP_DIV || u[p].group == GROUP_MISS) return u[p].land >= 0 && c >= u[p].land + 1;
    return u[p].grant >= 0 && c >= u[p].grant + u[p].group;
  endfunction

  function automatic int groupOf(int id);
    return id >= 0 ? u[id].group : 0;
  endfunction

  function automatic int grantAt(longint c);
    return c >= 1 ? grantHist[c % 8] : -1;
  endfunction

  // ---- reset -------------------------------------------------------------------
  task automatic modelReset();
    u.delete();
    inflight.delete();
    freeQ.delete();
    nextId = 0;
    for (int r = 0; r < 8; r++) begin amap[r] = r; cmap[r] = r; end
    for (int g = 0; g < 64; g++) lastWriter[g] = -1;
    for (int g = 8; g < 64; g++) freeQ.push_back(g);
    liveMask = 0;
    extBusy[GROUP_DIV] = -1;
    extBusy[GROUP_MISS] = -1;
    for (int k = 0; k < N; k++) begin occ[k] = 0; rowId[k] = -1; end
    for (int c = 0; c < 8; c++) begin
      grantHist[c] = -1;
      stealHist[c] = 0;
      for (int k = 0; k < N; k++) occHist[c][k] = 0;
    end
    tail = 0;
    expGrant = -1;
    r2Id = -1;
    dsId = -1;
  endtask

  // ---- rename one uop into R2 --------------------------------------------------
  task automatic renameOne();
    uop_t x;
    int   r1, r2, cls, snapFree;
    r2Id = -1;
    if (!renameOn || freeQ.size() == 0 || $urandom_range(99) < bubble) return;
    x = '{default: 0};
    cls = $urandom_range(99);
    x.group = 1;
    if (cls < 10)                   x.group = 3;
    else if (cls < 18)              x.group = 4;
    else if (cls < 30)              x.group = 5;
    else if (cls < 30 + extRate)    x.group = GROUP_DIV;
    else if (cls < 30 + 2 * extRate) x.group = GROUP_MISS;
    else if (cls < 44 + 2 * extRate) begin x.isBranch = 1; x.group = 0; end
    else if (cls < 50 + 2 * extRate) begin x.store = 1; x.group = 0; end
    if ((x.group == GROUP_DIV || x.group == GROUP_MISS) && extBusy[x.group] >= 0) x.group = 1;
    snapFree = -1;
    if (x.isBranch) begin
      for (int s = 0; s < 4; s++) if (!liveMask[s] && snapFree < 0) snapFree = s;
      if (snapFree < 0) begin x.isBranch = 0; x.group = 1; end
    end
    if ($urandom_range(99) < skipRate && !x.isBranch) begin x.skip = 1; x.store = 0; x.group = 0; if (extBusy[GROUP_DIV] == nextId) extBusy[GROUP_DIV] = -1; end
    x.rdWE = !x.isBranch && !x.store && !x.skip;
    x.use1 = $urandom_range(99) < 85;
    x.use2 = x.isBranch || x.store || $urandom_range(99) < 55;
    r1 = $urandom_range(7);
    r2 = $urandom_range(7);
    x.tag1 = amap[r1];
    x.tag2 = amap[r2];
    x.prod1 = x.use1 ? lastWriter[x.tag1] : -1;
    x.prod2 = x.use2 ? lastWriter[x.tag2] : -1;
    if (x.prod1 >= 0 && u[x.prod1].committed) x.prod1 = -1;
    if (x.prod2 >= 0 && u[x.prod2].committed) x.prod2 = -1;
    x.rd = $urandom_range(1, 7);
    x.oldTag = amap[x.rd];
    x.rdTag = x.rdWE ? freeQ.pop_front() : $urandom_range(63);
    if (x.rdWE) begin amap[x.rd] = x.rdTag; lastWriter[x.rdTag] = nextId; end
    x.mask = liveMask;
    x.snap = x.isBranch ? snapFree : $urandom_range(3);
    if (x.isBranch) liveMask[snapFree] = 1'b1;
    x.slot = -1; x.disp = -1; x.grant = -1; x.land = -1; x.resolveAt = -1; x.killAt = -1;
    if (!x.skip && (x.group == GROUP_DIV || x.group == GROUP_MISS)) extBusy[x.group] = nextId;
    u[nextId] = x;
    inflight.push_back(nextId);
    r2Id = nextId;
    nextId++;
  endtask

  // ---- kill everything younger than keep (keep = -1: flush all) ----------------
  task automatic killYounger(int keep);
    int n [$];
    foreach (inflight[i]) begin
      int id = inflight[i];
      if (id > keep) begin
        u[id].killed = 1;
        u[id].killAt = t;
        if (u[id].rdWE) begin freeQ.push_back(u[id].rdTag); lastWriter[u[id].rdTag] = -1; end
        if (u[id].isBranch && !(u[id].resolveAt >= 0 && u[id].resolveAt <= t)) liveMask[u[id].snap] = 1'b0;
        if (u[id].slot >= 0 && occ[u[id].slot] && rowId[u[id].slot] == id) occ[u[id].slot] = 0;
        if (extBusy[GROUP_DIV] == id) extBusy[GROUP_DIV] = -1;
        if (extBusy[GROUP_MISS] == id) extBusy[GROUP_MISS] = -1;
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
    int       resolver, divLand, missLand, w, keep;
    bit       mis, flush, steal;
    bit [N-1:0] expVis, expWake3, expWake4, expWake5, expPrev;
    bit [3:0] clear;
    int       g1, g2, g3, g4;

    @(posedge clk); #1;
    t++;

    // ---- registered outputs ----------------------------------------------------
    if (is_pr_grant !== oneHot(expGrant >= 0 ? u[expGrant].slot : -1))
      fail("chk_grant", $sformatf("grant %b exp uop %0d slot %0d", is_pr_grant, expGrant,
                                  expGrant >= 0 ? u[expGrant].slot : -1));
    if (expGrant >= 0 && iq_grantBranchMask !== u[expGrant].mask)
      fail("chk_mask", $sformatf("mask %b exp %b", iq_grantBranchMask, u[expGrant].mask));
    if (iq_tailSlot !== oneHot(tail)) fail("chk_tail", $sformatf("tail %b exp %0d", iq_tailSlot, tail));
    g1 = grantAt(t - 1);
    g2 = grantAt(t - 2);
    g3 = grantAt(t - 3);
    g4 = grantAt(t - 4);
    expPrev = g1 >= 0 ? oneHot(u[g1].slot) : '0;
    expWake3 = (g2 >= 0 && groupOf(g2) == 3) ? oneHot(u[g2].slot) : '0;
    expWake4 = (g3 >= 0 && groupOf(g3) == 4) ? oneHot(u[g3].slot) : '0;
    expWake5 = (g4 >= 0 && groupOf(g4) == 5) ? oneHot(u[g4].slot) : '0;
    for (int k = 0; k < N; k++) expVis[k] = occ[k];
    if (g1 >= 0 && (groupOf(g1) == 4 || groupOf(g1) == 5)) expVis |= oneHot(u[g1].slot);
    if (g2 >= 0 && groupOf(g2) == 5 && !(u[g2].killed && u[g2].killAt == t - 1)) expVis |= oneHot(u[g2].slot);
    if (iq_grantPrevious !== expPrev) fail("chk_grantPrevious", $sformatf("%b exp %b", iq_grantPrevious, expPrev));
    if (iq_wakeL3 !== expWake3) fail("chk_wake", $sformatf("L3 %b exp %b", iq_wakeL3, expWake3));
    if (iq_wakeL4 !== expWake4) fail("chk_wake", $sformatf("L4 %b exp %b", iq_wakeL4, expWake4));
    if (iq_wakeL5 !== expWake5) fail("chk_wake", $sformatf("L5 %b exp %b", iq_wakeL5, expWake5));
    if (iq_visible !== expVis) fail("chk_visible", $sformatf("%b exp %b", iq_visible, expVis));
    begin
      bit busy;
      busy = t >= 2 && occHist[(t - 1) % 8][tail];
      if (g2 >= 0 && u[g2].slot == tail && (groupOf(g2) == 4 || groupOf(g2) == 5)) busy = 1;
      if (g3 >= 0 && u[g3].slot == tail && groupOf(g3) == 5) busy = 1;
      if (iq_dispatchReady !== !busy) fail("chk_ready", $sformatf("ready %0d exp %0d", iq_dispatchReady, !busy));
    end
    for (int k = 0; k < N; k++) occHist[t % 8][k] = occ[k];

    // ---- drive cycle t: resolve, flush -----------------------------------------
    resolver = -1;
    foreach (inflight[i]) if (u[inflight[i]].isBranch && u[inflight[i]].resolveAt == t) resolver = inflight[i];
    mis = resolver >= 0 && $urandom_range(99) < misRate;
    flush = renameOn && inflight.size() > 0 && $urandom_range(999) < flushRate;
    ex_resolveValid      = resolver >= 0;
    ex_resolveSnapshot   = resolver >= 0 ? u[resolver].snap : $urandom;
    ex_resolveMispredict = mis;
    cm_flush             = flush;
    killNow              = mis || flush;
    clear = resolver >= 0 ? 4'(1) << u[resolver].snap : 4'b0;

    // ---- slot sd: announce deliveries landing next cycle, random steals --------
    divLand = extBusy[GROUP_DIV];
    missLand = extBusy[GROUP_MISS];
    sd_divWake  = divLand >= 0 && u[divLand].land == t + 1;
    sd_missWake = missLand >= 0 && u[missLand].land == t + 1;
    steal = sd_divWake || sd_missWake || $urandom_range(999) < stealRate;
    sd_steal = steal;
    stealHist[t % 8] = steal;

    // ---- DS: credit, slot-sd dependencies of the uop in DS ---------------------
    robCredit = 1'b1;
    begin
      int n = 0;
      foreach (inflight[i]) if (u[inflight[i]].disp >= 0) n++;
      if (n >= 16 || $urandom_range(99) < bp) robCredit = 1'b0;
    end
    dsSkip = dsId >= 0 && u[dsId].skip;
    pds_ds_rs1FromDiv = 1'b0; pds_ds_rs1FromMiss = 1'b0;
    pds_ds_rs2FromDiv = 1'b0; pds_ds_rs2FromMiss = 1'b0;
    if (dsId >= 0) begin
      int  ps [2];
      bit  dv [2], ms [2];
      ps[0] = u[dsId].use1 ? u[dsId].prod1 : -1;
      ps[1] = u[dsId].use2 && u[dsId].prod2 != ps[0] ? u[dsId].prod2 : -1;
      foreach (ps[i]) begin
        dv[i] = 0;
        ms[i] = 0;
        if (ps[i] >= 0 && !u[ps[i]].committed && (u[ps[i]].land < 0 || u[ps[i]].land >= t)) begin
          dv[i] = u[ps[i]].group == GROUP_DIV;
          ms[i] = u[ps[i]].group == GROUP_MISS;
        end
      end
      pds_ds_rs1FromDiv = dv[0]; pds_ds_rs1FromMiss = ms[0];
      pds_ds_rs2FromDiv = dv[1]; pds_ds_rs2FromMiss = ms[1];
    end

    // ---- R2 --------------------------------------------------------------------
    if (r2Id >= 0) begin
      uop_t x = u[r2Id];
      int   lv = 0;
      r2_pds_valid = 1'b1;
      r2_pds_rs1Tag = x.tag1; r2_pds_rs2Tag = x.tag2; r2_pds_rdTag = x.rdTag; r2_pds_rdOldTag = x.oldTag;
      r2_pds_rs1Use = x.use1; r2_pds_rs2Use = x.use2; r2_pds_rdWriteEnable = x.rdWE;
      r2_pds_rdIndex = x.rd; r2_pds_branchMask = x.mask; r2_pds_snapshot = x.snap;
      case (x.group)
        1: lv = 1 << LATENCY_1;
        3: lv = 1 << LATENCY_3;
        4: lv = 1 << LATENCY_4;
        5: lv = 1 << LATENCY_5;
        GROUP_DIV, GROUP_MISS: lv = 1 << LATENCY_DIV;
        default: lv = 0;
      endcase
      d2_pds_latency = lv;
    end else begin
      r2_pds_valid = 1'b0;
      r2_pds_rs1Tag = $urandom; r2_pds_rs2Tag = $urandom; r2_pds_rs1Use = $urandom; r2_pds_rs2Use = $urandom;
    end
    #1;

    if (stall_r2_pds !== (stall_pds_ds && r2Id >= 0)) fail("chk_stall", "stall_r2_pds");
    if (pds_ds_valid !== (dsId >= 0)) fail("chk_dsValid", $sformatf("valid %0d exp %0d", pds_ds_valid, dsId >= 0));
    if (stall_pds_ds && dsId >= 0 && !iq_dispatchReady) begin
      for (int k = 0; k < N; k++) if (!occ[k] && k != tail) begin cov["tailStall"]++; break; end
    end

    // ---- expected grant: oldest row whose producers are done -------------------
    w = -1;
    for (int k = 0; k < N; k++)
      if (occ[k]) begin
        int id = rowId[k];
        if (avail(u[id].prod1, t) && avail(u[id].prod2, t) && (w < 0 || id < w)) w = id;
      end
    if (w >= 0 && t >= 1 && stealHist[(t - 1) % 8]) begin cov["steal"]++; w = -1; end
    if (w >= 0 && killNow && (flush || w > resolver)) begin cov["killGranted"]++; w = -1; end
    expGrant = w;
    grantHist[t % 8] = w;

    // ---- coverage: what the rows and the dispatching uop catch this cycle ------
    for (int k = 0; k < N; k++)
      if (occ[k]) begin
        int id = rowId[k];
        int nLate = 0, nChain = 0;
        int ps [2];
        ps[0] = u[id].prod1;
        ps[1] = (u[id].prod2 == u[id].prod1) ? -1 : u[id].prod2;
        foreach (ps[i]) if (ps[i] >= 0 && !u[ps[i]].committed) begin
          int p = ps[i];
          if (u[p].group >= 3 && u[p].group <= 5 && u[p].grant >= 0 && u[p].grant + u[p].group - 1 == t) nLate++;
          if ((u[p].group == GROUP_DIV || u[p].group == GROUP_MISS) && u[p].land == t) nLate++;
          if (u[p].group == 1 && expGrant == p) nChain++;
        end
        if (nLate == 2) cov["late2"]++;
        if (nLate == 1 && nChain == 1) cov["chainPlusLate"]++;
      end
    if (ds_fire) begin
      int ps [2];
      ps[0] = u[dsId].prod1;
      ps[1] = u[dsId].prod2;
      foreach (ps[i]) if (ps[i] >= 0 && !u[ps[i]].committed) begin
        int p = ps[i];
        if (u[p].group == 1 && expGrant == p) cov["newHit"]++;
        if (u[p].group == 1 && u[p].grant == t - 1) cov["grantPrevious"]++;
        if (u[p].group >= 3 && u[p].group <= 5 && u[p].grant >= 0) begin
          if (u[p].grant + u[p].group - 1 == t) cov["landNow"]++;
          if (u[p].grant + u[p].group - 1 == t + 1) cov["dispatchTerm"]++;
          if (u[p].slot == tail && u[p].grant + u[p].group - 1 >= t - 1) cov["ownColumn"]++;
        end
        if ((u[p].group == GROUP_DIV || u[p].group == GROUP_MISS) && u[p].land == t) cov["extNow"]++;
        if ((u[p].group == GROUP_DIV || u[p].group == GROUP_MISS) && u[p].land == t + 1) cov["extTerm"]++;
      end
      if (g3 >= 0 && u[g3].slot == tail && groupOf(g3) == 4) cov["reuseEdgeL4"]++;
      if (g4 >= 0 && u[g4].slot == tail && groupOf(g4) == 5) cov["reuseEdgeL5"]++;
      if (clear & u[dsId].mask) cov["resolveOnDispatch"]++;
      if (tail == N - 1) cov["wrap"]++;
      if (mis) cov["fireInMispredict"]++;
      if (flush) cov["fireInFlush"]++;
    end
    if (sd_divWake) cov["divWake"]++;
    if (sd_missWake) cov["missWake"]++;

    // ---- edge: grant leaves, dispatch writes, slot sd scheduled ----------------
    if (w >= 0) begin
      int k = u[w].slot;
      occ[k] = 0;
      u[w].grant = t;
      if (u[w].isBranch) u[w].resolveAt = t + 4;
      if (u[w].group == GROUP_DIV || u[w].group == GROUP_MISS) u[w].land = t + 2 + $urandom_range(landMax - 2);
    end
    if (ds_fire && u[dsId].skip) begin
      if (!iq_dispatchReady) cov["skipFullIq"]++;
      if (!iq_dispatchReady && occ[tail]) cov["skipOverLive"]++;
      u[dsId].disp = t;
    end else if (ds_fire) begin
      occ[tail] = 1;
      rowId[tail] = dsId;
      u[dsId].slot = tail;
      u[dsId].disp = t;
      tail = (tail + 1) % N;
    end
    foreach (inflight[i]) begin
      int id = inflight[i];
      if ((u[id].group == GROUP_DIV || u[id].group == GROUP_MISS) && u[id].land == t) extBusy[u[id].group] = -1;
    end

    // ---- commit: oldest, done --------------------------------------------------
    if (!flush && inflight.size() > 0) begin
      int  id = inflight[0];
      bit  done;
      done = u[id].grant >= 0 && t >= u[id].grant + (u[id].isBranch ? 5 : u[id].group >= 3 && u[id].group <= 5 ? u[id].group : 1);
      if (u[id].group == GROUP_DIV || u[id].group == GROUP_MISS) done = u[id].land >= 0 && t > u[id].land;
      if (u[id].skip) done = u[id].disp >= 0 && t > u[id].disp;
      if (done) begin
        u[id].committed = 1;
        if (u[id].rdWE) begin cmap[u[id].rd] = u[id].rdTag; freeQ.push_back(u[id].oldTag); end
        if (u[id].rdWE && lastWriter[u[id].rdTag] == id) lastWriter[u[id].rdTag] = -1;
        void'(inflight.pop_front());
      end
    end

    // ---- resolve: masks cleared, snapshot freed; kill the younger ones ---------
    if (resolver >= 0) begin
      foreach (inflight[i]) u[inflight[i]].mask &= ~clear;
      liveMask &= ~clear;
    end
    if (flush) begin
      cov["flush"]++;
      killYounger(-1);
      liveMask = 0;
    end else if (mis) begin
      cov["mispredict"]++;
      killYounger(resolver);
    end

    // ---- pipeline registers ----------------------------------------------------
    if (!killNow) begin
      if (!stall_pds_ds) begin
        dsId = r2Id;
        renameOne();
      end else if (r2Id < 0) renameOne();
    end else renameOne();
  endtask

  // ---- drain: no new uops, no kills, everything commits ------------------------
  task automatic drain();
    int guard = 0;
    renameOn = 0;
    misRate = 0;
    flushRate = 0;
    while ((inflight.size() > 0 || r2Id >= 0 || dsId >= 0) && guard < 2000) begin
      step();
      guard++;
    end
    if (inflight.size() > 0) fail("chk_drain", $sformatf("%0d uops never committed, head %0d", inflight.size(), inflight[0]));
  endtask

  // ---- phases ------------------------------------------------------------------
  task automatic phase(string name, int cycles, int bubbleIn, int bpIn, int misIn, int flushIn,
                       int extIn, int stealIn, int landIn);
    bubble = bubbleIn;
    bp = bpIn;
    misRate = misIn;
    flushRate = flushIn;
    extRate = extIn;
    stealRate = stealIn;
    landMax = landIn;
    renameOn = 1;
    resetn = 1'b0;
    modelReset();
    r2_pds_valid = 1'b0;
    ex_resolveValid = 1'b0;
    cm_flush = 1'b0;
    killNow = 1'b0;
    robCredit = 1'b0;
    sd_steal = 1'b0; sd_divWake = 1'b0; sd_missWake = 1'b0;
    repeat (3) @(posedge clk);
    #1 resetn = 1'b1;
    t = 0;
    renameOne();
    repeat (cycles) step();
    drain();
    $display("  phase %-9s %0d cycles, %0d uops", name, cycles, nextId);
  endtask

  int unsigned seed = 1;
  int          cycles = 100000;

  initial begin
    void'($value$plusargs("seed=%d", seed));
    void'($value$plusargs("cycles=%d", cycles));
    void'($value$plusargs("skip=%d", skipRate));
    void'($urandom(seed));
    errors = 0;
    phase("realistic", cycles, 10, 10, 10, 2, 3, 5, 10);
    phase("stall", cycles, 5, 60, 10, 2, 3, 5, 10);
    phase("kill", cycles, 5, 15, 45, 10, 3, 5, 10);
    phase("slotsd", cycles, 5, 10, 10, 2, 10, 40, 10);
    phase("slowsd", cycles, 5, 10, 5, 1, 12, 10, 40);
    phase("killfire", 4 * cycles, 0, 5, 90, 0, 3, 5, 10);   // dense mispredicts: rows die as they are written
    foreach (cov[k]) $display("  cov %-20s %0d", k, cov[k]);
    begin
      string need [24] = '{"skipFullIq", "skipOverLive", "fireInMispredict", "fireInFlush", "tailStall", "steal", "killGranted", "late2", "chainPlusLate", "newHit",
                           "grantPrevious", "landNow", "dispatchTerm", "ownColumn", "extNow",
                           "extTerm", "reuseEdgeL4", "reuseEdgeL5", "resolveOnDispatch", "wrap",
                           "divWake", "missWake", "flush", "mispredict"};
      foreach (need[i]) if (!cov.exists(need[i]) || cov[need[i]] == 0) begin
        $display("ERROR chk_cov: stimulus misses %s", need[i]);
        errors++;
      end
    end
    errors += slotsdErrors;
    if (errors == 0) $display("PASS  issue_queue");
    else             $fatal(1, "FAIL  issue_queue (%0d errors)", errors);
    $finish;
  end

endmodule
