// ================================================================================
//  dispatch_fifo_tb -- elastic, in-order, lossless between the handshakes, 
//  and empty after flush
// ================================================================================

module dispatch_fifo_tb;
  localparam int W     = 96;
  localparam int DEPTH = 8;

  logic         clk = 0, resetn, flush;
  logic         enq_valid, enq_ready;
  logic [W-1:0] enq_data;
  logic         deq_valid, deq_ready;
  logic [W-1:0] deq_data;
  int           errors = 0;

  dispatch_fifo #(.W(W), .DEPTH(DEPTH)) dut (
    .clk, .resetn, .flush,
    .enq_valid, .enq_data, .enq_ready,
    .deq_valid, .deq_data, .deq_ready
  );

  always #5 clk = ~clk;

  task automatic fail(input string msg);
    $error("%s", msg);
    errors++;
  endtask

  // enqueue one word; must be accepted this cycle
  task automatic enqOne(input logic [W-1:0] d, input string note);
    enq_valid = 1; enq_data = d;
    #1;
    if (!enq_ready) fail({note, ": enq refused"});
    @(posedge clk); #1;
    enq_valid = 0;
  endtask

  // dequeue one word; must be present and match
  task automatic deqOne(input logic [W-1:0] want, input string note);
    deq_ready = 1;
    #1;
    if (!deq_valid)              fail({note, ": deq_valid clear"});
    else if (deq_data !== want)  fail({note, ": wrong data"});
    @(posedge clk); #1;
    deq_ready = 0;
  endtask

  logic [W-1:0] model[$];   // reference queue for the random stress phase

  initial begin
    resetn = 0; flush = 0;
    enq_valid = 0; enq_data = '0; deq_ready = 0;
    @(posedge clk); @(posedge clk);
    #1 resetn = 1;
    @(posedge clk); #1;

    // ---- A: empty after reset --------------------------------------------------
    if (deq_valid)  fail("A: deq_valid while empty");
    if (!enq_ready) fail("A: not ready while empty");

    // ---- B: one word in, same word out, in that order --------------------------
    enqOne(96'hAAAA_BBBB_CCCC_DDDD_EEEE_0001, "B");
    if (!deq_valid) fail("B: deq_valid clear after enq");
    deqOne(96'hAAAA_BBBB_CCCC_DDDD_EEEE_0001, "B");
    if (deq_valid)  fail("B: deq_valid set after drain");

    // ---- C: fills up exactly at DEPTH, drains in order -------------------------
    for (int i = 0; i < DEPTH; i++) begin
      if (!enq_ready) fail($sformatf("C: not ready at entry %0d", i));
      enqOne(96'h1000 + W'(i), "C");
    end
    if (enq_ready) fail("C: still ready after DEPTH enqueues");
    for (int i = 0; i < DEPTH; i++)
      deqOne(96'h1000 + W'(i), "C");
    if (deq_valid) fail("C: still valid after full drain");

    // ---- D: enq while full is refused, nothing is lost or reordered ------------
    for (int i = 0; i < DEPTH; i++) enqOne(96'h2000 + W'(i), "D");
    enq_valid = 1; enq_data = 96'hDEAD;   // held at a closed door
    #1;
    if (enq_ready) fail("D: ready while full");
    @(posedge clk); #1;
    enq_valid = 0;
    for (int i = 0; i < DEPTH; i++)
      deqOne(96'h2000 + W'(i), "D");
    if (deq_valid) fail("D: phantom entry after refused enq");

    // ---- E: streaming, simultaneous enq + deq at partial fill ------------------
    enqOne(96'h3000, "E");
    for (int i = 1; i <= 20; i++) begin
      enq_valid = 1; enq_data = 96'h3000 + W'(i); deq_ready = 1;
      #1;
      if (!enq_ready || !deq_valid)          fail("E: stream stalled");
      else if (deq_data !== 96'h3000 + W'(i - 1)) fail("E: stream out of order");
      @(posedge clk); #1;
    end
    enq_valid = 0;
    deqOne(96'h3000 + W'(20), "E");
    if (deq_valid) fail("E: not empty after stream drain");

    // ---- F: flush empties it ---------------------------------------------------
    for (int i = 0; i < 5; i++) enqOne(96'h4000 + W'(i), "F");
    #1 flush = 1;
    @(posedge clk); #1;
    flush = 0;
    if (deq_valid)  fail("F: deq_valid set after flush");
    if (!enq_ready) fail("F: not ready after flush");
    enqOne(96'h5000, "F");
    deqOne(96'h5000, "F: first word after flush");

    // ---- G: random stress against a reference queue ----------------------------
    for (int k = 0; k < 5000; k++) begin
      automatic logic         ev = 1'($urandom());
      automatic logic         dr = 1'($urandom());
      automatic logic         fl = ($urandom_range(0, 99) == 0);
      automatic logic [W-1:0] d  = {32'($urandom()), 32'($urandom()), 32'($urandom())};
      automatic logic         mEnq, mDeq;

      enq_valid = ev; enq_data = d; deq_ready = dr; flush = fl;
      mEnq = ev && (model.size() < DEPTH);   // both judged on the pre-edge state
      mDeq = dr && (model.size() != 0);
      #1;
      if (enq_ready !== (model.size() < DEPTH)) fail("G: enq_ready vs model");
      if (deq_valid !== (model.size() != 0))    fail("G: deq_valid vs model");
      if (deq_valid && deq_data !== model[0])   fail("G: deq_data vs model");
      if (fl) model = {};
      else begin
        if (mDeq) void'(model.pop_front());
        if (mEnq) model.push_back(d);
      end
      @(posedge clk); #1;
    end
    enq_valid = 0; deq_ready = 0; flush = 0;

    if (errors == 0) $display("PASS  dispatch_fifo");
    else             $fatal(1, "FAIL  dispatch_fifo (%0d errors)", errors);
    $finish;
  end
endmodule
