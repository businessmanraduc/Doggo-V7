// ===================================================================================
//  rob_tb -- complete out of order, commit in order
// ===================================================================================

module rob_tb;
  localparam int DEPTH = 16;

  logic        clk = 0;
  logic        resetn, flush;

  logic        disp_valid, disp_regWrite, disp_isStore, disp_ready;
  logic [31:0] disp_pc;
  logic [4:0]  disp_archDestReg;
  logic [3:0]  disp_idx;

  logic        cmpl_valid, cmpl_exception;
  logic [3:0]  cmpl_idx;
  logic [31:0] cmpl_result;
  trapCause_t  cmpl_cause;

  logic [3:0]  fwd_idxA, fwd_idxB;
  logic [31:0] fwd_dataA, fwd_dataB;
  logic        fwd_doneA, fwd_doneB;

  logic        cmt_valid, cmt_regWrite, cmt_exception, cmt_isStore, cmt_accept;
  logic [31:0] cmt_pc, cmt_result;
  logic [4:0]  cmt_archDestReg;
  trapCause_t  cmt_cause;

  int errors = 0;

  rob #(.DEPTH(DEPTH)) dut (.*);

  always #5 clk = ~clk;

  task automatic fail(input string note);
    $error("%s", note);
    errors++;
  endtask

  task automatic check(input string note, input int got, input int want);
    if (got !== want) begin
      $error("%-32s got %0d, want %0d", note, got, want);
      errors++;
    end
  endtask

  task automatic dispatch(
    input        [31:0] pc,
    input        [4:0]  rd,
    input  logic        isStore,
    output logic [3:0]  tk
  );
    disp_valid = 1; disp_pc = pc; disp_archDestReg = rd;
    disp_regWrite = 1; disp_isStore = isStore;
    #1 tk = disp_idx;
    @(posedge clk); #1;
    disp_valid = 0;
  endtask

  task automatic complete(
    input        [3:0]  tk,
    input        [31:0] res,
    input logic         exc,
    input trapCause_t   cause
  );
    cmpl_valid = 1; cmpl_idx = tk; cmpl_result = res;
    cmpl_exception = exc; cmpl_cause = cause;
    @(posedge clk); #1;
    cmpl_valid = 0;
  endtask

  logic [3:0] t0, t1, t2, t3, tk;

  initial begin
    resetn = 0; flush = 0;
    disp_valid = 0; disp_pc = 0; disp_archDestReg = 0; disp_regWrite = 0; disp_isStore = 0;
    cmpl_valid = 0; cmpl_idx = 0; cmpl_result = 0; cmpl_exception = 0; cmpl_cause = TRAP_ILLEGAL_INSTR;
    fwd_idxA = 0; fwd_idxB = 0; cmt_accept = 0;
    repeat (2) @(posedge clk);
    #1 resetn = 1;
    @(posedge clk); #1;

    // ---- A: empty after reset -----------------------------------------------------
    if (cmt_valid)  fail("A: cmt_valid set while empty");
    if (!disp_ready) fail("A: not ready while empty");

    // ---- B: dispatch hands out sequential tickets ---------------------------------
    dispatch(32'h1000, 5'd1, 0, t0);   // the slow one (a div, say)
    dispatch(32'h1004, 5'd4, 0, t1);
    dispatch(32'h1008, 5'd7, 0, t2);
    dispatch(32'h100C, 5'd10, 0, t3);
    chk("B: ticket 0", int'(t0), 0);
    chk("B: ticket 1", int'(t1), 1);
    chk("B: ticket 2", int'(t2), 2);
    chk("B: ticket 3", int'(t3), 3);

    // ---- C: complete OUT of order; head is not done, so nothing may commit --------
    complete(t1, 32'hAAAA_0001, 0, TRAP_ILLEGAL_INSTR);
    if (cmt_valid) fail("C: committed with an undone head");
    complete(t3, 32'hAAAA_0003, 0, TRAP_ILLEGAL_INSTR);
    complete(t2, 32'hAAAA_0002, 0, TRAP_ILLEGAL_INSTR);
    if (cmt_valid) fail("C: committed out of order");

    // ---- D: forward an uncommitted result (the whole point) -----------------------
    #1 fwd_idxA = t1; fwd_idxB = t0;
    #1;
    if (!fwd_doneA)                   fail("D: entry 1 done but fwd_doneA clear");
    if (fwd_dataA !== 32'hAAAA_0001)  fail("D: forwarded wrong data for entry 1");
    if (fwd_doneB)                    fail("D: entry 0 not done but fwd_doneB set");

    // ---- E: head completes -> everything drains IN ORDER --------------------------
    complete(t0, 32'hAAAA_0000, 0, TRAP_ILLEGAL_INSTR);
    #1 cmt_accept = 1;
    #1;
    chk("E: commit 0 pc",     int'(cmt_pc),     32'h1000);
    chk("E: commit 0 rd",     int'(cmt_archDestReg), 1);
    chk("E: commit 0 result", int'(cmt_result), 32'hAAAA_0000);
    if (!cmt_valid) fail("E: head done but cmt_valid clear");
    @(posedge clk); #1;
    chk("E: commit 1 pc",     int'(cmt_pc),     32'h1004);
    chk("E: commit 1 result", int'(cmt_result), 32'hAAAA_0001);
    @(posedge clk); #1;
    chk("E: commit 2 pc",     int'(cmt_pc),     32'h1008);
    @(posedge clk); #1;
    chk("E: commit 3 pc",     int'(cmt_pc),     32'h100C);
    chk("E: commit 3 rd",     int'(cmt_archDestReg), 10);
    @(posedge clk); #1;
    if (cmt_valid) fail("E: still committing after the last entry");
    cmt_accept = 0;

    // ---- F: fills up exactly at DEPTH ---------------------------------------------
    for (int i = 0; i < DEPTH; i++) begin
      if (!disp_ready) fail($sformatf("F: not ready at entry %0d", i));
      dispatch(32'h2000 + i*4, 5'(i), 0, tk);
    end
    if (disp_ready) fail("F: still ready after DEPTH dispatches");

    // ---- G: flush empties it ------------------------------------------------------
    #1 flush = 1;
    @(posedge clk); #1;
    flush = 0;
    #1;
    if (!disp_ready) fail("G: not ready after flush");
    if (cmt_valid)   fail("G: cmt_valid set after flush");

    // ---- H: an exception rides through to commit ----------------------------------
    dispatch(32'h3000, 5'd2, 0, tk);
    complete(tk, 32'h0, 1, TRAP_LOAD_MISALIGN);
    #1;
    if (!cmt_valid)   fail("H: faulting entry never became committable");
    if (!cmt_exception) fail("H: exception lost");
    chk("H: cause", int'(cmt_cause), int'(TRAP_LOAD_MISALIGN));
    chk("H: pc",    int'(cmt_pc),    32'h3000);

    if (errors == 0) $display("PASS  rob");
    else             $fatal(1, "FAIL  rob (%0d errors)", errors);
    $finish;
  end

endmodule

