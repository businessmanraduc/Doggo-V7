// ================================================================================
//  ftq_tb -- pushes finished pairs in, walks them out one word per cycle, and
//  holds the queue to the word stream the predictor meant to describe.
// ================================================================================
module ftq_tb;
  localparam int DEPTH  = 16;
  localparam int MARGIN = 2;
  localparam int PHT_W  = 13;
  localparam int RAS_W  = 3;
  localparam int PTR_W  = 4;

  logic clk = 0;
  always #5 clk = ~clk;

  logic             resetn, flush;
  logic             push, push_validB;
  logic [31:2]      push_pcA, push_pcB;
  logic [1:0]       push_hwValidA, push_hwValidB;
  logic [PHT_W-1:0] push_gshareA, push_gshareB;
  logic [RAS_W-1:0] push_rasPtr;
  logic             canPush;
  logic             issueValid, issue;
  logic [31:2]      issuePC;
  logic [31:2]      headPC;
  logic [1:0]       headHwValid;
  logic [PHT_W-1:0] headGshare;
  logic [RAS_W-1:0] headRasPtr;
  logic             retire, replay;

  int errors = 0;

  ftq #(.DEPTH(DEPTH), .MARGIN(MARGIN), .PHT_INDEX_W(PHT_W), .RAS_PTR_W(RAS_W)) dut (
    .clk, .resetn, .flush,
    .push, .push_pcA, .push_pcB, .push_hwValidA, .push_hwValidB,
    .push_gshareA, .push_gshareB, .push_rasPtr, .push_validB, .canPush,
    .issueValid, .issuePC, .issue,
    .headPC, .headHwValid, .headGshare, .headRasPtr, .retire, .replay
  );

  initial begin
    #500000;
    $fatal(1, "FAIL  ftq: watchdog fired");
  end

  // ---- the queue must never take more than it can hold -------------------------
  always @(posedge clk) begin
    if (resetn && dut.count > (PTR_W+2)'(2*DEPTH))
      begin $error("invariant: count=%0d exceeds DEPTH", dut.count); errors++; end
    if (resetn && dut.unissued > dut.count)
      begin $error("invariant: unissued=%0d exceeds count=%0d",
                   dut.unissued, dut.count); errors++; end
  end

  // ---- pair n carries its own index in every field -----------------------------
  function automatic logic [31:2] pcAof (input int n); return 30'(32'h0000_1000 + n*8); endfunction
  function automatic logic [31:2] pcBof (input int n); return 30'(32'h0000_1004 + n*8); endfunction
  function automatic logic [PHT_W-1:0] gsAof (input int n); return PHT_W'(n);      endfunction
  function automatic logic [PHT_W-1:0] gsBof (input int n); return PHT_W'(n + 64); endfunction
  function automatic logic [RAS_W-1:0] rasOf (input int n); return RAS_W'(n);      endfunction

  task automatic doPush(input int n, input logic validB);
    push          = 1'b1;
    push_pcA      = pcAof(n);       push_pcB      = pcBof(n);
    push_hwValidA = 2'b11;          push_hwValidB = validB ? 2'b01 : 2'b00;
    push_gshareA  = gsAof(n);       push_gshareB  = gsBof(n);
    push_rasPtr   = rasOf(n);       push_validB   = validB;
    @(negedge clk);
    push = 1'b0;
  endtask

  task automatic step(input int cycles);
    repeat (cycles) @(negedge clk);
  endtask

  task automatic doReset();
    resetn = 1'b0; flush = 1'b0; push = 1'b0; issue = 1'b0;
    retire = 1'b0; replay = 1'b0; push_validB = 1'b0;
    push_pcA = '0; push_pcB = '0; push_hwValidA = '0; push_hwValidB = '0;
    push_gshareA = '0; push_gshareB = '0; push_rasPtr = '0;
    repeat (2) @(negedge clk);
    resetn = 1'b1;
    @(negedge clk);
  endtask

  // ---- take one word off the issue port ----------------------------------------
  task automatic takeIssue(input logic [31:2] wantPC, input string note);
    if (issueValid !== 1'b1) begin
      $error("%-38s issue port idle (expected %h)", note, {wantPC, 2'b00}); errors++;
    end else if (issuePC !== wantPC) begin
      $error("%-38s issuePC=%h (expected %h)",
             note, {issuePC, 2'b00}, {wantPC, 2'b00}); errors++;
    end
    issue = 1'b1;
    @(negedge clk);
    issue = 1'b0;
  endtask

  // ---- retire one word and check the metadata that rides with it ---------------
  task automatic takeRetire(input logic [31:2] wantPC, input logic [1:0] wantHw,
                            input logic [PHT_W-1:0] wantGs, input logic [RAS_W-1:0] wantRas,
                            input string note);
    if (headPC !== wantPC) begin
      $error("%-38s headPC=%h (expected %h)",
             note, {headPC, 2'b00}, {wantPC, 2'b00}); errors++;
    end else if (headHwValid !== wantHw) begin
      $error("%-38s hwValid=%b (expected %b)", note, headHwValid, wantHw); errors++;
    end else if (headGshare !== wantGs) begin
      $error("%-38s gshare=%h (expected %h)", note, headGshare, wantGs); errors++;
    end else if (headRasPtr !== wantRas) begin
      $error("%-38s rasPtr=%0d (expected %0d)", note, headRasPtr, wantRas); errors++;
    end
    retire = 1'b1;
    @(negedge clk);
    retire = 1'b0;
  endtask

  // ---- A - a full pair goes in and comes out as two words ----------------------
  task automatic checkPairInOrder();
    doReset();
    doPush(0, 1'b1);
    step(1);
    takeIssue(pcAof(0), "A: issue word A");
    takeIssue(pcBof(0), "A: issue word B");
    if (issueValid !== 1'b0) begin
      $error("A: issue port still valid after both words"); errors++;
    end
    takeRetire(pcAof(0), 2'b11, gsAof(0), rasOf(0), "A: retire word A");
    takeRetire(pcBof(0), 2'b01, gsBof(0), rasOf(0), "A: retire word B");
  endtask

  // ---- B - a suppressed B is stepped over on both ports, costing no cycle ------
  task automatic checkSuppressedBSkipped();
    doReset();
    doPush(0, 1'b0);              // A was a taken branch, B is wrong-path
    doPush(1, 1'b1);
    step(1);
    takeIssue(pcAof(0), "B: issue pair 0 word A");
    takeIssue(pcAof(1), "B: hole skipped, straight to pair 1");
    takeIssue(pcBof(1), "B: issue pair 1 word B");
    takeRetire(pcAof(0), 2'b11, gsAof(0), rasOf(0), "B: retire pair 0 word A");
    takeRetire(pcAof(1), 2'b11, gsAof(1), rasOf(1), "B: retire skips the hole");
    takeRetire(pcBof(1), 2'b01, gsBof(1), rasOf(1), "B: retire pair 1 word B");
    //  A hole must not be counted as a word, or the counters leak upward and the
    //  queue never reports empty again.
    if (issueValid !== 1'b0) begin
      $error("B: issue port still valid after draining every word"); errors++;
    end
    if (dut.count !== '0) begin
      $error("B: count=%0d after draining, the hole leaked", dut.count); errors++;
    end
    if (dut.unissued !== '0) begin
      $error("B: unissued=%0d after draining, the hole leaked", dut.unissued); errors++;
    end
  endtask

  // ---- C - a miss rewinds the issue pointer to the word that missed ------------
  task automatic checkReplayRewinds();
    doReset();
    doPush(0, 1'b1);
    doPush(1, 1'b1);
    step(1);
    takeIssue(pcAof(0), "C: issue A0");
    takeIssue(pcBof(0), "C: issue B0");
    takeIssue(pcAof(1), "C: issue A1");
    replay = 1'b1;                 // A0 missed in the cache
    @(negedge clk);
    replay = 1'b0;
    takeIssue(pcAof(0), "C: re-issues the word that missed");
    takeIssue(pcBof(0), "C: and the ones behind it");
    takeIssue(pcAof(1), "C: in the same order");
  endtask

  // ---- D - a replay from mid-pair comes back to the right half -----------------
  task automatic checkReplayMidPair();
    doReset();
    doPush(0, 1'b1);
    doPush(1, 1'b1);
    step(1);
    takeIssue(pcAof(0), "D: issue A0");
    takeRetire(pcAof(0), 2'b11, gsAof(0), rasOf(0), "D: retire A0");
    takeIssue(pcBof(0), "D: issue B0");
    takeIssue(pcAof(1), "D: issue A1");
    replay = 1'b1;                 // now B0 is the oldest, and it missed
    @(negedge clk);
    replay = 1'b0;
    takeIssue(pcBof(0), "D: re-issues from the B half");
  endtask

  // ---- E - flush empties every pointer -----------------------------------------
  task automatic checkFlush();
    doReset();
    doPush(0, 1'b1);
    doPush(1, 1'b1);
    step(1);
    takeIssue(pcAof(0), "E: issue before the flush");
    flush = 1'b1;
    @(negedge clk);
    flush = 1'b0;
    if (issueValid !== 1'b0) begin
      $error("E: queue still offering a word after a flush"); errors++;
    end
    doPush(5, 1'b1);
    step(1);
    takeIssue(pcAof(5), "E: first word after the flush");
  endtask

  // ---- F - the credit stops the predictor before the queue overflows -----------
  task automatic checkCredit();
    int pushed;
    doReset();
    pushed = 0;
    while (canPush && pushed < DEPTH + 4) begin
      doPush(pushed, 1'b1);
      pushed++;
    end
    if (pushed >= DEPTH + 4) begin
      $error("F: credit never dropped after %0d pushes", pushed); errors++;
    end
    if (dut.count > (PTR_W+2)'(2*DEPTH)) begin
      $error("F: overflowed to count=%0d", dut.count); errors++;
    end
    // draining one pair must hand the credit back
    takeIssue(pcAof(0), "F: drain issue A");
    takeIssue(pcBof(0), "F: drain issue B");
    takeRetire(pcAof(0), 2'b11, gsAof(0), rasOf(0), "F: drain retire A");
    takeRetire(pcBof(0), 2'b01, gsBof(0), rasOf(0), "F: drain retire B");
    if (canPush !== 1'b1) begin
      $error("F: credit not returned after a pair retired"); errors++;
    end
  endtask

  // ---- G - order survives a wrap around the end of the memory ------------------
  //  Push while there is credit, drain a whole pair when there is not. Tracking
  //  the two indices separately keeps this honest whatever the credit threshold
  //  happens to be.
  task automatic checkWrap();
    int nextPush, nextDrain, drains;
    doReset();
    nextPush = 0; nextDrain = 0; drains = 0;
    while (nextPush < DEPTH + 6) begin
      if (canPush) begin
        doPush(nextPush, 1'b1);
        nextPush++;
      end else begin
        takeIssue (pcAof(nextDrain), $sformatf("G: issue A%0d",  nextDrain));
        takeIssue (pcBof(nextDrain), $sformatf("G: issue B%0d",  nextDrain));
        takeRetire(pcAof(nextDrain), 2'b11, gsAof(nextDrain), rasOf(nextDrain),
                   $sformatf("G: retire A%0d", nextDrain));
        takeRetire(pcBof(nextDrain), 2'b01, gsBof(nextDrain), rasOf(nextDrain),
                   $sformatf("G: retire B%0d", nextDrain));
        nextDrain++;
        drains++;
      end
    end
    if (drains == 0) begin
      $error("G: never filled the queue, the wrap was not exercised"); errors++;
    end
  endtask

  initial begin
    checkPairInOrder();
    checkSuppressedBSkipped();
    checkReplayRewinds();
    checkReplayMidPair();
    checkFlush();
    checkCredit();
    checkWrap();

    if (errors == 0) $display("PASS  ftq");
    else             $fatal(1, "FAIL  ftq (%0d errors)", errors);
    $finish;
  end

endmodule
