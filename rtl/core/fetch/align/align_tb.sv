// ================================================================================
//  align_tb -- drives the aligner from a behavioural fetch queue and checks the
//  instruction stream it produces: both widths, both positions, straddles,
//  dead halfwords, backpressure and flush.
// ================================================================================
module align_tb;
  logic clk = 0;
  always #5 clk = ~clk;

  logic        resetn, flush;
  logic        fq_validA, fq_validB;
  logic [31:2] fq_pcA;
  logic [1:0]  fq_hwValidA, fq_hwValidB;
  logic [12:0] fq_gshareA;
  logic [2:0]  fq_rasPtrA;
  logic [31:0] fq_wordA, fq_wordB;
  logic [1:0]  fq_take;
  logic        out_valid, out_isCompressed, out_ready;
  logic [31:1] out_pc;
  logic [31:0] out_instr;
  logic [12:0] out_gshare;
  logic [2:0]  out_rasPtr;

  int errors = 0;

  align dut (
    .clk, .resetn, .flush,
    .fq_validA, .fq_pcA, .fq_hwValidA, .fq_gshareA, .fq_rasPtrA, .fq_wordA,
    .fq_validB, .fq_hwValidB, .fq_wordB, .fq_take,
    .out_valid, .out_pc, .out_instr, .out_isCompressed, .out_gshare, .out_rasPtr,
    .out_ready
  );

  initial begin
    #500000;
    $fatal(1, "FAIL  align: watchdog fired");
  end

  // ---- behavioural fetch queue -------------------------------------------------
  logic [31:0] mWord [0:63];
  logic [31:2] mPc   [0:63];
  logic [1:0]  mHw   [0:63];
  logic [12:0] mGs   [0:63];
  logic [2:0]  mRp   [0:63];
  logic [5:0]  mHead;
  int          mCount;

  assign fq_validA   = (mCount >= 1);
  assign fq_validB   = (mCount >= 2);
  assign fq_pcA      = mPc  [mHead];
  assign fq_hwValidA = mHw  [mHead];
  assign fq_gshareA  = mGs  [mHead];
  assign fq_rasPtrA  = mRp  [mHead];
  assign fq_wordA    = mWord[mHead];
  assign fq_hwValidB = mHw  [mHead + 6'd1];
  assign fq_wordB    = mWord[mHead + 6'd1];

  logic [5:0] mTail;
  always_ff @(posedge clk) begin
    if (fq_take != 2'd0) begin
      mHead  <= mHead + 6'(fq_take);
      mCount <= mCount - int'(fq_take);
    end
  end

  task automatic push(input logic [31:0] pc, input logic [1:0] hw,
                      input logic [31:0] word);
    mWord[mTail] = word;
    mPc  [mTail] = pc[31:2];
    mGs  [mTail] = 13'(pc >> 2);
    mRp  [mTail] = 3'(pc >> 2);
    mHw  [mTail] = hw;
    mTail        = mTail + 6'd1;
    mCount       = mCount + 1;
  endtask

  // repointing the fetch stream always comes with a flush in the real machine
  task automatic restart();
    flush = 1'b1;
    @(negedge clk);
    flush = 1'b0;
    resetModel();
  endtask

  task automatic resetModel();
    mHead  = '0;
    mTail  = '0;
    mCount = 0;
  endtask

  // ---- instruction payloads that are self-identifying ---------------------------
  function automatic logic [15:0] cw(input int n); return {8'(n), 8'h01}; endfunction
  function automatic logic [31:0] ww(input int n); return {24'(n), 8'h33}; endfunction

  // ---- wait for the next accepted instruction and check it ---------------------
  task automatic expectEmit(input logic [31:0] pc, input logic [31:0] instr,
                            input logic isC, input logic [1:0] take,
                            input string note);
    int guard;
    #1;                        // let the model's assigns settle after a push
    guard = 0;
    while (!(out_valid && out_ready) && guard < 60) begin
      @(negedge clk); guard++;
    end
    if (guard >= 60) begin
      $error("%-30s nothing emitted", note); errors++; return;
    end
    if (out_pc !== pc[31:1]) begin
      $error("%-30s pc=%h (expected %h)", note, {out_pc, 1'b0}, pc); errors++;
    end else if (out_isCompressed !== isC) begin
      $error("%-30s isCompressed=%b (expected %b)", note, out_isCompressed, isC);
      errors++;
    end else if (isC ? (out_instr[15:0] !== instr[15:0])
                     : (out_instr      !== instr)) begin
      $error("%-30s instr=%h (expected %h)", note, out_instr, instr); errors++;
    end else if (out_gshare !== 13'(({out_pc, 1'b0}) >> 2)) begin
      $error("%-30s gshare=%h (expected %h)", note, out_gshare,
             13'(({out_pc, 1'b0}) >> 2)); errors++;
    end else if (out_rasPtr !== 3'(({out_pc, 1'b0}) >> 2)) begin
      $error("%-30s rasPtr=%h (expected %h)", note, out_rasPtr,
             3'(({out_pc, 1'b0}) >> 2)); errors++;
    end else if (fq_take !== take) begin
      $error("%-30s take=%0d (expected %0d)", note, fq_take, take); errors++;
    end
    @(negedge clk);
  endtask

  task automatic expectIdle(input string note);
    #1;
    if (out_valid !== 1'b0) begin
      $error("%-30s out_valid high with nothing to emit", note); errors++;
    end
  endtask

  initial begin
    resetn = 1'b0; flush = 1'b0; out_ready = 1'b1;
    resetModel();
    @(negedge clk); @(negedge clk);
    resetn = 1'b1;

    checkTwoCompressed();
    checkWideAligned();
    checkStraddleLiveTail();
    checkStraddleDeadTail();
    checkEnteredHigh();
    checkExitAfterLow();
    checkStraddleStall();
    checkBackpressure();
    checkFlush();

    if (errors == 0) $display("PASS  align");
    else             $fatal(1, "FAIL  align (%0d errors)", errors);
    $finish;
  end

  // ---- two compressed instructions share one word ------------------------------
  task automatic checkTwoCompressed();
    restart();
    push(32'h0000_1000, 2'b11, {cw(2), cw(1)});
    expectEmit(32'h0000_1000, {16'b0, cw(1)}, 1'b1, 2'd0, "2x16: low half");
    expectEmit(32'h0000_1002, {16'b0, cw(2)}, 1'b1, 2'd1, "2x16: high half");
    @(negedge clk);
    expectIdle("2x16: drained");
  endtask

  // ---- one 32-bit instruction filling a word -----------------------------------
  task automatic checkWideAligned();
    restart();
    push(32'h0000_1010, 2'b11, ww(5));
    expectEmit(32'h0000_1010, ww(5), 1'b0, 2'd1, "32 aligned");
    @(negedge clk);
    expectIdle("32 aligned: drained");
  endtask

  // ---- straddle where the tail word still has a live high half -----------------
  task automatic checkStraddleLiveTail();
    logic [31:0] w;
    restart();
    w = ww(7);
    push(32'h0000_1020, 2'b11, {w[15:0],  cw(9)});
    push(32'h0000_1024, 2'b11, {cw(10),   w[31:16]});
    expectEmit(32'h0000_1020, {16'b0, cw(9)},  1'b1, 2'd0, "straddle: leading 16");
    expectEmit(32'h0000_1022, w,               1'b0, 2'd1, "straddle: the 32");
    expectEmit(32'h0000_1026, {16'b0, cw(10)}, 1'b1, 2'd1, "straddle: trailing 16");
    @(negedge clk);
    expectIdle("straddle: drained");
  endtask

  // ---- straddle into a tail whose high half is dead: both entries retire -------
  task automatic checkStraddleDeadTail();
    logic [31:0] w;
    restart();
    w = ww(8);
    push(32'h0000_1030, 2'b11, {w[15:0], cw(11)});
    push(32'h0000_1034, 2'b01, {cw(12),  w[31:16]});   // straddle tail
    push(32'h0000_2000, 2'b11, {cw(13),  cw(14)});     // branch target
    expectEmit(32'h0000_1030, {16'b0, cw(11)}, 1'b1, 2'd0, "dead tail: leading 16");
    expectEmit(32'h0000_1032, w,               1'b0, 2'd2, "dead tail: pops both");
    expectEmit(32'h0000_2000, {16'b0, cw(14)}, 1'b1, 2'd0, "dead tail: target low");
    expectEmit(32'h0000_2002, {16'b0, cw(13)}, 1'b1, 2'd1, "dead tail: target high");
    @(negedge clk);
    expectIdle("dead tail: drained");
  endtask

  // ---- redirect landed on an odd halfword: the low half is never decoded -------
  task automatic checkEnteredHigh();
    restart();
    push(32'h0000_1040, 2'b10, {cw(15), cw(16)});
    expectEmit(32'h0000_1042, {16'b0, cw(15)}, 1'b1, 2'd1, "entered high");
    @(negedge clk);
    expectIdle("entered high: drained");
  endtask

  // ---- compressed branch in the low half: the high half is never decoded -------
  task automatic checkExitAfterLow();
    restart();
    push(32'h0000_1050, 2'b01, {cw(17), cw(18)});
    push(32'h0000_3000, 2'b11, {cw(19), cw(20)});
    expectEmit(32'h0000_1050, {16'b0, cw(18)}, 1'b1, 2'd1, "exit low: branch");
    expectEmit(32'h0000_3000, {16'b0, cw(20)}, 1'b1, 2'd0, "exit low: target");
  endtask

  // ---- a straddle cannot be formed until the second word arrives ---------------
  task automatic checkStraddleStall();
    logic [31:0] w;
    restart();
    w = ww(21);
    push(32'h0000_1060, 2'b11, {w[15:0], cw(22)});
    expectEmit(32'h0000_1060, {16'b0, cw(22)}, 1'b1, 2'd0, "stall: leading 16");
    repeat (3) begin
      expectIdle("stall: waiting for tail");
      @(negedge clk);
    end
    push(32'h0000_1064, 2'b11, {cw(23), w[31:16]});
    expectEmit(32'h0000_1062, w, 1'b0, 2'd1, "stall: released");
  endtask

  // ---- decode backpressure must freeze the queue entirely ----------------------
  task automatic checkBackpressure();
    restart();
    push(32'h0000_1070, 2'b11, ww(24));              // retires an entry
    push(32'h0000_1074, 2'b11, {cw(26), cw(27)});    // two compressed
    out_ready = 1'b0;
    repeat (4) begin
      @(negedge clk);
      if (fq_take !== 2'd0) begin
        $error("backpressure: retired %0d entries with out_ready low", fq_take);
        errors++;
      end
      if (out_valid !== 1'b1) begin
        $error("backpressure: out_valid dropped while stalled"); errors++;
      end
    end
    out_ready = 1'b1;
    expectEmit(32'h0000_1070, ww(24), 1'b0, 2'd1, "backpressure: wide resumed");

    // stall again mid-word: the position must not creep forward
    out_ready = 1'b0;
    repeat (3) begin
      @(negedge clk);
      if (fq_take !== 2'd0) begin
        $error("backpressure: retired mid-word while stalled"); errors++;
      end
    end
    out_ready = 1'b1;
    expectEmit(32'h0000_1074, {16'b0, cw(27)}, 1'b1, 2'd0, "backpressure: held position");
    expectEmit(32'h0000_1076, {16'b0, cw(26)}, 1'b1, 2'd1, "backpressure: then advances");
  endtask

  // ---- flush returns the aligner to the start of whatever comes next -----------
  task automatic checkFlush();
    restart();
    push(32'h0000_1080, 2'b11, {cw(28), cw(29)});
    expectEmit(32'h0000_1080, {16'b0, cw(29)}, 1'b1, 2'd0, "flush: first half");
    // aligner is now parked on the high half; flush and repoint the queue
    flush = 1'b1;
    @(negedge clk);
    flush = 1'b0;
    resetModel();
    push(32'h0000_4000, 2'b11, {cw(30), cw(31)});
    expectEmit(32'h0000_4000, {16'b0, cw(31)}, 1'b1, 2'd0, "flush: restarts low");
  endtask

endmodule
