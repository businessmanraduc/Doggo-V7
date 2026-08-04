// ================================================================================
//  bpredict_tb -- installs one branch in the BTB, runs the fetch stream, and
//  checks the halfword-valid mask published for every word the frontend issues.
//  Covers the four shapes a taken branch can take, plus the prediction shadow.
// ================================================================================
module bpredict_tb;
  localparam int          BTB_INDEX_W = 9;
  localparam int          TAG_W       = 11;
  localparam logic [31:0] RESET_PC    = 32'h0000_0800;

  logic clk = 0;
  always #5 clk = ~clk;

  logic                   boot, redirectValid, stall;
  logic [31:0]            redirectPC;
  logic [12:0]            redirectBHR;
  logic                   btbWrEnable;
  logic [BTB_INDEX_W-1:0] btbWrIndex;
  logic [53:0]            btbWrEntry;
  logic                   phtWrEnable;
  logic [12:0]            phtWrIndex;
  logic [1:0]             phtWrCounter;
  logic [31:0]            nextPC;
  logic                   fetchValid;
  logic [31:2]            fetchPC;
  logic [1:0]             fetchHwValid;
  logic [12:0]            fetchGshare;

  int errors = 0;

  bpredict #(.OUT_REG(1'b0), .BTB_INDEX_W(BTB_INDEX_W), .TAG_W(TAG_W),
             .RESET_PC(RESET_PC)) dut (
    .clk, .boot, .redirectValid, .redirectPC, .redirectBHR, .stall,
    .btbWrEnable, .btbWrIndex, .btbWrEntry,
    .phtWrEnable, .phtWrIndex, .phtWrCounter,
    .nextPC, .fetchValid, .fetchPC, .fetchHwValid, .fetchGshare
  );

  initial begin
    #200000;
    $fatal(1, "FAIL  bpredict: watchdog fired");
  end

  // ---- recorded fetch stream ---------------------------------------------------
  logic [31:2] recPC   [0:127];
  logic [1:0]  recMask [0:127];
  logic [12:0] recGs   [0:127];
  int          recCount;

  task automatic step(input int cycles);
    for (int k = 0; k < cycles; k++) begin
      @(negedge clk);
      if (fetchValid && recCount < 128) begin
        recPC[recCount]   = fetchPC;
        recMask[recCount] = fetchHwValid;
        recGs[recCount]   = fetchGshare;
        recCount++;
      end
    end
  endtask

  function automatic int findPC(input logic [31:0] pc);
    for (int k = 0; k < recCount; k++) if (recPC[k] === pc[31:2]) return k;
    return -1;
  endfunction

  // ---- entry as btb.sv slices it: index and tag both come from the word --------
  function automatic logic [53:0] packEntry(
    input logic cond, strd, exitLow,
    input logic [31:0] word, input logic [31:0] tgt);
    logic [53:0] e;
    e = '0;
    e[53] = 1'b1;              // valid
    e[52] = 1'b1;              // isBranch
    e[51] = cond;
    e[50] = strd;
    e[49] = exitLow;
    e[31 +: TAG_W] = word[BTB_INDEX_W+TAG_W+1 : BTB_INDEX_W+2];
    e[30:0]        = tgt[31:1];
    return e;
  endfunction

  task automatic installBranch(
    input logic [31:0] word, input logic [31:0] tgt, input logic strd, exitLow);
    @(negedge clk);
    btbWrEnable = 1'b1;
    btbWrIndex  = word[BTB_INDEX_W+1 : 2];
    btbWrEntry  = packEntry(1'b0, strd, exitLow, word, tgt);
    @(negedge clk);
    btbWrEnable = 1'b0;
  endtask

  task automatic installBranchC(
    input logic [31:0] word, input logic [31:0] tgt, input logic cond);
    @(negedge clk);
    btbWrEnable = 1'b1;
    btbWrIndex  = word[BTB_INDEX_W+1 : 2];
    btbWrEntry  = packEntry(cond, 1'b0, 1'b0, word, tgt);
    @(negedge clk);
    btbWrEnable = 1'b0;
  endtask

  //  index as bpredict folds it: the probe address xor the history in use
  task automatic trainPht(input logic [31:0] word, input logic [12:0] bhr,
                          input logic [1:0] counter);
    @(negedge clk);
    phtWrEnable  = 1'b1;
    phtWrIndex   = word[14:2] ^ bhr;
    phtWrCounter = counter;
    @(negedge clk);
    phtWrEnable  = 1'b0;
  endtask

  // ---- jump the frontend somewhere and record what it issues -------------------
  task automatic runFrom(input logic [31:0] start, input int cycles);
    @(negedge clk);
    redirectValid = 1'b1;
    redirectPC    = start;
    @(negedge clk);
    redirectValid = 1'b0;
    recCount = 0;
    step(cycles);
  endtask

  task automatic runFromParked(input logic [31:0] start, input int cycles,
                               input int parkAfter, input int parkLen);
    @(negedge clk);
    redirectValid = 1'b1;
    redirectPC    = start;
    @(negedge clk);
    redirectValid = 1'b0;
    recCount = 0;
    step(parkAfter);
    stall = 1'b1;
    repeat (parkLen) @(negedge clk);
    stall = 1'b0;
    step(cycles - parkAfter);
  endtask

  task automatic expectAt(input int idx, input logic [31:0] pc,
                          input logic [1:0] mask, input string note);
    if (idx < 0 || idx >= recCount) begin
      $error("%-28s no record at index %0d", note, idx); errors++;
    end else if (recPC[idx] !== pc[31:2]) begin
      $error("%-28s slot %0d is word %h (expected %h)",
             note, idx, {recPC[idx], 2'b00}, {pc[31:2], 2'b00}); errors++;
    end else if (recMask[idx] !== mask) begin
      $error("%-28s word %h mask=%b (expected %b)",
             note, {recPC[idx], 2'b00}, recMask[idx], mask); errors++;
    end
  endtask

  initial begin
    boot = 1'b0; redirectValid = 1'b0; redirectPC = '0;
    redirectBHR = '0; stall = 1'b0;
    btbWrEnable = 1'b0; btbWrIndex = '0; btbWrEntry = '0;
    phtWrEnable = 1'b0; phtWrIndex = '0; phtWrCounter = '0;
    recCount = 0;

    @(negedge clk);
    boot = 1'b1;
    @(negedge clk);
    boot = 1'b0;
    step(8);

    checkWideBranchLowHalf();
    checkCompressedBranchLowHalf();
    checkStraddlingBranch();
    checkOddHalfwordTarget();
    checkShadowAfterRedirect();
    checkStallParksFetch();
    checkStallKeepsPrediction();
    checkBhrRestore();
    checkBhrConditionalOnly();
    checkBhrAcrossPark();
    checkGshareAlignment();
    checkGshareAcrossShift();

    if (errors == 0) $display("PASS  bpredict");
    else             $fatal(1, "FAIL  bpredict (%0d errors)", errors);
    $finish;
  end

  // ---- 32-bit branch filling the low half: whole word live, then the overrun ---
  task automatic checkWideBranchLowHalf();
    int i;
    installBranch(32'h0000_1010, 32'h0000_3000, 1'b0, 1'b0);
    runFrom(32'h0000_1000, 24);
    i = findPC(32'h0000_1010);
    expectAt(i,   32'h0000_1010, 2'b11, "wide/low: branch word");
    expectAt(i+1, 32'h0000_1014, 2'b00, "wide/low: overrun killed");
    expectAt(i+2, 32'h0000_3000, 2'b11, "wide/low: target");
  endtask

  // ---- 16-bit branch in the low half: the high half must be cut off ------------
  task automatic checkCompressedBranchLowHalf();
    int i;
    installBranch(32'h0000_1110, 32'h0000_3100, 1'b0, 1'b1);
    runFrom(32'h0000_1100, 24);
    i = findPC(32'h0000_1110);
    expectAt(i,   32'h0000_1110, 2'b01, "cmp/low: high half cut");
    expectAt(i+1, 32'h0000_1114, 2'b00, "cmp/low: overrun killed");
    expectAt(i+2, 32'h0000_3100, 2'b11, "cmp/low: target");
  endtask

  // ---- straddling branch: tail word keeps its low half, then the overrun -------
  task automatic checkStraddlingBranch();
    int i;
    installBranch(32'h0000_1210, 32'h0000_3200, 1'b1, 1'b0);
    runFrom(32'h0000_1200, 24);
    i = findPC(32'h0000_1210);
    expectAt(i,   32'h0000_1210, 2'b11, "straddle: branch word");
    expectAt(i+1, 32'h0000_1214, 2'b01, "straddle: tail low half only");
    expectAt(i+2, 32'h0000_1218, 2'b00, "straddle: overrun killed");
    expectAt(i+3, 32'h0000_3200, 2'b11, "straddle: target");
  endtask

  // ---- target with bit 1 set: the target word starts at its high half ----------
  task automatic checkOddHalfwordTarget();
    int i;
    installBranch(32'h0000_1310, 32'h0000_3302, 1'b0, 1'b0);
    runFrom(32'h0000_1300, 24);
    i = findPC(32'h0000_1310);
    expectAt(i,   32'h0000_1310, 2'b11, "odd tgt: branch word");
    expectAt(i+1, 32'h0000_1314, 2'b00, "odd tgt: overrun killed");
    expectAt(i+2, 32'h0000_3300, 2'b10, "odd tgt: low half skipped");
    expectAt(i+3, 32'h0000_3304, 2'b11, "odd tgt: back to normal");
  endtask

  // ---- verdicts in flight behind a redirect describe wrong-path words ----------
  task automatic checkShadowAfterRedirect();
    installBranch(32'h0000_1508, 32'h0000_3500, 1'b0, 1'b0);

    @(negedge clk); redirectValid = 1'b1; redirectPC = 32'h0000_1500;
    @(negedge clk); redirectValid = 1'b0;
    step(1);                     // 0x1508 gets probed in here

    @(negedge clk); redirectValid = 1'b1; redirectPC = 32'h0000_1600;
    @(negedge clk); redirectValid = 1'b0;

    recCount = 0;
    step(12);

    if (findPC(32'h0000_3500) >= 0) begin
      $error("shadow: a stale verdict still redirected the frontend");
      errors++;
    end
    if (findPC(32'h0000_1600) < 0) begin
      $error("shadow: frontend never reached the redirect target");
      errors++;
    end
  endtask

  // ---- parking freezes the fetch stream and issues no words -------------------
  task automatic checkStallParksFetch();
    logic [31:0] frozen;
    runFrom(32'h0000_1700, 4);
    frozen = nextPC;
    stall  = 1'b1;
    repeat (5) begin
      @(negedge clk);
      if (nextPC !== frozen) begin
        $error("park: nextPC advanced to %h while parked", nextPC); errors++;
      end
      if (fetchValid !== 1'b0) begin
        $error("park: fetchValid high while parked"); errors++;
      end
    end
    stall = 1'b0;
    @(negedge clk);
    if (fetchValid !== 1'b1) begin
      $error("park: fetchValid did not resume"); errors++;
    end
    @(negedge clk);
    if (nextPC === frozen) begin
      $error("park: nextPC did not resume"); errors++;
    end
  endtask

  // ---- a park may delay the fetch stream but must never alter it -------------
  task automatic checkStallKeepsPrediction();
    logic [31:2] refPC [0:63];
    int          refCount;

    redirectBHR = '0;
    installBranchC(32'h0000_7010, 32'h0000_3700, 1'b1);
    trainPht(32'h0000_7010, 13'h0, 2'd3);

    runFrom(32'h0000_7000, 24);
    refCount = recCount;
    for (int k = 0; k < recCount; k++) refPC[k] = recPC[k];
    if (findPC(32'h0000_3700) < 0) begin
      $error("park: reference run never reached the target"); errors++;
    end

    for (int lead = 1; lead <= 6; lead++) begin
      @(negedge clk); redirectValid = 1'b1; redirectPC = 32'h0000_7000;
      @(negedge clk); redirectValid = 1'b0;
      recCount = 0;
      step(lead);
      stall = 1'b1;
      repeat (5) @(negedge clk);
      stall = 1'b0;
      step(24);

      if (recCount < refCount) begin
        $error("park(lead %0d): issued %0d words, reference issued %0d",
               lead, recCount, refCount); errors++;
      end else begin
        for (int k = 0; k < refCount; k++) begin
          if (recPC[k] !== refPC[k]) begin
            $error("park(lead %0d): word %0d is %h, reference issued %h",
                   lead, k, {recPC[k], 2'b00}, {refPC[k], 2'b00}); errors++;
          end
        end
      end
    end
  endtask

  // ---- a park must not disturb the branch history either ---------------------
  task automatic checkBhrAcrossPark();
    logic [12:0] refBhr;
    logic [12:0] base;
    base        = 13'h1555;
    redirectBHR = base;
    installBranchC(32'h0000_8010, 32'h0000_3800, 1'b1);

    runFrom(32'h0000_8000, 16);
    refBhr = dut.branchHistory;
    if (refBhr === base) begin
      $error("bhr/park: reference run never shifted the history"); errors++;
    end

    for (int lead = 1; lead <= 6; lead++) begin
      @(negedge clk); redirectValid = 1'b1; redirectPC = 32'h0000_8000;
      @(negedge clk); redirectValid = 1'b0;
      step(lead);
      stall = 1'b1;
      repeat (5) @(negedge clk);
      stall = 1'b0;
      step(16);
      if (dut.branchHistory !== refBhr) begin
        $error("bhr/park(lead %0d): history %h, undisturbed run gave %h",
               lead, dut.branchHistory, refBhr); errors++;
      end
    end
  endtask

  // ---- a redirect reloads the history the backend recovered -------------------
  task automatic checkBhrRestore();
    redirectBHR = 13'h1555;
    @(negedge clk); redirectValid = 1'b1; redirectPC = 32'h0000_1800;
    @(negedge clk); redirectValid = 1'b0;
    if (dut.branchHistory !== 13'h1555) begin
      $error("bhr: restore loaded %h (expected 1555)", dut.branchHistory); errors++;
    end
  endtask

  // ---- the history moves on conditional branches and nothing else -------------
  task automatic checkBhrConditionalOnly();
    logic [12:0] base;
    base        = 13'h1555;
    redirectBHR = base;

    // plain sequential code must not disturb it
    @(negedge clk); redirectValid = 1'b1; redirectPC = 32'h0000_5100;
    @(negedge clk); redirectValid = 1'b0;
    repeat (10) @(negedge clk);
    if (dut.branchHistory !== base) begin
      $error("bhr: shifted %h with no branches in the stream", dut.branchHistory);
      errors++;
    end

    // an unconditional branch consults no counter, so it contributes nothing
    installBranchC(32'h0000_5010, 32'h0000_3500, 1'b0);
    runFrom(32'h0000_5000, 12);
    if (dut.branchHistory !== base) begin
      $error("bhr: shifted %h on an unconditional branch", dut.branchHistory);
      errors++;
    end

    // a conditional branch shifts in the direction the PHT gave
    installBranchC(32'h0000_6010, 32'h0000_3600, 1'b1);
    runFrom(32'h0000_6000, 12);
    if (dut.branchHistory !== {base[11:0], 1'b0}) begin
      $error("bhr: conditional gave %h (expected %h)",
             dut.branchHistory, {base[11:0], 1'b0}); errors++;
    end
  endtask

  // ---- the snapshot must be the index the PHT was actually probed with ---------
  task automatic checkGshareAlignment();
    logic [12:0] bhr;

    bhr         = 13'h0000;
    redirectBHR = bhr;
    runFrom(32'h0000_7000, 10);
    expectGshareRun(bhr, "gshare: zero history");

    bhr         = 13'h1AC5;
    redirectBHR = bhr;
    runFrom(32'h0000_7400, 10);
    expectGshareRun(bhr, "gshare: loaded history");
  endtask

  task automatic expectGshareRun(input logic [12:0] bhr, input string note);
    if (recCount < 4) begin
      $error("%-28s only %0d words recorded", note, recCount); errors++;
      return;
    end
    for (int k = 0; k < recCount; k++) begin
      if (recGs[k] !== (recPC[k][14:2] ^ bhr)) begin
        $error("%-28s word %h gshare=%h (expected %h)", note,
               {recPC[k], 2'b00}, recGs[k], recPC[k][14:2] ^ bhr); errors++;
        return;
      end
    end
  endtask

  // ---- the snapshot must move with the history, three words behind the branch --
  task automatic checkGshareAcrossShift();
    logic [12:0] b, bAfter;
    int i;

    b      = 13'h1AC5;
    bAfter = {b[11:0], 1'b0};

    redirectBHR = b;
    trainPht(32'h0000_7810, b, 2'd0);              // strongly not taken
    installBranchC(32'h0000_7810, 32'h0000_3700, 1'b1);
    runFrom(32'h0000_7800, 14);

    expectShiftStream(b, bAfter, "gshare shift");

    //  a park freezes the history pipeline with everything else, so the same
    //  stream must come out whatever cycle it lands on
    for (int p = 1; p <= 6; p++) begin
      runFromParked(32'h0000_7800, 14, p, 3);
      expectShiftStream(b, bAfter, $sformatf("gshare park@%0d", p));
    end
  endtask

  task automatic expectShiftStream(input logic [12:0] b, input logic [12:0] bAfter,
                                   input string note);
    int i;
    i = findPC(32'h0000_7810);
    if (i < 0 || i + 4 >= recCount) begin
      $error("%-28s branch word not in the recorded stream", note); errors++;
      return;
    end
    expectGshareAt(i,   32'h0000_7810, b,      {note, ": branch word"});
    expectGshareAt(i+1, 32'h0000_7814, b,      {note, ": +1 old history"});
    expectGshareAt(i+2, 32'h0000_7818, b,      {note, ": +2 old history"});
    expectGshareAt(i+3, 32'h0000_781C, bAfter, {note, ": +3 new history"});
    expectGshareAt(i+4, 32'h0000_7820, bAfter, {note, ": +4 new history"});
  endtask

  task automatic expectGshareAt(input int idx, input logic [31:0] pc,
                                input logic [12:0] bhr, input string note);
    if (recPC[idx] !== pc[31:2]) begin
      $error("%-28s slot %0d is word %h (expected %h)",
             note, idx, {recPC[idx], 2'b00}, pc); errors++;
    end else if (recGs[idx] !== (pc[14:2] ^ bhr)) begin
      $error("%-28s word %h gshare=%h (expected %h)",
             note, pc, recGs[idx], pc[14:2] ^ bhr); errors++;
    end
  endtask

endmodule

