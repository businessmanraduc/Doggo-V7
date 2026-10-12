// ================================================================================
//  rename_tb -- rename against an independent reference
// ================================================================================
//  Reference: map and retirement map as arrays, free list as an unbounded log
//  with integer head/tail/commit pointers (no ring), snapshots copied at rename
//  time (not a cycle late). Both registers (R1/R2, R2/PreDS) are shadowed cycle
//  by cycle with their stalls and kills. The bench is the rest of the core: a
//  D/R1 register that holds on stall_d_r1 and is flushed on a kill, an in-order
//  ROB that resolves branches out of order (mispredict kills the younger ones),
//  commits from the head and flushes at the head, with or without a commit.
//  Semantic checks at the ROB, independent of the reference: a commit's old tag
//  is the retirement map's entry, a new tag is in no live mapping, a uop's
//  branch mask is exactly the older unresolved branches, a snapshot index is
//  not in use. Phases: realistic ROB 16, ROB 48 with slow commit (free-list
//  stall), branch-heavy (snapshot stall); a reset starts every phase. R1 is
//  held for two cycles after a kill (recovery from registered kills).
// ================================================================================

/* verilator lint_off WIDTHEXPAND */
module rename_tb;

  logic       clk = 1'b0;
  logic       resetn = 1'b0;
  logic       d_r1_valid = 1'b0;
  logic [4:0] d_r1_rs1Index = '0, d_r1_rs2Index = '0, d_r1_rdIndex = '0;
  logic       d_r1_rs1Use = 1'b0, d_r1_rs2Use = 1'b0, d_r1_rdWriteEnable = 1'b0;
  logic       d_r1_isBranch = 1'b0, d_r1_isJalr = 1'b0;
  logic       stall_r2_pds = 1'b0;
  logic       stall_r1_r2, stall_d_r1;
  logic       ex_resolveValid = 1'b0;
  logic [1:0] ex_resolveSnapshot = '0;
  logic       ex_resolveMispredict = 1'b0;
  logic       cm_commitRd = 1'b0;
  logic [4:0] cm_rdIndex = '0;
  logic [5:0] cm_rdTag = '0, cm_rdOldTag = '0;
  logic       cm_flush = 1'b0;
  logic       r2_pds_valid;
  logic [5:0] r2_pds_rs1Tag, r2_pds_rs2Tag, r2_pds_rdTag, r2_pds_rdOldTag;
  logic       r2_pds_rs1Use, r2_pds_rs2Use, r2_pds_rdWriteEnable;
  logic [4:0] r2_pds_rdIndex;
  logic [3:0] r2_pds_branchMask;
  logic [1:0] r2_pds_snapshot;

  rename u_dut (.*);

  always #5 clk = ~clk;

  // ---- reference state ---------------------------------------------------------
  typedef struct {
    bit       valid, rs1Use, rs2Use, rdWE, needSnap;
    int       rs1Tag, rs2Tag, rdTag, oldTag;
    bit [4:0] rdIndex;
    bit [3:0] mask;
    bit [1:0] snap;
  } exp_t;

  int       rmap [32], rret [32];
  int       fq [longint];                   // free-list log
  longint   fh, ft, fc;                     // head, tail, commit head
  bit       rinit, rstall;
  bit       kq1, kq2;                       // kill one and two cycles ago
  int       smap [4][32];
  longint   shead [4];
  longint   sage [4];                      // rename order of the snapshot's branch
  longint   nTake = 0;
  bit [3:0] live;
  exp_t     e1, e2;                         // shadows of r1_r2, r2_pds

  typedef struct {
    int       id;
    bit       rdWE, isBr, resolved;
    bit [4:0] rdIndex;
    int       rdTag, oldTag;
    bit [1:0] snap;
  } rob_t;
  rob_t rob [$];
  int   nextId = 0;

  // ---- this cycle's decisions, applied at the next edge ------------------------
  bit       c_kill, c_mis, c_flush, c_go, c_write, c_take, c_stall1, c_commit, c_push;
  bit [3:0] c_clear;
  bit [1:0] c_fidx;
  exp_t     c_exp;
  int       c_resolveId, c_commitId;
  rob_t     c_pushed;

  // ---- phase knobs -------------------------------------------------------------
  int robCap, pValid, pBranch, pJalr, pResolve, pMis, pCommit, pFlush, pStall;

  int errors = 0;
  int nGo, nMis, nFlushC, nFlushN, nFreeStall, nSnapStall, nHold1, nHold2, nKillXfer;
  int nCommit, nWrap;

  int seen [string];
  task automatic fail(string name, string what);
    errors++;
    if (errors <= 20 || !seen.exists(name)) $display("ERROR %s: %s  t=%0t", name, what, $time);
    seen[name] = 1;
  endtask

  function automatic bit pct(int p);
    return $urandom_range(99) < p;
  endfunction

  function automatic bit [1:0] lowestFree(bit [3:0] busy);
    for (int i = 0; i < 4; i++) if (!busy[i]) return 2'(i);
    return 2'd0;
  endfunction

  task automatic refReset();
    for (int r = 0; r < 32; r++) begin
      rmap[r] = r;
      rret[r] = r;
    end
    fq.delete();
    fh = 0; ft = 0; fc = 0;
    rinit = 1'b1; rstall = 1'b1; live = '0; kq1 = 1'b0; kq2 = 1'b0;
    e1 = '{default: 0};
    e2 = '{default: 0};
    rob.delete();
  endtask

  // ---- edge: apply the decisions of the cycle that just ended ------------------
  task automatic refEdge();
    bit     rstallN;
    longint fcN;
    int     k;
    exp_t   e2n, e1n;

    rstallN = rinit | ((ft - fh) < 2);
    if (c_commit) rret[cm_rdIndex] = cm_rdTag;
    fcN = fc + longint'(c_commit);
    if (rinit) begin
      fq[ft] = 32 + int'(ft);
      if (ft == 31) rinit = 1'b0;
      ft++;
    end else if (c_commit) begin
      fq[ft] = cm_rdOldTag;
      ft++;
    end
    if (c_flush) begin
      rmap = rret;
      fh   = fcN;
      live = '0;
    end else if (c_mis) begin
      rmap = smap[ex_resolveSnapshot];
      fh   = shead[ex_resolveSnapshot];
      for (int i = 0; i < 4; i++)
        if (live[i] && sage[i] >= sage[ex_resolveSnapshot]) live[i] = 1'b0;
    end else begin
      if (c_write) begin
        rmap[c_exp.rdIndex] = c_exp.rdTag;
        fh++;
      end
      live = (live & ~c_clear) | (c_take ? 4'(1) << c_fidx : 4'b0);
      if (c_take) begin
        smap[c_fidx]  = rmap;
        shead[c_fidx] = fh;
        sage[c_fidx]  = nTake++;
      end
    end
    fc     = fcN;
    rstall = rstallN;
    kq2    = kq1;
    kq1    = c_kill;
    if (fh >= 64 && fh % 32 == 0) nWrap++;

    // ---- register shadows ------------------------------------------------------
    e2n = e2;
    if (c_kill)             e2n.valid = 1'b0;
    else if (!stall_r2_pds) e2n = e1;
    e2n.mask = (stall_r2_pds ? e2.mask : e1.mask) & ~c_clear;
    e1n = e1;
    if (c_kill)             e1n.valid = 1'b0;
    else if (!c_stall1) begin
      e1n = c_exp;
      e1n.valid = c_go;
    end
    e1n.mask = (c_stall1 ? e1.mask : c_exp.mask) & ~c_clear;
    e1 = e1n;
    e2 = e2n;

    // ---- bench ROB -------------------------------------------------------------
    if (c_commitId >= 0 && rob.size() != 0 && rob[0].id == c_commitId) void'(rob.pop_front());
    if (c_flush) rob.delete();
    if (ex_resolveValid && !c_flush) begin
      k = -1;
      foreach (rob[i]) if (rob[i].id == c_resolveId) k = i;
      if (k >= 0) begin
        rob[k].resolved = 1'b1;
        if (c_mis) while (rob.size() > k + 1) void'(rob.pop_back());
      end
    end
    if (c_push && !c_kill) rob.push_back(c_pushed);
  endtask

  // ---- registered outputs against the R2/PreDS shadow --------------------------
  task automatic checkOutputs();
    if (r2_pds_valid !== e2.valid) fail("chk_valid", $sformatf("valid %0d exp %0d", r2_pds_valid, e2.valid));
    if (!e2.valid || r2_pds_valid !== 1'b1) return;
    if (r2_pds_rs1Tag != e2.rs1Tag || r2_pds_rs2Tag != e2.rs2Tag)
      fail("chk_src", $sformatf("rs1 %0d rs2 %0d exp %0d %0d", r2_pds_rs1Tag, r2_pds_rs2Tag, e2.rs1Tag, e2.rs2Tag));
    if (r2_pds_rdOldTag != e2.oldTag)
      fail("chk_old", $sformatf("old %0d exp %0d", r2_pds_rdOldTag, e2.oldTag));
    if (e2.rdWE && r2_pds_rdTag != e2.rdTag)
      fail("chk_dest", $sformatf("rd %0d exp %0d", r2_pds_rdTag, e2.rdTag));
    if ({r2_pds_rs1Use, r2_pds_rs2Use, r2_pds_rdWriteEnable, r2_pds_rdIndex} !=
        {e2.rs1Use, e2.rs2Use, e2.rdWE, e2.rdIndex})
      fail("chk_pass", "pass-through fields");
    if (r2_pds_branchMask != e2.mask)
      fail("chk_bmask", $sformatf("mask %b exp %b", r2_pds_branchMask, e2.mask));
    if (e2.needSnap && r2_pds_snapshot != e2.snap)
      fail("chk_snapidx", $sformatf("snapshot %0d exp %0d", r2_pds_snapshot, e2.snap));
  endtask

  // ---- stimulus for the coming cycle -------------------------------------------
  bit prevKill = 1'b0, prevStallD = 1'b0;

  task automatic chooseInputs();
    int cand [$];
    int pick;

    // D/R1 register: flushed by a kill, held on stall, else a new uop or bubble
    if (prevKill) d_r1_valid = 1'b0;
    if (prevKill || !prevStallD || !d_r1_valid) begin
      d_r1_valid    = prevKill ? pct(30) : pct(pValid);   // also right after a kill
      d_r1_rs1Index = 5'($urandom);
      d_r1_rs2Index = 5'($urandom);
      d_r1_rdIndex  = 5'($urandom);
      d_r1_rs1Use   = pct(80);
      d_r1_rs2Use   = pct(50);
      d_r1_isBranch = 1'b0;
      d_r1_isJalr   = 1'b0;
      if (pct(pBranch))    d_r1_isBranch = 1'b1;
      else if (pct(pJalr)) d_r1_isJalr = 1'b1;
      d_r1_rdWriteEnable = !d_r1_isBranch && pct(75) && d_r1_rdIndex != 0;
    end

    stall_r2_pds = pct(pStall) || rob.size() >= robCap;

    // resolve: a random unresolved branch in the ROB
    ex_resolveValid = 1'b0;
    ex_resolveMispredict = 1'b0;
    c_resolveId = -1;
    foreach (rob[i]) if (rob[i].isBr && !rob[i].resolved) cand.push_back(i);
    if (cand.size() != 0 && pct(pResolve)) begin
      pick = cand[$urandom_range(cand.size() - 1)];
      ex_resolveValid      = 1'b1;
      ex_resolveSnapshot   = rob[pick].snap;
      ex_resolveMispredict = pct(pMis);
      c_resolveId          = rob[pick].id;
    end

    // commit from the head; flush at the head with or without a commit
    cm_commitRd = 1'b0;
    cm_flush    = 1'b0;
    c_commit    = 1'b0;
    c_commitId  = -1;
    if (rob.size() != 0 && (!rob[0].isBr || rob[0].resolved) && rob[0].id != c_resolveId &&
        pct(pCommit)) begin
      c_commitId = rob[0].id;
      if (pct(pFlush)) begin
        cm_flush = 1'b1;
        if (pct(50)) begin
          c_commit = rob[0].rdWE;
          nFlushC++;
        end else begin
          nFlushN++;
        end
      end else begin
        c_commit = rob[0].rdWE;
        nCommit++;
      end
      cm_commitRd = c_commit;
      cm_rdIndex  = rob[0].rdIndex;
      cm_rdTag    = 6'(rob[0].rdTag);
      cm_rdOldTag = 6'(rob[0].oldTag);
      if (c_commit && rob[0].oldTag != rret[rob[0].rdIndex])
        fail("chk_retire", $sformatf("old tag %0d, retirement map x%0d = %0d",
                                     rob[0].oldTag, rob[0].rdIndex, rret[rob[0].rdIndex]));
    end
  endtask

  // ---- combinational reference, compared with the DUT's stall outputs ----------
  task automatic refComb();
    bit need, block, stallD;
    bit inUse [64];
    bit [3:0] unres;

    c_clear  = ex_resolveValid ? 4'(1) << ex_resolveSnapshot : 4'b0;
    c_mis    = ex_resolveValid & ex_resolveMispredict;
    c_flush  = cm_flush;
    c_kill   = c_mis | c_flush;
    c_stall1 = stall_r2_pds & e1.valid;
    need     = d_r1_isBranch | d_r1_isJalr;
    block    = rstall | kq1 | kq2 | (need & (&live));
    stallD   = c_stall1 | (d_r1_valid & block);
    c_go     = d_r1_valid & !stallD & !c_kill;
    c_write  = c_go & d_r1_rdWriteEnable;
    c_take   = c_go & need;
    c_fidx   = lowestFree(live);

    c_exp.valid    = 1'b1;
    c_exp.rs1Tag   = rmap[d_r1_rs1Index];
    c_exp.rs2Tag   = rmap[d_r1_rs2Index];
    c_exp.oldTag   = rmap[d_r1_rdIndex];
    c_exp.rdTag    = fq.exists(fh) ? fq[fh] : -1;
    c_exp.rs1Use   = d_r1_rs1Use;
    c_exp.rs2Use   = d_r1_rs2Use;
    c_exp.rdWE     = d_r1_rdWriteEnable;
    c_exp.rdIndex  = d_r1_rdIndex;
    c_exp.needSnap = need;
    c_exp.mask     = live & ~c_clear;
    c_exp.snap     = c_fidx;

    if (stall_d_r1 !== stallD) fail("chk_stall", $sformatf("stall_d_r1 %0d exp %0d", stall_d_r1, stallD));
    if (stall_r1_r2 !== c_stall1) fail("chk_stall", $sformatf("stall_r1_r2 %0d exp %0d", stall_r1_r2, c_stall1));

    if (c_write) begin
      if (fh >= ft) fail("chk_empty", "pop from an empty free list");
      for (int r = 0; r < 32; r++) inUse[rret[r]] = 1'b1;
      foreach (rob[i]) if (rob[i].rdWE) inUse[rob[i].rdTag] = 1'b1;
      if (e1.valid && e1.rdWE) inUse[e1.rdTag] = 1'b1;
      if (e2.valid && e2.rdWE) inUse[e2.rdTag] = 1'b1;
      if (c_exp.rdTag < 0 || inUse[c_exp.rdTag])
        fail("chk_tagfree", $sformatf("new tag %0d is live", c_exp.rdTag));
    end

    // every tag exactly once: retirement map, in flight, free list
    if (!rinit) begin
      int cnt [64];
      foreach (cnt[t]) cnt[t] = 0;
      for (int r = 0; r < 32; r++) cnt[rret[r]]++;
      foreach (rob[i]) if (rob[i].rdWE) cnt[rob[i].rdTag]++;
      if (e1.valid && e1.rdWE) cnt[e1.rdTag]++;
      if (e2.valid && e2.rdWE) cnt[e2.rdTag]++;
      for (longint q = fh; q < ft; q++) cnt[fq[q]]++;
      foreach (cnt[t]) if (cnt[t] != 1) begin
        fail("chk_conserve", $sformatf("tag %0d counted %0d times", t, cnt[t]));
        break;
      end
    end

    // transfer into the ROB: semantic mask and snapshot checks
    c_push = r2_pds_valid && !stall_r2_pds;
    if (c_push) begin
      unres = '0;
      foreach (rob[i]) if (rob[i].isBr && !rob[i].resolved) unres[rob[i].snap] = 1'b1;
      if (r2_pds_branchMask != unres)
        fail("chk_maskorder", $sformatf("mask %b, older unresolved %b", r2_pds_branchMask, unres));
      if (e2.needSnap && unres[r2_pds_snapshot])
        fail("chk_snapfree", $sformatf("snapshot %0d in use", r2_pds_snapshot));
      c_pushed = '{id: nextId++, rdWE: r2_pds_rdWriteEnable, isBr: e2.needSnap, resolved: 1'b0,
                   rdIndex: r2_pds_rdIndex, rdTag: r2_pds_rdTag, oldTag: r2_pds_rdOldTag,
                   snap: r2_pds_snapshot};
      if (c_kill) nKillXfer++;
    end

    nGo        += int'(c_go);
    nMis       += int'(c_mis);
    nFreeStall += int'(d_r1_valid && rstall && !rinit && ft - fh < 4 && !c_stall1 && !kq1 && !kq2);
    nSnapStall += int'(d_r1_valid && need && (&live) && !rstall && !c_stall1 && !kq1 && !kq2);
    nHold1     += int'(c_stall1);
    nHold2     += int'(stall_r2_pds && e2.valid);
    prevKill   = c_kill;
    prevStallD = stallD;
  endtask

  // ---- one cycle ---------------------------------------------------------------
  bit inReset;

  task automatic cycle(bit rst);
    @(negedge clk);
    if (inReset) refReset();
    else         refEdge();
    if (!inReset) checkOutputs();
    resetn  = !rst;
    inReset = rst;
    if (rst) begin
      d_r1_valid = 1'b0; ex_resolveValid = 1'b0; cm_commitRd = 1'b0; cm_flush = 1'b0;
      stall_r2_pds = 1'b0; c_commitId = -1; c_resolveId = -1;
      prevKill = 1'b0; prevStallD = 1'b0;
    end else begin
      chooseInputs();
      #1;
      refComb();
    end
  endtask

  task automatic phase(int n, int cap, int pv, int pb, int pj, int pr, int pm, int pc,
                       int pf, int ps);
    robCap = cap; pValid = pv; pBranch = pb; pJalr = pj; pResolve = pr; pMis = pm;
    pCommit = pc; pFlush = pf; pStall = ps;
    repeat (3) cycle(1'b1);
    repeat (n) cycle(1'b0);
    $display("phase rob %0d: go %0d free stall %0d snapshot stall %0d", cap, nGo, nFreeStall, nSnapStall);
  endtask

  int unsigned seed = 1;
  bit          cov;

  initial begin
    void'($value$plusargs("seed=%d", seed));
    void'($urandom(seed));
    inReset = 1'b1;
    {nGo, nMis, nFlushC, nFlushN, nFreeStall, nSnapStall, nHold1, nHold2, nKillXfer, nCommit,
     nWrap} = '0;
    //     cycles  rob  valid br jalr res mis com flush stall
    phase(100000,  16,  85,  15, 5,   40, 25, 60, 1,    15);
    phase(60000,   48,  95,  5,  2,   50, 20, 15, 0,    5);
    phase(60000,   16,  90,  45, 10,  15, 30, 60, 1,    10);
    cycle(1'b0);

    $display("go %0d commits %0d mispredicts %0d flushes %0d+%0d wraps %0d", nGo, nCommit, nMis,
             nFlushC, nFlushN, nWrap);
    $display("free stall %0d snapshot stall %0d held r1/r2 %0d r2/pds %0d killed transfers %0d",
             nFreeStall, nSnapStall, nHold1, nHold2, nKillXfer);
    cov = nGo > 50000 && nMis != 0 && nFlushC != 0 && nFlushN != 0 && nFreeStall != 0 &&
          nSnapStall != 0 && nHold1 != 0 && nHold2 != 0 && nKillXfer != 0 && nWrap != 0;
    if (!cov) begin
      $display("ERROR chk_cov: stimulus misses a case");
      errors++;
    end
    if (errors == 0) $display("PASS  rename");
    else             $fatal(1, "FAIL  rename (%0d errors)", errors);
    $finish;
  end

endmodule
