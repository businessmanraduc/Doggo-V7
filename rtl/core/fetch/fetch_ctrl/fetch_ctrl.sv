// ================================================================================
//  PHANTOoOM-32 -- Fetch Control
// ================================================================================
//  Owns the three things that live between the predictor, cache and fetch
//  queue which belong to none of them:
//
//  Metadata delay - The cache takes an address in F0 and reports in F3. bpredict
//                   already publishes its metadata one cycle late, so two more
//                   stages line the two up.
//  Kill           - A word is only wanted if it is live and still on the path
//                   being fetched. Everything else (overrun behind taken
//                   branch/wrong-path words behind redirect) is killed at F3
//                   so the fill engine never chases it.
//  Miss Replay    - The fill engine fills the line but never delivers the
//                   word, so the miss is replayed from here. Clearing the
//                   valid chain drops the two words already behind the missed
//                   one, which would otherwise reach the queue ahead of it.
//
//  Solo Fmax (ring-of-regs, nextpnr --85k, tw=100, 20 seeds): see fmax.md
// ================================================================================
module fetch_ctrl #(
  parameter int PHT_INDEX_W = 13
) (
  input  logic                   clk,
  input  logic                   resetn,

  // ---- bpredict: metadata for the word issued one cycle ago --------------------
  input  logic [31:2]            fetchPC,
  input  logic [1:0]             fetchHwValid,
  input  logic [PHT_INDEX_W-1:0] fetchGshare,

  // ---- icache ------------------------------------------------------------------
  input  logic                   hit,
  input  logic                   fillBusy,

  // ---- fetch queue credit ------------------------------------------------------
  input  logic                   canFetch,

  // ---- backend -----------------------------------------------------------------
  input  logic                   backendRedirect,

  // ---- steering ----------------------------------------------------------------
  output logic                   boot,
  output logic                   stall,
  output logic                   lookupValid,
  output logic                   lookupKill,
  output logic                   replayValid,
  output logic [31:0]            replayPC,
  output logic [PHT_INDEX_W-1:0] replayBHR,

  // ---- fetch queue push --------------------------------------------------------
  output logic                   pushValid,
  output logic [31:2]            pushPC,
  output logic [1:0]             pushHwValid,
  output logic [PHT_INDEX_W-1:0] pushGshare
);

  assign boot = ~resetn;

  // ---- metadata delay: F1 (from bpredict) to F3 (cache report) -----------------
  logic                   validF1,  validF2, validF3;
  logic [31:2]            pcF2,     pcF3;
  logic [1:0]             hwF2,     hwF3;
  logic [PHT_INDEX_W-1:0] gsF2, gsF3;

  logic wantF3;  assign wantF3  = validF3 && (hwF3 != 2'b00);
  logic missNow; assign missNow = wantF3 && !hit;

  always_ff @(posedge clk) begin
    if (!resetn || backendRedirect || missNow) begin
      validF1 <= 1'b0; validF2 <= 1'b0; validF3 <= 1'b0;
    end else begin
      validF1 <= lookupValid;
      validF2 <= validF1;
      validF3 <= validF2;
    end

    pcF2 <= fetchPC; hwF2 <= fetchHwValid; gsF2 <= fetchGshare;
    pcF3 <= pcF2;    hwF3 <= hwF2;         gsF3 <= gsF2;
  end

  // ---- replay: wait for fill to start, then to finish --------------------------
  localparam logic [1:0] R_IDLE = 2'd0, R_BUSY = 2'd1, R_DONE = 2'd2;

  logic [1:0]             rState;
  logic [31:2]            missPC;
  logic [1:0]             missHw;
  logic [PHT_INDEX_W-1:0] missGs;

  always_ff @(posedge clk) begin
    if (!resetn || backendRedirect) begin
      rState <= R_IDLE;
    end else begin
      case (rState)
        R_IDLE: if (missNow) begin
          rState <= R_BUSY;
          missPC <= pcF3;
          missHw <= hwF3;
          missGs <= gsF3;
        end

        R_BUSY: if (fillBusy) begin
          rState <= R_DONE;
        end

        R_DONE: if (!fillBusy) begin
          rState <= R_IDLE;
        end

        default: rState <= R_IDLE;
      endcase
    end
  end

  assign replayValid = (rState == R_DONE) && !fillBusy && !backendRedirect;
  assign replayPC    = {missPC, ~missHw[0], 1'b0};
  assign replayBHR   = missGs ^ missPC[PHT_INDEX_W+1:2];

  // ---- steering ----------------------------------------------------------------
  assign stall       = fillBusy || missNow || !canFetch;
  assign lookupValid = resetn && !stall && !backendRedirect && !replayValid;
  assign lookupKill  = !wantF3;

  assign pushValid   = wantF3 && hit;
  assign pushPC      = pcF3;
  assign pushHwValid = hwF3;
  assign pushGshare  = gsF3;

endmodule

