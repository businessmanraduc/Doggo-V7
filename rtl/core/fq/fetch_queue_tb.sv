// ================================================================================
//  fetch_queue_tb -- drives the fetch queue through its real ports: pushes look
//  like cache hits landing at F3, pops look like align taking one entry.
// ================================================================================
module fetch_queue_tb;
  localparam int DEPTH   = 16;
  localparam int LATENCY = 3;

  logic clk = 0;
  always #5 clk = ~clk;

  logic        resetn, flush;
  logic        push_valid;
  logic [31:2] push_pc;
  logic [1:0]  push_hwValid;
  logic [31:0] push_word;
  logic        canFetch;
  logic        pop_validA, pop_validB;
  logic [1:0]  pop_take;
  logic [31:2] pop_pcA, pop_pcB;
  logic [1:0]  pop_hwValidA, pop_hwValidB;
  logic [31:0] pop_wordA, pop_wordB;

  int errors = 0;

  fetch_queue #(.DEPTH(DEPTH), .FETCH_LATENCY(LATENCY)) dut (
    .clk, .resetn, .flush,
    .push_valid, .push_pc, .push_hwValid, .push_word,
    .canFetch,
    .pop_validA, .pop_pcA, .pop_hwValidA, .pop_wordA,
    .pop_validB, .pop_pcB, .pop_hwValidB, .pop_wordB,
    .pop_take
  );

  initial begin
    #500000;
    $fatal(1, "FAIL  fetch_queue: watchdog fired (count=%0d)", dut.count);
  end

  // ---- payloads carry their own index so ordering is self-checking -------------
  function automatic logic [31:2] pcOf (input int n); return 30'(32'h0000_1000 + n); endfunction
  function automatic logic [31:0] wdOf (input int n); return 32'hA000_0000 + n;      endfunction

  // ---- one clock with the given stimulus held across the edge ------------------
  task automatic cycle(input logic pv, input int n, input logic [1:0] hw,
                       input logic [1:0] take, input logic fl);
    push_valid   = pv;
    push_pc      = pcOf(n);
    push_hwValid = hw;
    push_word    = wdOf(n);
    pop_take     = take;
    flush        = fl;
    @(negedge clk);
  endtask

  task automatic idle(input int cycles);
    for (int k = 0; k < cycles; k++) cycle(1'b0, 0, 2'b11, 2'd0, 1'b0);
  endtask

  task automatic expectHead(input int n, input logic [1:0] hw, input string note);
    if (pop_validA !== 1'b1) begin
      $error("%-24s head not valid (expected entry %0d)", note, n); errors++;
    end else if (pop_pcA !== pcOf(n) || pop_wordA !== wdOf(n)) begin
      $error("%-24s head = pc %h word %h (expected %h / %h)",
             note, pop_pcA, pop_wordA, pcOf(n), wdOf(n)); errors++;
    end else if (pop_hwValidA !== hw) begin
      $error("%-24s head hwValid=%b (expected %b)", note, pop_hwValidA, hw); errors++;
    end
  endtask

  task automatic expectAhead(input int n, input logic [1:0] hw, input string note);
    if (pop_validB !== 1'b1) begin
      $error("%-24s head+1 not valid (expected entry %0d)", note, n); errors++;
    end else if (pop_pcB !== pcOf(n) || pop_wordB !== wdOf(n)) begin
      $error("%-24s head+1 = pc %h word %h (expected %h / %h)",
             note, pop_pcB, pop_wordB, pcOf(n), wdOf(n)); errors++;
    end else if (pop_hwValidB !== hw) begin
      $error("%-24s head+1 hwValid=%b (expected %b)", note, pop_hwValidB, hw); errors++;
    end
  endtask

  task automatic expectEmpty(input string note);
    if (pop_validA !== 1'b0 || pop_validB !== 1'b0) begin
      $error("%-24s queue not empty (A=%b B=%b)", note, pop_validA, pop_validB);
      errors++;
    end
  endtask

  initial begin
    resetn = 1'b0;
    cycle(1'b0, 0, 2'b11, 2'd0, 1'b0);
    cycle(1'b0, 0, 2'b11, 2'd0, 1'b0);
    resetn = 1'b1;

    checkEmptyAtReset();
    checkTwoEntryWindow();
    checkMaskCarried();
    checkDeadWordDropped();
    checkWrapOrdering();
    checkCredit();
    checkFullDropsNothingResident();
    checkPopTwo();
    checkFlushAndShadow();

    if (errors == 0) $display("PASS  fetch_queue");
    else             $fatal(1, "FAIL  fetch_queue (%0d errors)", errors);
    $finish;
  end

  // ---- nothing visible, and F0 is free to fetch --------------------------------
  task automatic checkEmptyAtReset();
    idle(1);
    expectEmpty("reset");
    if (canFetch !== 1'b1) begin
      $error("reset: canFetch low on an empty queue"); errors++;
    end
  endtask

  // ---- head and head+1 are the two oldest entries, in order --------------------
  task automatic checkTwoEntryWindow();
    cycle(1'b1, 0, 2'b11, 2'd0, 1'b0);
    expectHead(0, 2'b11, "one entry");
    if (pop_validB !== 1'b0) begin
      $error("one entry: head+1 valid with a single entry queued"); errors++;
    end

    cycle(1'b1, 1, 2'b11, 2'd0, 1'b0);
    expectHead (0, 2'b11, "two entries");
    expectAhead(1, 2'b11, "two entries");

    cycle(1'b0, 0, 2'b11, 2'd1, 1'b0);
    expectHead(1, 2'b11, "after take");
    if (pop_validB !== 1'b0) begin
      $error("after take: head+1 valid with a single entry left"); errors++;
    end

    cycle(1'b0, 0, 2'b11, 2'd1, 1'b0);
    idle(1);
    expectEmpty("drained");

    cycle(1'b0, 0, 2'b11, 2'd1, 1'b0);
    expectEmpty("take while empty");
  endtask

  // ---- the mask rides with its word, per entry ---------------------------------
  task automatic checkMaskCarried();
    cycle(1'b1, 50, 2'b01, 2'd0, 1'b0);
    cycle(1'b1, 51, 2'b10, 2'd0, 1'b0);
    expectHead (50, 2'b01, "mask: exit after low");
    expectAhead(51, 2'b10, "mask: entered high");
    cycle(1'b0, 0, 2'b11, 2'd1, 1'b0);
    expectHead(51, 2'b10, "mask: survives a pop");
    cycle(1'b0, 0, 2'b11, 2'd1, 1'b0);
    idle(1);
    expectEmpty("mask: drained");
  endtask

  // ---- a dead word must not occupy a slot at all -------------------------------
  task automatic checkDeadWordDropped();
    cycle(1'b1, 60, 2'b11, 2'd0, 1'b0);
    cycle(1'b1, 61, 2'b00, 2'd0, 1'b0);   // overrun word behind a taken branch
    cycle(1'b1, 62, 2'b11, 2'd0, 1'b0);
    expectHead (60, 2'b11, "dead: live word kept");
    expectAhead(62, 2'b11, "dead: word skipped");
    if (dut.count !== 2) begin
      $error("dead: queue holds %0d entries (expected 2)", dut.count); errors++;
    end
    cycle(1'b0, 0, 2'b11, 2'd1, 1'b0);
    cycle(1'b0, 0, 2'b11, 2'd1, 1'b0);
    idle(1);
    expectEmpty("dead: drained");
  endtask

  // ---- push and pop together for longer than DEPTH, straight through the wrap --
  task automatic checkWrapOrdering();
    int nextPush, nextPop;
    nextPush = 100;
    nextPop  = 100;

    for (int k = 0; k < 4; k++) begin
      cycle(1'b1, nextPush, 2'b11, 2'd0, 1'b0);
      nextPush++;
    end

    for (int k = 0; k < 40; k++) begin
      expectHead (nextPop,     2'b11, "wrap head");
      expectAhead(nextPop + 1, 2'b11, "wrap head+1");
      cycle(1'b1, nextPush, 2'b11, 2'd1, 1'b0);
      nextPush++;
      nextPop++;
    end

    while (pop_validA === 1'b1) begin
      expectHead(nextPop, 2'b11, "wrap drain");
      cycle(1'b0, 0, 2'b11, 2'd1, 1'b0);
      nextPop++;
    end
    if (nextPop != nextPush) begin
      $error("wrap: pushed %0d entries, popped %0d", nextPush - 100, nextPop - 100);
      errors++;
    end
  endtask

  // ---- credit must close while FETCH_LATENCY lookups can still land ------------
  task automatic checkCredit();
    int  lastOpen;
    bit  closed;
    idle(1);
    expectEmpty("credit start");
    lastOpen = -1;
    closed   = 1'b0;

    for (int k = 0; k < DEPTH; k++) begin
      if (canFetch === 1'b1) begin
        if (closed) begin
          $error("credit: canFetch reopened at count %0d", k); errors++;
        end
        lastOpen = k;
      end else begin
        closed = 1'b1;
      end
      cycle(1'b1, 200 + k, 2'b11, 2'd0, 1'b0);
    end

    if (lastOpen != DEPTH - LATENCY - 1) begin
      $error("credit: last open count %0d (expected %0d)",
             lastOpen, DEPTH - LATENCY - 1);
      errors++;
    end
  endtask

  // ---- the queue is full now: extra pushes are dropped, residents survive ------
  task automatic checkFullDropsNothingResident();
    for (int k = 0; k < 4; k++) cycle(1'b1, 900 + k, 2'b11, 2'd0, 1'b0);
    expectHead (200, 2'b11, "overflow head");
    expectAhead(201, 2'b11, "overflow head+1");

    for (int k = 0; k < DEPTH; k++) begin
      expectHead(200 + k, 2'b11, "full drain");
      cycle(1'b0, 0, 2'b11, 2'd1, 1'b0);
    end
    idle(1);
    expectEmpty("full drained");
  endtask

  // ---- align retires two entries when a straddle finishes off the second ------
  task automatic checkPopTwo();
    idle(1);
    expectEmpty("popTwo start");
    cycle(1'b1, 700, 2'b11, 2'd0, 1'b0);
    cycle(1'b1, 701, 2'b01, 2'd0, 1'b0);
    cycle(1'b1, 702, 2'b11, 2'd0, 1'b0);
    expectHead (700, 2'b11, "popTwo: before");
    expectAhead(701, 2'b01, "popTwo: before");
    cycle(1'b0, 0, 2'b11, 2'd2, 1'b0);
    expectHead(702, 2'b11, "popTwo: both retired");
    if (dut.count !== 1) begin
      $error("popTwo: count=%0d after a double retire (expected 1)", dut.count);
      errors++;
    end
    cycle(1'b0, 0, 2'b11, 2'd1, 1'b0);
    idle(1);
    expectEmpty("popTwo: drained");

    // a double retire must not be honoured with only one entry present
    cycle(1'b1, 710, 2'b11, 2'd0, 1'b0);
    cycle(1'b0, 0, 2'b11, 2'd2, 1'b0);
    idle(1);
    expectEmpty("popTwo: clamped to one");
  endtask

  // ---- flush empties the queue and swallows the lookups still in flight --------
  task automatic checkFlushAndShadow();
    for (int k = 0; k < 5; k++) cycle(1'b1, 300 + k, 2'b11, 2'd0, 1'b0);
    expectHead(300, 2'b11, "pre-flush");

    cycle(1'b1, 399, 2'b11, 2'd0, 1'b1);
    expectEmpty("flush cycle");

    for (int k = 0; k < LATENCY; k++) begin
      cycle(1'b1, 400 + k, 2'b11, 2'd0, 1'b0);
      if (pop_validA !== 1'b0) begin
        $error("shadow: stale push %0d entered the queue", k); errors++;
      end
    end

    cycle(1'b1, 500, 2'b11, 2'd0, 1'b0);
    expectHead(500, 2'b11, "post-shadow");

    cycle(1'b1, 501, 2'b11, 2'd0, 1'b0);
    expectAhead(501, 2'b11, "post-shadow head+1");
  endtask

endmodule
