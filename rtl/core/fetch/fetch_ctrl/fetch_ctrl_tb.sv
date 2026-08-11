// ================================================================================
//  fetch_ctrl_tb -- models the pipeline around the control block rather than
//  hand-counting it: one present() call is one F0 cycle, and the harness delivers
//  that word's metadata at F2 and its cache verdict at F4 by itself. A word is
//  only consumed when the block actually issues a lookup, so parks need no
//  special handling.
// ================================================================================
module fetch_ctrl_tb;
  localparam int PHT_W = 13;
  localparam logic MISS = 1'b0, HIT = 1'b1;

  logic clk = 0;
  always #5 clk = ~clk;

  logic              resetn;
  logic [31:2]       fetchPC;
  logic [1:0]        fetchHwValid;
  logic [PHT_W-1:0]  fetchGshare;
  logic [2:0]        fetchRasPtr;
  logic              hit, fillBusy, canFetch, backendRedirect;
  logic              boot, stall, lookupValid, lookupKill, replayValid;
  logic [31:0]       replayPC;
  logic [PHT_W-1:0]  replayBHR;
  logic [2:0]        replayRasPtr;
  logic              pushValid;
  logic [31:2]       pushPC;
  logic [1:0]        pushHwValid;
  logic [PHT_W-1:0]  pushGshare;
  logic [2:0]        pushRasPtr;

  int errors = 0;

  fetch_ctrl #(.PHT_INDEX_W(PHT_W)) dut (
    .clk, .resetn,
    .fetchPC, .fetchHwValid, .fetchGshare, .fetchRasPtr,
    .hit, .fillBusy, .canFetch, .backendRedirect,
    .boot, .stall, .lookupValid, .lookupKill,
    .replayValid, .replayPC, .replayBHR, .replayRasPtr,
    .pushValid, .pushPC, .pushHwValid, .pushGshare, .pushRasPtr
  );

  initial begin
    #200000;
    $fatal(1, "FAIL  fetch_ctrl: watchdog fired");
  end

  task automatic fail(input string note);
    $error("%s", note); errors++;
  endtask

  // ---- the word offered at F0 this cycle ---------------------------------------
  logic [31:0]      curPC;
  logic [1:0]       curHw;
  logic [PHT_W-1:0] curGs;
  logic [2:0]       curRp;
  logic             curHit;

  // metadata lands two cycles behind its lookup, the cache verdict four
  logic [31:2]      pcF1;
  logic [1:0]       hwF1;
  logic [PHT_W-1:0] gsF1;
  logic [2:0]       rpF1;
  logic hitF1, hitF2, hitF3;
  always_ff @(posedge clk) begin
    if (lookupValid) begin
      pcF1  <= curPC[31:2];
      hwF1  <= curHw;
      gsF1  <= curGs;
      rpF1  <= curRp;
      hitF1 <= curHit;
    end
    fetchPC      <= pcF1;
    fetchHwValid <= hwF1;
    fetchGshare  <= gsF1;
    fetchRasPtr  <= rpF1;
    hitF2 <= hitF1;
    hitF3 <= hitF2;
    hit   <= hitF3;
  end

  // ---- the cache's own qualifier, so the block can be held to it ---------------
  logic iv1, iv2, iv3, iv4;
  always_ff @(posedge clk) begin
    if (!resetn) begin iv1 <= 1'b0;        iv2 <= 1'b0; iv3 <= 1'b0; iv4 <= 1'b0; end
    else         begin iv1 <= lookupValid; iv2 <= iv1;  iv3 <= iv2;  iv4 <= iv3;  end
  end

  always @(posedge clk) begin
    if (resetn && dut.validF4 && !iv4)
      fail("invariant: claimed a word the cache was never asked to fetch");
    if (resetn && pushValid && !iv4)
      fail("invariant: pushed a word the cache was never asked to fetch");
    if (resetn && replayValid && lookupValid)
      fail("invariant: lookup issued on the replay cycle");
    if (resetn && backendRedirect && lookupValid)
      fail("invariant: lookup issued on a redirect cycle");
  end

  // ---- recorded push stream ----------------------------------------------------
  logic [31:2]      recPC [0:63];
  logic [1:0]       recHw [0:63];
  logic [PHT_W-1:0] recGs [0:63];
  int               recCount;

  // ---- recorded replays --------------------------------------------------------
  logic [31:0]      repPC [0:7];
  logic [PHT_W-1:0] repBHR[0:7];
  logic [2:0]       repRp [0:7];
  int               repCount;

  always @(posedge clk) begin
    if (resetn && pushValid && recCount < 64) begin
      recPC[recCount] <= pushPC;
      recHw[recCount] <= pushHwValid;
      recGs[recCount] <= pushGshare;
      recCount        <= recCount + 1;
    end
    if (resetn && replayValid && repCount < 8) begin
      repPC [repCount] <= replayPC;
      repBHR[repCount] <= replayBHR;
      repRp [repCount] <= replayRasPtr;
      repCount         <= repCount + 1;
    end
  end

  // ---- one F0 cycle ------------------------------------------------------------
  task automatic present(input logic [31:0] pc, input logic [1:0] hw,
                         input logic [PHT_W-1:0] gs, input logic h,
                         input logic [2:0] rp = 3'd0);
    curPC = pc; curHw = hw; curGs = gs; curHit = h; curRp = rp;
    @(negedge clk);
  endtask

  //  no word offered: the block is parked or draining
  task automatic drain(input int n);
    for (int k = 0; k < n; k++) begin
      curHw = 2'b00; curHit = MISS;
      @(negedge clk);
    end
  endtask

  task automatic reset();
    resetn = 1'b0; fillBusy = 1'b1; canFetch = 1'b1; backendRedirect = 1'b0;
    curPC = '0; curHw = 2'b00; curGs = '0; curHit = MISS; curRp = 3'd0;
    fetchPC = '0; fetchHwValid = 2'b00; fetchGshare = '0; fetchRasPtr = 3'd0;
    pcF1 = '0; hwF1 = 2'b00; gsF1 = '0; rpF1 = 3'd0;
    hit = 1'b0; hitF1 = 1'b0; hitF2 = 1'b0; hitF3 = 1'b0;
    recCount = 0; repCount = 0;
    repeat (3) @(negedge clk);
    resetn   = 1'b1;
    fillBusy = 1'b0;
    @(negedge clk);
  endtask

  task automatic expectPush(input int idx, input logic [31:0] pc,
                            input logic [PHT_W-1:0] gs, input string note);
    if (idx >= recCount) begin
      $error("%-30s only %0d words pushed", note, recCount); errors++;
    end else if (recPC[idx] !== pc[31:2]) begin
      $error("%-30s slot %0d is word %h (expected %h)",
             note, idx, {recPC[idx], 2'b00}, pc); errors++;
    end else if (recGs[idx] !== gs) begin
      $error("%-30s word %h gshare=%h (expected %h)",
             note, pc, recGs[idx], gs); errors++;
    end
  endtask

  // ---- A - live words that hit reach the queue in order, each with its own metadata
  task automatic checkStraightThrough();
    reset();
    present(32'h0000_1000, 2'b11, 13'h0111, HIT);
    present(32'h0000_1004, 2'b11, 13'h0222, HIT);
    present(32'h0000_1008, 2'b11, 13'h0333, HIT);
    drain(4);
    if (recCount != 3) fail($sformatf("A: pushed %0d words (expected 3)", recCount));
    expectPush(0, 32'h0000_1000, 13'h0111, "A: first");
    expectPush(1, 32'h0000_1004, 13'h0222, "A: second");
    expectPush(2, 32'h0000_1008, 13'h0333, "A: third");
  endtask

  // ---- B - a dead word is killed at F4: no push, no fill, no park --------------
  task automatic checkDeadWordKilled();
    reset();
    present(32'h0000_2000, 2'b11, 13'h0444, HIT);
    present(32'h0000_2004, 2'b00, 13'h0555, MISS);   // dead, and would miss
    present(32'h0000_2008, 2'b11, 13'h0666, HIT);
    // F4 of the dead word
    curHw = 2'b00; curHit = MISS;
    repeat (2) @(negedge clk);
    #1;
    if (lookupKill !== 1'b1) fail("B: dead word not killed at F4");
    if (stall      !== 1'b0) fail("B: dead word parked the frontend");
    drain(4);
    if (recCount != 2) fail($sformatf("B: pushed %0d words (expected 2)", recCount));
    expectPush(0, 32'h0000_2000, 13'h0444, "B: before the dead word");
    expectPush(1, 32'h0000_2008, 13'h0666, "B: after the dead word");
    if (repCount != 0) fail("B: a dead word triggered a replay");
  endtask

  // ---- C - a miss parks, drops the three behind it, and replays the missed PC --
  task automatic checkMissReplay();
    reset();
    present(32'h0000_3000, 2'b11, 13'h0666, MISS, 3'd5);  // this one misses
    present(32'h0000_3004, 2'b11, 13'h0777, HIT,  3'd6);  // in flight behind it
    present(32'h0000_3008, 2'b11, 13'h0888, HIT,  3'd7);  // in flight behind it
    @(negedge clk);
    #1;                                              // F4 of 3000: the miss is live
    if (stall       !== 1'b1) fail("C: miss did not park the frontend");
    if (lookupValid !== 1'b0) fail("C: lookup issued during a miss");

    fillBusy = 1'b1;                                 // the fill engine takes it
    drain(6);
    if (recCount != 0)
      fail($sformatf("C: %0d words reached the queue behind the miss", recCount));
    if (repCount != 0) fail("C: replayed while the fill was still running");

    fillBusy = 1'b0;
    drain(2);
    if (repCount != 1) fail($sformatf("C: %0d replays (expected 1)", repCount));
    else begin
      if (repPC[0] !== 32'h0000_3000)
        fail($sformatf("C: replayPC=%h (expected 0000_3000)", repPC[0]));
      if (repBHR[0] !== (13'h0666 ^ 13'(32'h0000_3000 >> 2)))
        fail($sformatf("C: replayBHR=%h (expected %h)", repBHR[0],
                       13'h0666 ^ 13'(32'h0000_3000 >> 2)));
      if (repRp[0] !== 3'd5)
        fail($sformatf("C: replayRasPtr=%0d (expected 5)", repRp[0]));
    end
  endtask

  // ---- D - a word entered at its high half replays there, not at the word start
  task automatic checkReplayKeepsHalf();
    reset();
    present(32'h0000_4000, 2'b10, 13'h0999, MISS);   // entered at the high half
    present(32'h0000_4004, 2'b11, 13'h0AAA, HIT);
    present(32'h0000_4008, 2'b11, 13'h0BBB, HIT);
    fillBusy = 1'b1;
    drain(3);
    fillBusy = 1'b0;
    drain(2);
    if (repCount != 1) fail("D: no replay");
    else if (repPC[0] !== 32'h0000_4002)
      fail($sformatf("D: replayPC=%h (expected 0000_4002)", repPC[0]));
  endtask

  // ---- E - a backend redirect cancels a pending replay -------------------------
  task automatic checkRedirectCancelsReplay();
    reset();
    present(32'h0000_5000, 2'b11, 13'h0CCC, MISS);
    present(32'h0000_5004, 2'b11, 13'h0DDD, HIT);
    present(32'h0000_5008, 2'b11, 13'h0EEE, HIT);
    fillBusy = 1'b1;
    drain(2);

    backendRedirect = 1'b1;
    @(negedge clk);
    backendRedirect = 1'b0;

    fillBusy = 1'b0;
    drain(5);
    if (repCount != 0) fail("E: replay survived a backend redirect");
  endtask

  // ---- F - a backend redirect kills the words already in flight behind it ------
  task automatic checkRedirectKillsInFlight();
    reset();
    present(32'h0000_6000, 2'b11, 13'h0111, HIT);
    present(32'h0000_6004, 2'b11, 13'h0222, HIT);

    backendRedirect = 1'b1;
    @(negedge clk);
    backendRedirect = 1'b0;

    drain(4);
    if (recCount != 0)
      fail($sformatf("F: %0d wrong-path words reached the queue", recCount));
    #1;
    if (lookupKill !== 1'b1) fail("F: wrong-path word not killed at F4");
  endtask

  // ---- G - no credit parks the frontend without killing anything ---------------
  task automatic checkCreditParks();
    reset();
    present(32'h0000_7000, 2'b11, 13'h0AAA, HIT);
    canFetch = 1'b0;
    #1;
    if (stall       !== 1'b1) fail("G: no credit did not park");
    if (lookupValid !== 1'b0) fail("G: lookup issued without credit");
    drain(3);
    canFetch = 1'b1;
    #1;
    if (stall       !== 1'b0) fail("G: still parked after credit returned");
    if (lookupValid !== 1'b1) fail("G: lookup did not resume");
    drain(3);
    // the word looked up before the park still arrives
    if (recCount != 1) fail($sformatf("G: pushed %0d words (expected 1)", recCount));
    else expectPush(0, 32'h0000_7000, 13'h0AAA, "G: word from before the park");
  endtask

  initial begin
    checkStraightThrough();
    checkDeadWordKilled();
    checkMissReplay();
    checkReplayKeepsHalf();
    checkRedirectCancelsReplay();
    checkRedirectKillsInFlight();
    checkCreditParks();

    if (errors == 0) $display("PASS  fetch_ctrl");
    else             $fatal(1, "FAIL  fetch_ctrl (%0d errors)", errors);
    $finish;
  end

endmodule

