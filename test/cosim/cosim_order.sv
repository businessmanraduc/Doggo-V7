// ================================================================================
//  cosim_order -- puts the 0035 pending load back in program order (sim only)
// ================================================================================
//  A load retired without data (rt_pend) blocks the queue until its late value
//  (lv_*); younger events wait behind it, then reach cosim_event in order. One
//  pending load at a time. Ports are sampled at posedge. rt_mip must equal the
//  device lines SYNC_MIN..SYNC_MAX cycles before the retire.
// ================================================================================
module cosim_order #(
  parameter int SYNC_MIN = 0,
  parameter int SYNC_MAX = 0
) (
  input  logic        clk,
  input  logic        resetn,
  // ---- retire port: one event per cycle, program order -------------------------
  input  logic        rt_valid,
  input  logic [1:0]  rt_kind,              // 0 retire, 1 exception, 2 interrupt entry
  input  logic        rt_pend,
  input  logic [31:0] rt_pc,
  input  logic [31:0] rt_insn,
  input  logic [4:0]  rt_rd,
  input  logic [31:0] rt_rdVal,
  input  logic [1:0]  rt_memKind,           // 0 none, 1 load, 2 store
  input  logic [31:0] rt_memAddr,
  input  logic [2:0]  rt_memSize,
  input  logic [31:0] rt_memRdata,
  input  logic [31:0] rt_memWdata,
  input  logic [4:0]  rt_cause,
  input  logic [31:0] rt_mip,
  input  logic [31:0] rt_snap [9],
  // ---- late port: the pending load's value -------------------------------------
  input  logic        lv_valid,
  input  logic [31:0] lv_rdVal,
  input  logic [31:0] lv_word,
  // ---- device interrupt lines --------------------------------------------------
  input  logic [31:0] dv_lines,
  // ---- status ------------------------------------------------------------------
  output logic        co_fail,
  output int          co_queued
);

  import "DPI-C" function int cosim_event(input int kind, input int pc, input int insn,
    input int rd, input int rdVal, input int memKind, input int memAddr, input int memSize,
    input int memRdata, input int memWdata, input int cause, input int mip, input int snap[9]);

  typedef struct {
    int kind, pc, insn, rd, rdVal, memKind, memAddr, memSize, memRdata, memWdata, cause, mip;
    int snap[9];
    bit pending;
  } event_t;

  event_t      waiting [$];
  logic [31:0] lineHistory [SYNC_MAX + 1];
  bit          loadPending;
  int          pendingIndex;

  function automatic void applyLateValue();
    waiting[pendingIndex].rdVal    = lv_rdVal;
    waiting[pendingIndex].memRdata = lv_word;
    waiting[pendingIndex].pending  = 0;
    loadPending = 0;
  endfunction

  function automatic void orderFail(string message);
    $display("COSIM ORDER: %s", message);
    co_fail = 1;
  endfunction

  initial begin
    co_fail     = 0;
    co_queued   = 0;
    loadPending = 0;
  end

  always @(posedge clk) begin
    if (!resetn) begin
      waiting.delete();
      loadPending = 0;
      for (int i = 0; i <= SYNC_MAX; i++) lineHistory[i] = '0;
    end else begin
      event_t e;
      bit     linesMatch, lateForOlder;
      for (int i = SYNC_MAX; i > 0; i--) lineHistory[i] = lineHistory[i - 1];
      lineHistory[0] = dv_lines;
      if (rt_valid) begin
        linesMatch = 0;
        for (int i = SYNC_MIN; i <= SYNC_MAX; i++) if (rt_mip == lineHistory[i]) linesMatch = 1;
        if (!linesMatch)
          orderFail($sformatf("rt_mip %h not in the device line history (%0d..%0d cycles back)",
                              rt_mip, SYNC_MIN, SYNC_MAX));
      end
      // a late value belongs to the load already pending, else to one retired this cycle
      lateForOlder = lv_valid && loadPending;
      if (lateForOlder) applyLateValue();
      if (rt_valid) begin
        e.kind = int'(rt_kind); e.pc = rt_pc; e.insn = rt_insn; e.rd = int'(rt_rd);
        e.rdVal = rt_rdVal; e.memKind = int'(rt_memKind); e.memAddr = rt_memAddr;
        e.memSize = int'(rt_memSize); e.memRdata = rt_memRdata; e.memWdata = rt_memWdata;
        e.cause = int'(rt_cause); e.mip = rt_mip;
        for (int i = 0; i < 9; i++) e.snap[i] = rt_snap[i];
        e.pending = rt_pend;
        if (rt_pend) begin
          if (loadPending || rt_memKind != 2'd1)
            orderFail("second pending load, or pending event not a load");
          loadPending  = 1;
          pendingIndex = waiting.size();
        end
        waiting.push_back(e);
      end
      if (lv_valid && !lateForOlder) begin
        if (!loadPending) orderFail("late value without a pending load");
        else applyLateValue();
      end
      while (!co_fail && waiting.size() > 0 && !waiting[0].pending) begin
        e = waiting.pop_front();
        if (loadPending) pendingIndex--;
        if (cosim_event(e.kind, e.pc, e.insn, e.rd, e.rdVal, e.memKind, e.memAddr, e.memSize,
                        e.memRdata, e.memWdata, e.cause, e.mip, e.snap) != 0)
          co_fail = 1;
      end
      co_queued = waiting.size();
    end
  end

endmodule
