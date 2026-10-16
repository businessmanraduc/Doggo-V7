// ================================================================================
//  predisp_payload_tb -- decoder payload register, random fields and stalls
// ================================================================================
//  Every field gets an independent random value each cycle, so a dropped,
//  swapped or mis-widthed field shows up by name. MW = 3 checks the parameter
//  reaches the meta ports.
//  Checks:
//   - chk_pass: after a cycle without stall, every output equals the input.
//   - chk_hold: after a stall cycle, every output keeps its value.
//  Phases: no stall, light, heavy (long stall runs).
// ================================================================================

`include "uop_defs.svh"

module predisp_payload_tb;

  localparam int MW = 3;

  typedef struct packed {
    logic [30:0]          pc;
    logic [MW-1:0]        meta;
    logic                 isCall;
    logic                 isRet;
    logic [30:0]          branchTarget;
    logic [30:0]          seq;
    logic [CLASS_W-1:0]   class_;
    logic                 sub;
    logic                 selArith;
    logic                 selAnd;
    logic                 selOr;
    logic                 selXor;
    logic                 selSlt;
    logic                 sltUnsigned;
    logic                 shiftRight;
    logic                 shiftArith;
    logic                 xIsPC;
    logic                 xIsZero;
    logic                 zIsImm;
    logic                 zIsZero;
    logic                 branchUseLt;
    logic                 branchInvert;
    logic                 mulSignedA;
    logic                 mulSignedB;
    logic                 mulHigh;
    logic                 divSigned;
    logic                 divRemainder;
    logic [2:0]           func3;
    logic [SYSTEM_W-1:0]  system;
    logic                 serialising;
    logic [31:0]          immediate;
    logic                 illegal;
  } payload_t;

  logic     clk = 1'b0;
  logic     stall_pds_ds = 1'b0;
  payload_t in, out, expected;

  always #5 clk = ~clk;

  predisp_payload #(.MW(MW)) u_dut (
    .clk,
    .r2_pds_pc           (in.pc),
    .r2_pds_meta         (in.meta),
    .r2_pds_isCall       (in.isCall),
    .r2_pds_isRet        (in.isRet),
    .r2_pds_branchTarget (in.branchTarget),
    .r2_pds_seq          (in.seq),
    .r2_pds_class        (in.class_),
    .r2_pds_sub          (in.sub),
    .r2_pds_selArith     (in.selArith),
    .r2_pds_selAnd       (in.selAnd),
    .r2_pds_selOr        (in.selOr),
    .r2_pds_selXor       (in.selXor),
    .r2_pds_selSlt       (in.selSlt),
    .r2_pds_sltUnsigned  (in.sltUnsigned),
    .r2_pds_shiftRight   (in.shiftRight),
    .r2_pds_shiftArith   (in.shiftArith),
    .r2_pds_xIsPC        (in.xIsPC),
    .r2_pds_xIsZero      (in.xIsZero),
    .r2_pds_zIsImm       (in.zIsImm),
    .r2_pds_zIsZero      (in.zIsZero),
    .r2_pds_branchUseLt  (in.branchUseLt),
    .r2_pds_branchInvert (in.branchInvert),
    .r2_pds_mulSignedA   (in.mulSignedA),
    .r2_pds_mulSignedB   (in.mulSignedB),
    .r2_pds_mulHigh      (in.mulHigh),
    .r2_pds_divSigned    (in.divSigned),
    .r2_pds_divRemainder (in.divRemainder),
    .r2_pds_func3        (in.func3),
    .r2_pds_system       (in.system),
    .r2_pds_serialising  (in.serialising),
    .r2_pds_immediate    (in.immediate),
    .r2_pds_illegal      (in.illegal),
    .stall_pds_ds,
    .pds_ds_pc           (out.pc),
    .pds_ds_meta         (out.meta),
    .pds_ds_isCall       (out.isCall),
    .pds_ds_isRet        (out.isRet),
    .pds_ds_branchTarget (out.branchTarget),
    .pds_ds_seq          (out.seq),
    .pds_ds_class        (out.class_),
    .pds_ds_sub          (out.sub),
    .pds_ds_selArith     (out.selArith),
    .pds_ds_selAnd       (out.selAnd),
    .pds_ds_selOr        (out.selOr),
    .pds_ds_selXor       (out.selXor),
    .pds_ds_selSlt       (out.selSlt),
    .pds_ds_sltUnsigned  (out.sltUnsigned),
    .pds_ds_shiftRight   (out.shiftRight),
    .pds_ds_shiftArith   (out.shiftArith),
    .pds_ds_xIsPC        (out.xIsPC),
    .pds_ds_xIsZero      (out.xIsZero),
    .pds_ds_zIsImm       (out.zIsImm),
    .pds_ds_zIsZero      (out.zIsZero),
    .pds_ds_branchUseLt  (out.branchUseLt),
    .pds_ds_branchInvert (out.branchInvert),
    .pds_ds_mulSignedA   (out.mulSignedA),
    .pds_ds_mulSignedB   (out.mulSignedB),
    .pds_ds_mulHigh      (out.mulHigh),
    .pds_ds_divSigned    (out.divSigned),
    .pds_ds_divRemainder (out.divRemainder),
    .pds_ds_func3        (out.func3),
    .pds_ds_system       (out.system),
    .pds_ds_serialising  (out.serialising),
    .pds_ds_immediate    (out.immediate),
    .pds_ds_illegal      (out.illegal)
  );

  // ---- bookkeeping -------------------------------------------------------------
  longint t;
  int     errors;
  int     shown [string];
  int     cov [string];
  bit     primed, lastStall, prevHeld;
  int     stallRate, runLength;

  task automatic fail(string chk, string msg);
    if (shown[chk] < 5) $display("ERROR %s @%0d: %s", chk, t, msg);
    shown[chk]++;
    errors++;
  endtask

  // ---- per-field compare -------------------------------------------------------
`define CHK_FIELD(f) \
    if (out.f !== expected.f) \
      fail(chk, $sformatf("%s %0h exp %0h", `"f`", out.f, expected.f));

  task automatic checkFields(string chk);
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
    `CHK_FIELD(system)
    `CHK_FIELD(serialising)
    `CHK_FIELD(immediate)
    `CHK_FIELD(illegal)
  endtask

  // ---- reference: the register as the contract states it -----------------------
  always @(posedge clk) begin
    if (!stall_pds_ds) expected <= in;
    if (!stall_pds_ds) primed   <= 1'b1;
    lastStall <= stall_pds_ds;
  end

  // ---- stimulus and checks on the falling edge ---------------------------------
  task automatic randomise();
    payload_t p;
    for (int b = 0; b < $bits(payload_t); b += 32)
      p[b +: 32] = $urandom();
    in = p;
    if (runLength > 0) begin
      runLength--;
      stall_pds_ds = 1'b1;
    end else if ($urandom_range(99) < stallRate) begin
      stall_pds_ds = 1'b1;
      if (stallRate > 50) runLength = $urandom_range(6);
    end else
      stall_pds_ds = 1'b0;
  endtask

  task automatic runPhase(string name, int rate, int cycles);
    stallRate = rate;
    runLength = 0;
    for (int i = 0; i < cycles; i++) begin
      @(negedge clk);
      t++;
      if (primed) begin
        checkFields(lastStall ? "chk_hold" : "chk_pass");
        cov[lastStall ? "held" : "passed"]++;
        if (lastStall && prevHeld) cov["stallRun"]++;
        prevHeld = lastStall;
      end
      randomise();
    end
    $display("phase %-6s done", name);
  endtask

  int unsigned seed = 1;

  initial begin
    void'($value$plusargs("seed=%d", seed));
    void'($urandom(seed));
    errors = 0;
    t      = 0;
    in     = '0;
    runPhase("none",  0,  5000);
    runPhase("light", 25, 20000);
    runPhase("heavy", 80, 20000);
    foreach (cov[k]) $display("  cov %-8s %0d", k, cov[k]);
    if (cov["held"] == 0 || cov["passed"] == 0 || cov["stallRun"] == 0) begin
      $display("ERROR coverage hole");
      errors++;
    end
    if (errors == 0) $display("PASS  predisp_payload");
    else             $fatal(1, "FAIL  predisp_payload (%0d errors)", errors);
    $finish;
  end

endmodule
