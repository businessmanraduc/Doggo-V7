// ================================================================================
//  bpredict_tb -- stands in for the fetch engine: takes every address the FTQ
//  offers, retires it four cycles later, and holds the predictor to the exact
//  word stream it should have produced.
//
//  The stream is read off the ISSUE port, so anything the predictor decided not
//  to write never appears at all. There are no dead words to skip over.
// ================================================================================
module bpredict_tb;
  localparam int          BTB_INDEX_W = 9;
  localparam int          PHT_INDEX_W = 13;
  localparam int          TAG_W       = 11;
  localparam int          RAS_PTR_W   = 3;
  localparam int          BHR_W       = 24;
  localparam logic [31:0] RESET_PC    = 32'h0000_0800;

  logic clk = 0;
  always #5 clk = ~clk;

  logic                   resetn;
  logic                   redirectValid;
  logic [31:0]            redirectPC;
  logic [BHR_W-1:0]       redirectBHR;
  logic [RAS_PTR_W-1:0]   redirectRasPtr;
  logic                   btbWrEnable, btbWrBank;
  logic [BTB_INDEX_W-1:0] btbWrIndex;
  logic [53:0]            btbWrEntry;
  logic                   phtWrEnable;
  logic [PHT_INDEX_W-1:0] phtWrIndex;
  logic [1:0]             phtWrCounter;
  logic                   issueValid, issue;
  logic [31:2]            issuePC;
  logic [31:2]            headPC;
  logic [1:0]             headHwValid;
  logic [PHT_INDEX_W-1:0] headGshare;
  logic [RAS_PTR_W-1:0]   headRasPtr;
  logic                   retire, replay;

  int errors = 0;

  bpredict #(
    .BTB_INDEX_W(BTB_INDEX_W), .PHT_INDEX_W(PHT_INDEX_W), .TAG_W(TAG_W),
    .BHR_W(BHR_W), .RAS_PTR_W(RAS_PTR_W), .RESET_PC(RESET_PC)
  ) dut (
    .clk, .resetn,
    .redirectValid, .redirectPC, .redirectBHR, .redirectRasPtr,
    .btbWrEnable, .btbWrBank, .btbWrIndex, .btbWrEntry,
    .phtWrEnable, .phtWrIndex, .phtWrCounter,
    .issueValid, .issuePC, .issue,
    .headPC, .headHwValid, .headGshare, .headRasPtr, .retire, .replay
  );

  initial begin
    #2000000;
    $fatal(1, "FAIL  bpredict: watchdog fired");
  end

  // ---- the fetch engine we pretend to be ---------------------------------------
  //  Take every address offered, and retire it four cycles later the way the cache
  //  would. holdIssue lets a test stop taking, so the queue backs up into P0.
  logic       holdIssue;
  logic [3:0] flight;
  assign issue = issueValid && !holdIssue;

  always_ff @(posedge clk) begin
    if (!resetn || redirectValid || replay) flight <= '0;
    else                                    flight <= {flight[2:0], issue};
  end
  assign retire = flight[3];

  // ---- recorded issue stream ---------------------------------------------------
  logic [31:2]            recPC [0:255];
  logic [PHT_INDEX_W-1:0] recGs [0:255];
  int                     recCount;

  always_ff @(posedge clk) begin
    if (issue && recCount < 256) begin
      recPC[recCount] <= issuePC;
      recCount        <= recCount + 1;
    end
  end

  // ---- retired metadata, which is what the backend would see -------------------
  logic [31:2]            retPC [0:255];
  logic [1:0]             retHw [0:255];
  logic [PHT_INDEX_W-1:0] retGs [0:255];
  logic [RAS_PTR_W-1:0]   retRp [0:255];
  int                     retCount;

  always_ff @(posedge clk) begin
    if (retire && retCount < 256) begin
      retPC[retCount] <= headPC;
      retHw[retCount] <= headHwValid;
      retGs[retCount] <= headGshare;
      retRp[retCount] <= headRasPtr;
      retCount        <= retCount + 1;
    end
  end

  // ---- BTB entry, packed the way btb.sv slices it ------------------------------
  function automatic logic [53:0] packEntry(
    input logic v, br, cond, strd, exitLow, call, ret,
    input logic [TAG_W-1:0] tag, input logic [30:0] tgt);
    logic [53:0] e;
    e = '0;
    e[53] = v; e[52] = br; e[51] = cond; e[50] = strd; e[49] = exitLow;
    e[45] = v && br &&  cond;
    e[44] = v && br && !cond;
    e[43] = ret; e[42] = call;
    e[31 +: TAG_W] = tag; e[30:0] = tgt;
    return e;
  endfunction

  task automatic installEntry(input logic [31:0] word, input logic [53:0] e);
    @(negedge clk);
    btbWrEnable = 1'b1;
    btbWrBank   = word[2];
    btbWrIndex  = word[11:3];
    btbWrEntry  = e;
    @(negedge clk);
    btbWrEnable = 1'b0;
  endtask

  //  Unconditional by default, so the PHT stays out of the way unless a test
  //  deliberately brings it in.
  task automatic installBranch(input logic [31:0] word, input logic [31:0] tgt,
                               input logic strd = 1'b0, input logic exitLow = 1'b0,
                               input logic call = 1'b0, input logic ret = 1'b0);
    installEntry(word, packEntry(1'b1, 1'b1, 1'b0, strd, exitLow, call, ret,
                                 word[22:12], tgt[31:1]));
  endtask

  task automatic installConditional(input logic [31:0] word, input logic [31:0] tgt);
    installEntry(word, packEntry(1'b1, 1'b1, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0,
                                 word[22:12], tgt[31:1]));
  endtask

  task automatic writeCounter(input logic [PHT_INDEX_W-1:0] idx, input logic [1:0] c);
    @(negedge clk);
    phtWrEnable = 1'b1; phtWrIndex = idx; phtWrCounter = c;
    @(negedge clk);
    phtWrEnable = 1'b0;
  endtask

  task automatic step(input int cycles);
    repeat (cycles) @(negedge clk);
  endtask

  // ---- restart the predictor somewhere and record what it fetches --------------
  task automatic runFrom(input logic [31:0] start, input int cycles);
    @(negedge clk);
    redirectValid = 1'b1; redirectPC = start;
    @(negedge clk);
    redirectValid = 1'b0;
    recCount = 0; retCount = 0;
    step(cycles);
  endtask

  //  Redirect only after the predictor has been running, so there really are
  //  wrong-path pairs in flight for the shadow to have to swallow.
  task automatic runAfterTraffic(input logic [31:0] warm, input logic [31:0] start,
                                 input int cycles);
    @(negedge clk);
    redirectValid = 1'b1; redirectPC = warm;
    @(negedge clk);
    redirectValid = 1'b0;
    step(12);
    @(negedge clk);
    redirectValid = 1'b1; redirectPC = start;
    @(negedge clk);
    redirectValid = 1'b0;
    recCount = 0; retCount = 0;
    step(cycles);
  endtask

  //  Same as runFrom, but seeds the speculative history so a shifted-in ZERO is
  //  distinguishable from no shift at all.
  task automatic runFromWithBHR(input logic [31:0] start,
                                input logic [BHR_W-1:0] bhr, input int cycles);
    @(negedge clk);
    redirectValid = 1'b1; redirectPC = start; redirectBHR = bhr;
    @(negedge clk);
    redirectValid = 1'b0;
    recCount = 0; retCount = 0;
    step(cycles);
    redirectBHR = '0;
  endtask

  // ---- model of the group history ----------------------------------------------
  //  One bit per issued pair. The bit is a hash of that pair's own address, XORed
  //  with whether the pair contained a predicted-taken branch.
  function automatic logic pcHashOf(input logic [31:0] pc);
    return pc[3] ^ pc[6] ^ pc[10] ^ pc[14];
  endfunction

  function automatic logic [PHT_INDEX_W-1:0] foldOf(input logic [BHR_W-1:0] h);
    return h[PHT_INDEX_W-1:0] ^ PHT_INDEX_W'(h[BHR_W-1:PHT_INDEX_W]);
  endfunction

  function automatic logic [BHR_W-1:0] shiftIn(input logic [BHR_W-1:0] h,
                                               input logic [31:0] groupPC,
                                               input logic taken);
    return {h[BHR_W-2:0], taken ^ pcHashOf(groupPC)};
  endfunction

  //  History as seen by the pair that starts at base + k*8, walking straight line.
  function automatic logic [BHR_W-1:0] historyAtGroup(input logic [BHR_W-1:0] seed,
                                                      input logic [31:0] base,
                                                      input int k);
    logic [BHR_W-1:0] h;
    h = seed;
    for (int g = 0; g < k; g++) h = shiftIn(h, base + 32'(g)*8, 1'b0);
    return h;
  endfunction

  function automatic int findRetired(input logic [31:0] pc);
    for (int i = 0; i < retCount; i++)
      if (retPC[i] === pc[31:2]) return i;
    return -1;
  endfunction

  function automatic int findPC(input logic [31:0] pc);
    for (int i = 0; i < recCount; i++)
      if (recPC[i] === pc[31:2]) return i;
    return -1;
  endfunction

  task automatic expectAt(input int idx, input logic [31:0] pc, input string note);
    if (idx >= recCount) begin
      $error("%-40s only %0d words issued, wanted index %0d", note, recCount, idx);
      errors++;
    end else if (recPC[idx] !== pc[31:2]) begin
      $error("%-40s slot %0d is %h (expected %h)",
             note, idx, {recPC[idx], 2'b00}, {pc[31:2], 2'b00}); errors++;
    end
  endtask

  task automatic expectAbsent(input logic [31:0] pc, input string note);
    if (findPC(pc) >= 0) begin
      $error("%-40s %h reached the fetch engine", note, pc); errors++;
    end
  endtask

  // ================================================================================
  //  A - straight-line pairs come out in order, two words per cycle of prediction
  // ================================================================================
  task automatic checkSequential();
    runFrom(32'h0001_0000, 24);
    for (int k = 0; k < 8; k++)
      expectAt(k, 32'h0001_0000 + 32'(k)*4, $sformatf("A: sequential word %0d", k));
  endtask

  // ================================================================================
  //  B - THE ACCEPTANCE TEST: nothing is blind after a redirect
  // ================================================================================
  //  The glued predictor looked up nextPC+4 and never saw the redirect target at
  //  all, so a branch in the first two words after any redirect could not be
  //  predicted. Every position must be visible now.
  task automatic checkBlindSpot();
    logic [31:0] base, brWord, tgt;
    for (int k = 0; k < 6; k++) begin
      base   = 32'h0002_0000 + 32'(k) * 32'h0000_1000;
      brWord = base + 32'(k) * 4;
      tgt    = 32'h000E_0000 + 32'(k) * 32'h0000_0100;
      installBranch(brWord, tgt);
      runFrom(base, 40);
      if (findPC(tgt) < 0) begin
        $error("B: branch %0d word(s) after a redirect was never predicted", k);
        errors++;
      end
    end
  endtask

  // ================================================================================
  //  C - the shadow is exactly as deep as the pipeline
  // ================================================================================
  //  Too shallow and a wrong-path pair from before the redirect gets written, so
  //  the stream does not start at the target. Too deep and the target's own pair
  //  is thrown away, so the stream starts late. Both show up right here.
  task automatic checkShadowDepth();
    runAfterTraffic(32'h0003_0000, 32'h0004_0000, 24);
    expectAt(0, 32'h0004_0000, "C: stream starts exactly at the target");
    expectAt(1, 32'h0004_0004, "C: and continues from there");
    expectAt(2, 32'h0004_0008, "C: with nothing dropped");
    expectAbsent(32'h0003_0000, "C: pre-redirect word");
    expectAbsent(32'h0003_0020, "C: pre-redirect word");
  endtask

  // ================================================================================
  //  D - a taken branch in slot A drops its partner, and nothing behind it fetches
  // ================================================================================
  task automatic checkTakenInSlotA();
    int i;
    installBranch(32'h0005_0010, 32'h0005_2000);   // even word, so it lands in slot A
    runFrom(32'h0005_0000, 32);
    i = findPC(32'h0005_0010);
    if (i < 0) begin
      $error("D: never reached the branch"); errors++;
      return;
    end
    expectAt(i + 1, 32'h0005_2000, "D: target follows the branch immediately");
    expectAbsent(32'h0005_0014, "D: slot B of the branch pair");
    expectAbsent(32'h0005_0018, "D: the pair behind the branch");
  endtask

  // ================================================================================
  //  E - a taken branch in slot B keeps slot A, then redirects
  // ================================================================================
  task automatic checkTakenInSlotB();
    int i;
    installBranch(32'h0006_0014, 32'h0006_3000);   // odd word, so it lands in slot B
    runFrom(32'h0006_0000, 32);
    i = findPC(32'h0006_0010);
    if (i < 0) begin
      $error("E: never reached the pair holding the branch"); errors++;
      return;
    end
    expectAt(i + 1, 32'h0006_0014, "E: slot B is fetched");
    expectAt(i + 2, 32'h0006_3000, "E: then the target");
    expectAbsent(32'h0006_0018, "E: the pair behind the branch");
  endtask

  // ================================================================================
  //  F - a straddling branch keeps its tail
  // ================================================================================
  //  In slot A the tail is slot B of the same pair, so B stays live and the
  //  redirect lands on the pair after it.
  task automatic checkStraddleInSlotA();
    int i;
    installBranch(32'h0007_0010, 32'h0007_4000, 1'b1);
    runFrom(32'h0007_0000, 32);
    i = findPC(32'h0007_0010);
    if (i < 0) begin
      $error("F: never reached the straddling branch"); errors++;
      return;
    end
    expectAt(i + 1, 32'h0007_0014, "F: the tail half is still fetched");
    expectAt(i + 2, 32'h0007_4000, "F: then the target");
    expectAbsent(32'h0007_0018, "F: the pair behind the straddle");
  endtask

  //  A straddle in slot B is deliberately NOT predicted: its tail lands in the
  //  next pair and the hand-off would invalidate that pair. It must fall through
  //  as if the entry were not there, rather than redirect early and lose the tail.
  task automatic checkStraddleInSlotBFallsThrough();
    int i;
    installBranch(32'h0008_0014, 32'h0008_5000, 1'b1);
    runFrom(32'h0008_0000, 32);
    i = findPC(32'h0008_0014);
    if (i < 0) begin
      $error("G: never reached the straddling branch"); errors++;
      return;
    end
    expectAt(i + 1, 32'h0008_0018, "G: falls through to the tail");
    expectAt(i + 2, 32'h0008_001c, "G: and keeps going");
    expectAbsent(32'h0008_5000, "G: B-slot straddle target");
  endtask

  // ================================================================================
  //  H - a call pushes, a return pops back to the instruction after the call
  // ================================================================================
  task automatic checkCallReturn();
    int i;
    //  Index is PC[11:3], so the call and the return have to differ in those bits
    //  or the second install silently overwrites the first.
    installBranch(32'h0009_0010, 32'h0009_0400, 1'b0, 1'b0, 1'b1, 1'b0);
    installBranch(32'h0009_0430, 32'h0000_0000, 1'b0, 1'b0, 1'b0, 1'b1);
    runFrom(32'h0009_0000, 64);
    i = findPC(32'h0009_0430);
    if (i < 0) begin
      $error("H: never reached the callee's return"); errors++;
      return;
    end
    expectAt(i + 1, 32'h0009_0014, "H: return pops the address after the call");
  endtask

  //  A call in slot B returns to the word after IT, not after slot A.
  task automatic checkCallReturnSlotB();
    int i;
    installBranch(32'h000A_0014, 32'h000A_0400, 1'b0, 1'b0, 1'b1, 1'b0);
    installBranch(32'h000A_0430, 32'h0000_0000, 1'b0, 1'b0, 1'b0, 1'b1);
    runFrom(32'h000A_0000, 64);
    i = findPC(32'h000A_0430);
    if (i < 0) begin
      $error("I: never reached the callee's return"); errors++;
      return;
    end
    expectAt(i + 1, 32'h000A_0018, "I: return pops past the B-slot call");
  endtask

  // ================================================================================
  //  J - a conditional branch obeys the counter, in either slot
  // ================================================================================
  task automatic checkConditional();
    logic [PHT_INDEX_W-1:0] idx;
    installConditional(32'h000B_0010, 32'h000B_6000);
    //  The history is no longer zero after a redirect: it shifts a path-hash bit
    //  per issued pair, so the index has to come from the model.
    idx = PHT_INDEX_W'(32'h000B_0010 >> 2)
        ^ foldOf(historyAtGroup(24'h0, 32'h000B_0000, 2));
    writeCounter(idx, 2'b00);                // strongly not taken
    runFrom(32'h000B_0000, 32);
    expectAbsent(32'h000B_6000, "J: not-taken counter does not redirect");
    writeCounter(idx, 2'b11);                // strongly taken
    runFrom(32'h000B_0000, 32);
    if (findPC(32'h000B_6000) < 0) begin
      $error("J: taken counter did not redirect"); errors++;
    end
  endtask

  // ================================================================================
  //  K - the metadata that rides with a retired word
  // ================================================================================
  task automatic checkRetiredMetadata();
    runFrom(32'h000C_0000, 32);
    if (retCount < 4) begin
      $error("K: only %0d words retired", retCount); errors++;
      return;
    end
    for (int k = 0; k < 4; k++) begin
      if (retPC[k] !== 30'((32'h000C_0000 + 32'(k)*4) >> 2)) begin
        $error("K: retired word %0d is %h (expected %h)",
               k, {retPC[k], 2'b00}, 32'h000C_0000 + 32'(k)*4); errors++;
      end else if (retGs[k] !== (retPC[k][PHT_INDEX_W+1:2] ^
                                 foldOf(historyAtGroup(24'h0, 32'h000C_0000, k/2)))) begin
        $error("K: retired word %0d gshare=%h (expected %h)",
               k, retGs[k], retPC[k][PHT_INDEX_W+1:2] ^
               foldOf(historyAtGroup(24'h0, 32'h000C_0000, k/2))); errors++;
      end else if (retHw[k] !== 2'b11) begin
        $error("K: retired word %0d hwValid=%b (expected 11)", k, retHw[k]); errors++;
      end
    end
  endtask

  // ================================================================================
  //  L - the queue backing up parks the predictor instead of overflowing
  // ================================================================================
  task automatic checkQueueBackPressure();
    runFrom(32'h000D_0000, 4);
    holdIssue = 1'b1;
    step(40);                                  // far longer than the queue is deep
    if (dut.u_ftq.count > $bits(dut.u_ftq.count)'(2*32)) begin
      $error("L: FTQ overflowed to count=%0d", dut.u_ftq.count); errors++;
    end
    holdIssue = 1'b0;
    step(40);
    for (int k = 0; k < 8; k++)
      expectAt(k, 32'h000D_0000 + 32'(k)*4, $sformatf("L: word %0d after the park", k));
  endtask

  // ================================================================================
  //  M - one bit per ISSUED PAIR, and the bit carries the group's address hash
  // ================================================================================
  //  Walks straight line from a seeded history and holds every word's published
  //  index to the model. Pins the shift rate, the path hash and the 24->13 fold
  //  all at once; any of the three going wrong shows up here.
  task automatic checkGroupHistoryStream();
    logic [31:0] base;
    logic [BHR_W-1:0] seed, want;
    int i;
    base = 32'h000E_0000;
    seed = 24'h5A3C7;
    runFromWithBHR(base, seed, 64);
    for (int k = 0; k < 6; k++) begin
      want = historyAtGroup(seed, base, k);
      for (int half = 0; half < 2; half++) begin
        logic [31:0] w;
        w = base + 32'(k)*8 + 32'(half)*4;
        i = findRetired(w);
        if (i < 0) begin
          $error("M: never retired word %h", w); errors++;
        end else if (retGs[i] !== (PHT_INDEX_W'(w >> 2) ^ foldOf(want))) begin
          $error("M: word %h gshare=%h (expected %h, history %h at group %0d)",
                 w, retGs[i], PHT_INDEX_W'(w >> 2) ^ foldOf(want), want, k);
          errors++;
        end
      end
    end
  endtask

  // ================================================================================
  //  M2 - ZERO STALENESS: a taken pair's own bit is in the very next group's index
  // ================================================================================
  //  The provisional bit for the branch's group is a zero. When the branch turns
  //  out taken the redirect repairs it to a one, and the group at the target must
  //  already index with the repaired history. If the repair were late, or carried
  //  the wrong checkpoint, the target's index would be wrong here.
  task automatic checkZeroStaleness();
    logic [31:0] base, brWord, tgt;
    logic [BHR_W-1:0] seed, atBranch, repaired;
    int i;
    base   = 32'h0013_0000;
    brWord = base + 32'h10;          // group 2, slot A
    tgt    = 32'h0013_8000;
    seed   = 24'h1234A;

    installBranch(brWord, tgt);
    atBranch = historyAtGroup(seed, base, 2);
    repaired = shiftIn(atBranch, brWord, 1'b1);

    runFromWithBHR(base, seed, 64);
    i = findRetired(tgt);
    if (i < 0) begin
      $error("M2: never retired the branch target"); errors++;
      return;
    end
    if (retGs[i] !== (PHT_INDEX_W'(tgt >> 2) ^ foldOf(repaired))) begin
      $error("M2: target gshare=%h (expected %h, repaired history %h)",
             retGs[i], PHT_INDEX_W'(tgt >> 2) ^ foldOf(repaired), repaired);
      errors++;
    end
  endtask

  // ================================================================================
  //  N - a redirect reloads the speculative history from the backend's true copy
  // ================================================================================
  task automatic checkBhrRestore();
    logic [31:0] base, w;
    logic [BHR_W-1:0] seed;
    int i;
    base = 32'h000F_0000;
    w    = base + 32'h20;
    seed = 24'h155501;
    runFromWithBHR(base, seed, 48);
    i = findRetired(w);
    if (i < 0) begin
      $error("N: never retired the sampled word"); errors++;
      return;
    end
    if (retGs[i] !== (PHT_INDEX_W'(w >> 2) ^ foldOf(historyAtGroup(seed, base, 4)))) begin
      $error("N: gshare=%h (expected %h, restored seed %h)",
             retGs[i], PHT_INDEX_W'(w >> 2) ^ foldOf(historyAtGroup(seed, base, 4)),
             seed); errors++;
    end
  endtask

  // ================================================================================
  //  O - a not-taken branch is INVISIBLE to the history
  // ================================================================================
  //  A pair holding a not-taken branch looks exactly like a pair holding no branch
  //  at all. That costs nothing: both mean "we continued to the next sequential
  //  group", so there is no path to tell apart. The OUTCOME is still visible --
  //  the same group taken shifts ~pcHash instead of pcHash, and the groups after
  //  it are the target's rather than the sequential ones.
  //
  //  What the scheme really gives up is two conditional branches in ONE pair
  //  collapsing to one bit. Anything later that assumes per-branch direction bits
  //  has to change here.
  task automatic checkNotTakenIsInvisible();
    logic [31:0] base, brWord, later;
    logic [BHR_W-1:0] seed, want;
    int i;
    base   = 32'h0010_0000;
    brWord = base + 32'h10;
    later  = base + 32'h40;
    seed   = 24'h0AAA55;
    installConditional(brWord, 32'h0010_9000);   // counter defaults to not-taken
    runFromWithBHR(base, seed, 64);
    want = historyAtGroup(seed, base, 8);        // 0x40 / 8
    i = findRetired(later);
    if (i < 0) begin
      $error("O: never retired the word after the branch"); errors++;
      return;
    end
    if (retGs[i] !== (PHT_INDEX_W'(later >> 2) ^ foldOf(want))) begin
      $error("O: gshare=%h (expected %h) -- a not-taken branch moved the history",
             retGs[i], PHT_INDEX_W'(later >> 2) ^ foldOf(want)); errors++;
    end
  endtask

  // ================================================================================
  //  P - the history holds while the queue backs up
  // ================================================================================
  //  The shift is per ISSUED pair, so a throttle must delay a group, never skip
  //  one. That is what makes the history path-determined instead of timing-
  //  determined, and it is the whole reason this scheme is worth having.
  task automatic checkBhrAcrossPark();
    logic [31:0] base, later;
    logic [BHR_W-1:0] seed, want;
    int i;
    base = 32'h0011_0000; later = base + 32'h30;
    seed = 24'h123456;
    runFromWithBHR(base, seed, 4);
    holdIssue = 1'b1;
    step(30);
    holdIssue = 1'b0;
    step(60);
    want = historyAtGroup(seed, base, 6);
    i = findRetired(later);
    if (i < 0) begin
      $error("P: never retired the sampled word after the park"); errors++;
      return;
    end
    if (retGs[i] !== (PHT_INDEX_W'(later >> 2) ^ foldOf(want))) begin
      $error("P: gshare=%h after a park (expected %h) -- the park moved history",
             retGs[i], PHT_INDEX_W'(later >> 2) ^ foldOf(want)); errors++;
    end
  endtask

  // ================================================================================
  //  Q - both slots of a pair index with the SAME history
  // ================================================================================
  task automatic checkGshareSharedAcrossPair();
    logic [31:0] base, wA, wB;
    logic [BHR_W-1:0] seed, want;
    int ia, ib;
    base = 32'h0012_0000; wA = base + 32'h20; wB = wA + 32'd4;
    seed = 24'h055501;
    runFromWithBHR(base, seed, 48);
    want = historyAtGroup(seed, base, 4);
    ia = findRetired(wA);
    ib = findRetired(wB);
    if (ia < 0 || ib < 0) begin
      $error("Q: never retired both halves of the pair"); errors++;
      return;
    end
    if (retGs[ia] !== (PHT_INDEX_W'(wA >> 2) ^ foldOf(want))) begin
      $error("Q: slot A gshare=%h (expected %h)",
             retGs[ia], PHT_INDEX_W'(wA >> 2) ^ foldOf(want)); errors++;
    end
    if (retGs[ib] !== (PHT_INDEX_W'(wB >> 2) ^ foldOf(want))) begin
      $error("Q: slot B gshare=%h (expected %h, same history as slot A)",
             retGs[ib], PHT_INDEX_W'(wB >> 2) ^ foldOf(want)); errors++;
    end
  endtask

  // ================================================================================
  //  R - a redirect to a halfword address publishes the first word as high-half
  //  only. Every other test redirects to a word address, so startHi stays zero
  //  and its delay chain is never exercised.
  // ================================================================================
  task automatic checkMisalignedEntry();
    runFrom(32'h000C_0002, 20);
    if (retCount < 2) begin
      $error("R: only %0d words retired", retCount); errors++;
      return;
    end
    if (retHw[0] !== 2'b10) begin
      $error("R: first word hwValid=%b (expected 10, entered at the high half)",
             retHw[0]); errors++;
    end
    if (retHw[1] !== 2'b11) begin
      $error("R: second word hwValid=%b (expected 11)", retHw[1]); errors++;
    end
  endtask


  initial begin
    resetn = 1'b0; redirectValid = 1'b0; redirectPC = '0;
    redirectBHR = '0; redirectRasPtr = '0;
    btbWrEnable = 1'b0; btbWrBank = 1'b0; btbWrIndex = '0; btbWrEntry = '0;
    phtWrEnable = 1'b0; phtWrIndex = '0; phtWrCounter = '0;
    holdIssue = 1'b0; replay = 1'b0;
    recCount = 0; retCount = 0;
    repeat (3) @(negedge clk);
    resetn = 1'b1;
    step(8);

    checkSequential();
    checkBlindSpot();
    checkShadowDepth();
    checkTakenInSlotA();
    checkTakenInSlotB();
    checkStraddleInSlotA();
    checkStraddleInSlotBFallsThrough();
    checkCallReturn();
    checkCallReturnSlotB();
    checkConditional();
    checkRetiredMetadata();
    checkQueueBackPressure();
    checkBhrRestore();
    checkGroupHistoryStream();
    checkZeroStaleness();
    checkNotTakenIsInvisible();
    checkBhrAcrossPark();
    checkGshareSharedAcrossPair();
    checkMisalignedEntry();

    if (errors == 0) $display("PASS  bpredict");
    else             $fatal(1, "FAIL  bpredict (%0d errors)", errors);
    $finish;
  end

endmodule
