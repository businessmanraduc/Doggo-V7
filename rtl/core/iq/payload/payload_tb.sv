// ================================================================================
//  payload_tb -- payload RAM with named fields under the IQ slot contract
// ================================================================================
//  The bench plays dispatch (circular one-hot tail, a slot reused from the
//  cycle after its PR read) and the IQ grant (a dispatched, ungranted slot at
//  least 2 cycles after its dispatch). Every field is random per uop; the
//  bench packs its own struct in the reverse field order of the DUT.
//  Checks:
//   - chk_read: one cycle after a PR read, every pr_rf_* field equals the
//   field dispatched into the granted slot (reported by field name).
//  Phases: sparse, tight reuse, full queue. MW = 3.
// ================================================================================

`include "uop_defs.svh"

module payload_tb;

  localparam int MW = 3;

  typedef struct packed {
    logic [31:0]        immediate;
    logic [2:0]         func3;
    logic               divRemainder;
    logic               divSigned;
    logic               mulHigh;
    logic               mulSignedB;
    logic               mulSignedA;
    logic               branchInvert;
    logic               branchUseLt;
    logic               zIsZero;
    logic               zIsImm;
    logic               xIsZero;
    logic               xIsPC;
    logic               shiftArith;
    logic               shiftRight;
    logic               sltUnsigned;
    logic               selSlt;
    logic               selXor;
    logic               selOr;
    logic               selAnd;
    logic               selArith;
    logic               sub;
    logic [CLASS_W-1:0] class_;
    logic [30:0]        seq;
    logic [30:0]        branchTarget;
    logic               isRet;
    logic               isCall;
    logic [MW-1:0]      meta;
    logic [30:0]        pc;
    logic [1:0]         snapshot;
    logic               rdWriteEnable;
    logic [5:0]         rdTag;
    logic [5:0]         rs2Tag;
    logic [5:0]         rs1Tag;
    logic [3:0]         robIndex;
  } uop_t;

  logic clk = 1'b0;
  logic ds_fire = 1'b0;
  logic [7:0] iq_tailSlot = 8'b1;
  logic [7:0] is_pr_grant = '0;
  uop_t in, out;

  always #5 clk = ~clk;

  payload #(.MW(MW)) u_dut (
    .clk,
    .ds_fire,
    .iq_tailSlot,
    .is_pr_grant,
    .ds_robIndex           (in.robIndex),
    .pds_ds_rs1Tag         (in.rs1Tag),
    .pds_ds_rs2Tag         (in.rs2Tag),
    .pds_ds_rdTag          (in.rdTag),
    .pds_ds_rdWriteEnable  (in.rdWriteEnable),
    .pds_ds_snapshot       (in.snapshot),
    .pds_ds_pc             (in.pc),
    .pds_ds_meta           (in.meta),
    .pds_ds_isCall         (in.isCall),
    .pds_ds_isRet          (in.isRet),
    .pds_ds_branchTarget   (in.branchTarget),
    .pds_ds_seq            (in.seq),
    .pds_ds_class          (in.class_),
    .pds_ds_sub            (in.sub),
    .pds_ds_selArith       (in.selArith),
    .pds_ds_selAnd         (in.selAnd),
    .pds_ds_selOr          (in.selOr),
    .pds_ds_selXor         (in.selXor),
    .pds_ds_selSlt         (in.selSlt),
    .pds_ds_sltUnsigned    (in.sltUnsigned),
    .pds_ds_shiftRight     (in.shiftRight),
    .pds_ds_shiftArith     (in.shiftArith),
    .pds_ds_xIsPC          (in.xIsPC),
    .pds_ds_xIsZero        (in.xIsZero),
    .pds_ds_zIsImm         (in.zIsImm),
    .pds_ds_zIsZero        (in.zIsZero),
    .pds_ds_branchUseLt    (in.branchUseLt),
    .pds_ds_branchInvert   (in.branchInvert),
    .pds_ds_mulSignedA     (in.mulSignedA),
    .pds_ds_mulSignedB     (in.mulSignedB),
    .pds_ds_mulHigh        (in.mulHigh),
    .pds_ds_divSigned      (in.divSigned),
    .pds_ds_divRemainder   (in.divRemainder),
    .pds_ds_func3          (in.func3),
    .pds_ds_immediate      (in.immediate),
    .pr_rf_robIndex        (out.robIndex),
    .pr_rf_rs1Tag          (out.rs1Tag),
    .pr_rf_rs2Tag          (out.rs2Tag),
    .pr_rf_rdTag           (out.rdTag),
    .pr_rf_rdWriteEnable   (out.rdWriteEnable),
    .pr_rf_snapshot        (out.snapshot),
    .pr_rf_pc              (out.pc),
    .pr_rf_meta            (out.meta),
    .pr_rf_isCall          (out.isCall),
    .pr_rf_isRet           (out.isRet),
    .pr_rf_branchTarget    (out.branchTarget),
    .pr_rf_seq             (out.seq),
    .pr_rf_class           (out.class_),
    .pr_rf_sub             (out.sub),
    .pr_rf_selArith        (out.selArith),
    .pr_rf_selAnd          (out.selAnd),
    .pr_rf_selOr           (out.selOr),
    .pr_rf_selXor          (out.selXor),
    .pr_rf_selSlt          (out.selSlt),
    .pr_rf_sltUnsigned     (out.sltUnsigned),
    .pr_rf_shiftRight      (out.shiftRight),
    .pr_rf_shiftArith      (out.shiftArith),
    .pr_rf_xIsPC           (out.xIsPC),
    .pr_rf_xIsZero         (out.xIsZero),
    .pr_rf_zIsImm          (out.zIsImm),
    .pr_rf_zIsZero         (out.zIsZero),
    .pr_rf_branchUseLt     (out.branchUseLt),
    .pr_rf_branchInvert    (out.branchInvert),
    .pr_rf_mulSignedA      (out.mulSignedA),
    .pr_rf_mulSignedB      (out.mulSignedB),
    .pr_rf_mulHigh         (out.mulHigh),
    .pr_rf_divSigned       (out.divSigned),
    .pr_rf_divRemainder    (out.divRemainder),
    .pr_rf_func3           (out.func3),
    .pr_rf_immediate       (out.immediate)
  );

  // ---- slot model --------------------------------------------------------------
  uop_t   word [8];
  longint dispatchedAt [8];
  longint freeFrom [8];
  bit     granted [8];
  int     tail;

  longint t;
  int     errors, checks;
  int     shown [string];
  int     cov [string];
  int     dispatchRate, grantRate;
  bit     expectValid;
  uop_t   expected;
  int     expectSlot;

  task automatic fail(string chk, string msg);
    if (shown[chk] < 5) $display("ERROR %s @%0d: %s", chk, t, msg);
    shown[chk]++;
    errors++;
  endtask

`define CHK_FIELD(f) \
    if (out.f !== expected.f) \
      fail("chk_read", $sformatf("slot %0d %s %0h exp %0h", expectSlot, `"f`", out.f, expected.f));

  task automatic checkFields();
    `CHK_FIELD(robIndex)
    `CHK_FIELD(rs1Tag)
    `CHK_FIELD(rs2Tag)
    `CHK_FIELD(rdTag)
    `CHK_FIELD(rdWriteEnable)
    `CHK_FIELD(snapshot)
    `CHK_FIELD(pc)
    `CHK_FIELD(meta)
    `CHK_FIELD(isCall)
    `CHK_FIELD(isRet)
    `CHK_FIELD(branchTarget)
    `CHK_FIELD(seq)
    `CHK_FIELD(class_)
    `CHK_FIELD(sub)
    `CHK_FIELD(selArith)
    `CHK_FIELD(selAnd)
    `CHK_FIELD(selOr)
    `CHK_FIELD(selXor)
    `CHK_FIELD(selSlt)
    `CHK_FIELD(sltUnsigned)
    `CHK_FIELD(shiftRight)
    `CHK_FIELD(shiftArith)
    `CHK_FIELD(xIsPC)
    `CHK_FIELD(xIsZero)
    `CHK_FIELD(zIsImm)
    `CHK_FIELD(zIsZero)
    `CHK_FIELD(branchUseLt)
    `CHK_FIELD(branchInvert)
    `CHK_FIELD(mulSignedA)
    `CHK_FIELD(mulSignedB)
    `CHK_FIELD(mulHigh)
    `CHK_FIELD(divSigned)
    `CHK_FIELD(divRemainder)
    `CHK_FIELD(func3)
    `CHK_FIELD(immediate)
  endtask

  function automatic uop_t randomUop();
    uop_t u;
    for (int b = 0; b < $bits(uop_t); b += 32) u[b +: 32] = $urandom();
    return u;
  endfunction

  task automatic step();
    int pick, candidates [$];
    @(negedge clk);
    t++;
    if (expectValid) begin
      checks++;
      checkFields();
    end

    // ---- PR: grant one eligible slot -------------------------------------------
    for (int k = 0; k < 8; k++)
      if (dispatchedAt[k] >= 0 && !granted[k] && t >= dispatchedAt[k] + 2) candidates.push_back(k);
    is_pr_grant = '0;
    expectValid = 1'b0;
    if (candidates.size() > 0 && $urandom_range(99) < grantRate) begin
      pick = candidates[$urandom_range(candidates.size() - 1)];
      is_pr_grant[pick] = 1'b1;
      granted[pick]     = 1'b1;
      freeFrom[pick]    = t + 1;
      expectValid = 1'b1;
      expected    = word[pick];
      expectSlot  = pick;
      if (t == dispatchedAt[pick] + 2) cov["readEarliest"]++;
    end

    // ---- DS: dispatch into the tail when its slot is free ----------------------
    ds_fire = 1'b0;
    in      = randomUop();
    if ((dispatchedAt[tail] < 0 || granted[tail]) && t >= freeFrom[tail]
        && $urandom_range(99) < dispatchRate) begin
      ds_fire = 1'b1;
      if (granted[tail] && t == freeFrom[tail]) cov["reuseEarliest"]++;
      word[tail]         = in;
      dispatchedAt[tail] = t;
      granted[tail]      = 1'b0;
    end
    iq_tailSlot = 8'(1) << tail;
    if (ds_fire) tail = (tail + 1) % 8;
  endtask

  task automatic runPhase(string name, int dRate, int gRate, int cycles);
    dispatchRate = dRate;
    grantRate    = gRate;
    for (int i = 0; i < cycles; i++) step();
    $display("phase %-6s done", name);
  endtask

  int unsigned seed = 1;

  initial begin
    void'($value$plusargs("seed=%d", seed));
    void'($urandom(seed));
    errors = 0;
    checks = 0;
    t      = 0;
    tail   = 0;
    expectValid = 1'b0;
    for (int k = 0; k < 8; k++) begin
      dispatchedAt[k] = -1;
      freeFrom[k]     = 0;
      granted[k]      = 1'b0;
    end
    runPhase("sparse", 30, 30, 10000);
    runPhase("tight",  95, 95, 20000);
    runPhase("full",   90, 15, 10000);
    repeat (2) step();
    foreach (cov[k]) $display("  cov %-14s %0d", k, cov[k]);
    if (cov["readEarliest"] == 0 || cov["reuseEarliest"] == 0) begin
      $display("ERROR coverage hole");
      errors++;
    end
    if (errors == 0) $display("PASS  payload (%0d reads)", checks);
    else             $fatal(1, "FAIL  payload (%0d errors)", errors);
    $finish;
  end

endmodule
