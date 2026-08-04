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

  logic                   boot, redirectValid;
  logic [31:0]            redirectPC;
  logic                   btbWrEnable;
  logic [BTB_INDEX_W-1:0] btbWrIndex;
  logic [53:0]            btbWrEntry;
  logic                   phtWrEnable;
  logic [12:0]            phtWrIndex;
  logic [1:0]             phtWrCounter;
  logic [31:0]            nextPC;
  logic [31:2]            fetchPC;
  logic [1:0]             fetchHwValid;

  int errors = 0;

  bpredict #(.OUT_REG(1'b0), .BTB_INDEX_W(BTB_INDEX_W), .TAG_W(TAG_W),
             .RESET_PC(RESET_PC)) dut (
    .clk, .boot, .redirectValid, .redirectPC,
    .btbWrEnable, .btbWrIndex, .btbWrEntry,
    .phtWrEnable, .phtWrIndex, .phtWrCounter,
    .nextPC, .fetchPC, .fetchHwValid
  );

  initial begin
    #200000;
    $fatal(1, "FAIL  bpredict: watchdog fired");
  end

  // ---- recorded fetch stream ---------------------------------------------------
  logic [31:2] recPC   [0:127];
  logic [1:0]  recMask [0:127];
  int          recCount;

  task automatic step(input int cycles);
    for (int k = 0; k < cycles; k++) begin
      @(negedge clk);
      if (recCount < 128) begin
        recPC[recCount]   = fetchPC;
        recMask[recCount] = fetchHwValid;
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

endmodule

