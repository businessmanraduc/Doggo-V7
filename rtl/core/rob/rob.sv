// ================================================================================
//  ROB: reorder buffer, 16 entries, 1 dispatch and 1 commit per cycle
// ================================================================================
//  dispatch (DS)  ──fire───┐                    ┌──► ready, empty, robIndex to DS
//  respipe  (s+8) ──done───┤   ROB, 16 entries  │
//  LQ       (M4)  ──mark───┼─► tail ····· head ─┴──► cm_* to rename, LSU, CSR, FE
//  resolve  (EX)  ──rewind─┘
// ================================================================================
//  Mechanisms:
//   - Occupancy one-hot: ds_fire shifts up, mispredict loads rewind count,
//   commit shifts down.
//   - Mispredict: tail = branch + 1.
//   - Exception/Refetch: commits and raises cm_flush. ROB empties on its own
//    cm_flush and doesn't commit that cycle.
//   - headReady: the head entry is live and done, next states coming straight
//   from precalculated flops (stay: head, advance: head+1).
// ================================================================================
`include "uop_defs.svh"

module rob (
  input  logic                clk,
  input  logic                resetn,
  // ---- Dispatch-1/Dispatch inter-stage pipeline register -----------------------
  input  logic                ds_fire,
  input  logic [4:0]          pds_ds_rdIndex,
  input  logic [5:0]          pds_ds_rdTag,
  input  logic [5:0]          pds_ds_rdOldTag,
  input  logic                pds_ds_rdWriteEnable,
  input  logic [30:0]         pds_ds_pc,
  input  logic                pds_ds_rvc,
  input  logic [CLASS_W-1:0]  pds_ds_class,
  input  logic [SYSTEM_W-1:0] pds_ds_system,
  input  logic                pds_ds_illegal,
  input  logic                pds_ds_serialising,
  output logic                rob_dispatchReady,
  output logic                rob_empty,
  output logic [3:0]          ds_robIndex,
  // ---- completion (s+8) --------------------------------------------------------
  input  logic                wb_valid,
  input  logic [3:0]          wb_robIndex,
  input  logic                wb_exception,
  input  logic                wb_refetch,
  input  logic [31:0]         wb_badAddress,
  // ---- LQ ordering violation ---------------------------------------------------
  input  logic                lq_violationValid,
  input  logic [3:0]          lq_violationRobIndex,
  // ---- branch resolve (EX) -----------------------------------------------------
  input  logic                ex_resolveValid,
  input  logic                ex_resolveMispredict,
  input  logic [3:0]          ex_resolveRobIndex,
  // ---- commit (registered) -----------------------------------------------------
  output logic                cm_valid,
  output logic                cm_exception,
  output logic                cm_refetch,
  output logic                cm_flush,
  output logic [4:0]          cm_rdIndex,
  output logic [5:0]          cm_rdTag,
  output logic [5:0]          cm_rdOldTag,
  output logic                cm_rdWriteEnable,
  output logic [30:0]         cm_pc,
  output logic                cm_rvc,
  output logic [SYSTEM_W-1:0] cm_system,
  output logic                cm_illegal,
  output logic                cm_serialising,
  output logic                cm_isLoad,
  output logic                cm_isStore,
  output logic [31:0]         cm_badAddress
);

  localparam int N = 16;
  // ---- packed entry word -------------------------------------------------------
  typedef struct packed {
    logic [4:0]          rdIndex;
    logic [5:0]          rdTag;
    logic [5:0]          rdOldTag;
    logic                rdWriteEnable;
    logic [30:0]         pc;
    logic                rvc;
    logic [SYSTEM_W-1:0] system;
    logic                illegal;
    logic                serialising;
    logic                isLoad;
    logic                isStore;
  } word_t;
  word_t rb_writeWord, rb_readWord;

  assign rb_writeWord.rdIndex       = pds_ds_rdIndex;
  assign rb_writeWord.rdTag         = pds_ds_rdTag;
  assign rb_writeWord.rdOldTag      = pds_ds_rdOldTag;
  assign rb_writeWord.rdWriteEnable = pds_ds_rdWriteEnable;
  assign rb_writeWord.pc            = pds_ds_pc;
  assign rb_writeWord.rvc           = pds_ds_rvc;
  assign rb_writeWord.system        = pds_ds_system;
  assign rb_writeWord.illegal       = pds_ds_illegal;
  assign rb_writeWord.serialising   = pds_ds_serialising;
  assign rb_writeWord.isLoad        = pds_ds_class[CLASS_LOAD];
  assign rb_writeWord.isStore       = pds_ds_class[CLASS_STORE];

  // ---- done & trap at dispatch -------------------------------------------------
  logic rb_dispatchDone;      assign rb_dispatchDone      = pds_ds_illegal
    | pds_ds_class[CLASS_SYSTEM];
  logic rb_dispatchException; assign rb_dispatchException = pds_ds_illegal
    | pds_ds_system[SYSTEM_ECALL] | pds_ds_system[SYSTEM_EBREAK];
  logic rb_dispatchRefetch;   assign rb_dispatchRefetch   =
      pds_ds_system[SYSTEM_MRET]  | pds_ds_system[SYSTEM_FENCEI];

  // ---- pointers & occupancy state ----------------------------------------------
  logic [3:0]   rb_head, rb_headP1, rb_tail;
  logic [N-1:0] rb_headOneHot, rb_tailOneHot;
  logic [N:0]   rb_count;
  logic         rb_headReady;

  assign ds_robIndex       = rb_tail;
  assign rob_empty         = rb_count[0];
  assign rob_dispatchReady = !rb_count[N];

  // ---- late selects ------------------------------------------------------------
  logic rb_mispredict; assign rb_mispredict = ex_resolveValid & ex_resolveMispredict;
  logic rb_commit;     assign rb_commit     = rb_headReady    & !cm_flush;

  // ---- per-entry status --------------------------------------------------------
  logic [N-1:0] rb_done, rb_exception, rb_refetch;
  logic [N-1:0] rb_dispatchHit, rb_completionHit, rb_violationHit;

  for (genvar j = 0; j < N; j++) begin : g_hit
    assign rb_dispatchHit[j]   = ds_fire  & rb_tailOneHot[j];
    assign rb_completionHit[j] = wb_valid & (wb_robIndex == 4'(j));
    assign rb_violationHit[j]  = lq_violationValid & (lq_violationRobIndex == 4'(j));
  end

  always_ff @(posedge clk) begin
    for (int j = 0; j < N; j++) begin
      if (rb_dispatchHit[j]) begin
        rb_done[j]        <= rb_dispatchDone;
        rb_exception[j]   <= rb_dispatchException;
        rb_refetch[j]     <= rb_dispatchRefetch;
      end else begin
        if (rb_completionHit[j]) begin
          rb_done[j]      <= 1'b1;
          rb_exception[j] <= wb_exception;
        end
        if (rb_completionHit[j] | rb_violationHit[j])
          rb_refetch[j] <= rb_refetch[j] | (rb_completionHit[j] & wb_refetch) | rb_violationHit[j];
      end
    end
  end

  // ---- head ready - both outcomes from flops -----------------------------------
  logic rb_doneStay;     assign rb_doneStay     = |(rb_done & rb_headOneHot)
    | (wb_valid & wb_robIndex == rb_head);
  logic rb_doneAdvance;  assign rb_doneAdvance  = |(rb_done & {rb_headOneHot[N-2:0], rb_headOneHot[N-1]})
    | (wb_valid & wb_robIndex == rb_headP1);
  logic rb_readyStay;    assign rb_readyStay    = (!rb_count[0] & rb_doneStay)
    | (rb_count[0] & ds_fire & rb_dispatchDone);
  logic rb_readyAdvance; assign rb_readyAdvance = (!rb_count[0] & !rb_count[1] & rb_doneAdvance)
    | (rb_count[1] & ds_fire & rb_dispatchDone);

  // ---- occupancy ---------------------------------------------------------------
  logic [3:0] rb_rewindDistance; assign rb_rewindDistance = ex_resolveRobIndex - rb_head;
  logic [N:0] rb_countBase;      assign rb_countBase =
    rb_mispredict ? (N+1)'(2) << rb_rewindDistance :
    ds_fire       ? rb_count  << 1                 :
    rb_count;

  // ---- pointers ----------------------------------------------------------------
  always_ff @(posedge clk) begin
    if (!resetn || cm_flush) begin
      if (!resetn) begin
        rb_head       <= 4'd0;
        rb_headP1     <= 4'd1;
        rb_headOneHot <= N'(1);
        rb_tail       <= 4'd0;
        rb_tailOneHot <= N'(1);
      end else begin
        rb_tail       <= rb_head;
        rb_tailOneHot <= rb_headOneHot;
      end
      rb_count        <= (N+1)'(1);
      rb_headReady    <= 1'b0;
    end else begin
      rb_head         <= rb_head   + 4'(rb_commit);
      rb_headP1       <= rb_headP1 + 4'(rb_commit);
      rb_headOneHot   <= rb_commit ? {rb_headOneHot[N-2:0], rb_headOneHot[N-1]} : rb_headOneHot;
      rb_tail         <= rb_mispredict ? ex_resolveRobIndex + 4'd1 : rb_tail + 4'(ds_fire);
      rb_tailOneHot   <= rb_mispredict ? N'(1) << (ex_resolveRobIndex + 4'd1)
                       : ds_fire       ? {rb_tailOneHot[N-2:0], rb_tailOneHot[N-1]}
                       : rb_tailOneHot;
      rb_count        <= rb_commit ? rb_countBase >> 1 : rb_countBase;
      rb_headReady    <= rb_commit ? rb_readyAdvance   : rb_readyStay;
    end
  end

  // ---- RAM: write at tail on fire, read at head --------------------------------
  logic [$bits(rb_writeWord)-1:0] rb_ram [N];
  always_ff @(posedge clk) begin
    if (ds_fire) rb_ram[rb_tail] <= rb_writeWord;
  end

  // ---- commit outputs ----------------------------------------------------------
  always_ff @(posedge clk) begin
    rb_readWord <= rb_ram[rb_head];
    if (!resetn) begin
      cm_valid     <= 1'b0;
      cm_exception <= 1'b0;
      cm_refetch   <= 1'b0;
      cm_flush     <= 1'b0;
    end else begin
      cm_valid     <= rb_commit;
      cm_exception <= rb_commit & |  ( rb_exception & rb_headOneHot);
      cm_refetch   <= rb_commit & | ((~rb_exception & rb_refetch) & rb_headOneHot);
      cm_flush     <= rb_commit & | (( rb_exception | rb_refetch) & rb_headOneHot);
    end
  end

  assign cm_rdIndex       = rb_readWord.rdIndex;
  assign cm_rdTag         = rb_readWord.rdTag;
  assign cm_rdOldTag      = rb_readWord.rdOldTag;
  assign cm_rdWriteEnable = rb_readWord.rdWriteEnable;
  assign cm_pc            = rb_readWord.pc;
  assign cm_rvc           = rb_readWord.rvc;
  assign cm_system        = rb_readWord.system;
  assign cm_illegal       = rb_readWord.illegal;
  assign cm_serialising   = rb_readWord.serialising;
  assign cm_isLoad        = rb_readWord.isLoad;
  assign cm_isStore       = rb_readWord.isStore;

  // ---- bad address (mtval) - written by completion port, read at head ----------
  logic [31:0] rb_badAddress [N];
  always_ff @(posedge clk) begin
    if (wb_valid) rb_badAddress[wb_robIndex] <= wb_badAddress;
    cm_badAddress <= rb_badAddress[rb_head];
  end

endmodule

