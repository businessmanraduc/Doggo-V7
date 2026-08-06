// ================================================================================
//  icache_tb -- drives the cache through its real ports: fetches go in, and
//  misses are satisfied by a fake memory answering the burst request.
// ================================================================================
module icache_tb;
  localparam int MEM_LATENCY = 4;

  logic clk = 0;
  always #5 clk = ~clk;

  logic        resetn;
  logic [31:0] lookupAddr;
  logic        lookupValid;
  logic        lookupKill;
  logic [31:0] instrWord;
  logic        hit;
  logic        fillBusy;
  logic [31:0] fillAddr;
  logic        fillReq;
  logic [31:0] fillRData;
  logic        fillRValid;

  int errors    = 0;
  int fillCount = 0;

  icache dut (
    .clk, .resetn,
    .lookupAddr, .lookupValid, .lookupKill, .instrWord, .hit, .fillBusy,
    .fillAddr, .fillReq, .fillRData, .fillRValid
  );

  // ---- watchdog: a stuck fill hangs a wait(), which looks like nothing ---------
  initial begin
    #2000000;
    $fatal(1, "FAIL  icache: watchdog fired (fillBusy=%b state=%0d)",
           fillBusy, dut.u_fill.state);
  end

  // ---- fake memory: one burst of eight words per request -----------------------
  initial begin
    fillRValid = 1'b0;
    fillRData  = '0;
    forever begin
      @(negedge clk);
      if (fillReq) begin
        automatic logic [31:0] base = fillAddr;
        fillCount++;
        repeat (MEM_LATENCY) @(negedge clk);
        for (int k = 0; k < 8; k++) begin
          fillRValid = 1'b1;
          fillRData  = base + 32'(k * 4);
          @(negedge clk);
          fillRValid = 1'b0;
          @(negedge clk);              // gappy on purpose
        end
      end
    end
  end

  // ---- one fetch, verdict four cycles later ------------------------------------
  task automatic fetch(input logic [31:0] a, output logic gotHit,
                       output logic [31:0] word);
    @(negedge clk); lookupAddr = a; lookupValid = 1'b1;
    @(negedge clk); lookupValid = 1'b0;
    repeat (3) @(negedge clk);
    gotHit = hit;
    word   = instrWord;
  endtask

  // ---- fetch and replay until it lands, the way the frontend will --------------
  task automatic fetchThroughMiss(input logic [31:0] a, input string note);
    logic        h;
    logic [31:0] w;
    h = 1'b0;
    for (int attempt = 0; attempt < 4 && !h; attempt++) begin
      fetch(a, h, w);
      if (!h) begin
        wait (fillBusy === 1'b0);
        repeat (2) @(negedge clk);
      end
    end
    if (!h) begin
      $error("%-22s addr=%h still missing after a fill", note, a); errors++;
    end else if (w !== a) begin
      $error("%-22s addr=%h word=%h (expected %h)", note, a, w, a); errors++;
    end
  endtask

  // ---- power-up garbage, so the boot sweep is actually on trial ----------------
  task automatic poisonTags();
    for (int s = 0; s < 128; s++) begin
      dut.g_tagWay[0].u_tagBlk.mem[s] = {4'b0, 1'b1, 13'h0};
      dut.g_tagWay[1].u_tagBlk.mem[s] = {4'b0, 1'b1, 13'h0};
      dut.g_tagWay[2].u_tagBlk.mem[s] = {4'b0, 1'b1, 13'h0};
      dut.g_tagWay[3].u_tagBlk.mem[s] = {4'b0, 1'b1, 13'h0};
    end
  endtask

  initial begin
    resetn = 1'b0; lookupValid = 1'b0; lookupKill = 1'b0; lookupAddr = '0;
    poisonTags();
    repeat (3) @(negedge clk);
    resetn = 1'b1;

    // ---- no hit may escape while the boot sweep is still running ---------------
    checkSweepBlocksHits();

    // ---- a cold line: miss, fill, then hit with the right word -----------------
    fetchThroughMiss(32'h0000_1000, "cold line");
    if (fillCount != 1) begin
      $error("expected 1 fill, saw %0d", fillCount); errors++;
    end

    // ---- every word of that line is now present, no further fills --------------
    checkWholeLine(32'h0000_1000);
    if (fillCount != 1) begin
      $error("re-reading a resident line refilled it (%0d fills)", fillCount);
      errors++;
    end

    // ---- four tags in one set land in four different ways ----------------------
    checkWaySpread();

    // ---- back-to-back words of a resident line, one per cycle ------------------
    checkStreaming(32'h0000_1000);

    // ---- a walk over many lines, each satisfied by its own fill ----------------
    checkManyLines();

    // ---- a disowned miss must not reach the fill engine ------------------------
    checkKilledMissNeverFills();

    if (errors == 0) $display("PASS  icache");
    else             $fatal(1, "FAIL  icache (%0d errors)", errors);
    $finish;
  end

  // ---- a lookup the front end disowns at F4 must not start a fill --------------
  task automatic checkKilledMissNeverFills();
    int fillsBefore;

    fillsBefore = fillCount;

    // a cold address, but killed on the cycle its verdict lands
    @(negedge clk); lookupAddr = 32'h0002_4000; lookupValid = 1'b1;
    @(negedge clk); lookupValid = 1'b0;
    repeat (3) @(negedge clk);
    lookupKill = 1'b1;
    @(negedge clk);
    lookupKill = 1'b0;

    repeat (20) @(negedge clk);
    if (fillCount != fillsBefore) begin
      $error("killed miss started a fill (%0d -> %0d)", fillsBefore, fillCount);
      errors++;
    end
    if (fillBusy !== 1'b0) begin
      $error("killed miss left the fill engine busy"); errors++;
    end

    // and the same address still fills normally once it is not disowned
    fetchThroughMiss(32'h0002_4000, "killed then wanted");
    if (fillCount != fillsBefore + 1) begin
      $error("expected one fill after the kill, saw %0d", fillCount - fillsBefore);
      errors++;
    end
  endtask

  // ---- before initDone the tag LUTRAM is garbage: hit must stay low ------------
  task automatic checkSweepBlocksHits();
    int guard;
    //  Address 0xFE0 is tag 0 / set 127: the LAST set the sweep clears, and the
    //  one the poisoned tags will match. Held throughout so whichever cycle is
    //  the vulnerable one, a lookup is sitting in it.
    guard = 0;
    while (fillBusy === 1'b1 && guard < 200) begin
      @(negedge clk);
      lookupAddr  = 32'h0000_0FE0;
      lookupValid = 1'b1;
      if (hit !== 1'b0) begin
        $error("hit asserted during the boot sweep"); errors++;
      end
      guard++;
    end
    if (guard >= 200) begin
      $error("boot sweep never finished"); errors++;
    end

    for (int k = 0; k < 10; k++) begin
      @(negedge clk);
      lookupAddr  = 32'h0000_0FE0;
      lookupValid = 1'b1;
      if (hit !== 1'b0) begin
        $error("false hit on power-up garbage, %0d cycles after initDone", k);
        errors++;
      end
    end
    lookupValid = 1'b0;
    repeat (4) @(negedge clk);
    wait (fillBusy === 1'b0);
    repeat (8) @(negedge clk);
    fillCount = 0;
  endtask

  // ---- all eight words of a resident line read back correctly ------------------
  task automatic checkWholeLine(input logic [31:0] base);
    logic        h;
    logic [31:0] w;
    for (int k = 0; k < 8; k++) begin
      fetch(base + 32'(k * 4), h, w);
      if (!h) begin
        $error("resident line: word %0d missed", k); errors++;
      end else if (w !== base + 32'(k * 4)) begin
        $error("resident line: word %0d = %h (expected %h)",
               k, w, base + 32'(k * 4)); errors++;
      end
    end
  endtask

  // ---- four distinct tags in one set must occupy four distinct ways ------------
  task automatic checkWaySpread();
    logic [31:0] a;
    for (int t = 0; t < 4; t++) begin
      a = 32'h0020_0400 | (32'(t) << 12);   // set 0x20, clear of the other tests
      fetchThroughMiss(a, $sformatf("spread tag%0d", t));
    end
    // all four must still be resident: nothing evicted anything
    for (int t = 0; t < 4; t++) begin
      logic        h;
      logic [31:0] w;
      a = 32'h0020_0400 | (32'(t) << 12);   // set 0x20, clear of the other tests
      fetch(a, h, w);
      if (!h) begin
        $error("spread: tag%0d evicted, PLRU did not use all four ways", t);
        errors++;
      end
    end
  endtask

  // ---- consecutive addresses, one word per cycle, offset by the 4-cycle pipe ---
  task automatic checkStreaming(input logic [31:0] base);
    int idx;
    for (int k = 0; k < 8 + 4; k++) begin
      @(negedge clk);
      if (k >= 4) begin
        idx = k - 4;
        if (hit !== 1'b1 || instrWord !== base + 32'(idx * 4)) begin
          $error("stream word %0d: hit=%b word=%h (expected %h)",
                 idx, hit, instrWord, base + 32'(idx * 4)); errors++;
        end
      end
      if (k < 8) begin
        lookupAddr  = base + 32'(k * 4);
        lookupValid = 1'b1;
      end else begin
        lookupValid = 1'b0;
      end
    end
  endtask

  // ---- a walk across many lines and sets ---------------------------------------
  task automatic checkManyLines();
    logic [31:0] a;
    int          fillsBefore;
    fillsBefore = fillCount;
    for (int n = 0; n < 24; n++) begin
      a = 32'h0100_0000 | (32'(n) << 5);       // 24 consecutive lines
      fetchThroughMiss(a, $sformatf("walk line%0d", n));
    end
    if (fillCount - fillsBefore != 24) begin
      $error("walk: %0d fills for 24 fresh lines", fillCount - fillsBefore);
      errors++;
    end
  endtask

endmodule
