// ================================================================================
//  PHANTOoOM-32 -- Instruction Cache line-fill engine
// ================================================================================
//  Owns everything the lookup path never touches: the boot invalidate sweep,
//  the burst request to memory, and the writes into tag/data arrays.
//
//  States:
//    SWEEP   128 cycles clearing every valid bit, all four ways at once.
//            initDone is low and the cache does not report hits.
//    SETTLE  four cycles. The tag block samples the array in F0, so a lookup can
//            still be carrying pre-sweep tag data three cycles after set was cleared.
//    IDLE    waiting for a miss.
//    FILL    fillReq held, one word written per fillRValid beat into the victim.
//    TAG     the tag goes in last so a lookup racing the fill either misses or
//            hits a line that is complete, never half-filled.
//    DRAIN   three cycles, so that the in-flight lookups can be cleared since
//            they now hold stale information about the newly-filled line.
//
//  Solo Fmax (ring-of-regs, nextpnr --85k, tw=100, 20 seeds): see fmax.md
// ================================================================================
module linefill #(
  parameter int SET_IDX_W = 7,
  parameter int WIL_W     = 3,
  parameter int TAG_W     = 13,
  parameter int WORDIDX_W = SET_IDX_W + WIL_W
) (
  input  logic                  clk,
  input  logic                  resetn,

  // ---- miss report, registered -------------------------------------------------
  input  logic                  missValid,
  input  logic [TAG_W-1:0]      missTag,
  input  logic [SET_IDX_W-1:0]  missSet,
  input  logic [1:0]            missVictim,

  // ---- memory side: request held, words stream back in order -------------------
  output logic [31:0]           fillAddr,
  output logic                  fillReq,
  input  logic [31:0]           fillRData,
  input  logic                  fillRValid,

  // ---- array writes ------------------------------------------------------------
  output logic [3:0]            dataWrEnable,
  output logic [WORDIDX_W-1:0]  dataWrIndex,
  output logic [31:0]           dataWrWord,
  output logic [3:0]            tagWrEnable,
  output logic [SET_IDX_W-1:0]  tagWrSet,
  output logic [TAG_W-1:0]      tagWrTag,
  output logic                  tagWrValid,

  // ---- status ------------------------------------------------------------------
  output logic                  initDone,
  output logic                  fillBusy
);

  localparam int OFF_W      = WIL_W + 2;
  localparam int SETS       = 1 << SET_IDX_W;
  localparam int LINE_WORDS = 1 << WIL_W;
  localparam int PAD_W      = 32 - TAG_W - SET_IDX_W - OFF_W;

  localparam logic [2:0] S_SWEEP  = 3'd0;
  localparam logic [2:0] S_SETTLE = 3'd1;
  localparam logic [2:0] S_IDLE   = 3'd2;
  localparam logic [2:0] S_FILL   = 3'd3;
  localparam logic [2:0] S_TAG    = 3'd4;
  localparam logic [2:0] S_DRAIN  = 3'd5;

  logic [2:0]           state;
  logic [SET_IDX_W-1:0] sweepCount;
  logic [WIL_W-1:0]     beatCount;
  logic [1:0]           drainCount;
  logic [2:0]           settleCount;
  logic [TAG_W-1:0]     fillTag;
  logic [SET_IDX_W-1:0] fillSet;
  logic [1:0]           fillWay;

  // ---- sequencer ---------------------------------------------------------------
  always_ff @(posedge clk) begin
    if (!resetn) begin
      state  <= S_SWEEP;
      sweepCount  <= '0;
      beatCount   <= '0;
      drainCount  <= '0;
      settleCount <= '0;
    end else begin
      case (state)
        S_SWEEP: begin
          sweepCount <= sweepCount + 1'b1;
          if (sweepCount == SET_IDX_W'(SETS-1)) begin
            settleCount <= '0;
            state       <= S_SETTLE;
          end
        end

        S_SETTLE: begin
          settleCount <= settleCount + 1'b1;
          if (settleCount == 3'd3) state <= S_IDLE;
        end

        S_IDLE: begin
          if (missValid) begin
            fillTag   <= missTag;
            fillSet   <= missSet;
            fillWay   <= missVictim;
            beatCount <= '0;
            state     <= S_FILL;
          end
        end

        S_FILL: begin
          if (fillRValid) begin
            if (beatCount == WIL_W'(LINE_WORDS-1)) begin
              state <= S_TAG;
            end else begin
              beatCount <= beatCount + 1'b1;
            end
          end
        end

        S_TAG: begin
          drainCount <= '0;
          state      <= S_DRAIN;
        end

        S_DRAIN: begin
          drainCount <= drainCount + 1'b1;
          if (drainCount == 2'd2) begin
            state <= S_IDLE;
          end
        end

        default: state <= S_IDLE;
      endcase
    end
  end

  // ---- memory request ----------------------------------------------------------
  assign fillReq  = (state == S_FILL);
  assign fillAddr = {{PAD_W{1'b0}}, fillTag, fillSet, {OFF_W{1'b0}}};

  // ---- data array: one word per burst beat into victim way ---------------------
  assign dataWrEnable = ((state == S_FILL) && fillRValid)
    ? (4'b0001 << fillWay)
    : (4'b0000);
  assign dataWrIndex  = {fillSet, beatCount};
  assign dataWrWord   = fillRData;

  // ---- tag array: cleared wholesale while sweeping, set once when filled -------
  always_ff @(posedge clk) begin
    if (!resetn) begin
      tagWrEnable <= 4'b0000;
      tagWrSet    <= '0;
      tagWrTag    <= '0;
      tagWrValid  <= 1'b0;
    end else begin
      tagWrEnable <= 4'b0000;
      tagWrSet    <= fillSet;
      tagWrTag    <= fillTag;
      tagWrValid  <= 1'b1;
      if (state == S_SWEEP) begin
        tagWrEnable <= 4'b1111;
        tagWrSet    <= sweepCount;
        tagWrTag    <= '0;
        tagWrValid  <= 1'b0;
      end else if (state == S_TAG) begin
        tagWrEnable <= 4'b0001 << fillWay;
      end
    end
  end

  logic initDoneQ;
  always_ff @(posedge clk) begin
    if (!resetn) initDoneQ <= 1'b0;
    else         initDoneQ <= (state != S_SWEEP) && (state != S_SETTLE);
  end
  assign initDone = initDoneQ;
  assign fillBusy = (state != S_IDLE);

endmodule

