// ================================================================================
//  respipe_tb -- result pipe against a per-age uop model
// ================================================================================
//  The bench plays the IQ (one-hot grant with its branch mask), the payload
//  (rd tag, rd write enable, rob index one cycle after the grant), the ALU
//  (a new EX0/EX1 result every cycle) and the kill sources (resolve, flush).
//  The model keeps one uop per age: a kill tests the mask it holds that cycle,
//  then the resolve clears its bit; the WB stage is never killed.
//  Checks:
//   - chk_producer: the producer of every stage, RF/RR to EX3/WB.
//   - chk_tag: the rd tag of every stage that holds a producer.
//   - chk_wb: wb_valid (rd write enable or not), wb_robIndex when valid.
//   - chk_result: the result chain moves one stage per cycle, EX0/EX1 to WB/CM.
//   - chk_cov: a kill at every age, flush and mispredict kills, a mispredict on
//   a bit an earlier resolve cleared, WB in a flush cycle, WB without rd,
//   mid-run reset.
// ================================================================================

module respipe_tb;

  logic clk = 1'b0;
  always #5 clk = !clk;

  logic        resetn = 1'b0;
  logic [7:0]  is_pr_grant = '0;
  logic [3:0]  iq_grantBranchMask = '0;
  logic [5:0]  pr_rf_rdTag = '0;
  logic        pr_rf_rdWriteEnable = 1'b0;
  logic [3:0]  pr_rf_robIndex = '0;
  logic        ex0_resolveValid = 1'b0, ex0_resolveMispredict = 1'b0, cm_flush = 1'b0;
  logic [1:0]  ex0_resolveSnapshot = '0;
  logic [31:0] ex0_ex1_result = '0;
  logic        rf_rr_producer, rr_ex0_producer, ex0_ex1_producer;
  logic        ex1_ex2_producer, ex2_ex3_producer, ex3_wb_producer;
  logic [5:0]  rf_rr_rdTag, rr_ex0_rdTag, ex0_ex1_rdTag, ex1_ex2_rdTag, ex2_ex3_rdTag, ex3_wb_rdTag;
  logic [31:0] ex1_ex2_result, ex2_ex3_result, ex3_wb_result, wb_cm_result;
  logic        wb_valid;
  logic [3:0]  wb_robIndex;

  respipe u_dut (.*);

  typedef struct {
    bit         valid;
    bit         alive;
    logic [3:0] savedBits;   // bits cleared by a correct resolve
    logic [3:0] mask;
    logic [5:0] rdTag;
    bit         rdWriteEnable;
    logic [3:0] robIndex;
  } uop_t;

  uop_t        pipe [8];   // [a]: the uop at age a, 1 = PR/RF ... 7 = EX3/WB
  uop_t        cur;        // age 0: on is_pr_grant this cycle
  logic [31:0] driven [4]; // ex0_ex1_result of the last 4 cycles
  int          warm, errors = 0, checks = 0;
  int          cov [string];
  int          pGrant, pResolve, pMispredict, pFlush;
  string       covNeed [] = '{"killFlush", "killMispredict", "savedHit", "wbInFlush", "wbNoRd",
                              "midReset"};

  task automatic fail(string c, string m);
    errors++;
    if (errors <= 20) $display("ERROR %s %s", c, m);
  endtask

  task automatic clearModel();
    foreach (pipe[a]) pipe[a] = '{default: '0};
    warm = 0;
  endtask

  // ---- outputs just before the edge against the model --------------------------
  task automatic checkStage(string name, int a, logic producer, logic [5:0] rdTag);
    bit exp = pipe[a].valid && pipe[a].alive && pipe[a].rdWriteEnable;
    checks++;
    if (producer !== exp) fail("chk_producer", $sformatf("%s %b exp %b", name, producer, exp));
    else if (exp && rdTag !== pipe[a].rdTag)
      fail("chk_tag", $sformatf("%s %0d exp %0d", name, rdTag, pipe[a].rdTag));
  endtask

  task automatic checkOutputs();
    bit expWb = pipe[7].valid && pipe[7].alive;
    checkStage("rf_rr",   2, rf_rr_producer,   rf_rr_rdTag);
    checkStage("rr_ex0",  3, rr_ex0_producer,  rr_ex0_rdTag);
    checkStage("ex0_ex1", 4, ex0_ex1_producer, ex0_ex1_rdTag);
    checkStage("ex1_ex2", 5, ex1_ex2_producer, ex1_ex2_rdTag);
    checkStage("ex2_ex3", 6, ex2_ex3_producer, ex2_ex3_rdTag);
    checkStage("ex3_wb",  7, ex3_wb_producer,  ex3_wb_rdTag);
    if (wb_valid !== expWb) fail("chk_wb", $sformatf("wb_valid %b exp %b", wb_valid, expWb));
    else if (expWb && wb_robIndex !== pipe[7].robIndex)
      fail("chk_wb", $sformatf("wb_robIndex %0d exp %0d", wb_robIndex, pipe[7].robIndex));
    if (expWb && !pipe[7].rdWriteEnable) cov["wbNoRd"]++;
    if (warm >= 4) begin
      if (ex1_ex2_result !== driven[0]) fail("chk_result", $sformatf("ex1_ex2 %h exp %h", ex1_ex2_result, driven[0]));
      if (ex2_ex3_result !== driven[1]) fail("chk_result", $sformatf("ex2_ex3 %h exp %h", ex2_ex3_result, driven[1]));
      if (ex3_wb_result  !== driven[2]) fail("chk_result", $sformatf("ex3_wb %h exp %h",  ex3_wb_result,  driven[2]));
      if (wb_cm_result   !== driven[3]) fail("chk_result", $sformatf("wb_cm %h exp %h",   wb_cm_result,   driven[3]));
    end
  endtask

  task automatic shiftDriven();
    for (int k = 3; k >= 1; k--) driven[k] = driven[k - 1];
    driven[0] = ex0_ex1_result;
    warm++;
  endtask

  // ---- one cycle: drive, check before the edge, move the model across it -------
  task automatic cycle(bit doReset = 1'b0);
    logic [3:0] clear;
    bit         mispredict;

    @(posedge clk); #1;
    resetn = !doReset;
    cur = '{default: '0};
    if (!doReset && $urandom_range(99) < pGrant) begin
      cur.valid         = 1'b1;
      cur.alive         = 1'b1;
      cur.mask          = 4'($urandom);
      cur.rdTag         = 6'($urandom);
      cur.rdWriteEnable = $urandom_range(3) != 0;
      cur.robIndex      = 4'($urandom);
    end
    is_pr_grant        = cur.valid ? 8'(1) << $urandom_range(7) : '0;
    iq_grantBranchMask = cur.valid ? cur.mask : 4'($urandom);
    // PR/RF fields belong to last cycle's grant; garbage when there was none
    pr_rf_rdTag         = pipe[1].valid ? pipe[1].rdTag         : 6'($urandom);
    pr_rf_rdWriteEnable = pipe[1].valid ? pipe[1].rdWriteEnable : 1'($urandom);
    pr_rf_robIndex      = pipe[1].valid ? pipe[1].robIndex      : 4'($urandom);
    ex0_resolveValid      = $urandom_range(99) < pResolve;
    ex0_resolveSnapshot   = 2'($urandom);
    ex0_resolveMispredict = $urandom_range(99) < pMispredict;
    cm_flush              = $urandom_range(999) < pFlush;
    ex0_ex1_result        = $urandom;

    #7;
    checkOutputs();
    if (pipe[7].valid && pipe[7].alive && cm_flush) cov["wbInFlush"]++;
    if (doReset) begin
      if (pipe[7].valid && pipe[7].alive) cov["midReset"]++;
      clearModel();
      shiftDriven();
      return;
    end

    mispredict = ex0_resolveValid && ex0_resolveMispredict;
    clear      = ex0_resolveValid ? 4'(1) << ex0_resolveSnapshot : 4'b0;
    for (int a = 0; a <= 6; a++) begin
      uop_t u = a == 0 ? cur : pipe[a];
      if (u.valid && u.alive) begin
        if (cm_flush || (mispredict && u.mask[ex0_resolveSnapshot])) begin
          u.alive = 1'b0;
          cov[$sformatf("killAt%0d", a)]++;
          cov[cm_flush ? "killFlush" : "killMispredict"]++;
        end else if (mispredict && u.savedBits[ex0_resolveSnapshot]) begin
          cov["savedHit"]++;
        end
        if (!mispredict) u.savedBits |= clear & u.mask;
        u.mask &= ~clear;
      end
      if (a == 0) cur = u; else pipe[a] = u;
    end
    for (int a = 7; a >= 2; a--) pipe[a] = pipe[a - 1];
    pipe[1] = cur;
    shiftDriven();
  endtask

  task automatic phase(string name, int n, int g, int r, int m, int f);
    pGrant = g; pResolve = r; pMispredict = m; pFlush = f;
    repeat (n) cycle();
    $display("phase %-8s done, %0d errors so far", name, errors);
  endtask

  int seed;
  initial begin
    if (!$value$plusargs("seed=%d", seed)) seed = 1;
    void'($urandom(seed));
    repeat (64) void'($urandom);
    clearModel();

    repeat (3) @(posedge clk);
    #1 resetn = 1'b1;

    //     name       cycles grant resolve mispredict flush(/1000)
    phase("dense",    50000,  90,     20,        20,    5);
    phase("sparse",   50000,  30,     10,        10,    2);
    phase("kill",     50000,  80,     50,        50,   20);

    // ---- reset with the pipe full ----------------------------------------------
    pGrant = 100; pResolve = 0; pFlush = 0;
    repeat (8) cycle();
    cycle(1'b1);
    phase("mixed",    50000,  60,     30,        30,    5);

    foreach (cov[k]) $display("  cov %-16s %0d", k, cov[k]);
    for (int a = 0; a <= 6; a++)
      if (!cov.exists($sformatf("killAt%0d", a))) fail("chk_cov", $sformatf("killAt%0d", a));
    foreach (covNeed[i]) if (!cov.exists(covNeed[i])) fail("chk_cov", covNeed[i]);
    if (errors == 0) $display("PASS  respipe (%0d stage checks)", checks);
    else             $fatal(1, "FAIL  respipe (%0d errors)", errors);
    $finish;
  end

endmodule
