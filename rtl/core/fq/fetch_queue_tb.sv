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
  logic [30:0] push_pc;
  logic [31:0] push_word;
  logic        canFetch;
  logic        pop_validA, pop_validB, pop_taken;
  logic [30:0] pop_pcA, pop_pcB;
  logic [31:0] pop_wordA, pop_wordB;

  int errors = 0;

  fetch_queue #(.DEPTH(DEPTH), .FETCH_LATENCY(LATENCY)) dut (
    .clk, .resetn, .flush,
    .push_valid, .push_pc, .push_word,
    .canFetch,
    .pop_validA, .pop_pcA, .pop_wordA,
    .pop_validB, .pop_pcB, .pop_wordB,
    .pop_taken
  );

  initial begin
    #500000;
    $fatal(1, "FAIL  fetch_queue: watchdog fired (count=%0d)", dut.count);
  end

  // ---- payloads carry their own index so ordering is self-checking -------------
  function automatic logic [30:0] pcOf (input int n); return 31'(32'h0000_1000 + n); endfunction
  function automatic logic [31:0] wdOf (input int n); return 32'hA000_0000 + n;       endfunction

  // ---- one clock with the given stimulus held across the edge ------------------
  task automatic cycle(input logic pv, input int n, input logic take, input logic fl);
    push_valid = pv;
    push_pc    = pcOf(n);
    push_word  = wdOf(n);
    pop_taken  = take;
    flush      = fl;
    @(negedge clk);
  endtask

  task automatic idle(input int cycles);
    for (int k = 0; k < cycles; k++) cycle(1'b0, 0, 1'b0, 1'b0);
  endtask

  task automatic expectHead(input int n, input string note);
    if (pop_validA !== 1'b1) begin
      $error("%-24s head not valid (expected entry %0d)", note, n); errors++;
    end else if (pop_pcA !== pcOf(n) || pop_wordA !== wdOf(n)) begin
      $error("%-24s head = pc %h word %h (expected %h / %h)",
             note, pop_pcA, pop_wordA, pcOf(n), wdOf(n)); errors++;
    end
  endtask

  task automatic expectAhead(input int n, input string note);
    if (pop_validB !== 1'b1) begin
      $error("%-24s head+1 not valid (expected entry %0d)", note, n); errors++;
    end else if (pop_pcB !== pcOf(n) || pop_wordB !== wdOf(n)) begin
      $error("%-24s head+1 = pc %h word %h (expected %h / %h)",
             note, pop_pcB, pop_wordB, pcOf(n), wdOf(n)); errors++;
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
    cycle(1'b0, 0, 1'b0, 1'b0);
    cycle(1'b0, 0, 1'b0, 1'b0);
    resetn = 1'b1;

    checkEmptyAtReset();
    checkTwoEntryWindow();
    checkWrapOrdering();
    checkCredit();
    checkFullDropsNothingResident();
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
    cycle(1'b1, 0, 1'b0, 1'b0);
    expectHead(0, "one entry");
    if (pop_validB !== 1'b0) begin
      $error("one entry: head+1 valid with a single entry queued"); errors++;
    end

    cycle(1'b1, 1, 1'b0, 1'b0);
    expectHead (0, "two entries");
    expectAhead(1, "two entries");

    // taking one slides the window by exactly one
    cycle(1'b0, 0, 1'b1, 1'b0);
    expectHead(1, "after take");
    if (pop_validB !== 1'b0) begin
      $error("after take: head+1 valid with a single entry left"); errors++;
    end

    cycle(1'b0, 0, 1'b1, 1'b0);
    idle(1);
    expectEmpty("drained");

    // a take on an empty queue must not move the head
    cycle(1'b0, 0, 1'b1, 1'b0);
    expectEmpty("take while empty");
  endtask

  // ---- push and pop together for longer than DEPTH, straight through the wrap --
  task automatic checkWrapOrdering();
    int nextPush, nextPop;
    nextPush = 100;
    nextPop  = 100;

    // prime with four entries
    for (int k = 0; k < 4; k++) begin
      cycle(1'b1, nextPush, 1'b0, 1'b0);
      nextPush++;
    end

    // 40 simultaneous push/pop cycles: count holds, order must not slip
    for (int k = 0; k < 40; k++) begin
      expectHead (nextPop,     "wrap head");
      expectAhead(nextPop + 1, "wrap head+1");
      cycle(1'b1, nextPush, 1'b1, 1'b0);
      nextPush++;
      nextPop++;
    end

    // drain what is left
    while (pop_validA === 1'b1) begin
      expectHead(nextPop, "wrap drain");
      cycle(1'b0, 0, 1'b1, 1'b0);
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
      if (canFetch === 1'b1) begin                // count == k here
        if (closed) begin
          $error("credit: canFetch reopened at count %0d", k); errors++;
        end
        lastOpen = k;
      end else begin
        closed = 1'b1;
      end
      cycle(1'b1, 200 + k, 1'b0, 1'b0);
    end

    if (lastOpen != DEPTH - LATENCY - 1) begin
      $error("credit: last open count %0d (expected %0d)",
             lastOpen, DEPTH - LATENCY - 1);
      errors++;
    end
  endtask

  // ---- the queue is full now: extra pushes are dropped, residents survive ------
  task automatic checkFullDropsNothingResident();
    for (int k = 0; k < 4; k++) cycle(1'b1, 900 + k, 1'b0, 1'b0);
    expectHead (200, "overflow head");
    expectAhead(201, "overflow head+1");

    for (int k = 0; k < DEPTH; k++) begin
      expectHead(200 + k, "full drain");
      cycle(1'b0, 0, 1'b1, 1'b0);
    end
    idle(1);
    expectEmpty("full drained");
  endtask

  // ---- flush empties the queue and swallows the lookups still in flight --------
  task automatic checkFlushAndShadow();
    for (int k = 0; k < 5; k++) cycle(1'b1, 300 + k, 1'b0, 1'b0);
    expectHead(300, "pre-flush");

    // flush with a push in the same cycle: both the queue and that push go away
    cycle(1'b1, 399, 1'b0, 1'b1);
    expectEmpty("flush cycle");

    // the next FETCH_LATENCY pushes are stale in-flight lookups
    for (int k = 0; k < LATENCY; k++) begin
      cycle(1'b1, 400 + k, 1'b0, 1'b0);
      if (pop_validA !== 1'b0) begin
        $error("shadow: stale push %0d entered the queue", k); errors++;
      end
    end

    // the first lookup issued after the redirect is the first one kept
    cycle(1'b1, 500, 1'b0, 1'b0);
    expectHead(500, "post-shadow");

    cycle(1'b1, 501, 1'b0, 1'b0);
    expectAhead(501, "post-shadow head+1");
  endtask

endmodule
