`include "isa.svh"
// ================================================================================
//  PHANTOoOM-32 -- Reorder Buffer
// ================================================================================
//  Out-of-Order results wait to become in-order effects.
//
//  Three access points:
//    dispatch   in-order,      at tail     -- allocates, hands out robIdx ticket
//    completion out-of-order,  at cmplIdx  -- the FU cashes its ticket
//    commit     in-order,      at head     -- retires/fires trap
//
//  Solo Fmax (ring-of-regs, nextpnr --85k, tw=100, 20 seeds): 160.15 / 183.73 / 199.56
// ================================================================================
module rob #(
  parameter int DEPTH = 16,
  parameter int IDX_W = $clog2(DEPTH)
) (
  input  logic             clk,
  input  logic             resetn,
  input  logic             flush,               // trap/branch mispredict

  // ---- dispatch: allocate at tail, in program order ----------------------------
  input  logic             disp_valid,
  input  logic [31:0]      disp_pc,
  input  logic             disp_regWrite,
  input  logic [4:0]       disp_archDestReg,
  input  logic             disp_isStore,
  output logic             disp_ready,          // ROB not full
  output logic [IDX_W-1:0] disp_idx,            // the ticket

  // ---- completion: a functional unit cashes its ticket -------------------------
  input  logic             cmpl_valid,
  input  logic [IDX_W-1:0] cmpl_idx,
  input  logic [31:0]      cmpl_result,
  input  logic             cmpl_exception,
  input  trapCause_t       cmpl_cause,

  // ---- forwarding: issue-stage operand reads, combinational --------------------
  input  logic [IDX_W-1:0] fwd_idxA,
  output logic [31:0]      fwd_dataA,
  output logic             fwd_doneA,
  input  logic [IDX_W-1:0] fwd_idxB,
  output logic [31:0]      fwd_dataB,
  output logic             fwd_doneB,

  // ---- commit: retire the head, in program order -------------------------------
  output logic             cmt_valid,
  output logic [31:0]      cmt_pc,
  output logic             cmt_regWrite,
  output logic [4:0]       cmt_archDestReg,
  output logic [31:0]      cmt_result,
  output logic             cmt_exception,
  output trapCause_t       cmt_cause,
  output logic             cmt_isStore,
  input  logic             cmt_accept
);

  localparam int META_W = 32 + 1 + 5 + 1;   // pc, regWrite, archDestReg, isStore
  localparam int EXCP_W = 1 + 4;            // exception, cause

  (* ram_style = "distributed" *) logic [META_W-1:0] metaMem   [DEPTH];
  (* ram_style = "distributed" *) logic [31:0]       resultMem [DEPTH];
  (* ram_style = "distributed" *) logic [EXCP_W-1:0] excpMem   [DEPTH];
  logic [DEPTH-1:0] done;

  logic [IDX_W:0]   head,    tail;
  logic [IDX_W-1:0] headIdx, tailIdx;
  logic             empty,   full;
  logic [IDX_W:0]   count;
  logic             doDisp,  doCmt;

  assign headIdx = head[IDX_W-1:0];
  assign tailIdx = tail[IDX_W-1:0];
  assign empty   = (count == '0);
  assign full    = count[IDX_W];

  assign doDisp  = disp_valid && disp_ready;
  assign doCmt   = cmt_valid  && cmt_accept;

  // ---- dispatch ----------------------------------------------------------------
  assign disp_ready = !full;
  assign disp_idx   = tailIdx;

  // ---- forwarding --------------------------------------------------------------
  assign fwd_dataA  = resultMem[fwd_idxA];
  assign fwd_doneA  = done[fwd_idxA];
  assign fwd_dataB  = resultMem[fwd_idxB];
  assign fwd_doneB  = done[fwd_idxB];

  // ---- commit ------------------------------------------------------------------
  logic [EXCP_W-1:0] excpRd;
  assign cmt_valid     = !empty && done[headIdx];
  assign {cmt_pc, cmt_regWrite, cmt_archDestReg, cmt_isStore} = metaMem[headIdx];
  assign cmt_result    = resultMem[headIdx];
  assign excpRd        = excpMem[headIdx];
  assign cmt_exception = excpRd[EXCP_W-1];
  assign cmt_cause     = trapCause_t'(excpRd[EXCP_W-2:0]);

  // ---- pointers ----------------------------------------------------------------
  always_ff @(posedge clk) begin
    if (!resetn || flush) begin
      head  <= '0;
      tail  <= '0;
      count <= '0;
    end else begin
      if (doDisp) tail <= tail + 1'b1;
      if (doCmt)  head <= head + 1'b1;
      if (doDisp && !doCmt) count <= count + 1'b1;
      if (!doDisp && doCmt) count <= count - 1'b1;
    end
  end

  // ---- done bits: completion sets, dispatch clears reused slot -----------------
  logic [DEPTH-1:0] setMask, clrMask;
  always_comb begin
    setMask = cmpl_valid ? (DEPTH'(1) << cmpl_idx) : '0;
    clrMask = doDisp     ? (DEPTH'(1) << tailIdx)  : '0;
  end
  always_ff @(posedge clk) begin
    if (!resetn || flush) done <= '0;
    else                  done <= (done | setMask) & ~clrMask;
  end

  // ---- metadata: written once at dispatch --------------------------------------
  always_ff @(posedge clk) begin
    if (doDisp) begin
      metaMem[tailIdx] <= {disp_pc, disp_regWrite, disp_archDestReg, disp_isStore};
    end
  end

  // ---- result and exception: written once at completion ------------------------
  always_ff @(posedge clk) begin
    if (cmpl_valid) begin
      resultMem[cmpl_idx] <= cmpl_result;
      excpMem[cmpl_idx]   <= {cmpl_exception, cmpl_cause};
    end
  end

endmodule

