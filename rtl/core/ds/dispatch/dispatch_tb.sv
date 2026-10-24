// ================================================================================
//  dispatch_tb -- DS fire and stall against an ROB, IQ and predisp model
// ================================================================================
//  R2 fields change every cycle, also under a stall, so a flag sampled at the
//  wrong time shows up. The environment reacts to the DUT's outputs: predisp
//  holds on stall and clears on a kill, the ROB counts fires and commits and
//  drops a fire in a kill cycle, the IQ ready flag is random.
//  Checks:
//   - chk_fire: every output equals the reference (0060 equations).
//   - chk_stall: stall = valid & !fire.
//   - chk_iq: iqFire = iqGo & iqReady; no IQ write for system or illegal.
//   - chk_serial: a serialising uop fires only into an empty ROB.
//   - chk_robFull: no fire into a full ROB.
//   - chk_progress: a uop with room fires; a serialising one at the latest one
//     cycle after the ROB is seen empty with no fire.
//   - chk_once: a uop fires once.
//  Phases: light, heavy commit traffic, serialising-dense, kill-dense.
// ================================================================================

`include "uop_defs.svh"

module dispatch_tb;

  logic               clk = 1'b0;
  logic               resetn = 1'b0;
  logic [CLASS_W-1:0] r2_pds_class = '0;
  logic               r2_pds_illegal = 1'b0;
  logic               r2_pds_serialising = 1'b0;
  logic               pds_ds_valid = 1'b0;
  logic               pds_ds_serialising = 1'b0;
  logic               iq_dispatchReady = 1'b0;
  logic               rob_dispatchReady, rob_empty;
  logic               stall_pds_ds, ds_fire, ds_iqGo, ds_iqFire;

  always #5 clk = ~clk;

  dispatch u_dut (
    .clk, .resetn,
    .r2_pds_class, .r2_pds_illegal, .r2_pds_serialising,
    .pds_ds_valid, .pds_ds_serialising,
    .iq_dispatchReady, .rob_dispatchReady, .rob_empty,
    .stall_pds_ds, .ds_fire, .ds_iqGo, .ds_iqFire
  );

  // ---- environment state -------------------------------------------------------
  int unsigned r2Seq, dsSeq, lastFiredSeq;
  bit          r2Valid, dsSkip;
  int          robCount;
  bit          mispredict, flush;

  assign rob_empty         = robCount == 0;
  assign rob_dispatchReady = robCount < 16;

  // ---- bookkeeping -------------------------------------------------------------
  longint t;
  int     errors;
  int     shown [string];
  int     cov [string];
  int     commitRate, iqRate, serialRate, skipRate, killRate, flushRate, bubbleRate;
  bit     prevEmptyQuiet, prevStall, firedAny;

  task automatic fail(string chk, string msg);
    if (shown[chk] < 5) $display("ERROR %s @%0d: %s", chk, t, msg);
    shown[chk]++;
    errors++;
  endtask

  // ---- reference: the 0060 equations -------------------------------------------
  bit refSkip, refBlock;
  bit refGo, refIqFire, refFire, refStall;

  always_comb begin
    refGo     = pds_ds_valid & rob_dispatchReady & !refBlock & !refSkip;
    refIqFire = refGo & iq_dispatchReady;
    refFire   = pds_ds_valid & rob_dispatchReady & !refBlock & (refSkip | iq_dispatchReady);
    refStall  = pds_ds_valid & !refFire;
  end

  always @(posedge clk) begin
    if (!resetn) begin
      refSkip  <= 1'b0;
      refBlock <= 1'b0;
    end else begin
      if (!refStall) refSkip <= r2_pds_class[CLASS_SYSTEM] | r2_pds_illegal;
      refBlock <= (refStall ? pds_ds_serialising : r2_pds_serialising) & !(rob_empty & !refFire);
    end
  end

  // ---- environment update: predisp, predisp_payload, ROB -----------------------
  always @(posedge clk) begin
    if (resetn) begin
      prevEmptyQuiet <= rob_empty & !ds_fire;
      prevStall      <= stall_pds_ds;
      if (flush)
        robCount <= 0;
      else if (mispredict)
        robCount <= $urandom_range(robCount, 1);
      else
        robCount <= robCount + int'(ds_fire)
                  - int'(robCount > 0 && $urandom_range(99) < commitRate);
      if (mispredict | flush)
        pds_ds_valid <= 1'b0;
      else if (!stall_pds_ds)
        pds_ds_valid <= r2Valid;
      if (!stall_pds_ds) begin
        pds_ds_serialising <= r2_pds_serialising;
        dsSeq              <= r2Seq;
        dsSkip             <= r2_pds_class[CLASS_SYSTEM] | r2_pds_illegal;
      end
    end
  end

  // ---- stimulus ----------------------------------------------------------------
  task automatic randomiseR2();
    int c;
    r2Seq++;
    r2Valid = $urandom_range(99) >= bubbleRate;
    if ($urandom_range(99) < skipRate)
      c = CLASS_SYSTEM;
    else if ($urandom_range(99) < serialRate)
      c = CLASS_CSR;
    else
      c = $urandom_range(CLASS_DIV);
    r2_pds_class       = CLASS_W'(1) << c;
    r2_pds_illegal     = $urandom_range(99) < 3;
    r2_pds_serialising = c == CLASS_CSR || c == CLASS_SYSTEM;
    if (!r2Valid) begin
      r2_pds_class       = CLASS_W'($urandom());
      r2_pds_illegal     = 1'($urandom());
      r2_pds_serialising = 1'($urandom());
    end
  endtask

  task automatic randomiseCycle();
    randomiseR2();
    iq_dispatchReady = $urandom_range(99) < iqRate;
    flush            = $urandom_range(999) < flushRate;
    mispredict       = !flush && robCount > 0 && $urandom_range(999) < killRate;
  endtask

  // ---- checks, after the inputs settle -----------------------------------------
  task automatic checkCycle();
    if (ds_iqGo !== refGo || ds_iqFire !== refIqFire || ds_fire !== refFire
        || stall_pds_ds !== refStall)
      fail("chk_fire", $sformatf("go %b iqFire %b fire %b stall %b exp %b %b %b %b",
        ds_iqGo, ds_iqFire, ds_fire, stall_pds_ds, refGo, refIqFire, refFire, refStall));
    if (stall_pds_ds !== (pds_ds_valid & !ds_fire))
      fail("chk_stall", $sformatf("stall %b valid %b fire %b", stall_pds_ds, pds_ds_valid, ds_fire));
    if (ds_iqFire !== (ds_iqGo & iq_dispatchReady))
      fail("chk_iq", $sformatf("iqFire %b iqGo %b ready %b", ds_iqFire, ds_iqGo, iq_dispatchReady));
    if (pds_ds_valid && dsSkip && (ds_iqGo || ds_iqFire))
      fail("chk_iq", "system or illegal uop sent to the IQ");
    if (ds_fire && pds_ds_serialising && robCount != 0)
      fail("chk_serial", $sformatf("serialising fire with %0d ROB entries", robCount));
    if (ds_fire && robCount == 16)
      fail("chk_robFull", "fire into a full ROB");
    if (pds_ds_valid && rob_dispatchReady && (dsSkip || iq_dispatchReady) && !ds_fire
        && (!pds_ds_serialising || prevEmptyQuiet))
      fail("chk_progress", $sformatf("held with room, serialising %b", pds_ds_serialising));
    if (ds_fire) begin
      if (firedAny && dsSeq == lastFiredSeq)
        fail("chk_once", $sformatf("seq %0d fired twice", dsSeq));
      lastFiredSeq = dsSeq;
      firedAny     = 1'b1;
    end

    if (ds_fire && pds_ds_serialising)                      cov["serialFire"]++;
    if (pds_ds_valid && pds_ds_serialising && !rob_empty)   cov["serialWait"]++;
    if (pds_ds_valid && pds_ds_serialising && rob_empty && !prevEmptyQuiet
        && rob_dispatchReady && (dsSkip || iq_dispatchReady)) cov["serialCommitLag"]++;
    if (ds_fire && dsSkip)                                  cov["skipFire"]++;
    if (ds_fire && dsSkip && !iq_dispatchReady)             cov["skipFullIq"]++;
    if (ds_iqGo && !iq_dispatchReady)                       cov["iqGoNotReady"]++;
    if (ds_fire && mispredict)                              cov["fireInMispredict"]++;
    if (ds_fire && flush)                                   cov["fireInFlush"]++;
    if (pds_ds_valid && !rob_dispatchReady)                 cov["robFull"]++;
    if (stall_pds_ds && prevStall)                          cov["stallRun"]++;
    if (stall_pds_ds && r2_pds_serialising != pds_ds_serialising) cov["r2DiffersInStall"]++;
    if (!stall_pds_ds && r2_pds_serialising != pds_ds_serialising) cov["r2DiffersOnLoad"]++;
  endtask

  task automatic phase(string name, int cycles, int commit, int iq, int serial, int skip,
                       int kill, int fl, int bubble);
    commitRate = commit;
    iqRate     = iq;
    serialRate = serial;
    skipRate   = skip;
    killRate   = kill;
    flushRate  = fl;
    bubbleRate = bubble;
    for (int i = 0; i < cycles; i++) begin
      @(negedge clk);
      t++;
      randomiseCycle();
      #1;
      checkCycle();
    end
    $display("phase %-8s done", name);
  endtask

  int unsigned seed = 1;
  string       need [] = '{"serialFire", "serialWait", "serialCommitLag", "skipFire",
                           "skipFullIq", "iqGoNotReady", "fireInMispredict", "fireInFlush",
                           "robFull", "stallRun", "r2DiffersInStall", "r2DiffersOnLoad"};

  initial begin
    void'($value$plusargs("seed=%d", seed));
    void'($urandom(seed));
    errors   = 0;
    t        = 0;
    robCount = 0;
    repeat (3) @(negedge clk);
    resetn = 1'b1;
    //     name        cycles  commit iq  serial skip kill flush bubble
    phase("light",     50000,  60,    80, 3,     2,   5,   1,    20);
    phase("heavy",     50000,  15,    50, 3,     2,   5,   1,    5);
    phase("serial",    50000,  40,    70, 25,    15,  10,  2,    10);
    phase("killdense", 50000,  40,    60, 10,    10,  150, 30,   10);
    foreach (cov[k]) $display("  cov %-18s %0d", k, cov[k]);
    foreach (need[i])
      if (cov[need[i]] == 0) begin
        $display("ERROR coverage hole: %s", need[i]);
        errors++;
      end
    if (errors == 0) $display("PASS  dispatch");
    else             $fatal(1, "FAIL  dispatch (%0d errors)", errors);
    $finish;
  end

endmodule
