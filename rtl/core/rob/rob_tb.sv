// ================================================================================
//  rob_tb: reorder buffer against a cycle-exact model
// ================================================================================
//  The bench plays dispatch (fires only when ready and not in a kill cycle;
//  class / system / illegal chosen to make the entry pending, done or trapping),
//  the completion port (one per live, pending entry, killed ones filtered),
//  branch resolve (mispredict on a live pending entry) and LQ marks (live,
//  not head). Checks:
//   - chk_ready: rob_dispatchReady, rob_empty, ds_robIndex each cycle.
//   - chk_commit: cm_valid each cycle; payload, exception, refetch, flush on
//   every commit.
//   - chk_badAddress: last completion's address on every commit of
//   an entry that completed through the port.
// ================================================================================

`include "uop_defs.svh"

module rob_tb;

  localparam int N  = 16;
  localparam int PW = 60;

  logic          clk = 1'b0, resetn = 1'b0;
  logic          ds_fire = 1'b0, ds_done = 1'b0, ds_exception = 1'b0;
  logic [PW-1:0] ds_payload = '0;
  logic          rob_dispatchReady, rob_empty;
  logic [3:0]    ds_robIndex;
  logic          wb_valid = 1'b0, wb_exception = 1'b0, wb_refetch = 1'b0;
  logic [3:0]    wb_robIndex = '0;
  logic [31:0]   wb_badAddress = '0, cm_badAddress;
  logic          lq_violationValid = 1'b0;
  logic [3:0]    lq_violationRobIndex = '0;
  logic          ex_resolveValid = 1'b0, ex_resolveMispredict = 1'b0;
  logic [3:0]    ex_resolveRobIndex = '0;
  logic          cm_valid, cm_exception, cm_refetch, cm_flush;
  logic [PW-1:0] cm_payload;

  always #5 clk = ~clk;

  // ---- named fields <-> the model's packed word --------------------------------
  // {rdIndex, rdTag, rdOldTag, rdWriteEnable, pc, rvc, system, illegal,
  //  serialising, isLoad, isStore}
  logic [4:0]          cm_rdIndex;
  logic [5:0]          cm_rdTag, cm_rdOldTag;
  logic                cm_rdWriteEnable, cm_rvc, cm_illegal, cm_serialising, cm_isLoad, cm_isStore;
  logic [30:0]         cm_pc;
  logic [SYSTEM_W-1:0] cm_system;
  logic [CLASS_W-1:0]  ds_class;

  assign cm_payload = {cm_rdIndex, cm_rdTag, cm_rdOldTag, cm_rdWriteEnable, cm_pc, cm_rvc,
                       cm_system, cm_illegal, cm_serialising, cm_isLoad, cm_isStore};
  // isLoad / isStore travel in the class vector; the other class bits are noise
  always_comb begin
    ds_class               = CLASS_W'(ds_payload >> 20);
    ds_class[CLASS_SYSTEM] = !ds_payload[3] && ds_payload[9:4] != '0;   // system op, not illegal
    ds_class[CLASS_LOAD]   = ds_payload[1];
    ds_class[CLASS_STORE]  = ds_payload[0];
  end

  rob u_dut (
    .clk, .resetn,
    .ds_fire,
    .pds_ds_rdIndex       (ds_payload[59:55]),
    .pds_ds_rdTag         (ds_payload[54:49]),
    .pds_ds_rdOldTag      (ds_payload[48:43]),
    .pds_ds_rdWriteEnable (ds_payload[42]),
    .pds_ds_pc            (ds_payload[41:11]),
    .pds_ds_rvc           (ds_payload[10]),
    .pds_ds_class         (ds_class),
    .pds_ds_system        (ds_payload[9:4]),
    .pds_ds_illegal       (ds_payload[3]),
    .pds_ds_serialising   (ds_payload[2]),
    .rob_dispatchReady, .rob_empty, .ds_robIndex,
    .wb_valid, .wb_robIndex, .wb_exception, .wb_refetch, .wb_badAddress,
    .lq_violationValid, .lq_violationRobIndex,
    .ex_resolveValid, .ex_resolveMispredict, .ex_resolveRobIndex,
    .cm_valid, .cm_exception, .cm_refetch, .cm_flush,
    .cm_rdIndex, .cm_rdTag, .cm_rdOldTag, .cm_rdWriteEnable, .cm_pc, .cm_rvc,
    .cm_system, .cm_illegal, .cm_serialising, .cm_isLoad, .cm_isStore,
    .cm_badAddress
  );

  // class / system / illegal bits that make the entry pending, done or trapping
  function automatic logic [PW-1:0] shapeWord(logic [PW-1:0] v, bit done, bit exception);
    v[9:3] = '0;
    if (done && exception) begin
      case ($urandom_range(2))
        0: v[3] = 1'b1;                                    // illegal
        1: v[4 + SYSTEM_ECALL]  = 1'b1;
        2: v[4 + SYSTEM_EBREAK] = 1'b1;
      endcase
    end else if (done) begin
      case ($urandom_range(3))
        0: v[4 + SYSTEM_MRET]   = 1'b1;
        1: v[4 + SYSTEM_WFI]    = 1'b1;
        2: v[4 + SYSTEM_FENCE]  = 1'b1;
        3: v[4 + SYSTEM_FENCEI] = 1'b1;
      endcase
    end
    if (done) v[1:0] = '0;                                 // not a load or store
    return v;
  endfunction

  // ---- model -------------------------------------------------------------------
  bit            live [N], done [N], exc [N], ref_ [N], dsDone [N], badKnown [N];
  logic [PW-1:0] word [N];
  logic [31:0]   badAddr [N];
  longint        bornAt [N];
  int            head, tail, count;
  bit            flushReg;                   // model of cm_flush in this cycle
  // expected commit outputs for the next cycle
  bit            expValid, expExc, expRef, expFlush, expBadKnown;
  logic [PW-1:0] expWord;
  logic [31:0]   expBad;

  longint        t;
  int            errors, checks;
  int            shown [string];
  int            cov [string];
  int            pDispatch, pDone, pWb, pMis, pLq, pExc;

  task automatic fail(string chk, string msg);
    if (shown[chk] < 5) $display("ERROR %s @%0d: %s", chk, t, msg);
    shown[chk]++;
    errors++;
  endtask

  function automatic logic [PW-1:0] randomWord();
    logic [PW-1:0] v;
    for (int b = 0; b < PW; b += 32) v[b +: 32] = $urandom();
    return v;
  endfunction

  function automatic bit younger(int j, int idx);   // j strictly after idx, before tail
    int dj, di;
    dj = (j - head + N) % N;
    di = (idx - head + N) % N;
    return live[j] && dj > di;
  endfunction

  task automatic step();
    bit commit, mis, kill;
    int idx, wbIdx, lqIdx, cand [$];
    @(negedge clk);
    t++;

    // ---- check outputs of this cycle -------------------------------------------
    checks++;
    if (cm_valid !== expValid) fail("chk_commit", $sformatf("cm_valid %b exp %b", cm_valid, expValid));
    else if (expValid) begin
      if (cm_payload !== expWord) fail("chk_commit", $sformatf("payload %h exp %h", cm_payload[31:0], expWord[31:0]));
      if (cm_exception !== expExc) fail("chk_commit", $sformatf("exception %b exp %b", cm_exception, expExc));
      if (cm_refetch !== expRef) fail("chk_commit", $sformatf("refetch %b exp %b", cm_refetch, expRef));
      if (expBadKnown && cm_badAddress !== expBad)
        fail("chk_badAddress", $sformatf("badAddress %h exp %h", cm_badAddress, expBad));
    end
    if (cm_flush !== expFlush) fail("chk_commit", $sformatf("cm_flush %b exp %b", cm_flush, expFlush));
    if (rob_dispatchReady !== (count < N)) fail("chk_ready", $sformatf("dispatchReady %b count %0d", rob_dispatchReady, count));
    if (rob_empty !== (count == 0)) fail("chk_ready", $sformatf("empty %b count %0d", rob_empty, count));
    if (ds_robIndex !== 4'(tail)) fail("chk_ready", $sformatf("robIndex %0d exp %0d", ds_robIndex, tail));
    flushReg = expFlush;

    // ---- this cycle's commit ---------------------------------------------------
    commit   = count > 0 && done[head] && !flushReg;
    expValid = commit;
    expWord  = word[head];
    expExc   = commit && exc[head];
    expRef   = commit && ref_[head];
    expBadKnown = badKnown[head];
    expBad      = badAddr[head];
    expFlush = commit && (exc[head] || ref_[head]);
    if (count == N) cov["full"]++;

    // ---- resolve: mispredict on a live pending entry ---------------------------
    ex_resolveValid = 1'b0;
    ex_resolveMispredict = 1'b0;
    mis = 1'b0;
    if (!flushReg && $urandom_range(999) < pMis) begin
      for (int j = 0; j < N; j++) if (live[j] && !done[j]) cand.push_back(j);
      if (cand.size() > 0) begin
        idx = cand[$urandom_range(cand.size() - 1)];
        mis = 1'b1;
        ex_resolveValid = 1'b1;
        ex_resolveMispredict = 1'b1;
        ex_resolveRobIndex = 4'(idx);
        if (commit) cov["misCommit"]++;
        if (count == N) cov["misFull"]++;
        if ((idx + 1) % N == head) cov["misToFull"]++;
      end
      cand.delete();
    end else if ($urandom_range(9) == 0) begin
      ex_resolveValid = 1'b1;                    // correct prediction: no effect
      ex_resolveRobIndex = 4'($urandom());
    end
    kill = flushReg || mis;

    // ---- completion: a live pending entry, not killed this cycle ---------------
    wb_valid = 1'b0;
    wbIdx = -1;
    if (!flushReg && $urandom_range(99) < pWb) begin
      for (int j = 0; j < N; j++)
        if (live[j] && !done[j] && t > bornAt[j] + 1 && !(mis && younger(j, idx))) cand.push_back(j);
      if (cand.size() > 0) begin
        wbIdx = cand[$urandom_range(cand.size() - 1)];
        wb_valid     = 1'b1;
        wb_robIndex  = 4'(wbIdx);
        wb_exception = $urandom_range(999) < pExc;
        wb_refetch   = $urandom_range(999) < pExc;
        wb_badAddress = $urandom();
      end
      cand.delete();
    end

    // ---- LQ mark: live, not head, not killed this cycle ------------------------
    lq_violationValid = 1'b0;
    lqIdx = -1;
    if (!flushReg && $urandom_range(999) < pLq) begin
      for (int j = 0; j < N; j++)
        if (live[j] && j != head && !(mis && younger(j, idx))) cand.push_back(j);
      if (cand.size() > 0) begin
        lqIdx = cand[$urandom_range(cand.size() - 1)];
        lq_violationValid    = 1'b1;
        lq_violationRobIndex = 4'(lqIdx);
        if (lqIdx == wbIdx) cov["lqWithWb"]++;
      end
      cand.delete();
    end

    // ---- dispatch --------------------------------------------------------------
    ds_fire      = 1'b0;
    ds_done      = $urandom_range(99) < pDone;
    ds_exception = ds_done && $urandom_range(99) < 10;
    ds_payload   = shapeWord(randomWord(), ds_done, ds_exception);
    if (count < N && !kill && $urandom_range(99) < pDispatch) begin
      ds_fire = 1'b1;
      if (commit && count == N - 1) cov["fireCommit15"]++;
    end

    // ---- model update at the edge ----------------------------------------------
    if (flushReg) begin
      for (int j = 0; j < N; j++) live[j] = 1'b0;
      tail = head;
      count = 0;
      cov["flush"]++;
    end else begin
      if (commit) begin
        live[head] = 1'b0;
        head = (head + 1) % N;
        count--;
      end
      if (mis) begin
        for (int j = 0; j < N; j++) if (live[j] && younger(j, idx)) live[j] = 1'b0;
        tail = (idx + 1) % N;
        count = 0;
        for (int j = 0; j < N; j++) count += int'(live[j]);
        cov["mispredict"]++;
      end else if (ds_fire) begin
        live[tail]   = 1'b1;
        done[tail]   = ds_done;
        dsDone[tail] = ds_done;
        exc[tail]    = ds_exception;
        ref_[tail]   = 1'b0;
        word[tail]   = ds_payload;
        bornAt[tail] = t;
        badKnown[tail] = 1'b0;
        tail = (tail + 1) % N;
        count++;
      end
      if (wbIdx >= 0) begin
        done[wbIdx] = 1'b1;
        exc[wbIdx]  = wb_exception;
        ref_[wbIdx] = ref_[wbIdx] | wb_refetch;
        badAddr[wbIdx]  = wb_badAddress;
        badKnown[wbIdx] = 1'b1;
        if (wb_exception || wb_refetch) cov["wbMark"]++;
      end
      if (lqIdx >= 0) begin
        ref_[lqIdx] = 1'b1;
        cov["lqMark"]++;
      end
    end
    if (commit) cov["commits"]++;
  endtask

  task automatic runPhase(string name, int d, int dn, int wb, int ms, int lq, int ex, int cycles);
    pDispatch = d; pDone = dn; pWb = wb; pMis = ms; pLq = lq; pExc = ex;
    for (int i = 0; i < cycles; i++) step();
    $display("phase %-8s done", name);
  endtask

  int unsigned seed = 1;

  initial begin
    void'($value$plusargs("seed=%d", seed));
    void'($urandom(seed));
    errors = 0; checks = 0; t = 0;
    head = 0; tail = 0; count = 0;
    flushReg = 0; expValid = 0; expFlush = 0;
    for (int j = 0; j < N; j++) live[j] = 1'b0;
    repeat (3) @(negedge clk);
    resetn = 1'b1;
    //        name       disp done wb  mis lq  exc  cycles
    runPhase("sparse",   30,  10,  40, 10, 5,  5,   20000);
    runPhase("busy",     90,  10,  70, 20, 10, 5,   40000);
    runPhase("full",     95,  5,   15, 5,  5,  2,   20000);
    runPhase("kills",    80,  10,  50, 150, 30, 20, 20000);
    repeat (2) step();
    foreach (cov[k]) $display("  cov %-14s %0d", k, cov[k]);
    foreach (cov[k]) if (cov[k] == 0) begin $display("ERROR coverage hole %s", k); errors++; end
    if (cov.size() < 11) begin $display("ERROR coverage list short (%0d)", cov.size()); errors++; end
    if (errors == 0) $display("PASS  rob (%0d cycles)", checks);
    else             $fatal(1, "FAIL  rob (%0d errors)", errors);
    $finish;
  end

endmodule
