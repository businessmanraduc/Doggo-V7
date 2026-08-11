// ================================================================================
//  pht_tb -- checks both lookup ports, both precompute-both candidates, and that
//  the resolve bits are consumed live rather than delayed alongside the index.
// ================================================================================
module pht_tb;
  localparam int INDEX_W = 13;

  logic clk = 0;
  always #5 clk = ~clk;

  logic               readEnable;
  logic [INDEX_W-1:0] indexA, indexB;
  logic               resolveA, resolveB;
  logic               wrEnable;
  logic [INDEX_W-1:0] wrIndex;
  logic [1:0]         wrCounter;
  logic               takenA, takenB;

  int errors = 0;

  pht #(.INDEX_W(INDEX_W)) dut (
    .clk, .readEnable, .indexA, .indexB, .resolveA, .resolveB,
    .wrEnable, .wrIndex, .wrCounter, .takenA, .takenB
  );

  initial begin
    #500000;
    $fatal(1, "FAIL  pht: watchdog fired");
  end

  task automatic writeCounter(input logic [INDEX_W-1:0] idx, input logic [1:0] c);
    @(negedge clk);
    wrEnable = 1'b1; wrIndex = idx; wrCounter = c;
    @(negedge clk);
    wrEnable = 1'b0;
  endtask

  // ---- present a pair of indices and let the two-cycle read land ---------------
  task automatic arm(input logic [INDEX_W-1:0] ia, input logic [INDEX_W-1:0] ib);
    @(negedge clk);
    indexA = ia; indexB = ib;
    @(negedge clk);
    @(negedge clk);
  endtask

  task automatic expectTaken(input logic wantA, input logic wantB, input string note);
    if (takenA !== wantA) begin
      $error("%-40s takenA=%b (expected %b)", note, takenA, wantA); errors++;
    end
    if (takenB !== wantB) begin
      $error("%-40s takenB=%b (expected %b)", note, takenB, wantB); errors++;
    end
  endtask

  // ---- A - a counter written and read back on both ports -----------------------
  task automatic checkWriteReadBack();
    writeCounter(13'h0100, 2'b11);      // strongly taken
    writeCounter(13'h0200, 2'b00);      // strongly not taken
    resolveA = 1'b0; resolveB = 1'b0;
    arm(13'h0100, 13'h0200);
    expectTaken(1'b1, 1'b0, "A: both ports read their own index");
    arm(13'h0200, 13'h0100);
    expectTaken(1'b0, 1'b1, "A: ports are independent");
  endtask

  // ---- B - takenX is counter[1], so weak states straddle the threshold ---------
  task automatic checkThreshold();
    writeCounter(13'h0300, 2'b01);      // weakly not taken
    writeCounter(13'h0304, 2'b10);      // weakly taken
    resolveA = 1'b0; resolveB = 1'b0;
    arm(13'h0300, 13'h0304);
    expectTaken(1'b0, 1'b1, "B: counter[1] is the prediction");
  endtask

  // ---- C - resolve picks the alternate candidate -------------------------------
  task automatic checkAlternateSelected();
    writeCounter(13'h0400, 2'b00);      // index
    writeCounter(13'h0401, 2'b11);      // index ^ 1
    writeCounter(13'h0500, 2'b11);
    writeCounter(13'h0501, 2'b00);
    resolveA = 1'b0; resolveB = 1'b0;
    arm(13'h0400, 13'h0500);
    expectTaken(1'b0, 1'b1, "C: resolve=0 takes the primary");
    resolveA = 1'b1; resolveB = 1'b1;
    #1;
    expectTaken(1'b1, 1'b0, "C: resolve=1 takes the alternate");
  endtask

  // ---- D - resolve is LIVE, not sampled with the index -------------------------
  //  If it were delayed to match the index, toggling it here would take two more
  //  cycles to show up, and it would be the bit already folded into the index,
  //  which cancels out and drops a history bit from the table.
  task automatic checkResolveIsLive();
    writeCounter(13'h0600, 2'b00);
    writeCounter(13'h0601, 2'b11);
    writeCounter(13'h0700, 2'b00);
    writeCounter(13'h0701, 2'b11);
    resolveA = 1'b0; resolveB = 1'b0;
    arm(13'h0600, 13'h0700);
    expectTaken(1'b0, 1'b0, "D: primary before the toggle");
    resolveA = 1'b1;
    #1;
    expectTaken(1'b1, 1'b0, "D: slot A flips in the same cycle");
    resolveB = 1'b1;
    #1;
    expectTaken(1'b1, 1'b1, "D: slot B flips in the same cycle");
    resolveA = 1'b0; resolveB = 1'b0;
    #1;
    expectTaken(1'b0, 1'b0, "D: and flips straight back");
  endtask

  // ---- E - one write reaches all four copies -----------------------------------
  //  Port A primary, port A alternate, port B primary, port B alternate are the
  //  same table. A single update has to land in every one of them.
  task automatic checkAllCopiesWritten();
    writeCounter(13'h0800, 2'b11);
    writeCounter(13'h0801, 2'b00);
    resolveA = 1'b0; resolveB = 1'b0;
    arm(13'h0800, 13'h0800);
    expectTaken(1'b1, 1'b1, "E: primary copies of both ports");
    resolveA = 1'b1; resolveB = 1'b1;
    #1;
    expectTaken(1'b0, 1'b0, "E: alternate copies of both ports");
    // read index^1 with resolve=1, which lands back on 0x0800 through the alternates
    arm(13'h0801, 13'h0801);
    resolveA = 1'b1; resolveB = 1'b1;
    #1;
    expectTaken(1'b1, 1'b1, "E: alternates address index^1 correctly");
  endtask

  // ---- F - a moving stream, so the read latency has to be right ----------------
  task automatic checkMovingStream();
    logic [INDEX_W-1:0] ia [0:3];
    logic [INDEX_W-1:0] ib [0:3];
    logic               eA [0:3];
    logic               eB [0:3];
    for (int k = 0; k < 4; k++) begin
      ia[k] = INDEX_W'(13'h0900 + k*4);
      ib[k] = INDEX_W'(13'h0A00 + k*4);
      eA[k] = k[0];
      eB[k] = ~k[0];
      writeCounter(ia[k], eA[k] ? 2'b11 : 2'b00);
      writeCounter(ib[k], eB[k] ? 2'b11 : 2'b00);
    end
    resolveA = 1'b0; resolveB = 1'b0;
    @(negedge clk); indexA = ia[0]; indexB = ib[0];
    @(negedge clk); indexA = ia[1]; indexB = ib[1];
    @(negedge clk); indexA = ia[2]; indexB = ib[2];
    expectTaken(eA[0], eB[0], "F: stream slot 0");
    @(negedge clk); indexA = ia[3]; indexB = ib[3];
    expectTaken(eA[1], eB[1], "F: stream slot 1");
    @(negedge clk);
    expectTaken(eA[2], eB[2], "F: stream slot 2");
    @(negedge clk);
    expectTaken(eA[3], eB[3], "F: stream slot 3");
  endtask

  initial begin
    readEnable = 1'b1; wrEnable = 1'b0; wrIndex = '0; wrCounter = '0;
    indexA = '0; indexB = '0; resolveA = 1'b0; resolveB = 1'b0;
    @(negedge clk);

    checkWriteReadBack();
    checkThreshold();
    checkAlternateSelected();
    checkResolveIsLive();
    checkAllCopiesWritten();
    checkMovingStream();

    if (errors == 0) $display("PASS  pht");
    else             $fatal(1, "FAIL  pht (%0d errors)", errors);
    $finish;
  end

endmodule
