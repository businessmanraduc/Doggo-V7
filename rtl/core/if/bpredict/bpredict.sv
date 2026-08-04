// ================================================================================
//  PHANTOoOM-32 -- Branch Predictor (gen/arm/cap front-end steering)
// ================================================================================
//  Ties the BTB and the PHT to the branch history and the NextPC mux.
//  Produces nextPC, the address handed to the I-Cache each cycle.
//
//  NextPC priority: reset > backend redirect > pending straddle
//                    > predicted-taken > sequential (PC + 4)
//
//  ---- fetch-word metadata ------------------------------------------------------
//  The BTB read is two cycles and lookupPC only looks one fetch ahead, so
//  a verdict lands one word after the word it describes. Two consequences:
//    overrun   a predicted-taken redirect arrives too late to stop the next
//              sequential fetch, so one wrong-path word is fetched behind
//              every taken branch and is marked dead.
//    exit      a 16-bit branch in a word's low half means the high half is
//              never executed even tho the word is live.
//
//  ---- prediction shadow --------------------------------------------------------
//  After any redirect the two verdicts still in flight describe wrong-path
//  words, so predictions are surpressed for two cycles.
//
//  ---- parking ------------------------------------------------------------------
//  Stall parks F0 on an I-Cache fill or on fetch-queue credit. Everything in
//  the predictor freezes together: nextPC, the shadow, the history, and the
//  BTB+PHT read pipelines.
//
//  ---- branch history -----------------------------------------------------------
//  The BHR shifts one per conditional branch. On a redirect it is reloaded
//  from redirectBHR, which the backend recovers as gshareIndex ^ lookupPC[14:2].
//
//  OUT_REG is a single-tier knob:
//    0 - tier-2 output register implementation, portable
//    1 - tier-3 optimized embedded usage of ECP5 BSRAM output register
//
//  Solo Fmax (ring-of-regs, nextpnr --85k, tw=100, 20 seeds): see fmax.md
// ================================================================================
module bpredict #(
  parameter bit          OUT_REG     = 1'b0,
  parameter int          BTB_INDEX_W = 9,
  parameter int          PHT_INDEX_W = 13,
  parameter int          TAG_W       = 11,
  parameter logic [31:0] RESET_PC = 32'h0000_0000
) (
  input  logic                   clk,
  input  logic                   boot,
  input  logic                   redirectValid,
  input  logic [31:0]            redirectPC,
  input  logic [PHT_INDEX_W-1:0] redirectBHR,
  input  logic                   stall,

  // ---- BTB update --------------------------------------------------------------
  input  logic                   btbWrEnable,
  input  logic [BTB_INDEX_W-1:0] btbWrIndex,
  input  logic [53:0]            btbWrEntry,

  // ---- PHT update --------------------------------------------------------------
  input  logic                   phtWrEnable,
  input  logic [PHT_INDEX_W-1:0] phtWrIndex,
  input  logic [1:0]             phtWrCounter,

  // ---- fetch address + metadata for word issued one cycle ago ------------------
  output logic [31:0]            nextPC,
  output logic                   fetchValid,
  output logic [31:2]            fetchPC,
  output logic [1:0]             fetchHwValid
);

  // ---- F0 -> lookup address + gshare index -------------------------------------
  logic [31:0]            wordPC;
  logic [31:0]            lookupPC;
  logic [PHT_INDEX_W-1:0] branchHistory;
  logic [PHT_INDEX_W-1:0] gshareIndex;

  assign wordPC      = {nextPC[31:2], 2'b00};
  assign lookupPC    = wordPC + 32'd4;
  assign gshareIndex = lookupPC[PHT_INDEX_W+1:2] ^ branchHistory;

  // ---- BTB: target + kind ------------------------------------------------------
  logic        btbHit, btbIsBranch, btbIsConditional, btbIsStraddle, btbExitLow;
  logic [31:0] btbTarget;
  btb #(.OUT_REG(OUT_REG), .INDEX_W(BTB_INDEX_W), .TAG_W(TAG_W)) u_btb (
   .clk, .lookupPC, .readEnable(!stall),
    .wrEnable(btbWrEnable), .wrIndex(btbWrIndex), .wrEntry(btbWrEntry),
    .hit(btbHit), .isBranch(btbIsBranch), .isConditional(btbIsConditional),
    .isStraddle(btbIsStraddle), .exitAfterLow(btbExitLow), .target(btbTarget)
  );

  // ---- PHT: direction ----------------------------------------------------------
  logic phtTaken;
  pht #(.OUT_REG(OUT_REG), .INDEX_W(PHT_INDEX_W)) u_pht (
    .clk, .gshareIndex, .readEnable(!stall), .resolveBit(branchHistory[0]),
    .wrEnable(phtWrEnable), .wrIndex(phtWrIndex), .wrCounter(phtWrCounter),
    .takenPrediction(phtTaken)
  );

  // ---- prediction shadow: two verdicts behind a redirect -----------------------
  logic advance; assign advance = boot || redirectValid || !stall;

  logic shadowF1, shadowF2;
  logic verdictValid; assign verdictValid = !(shadowF1 || shadowF2);

  // ---- combine branch prediction outcome ---------------------------------------
  logic predictedTaken; assign predictedTaken =
    verdictValid && btbHit && btbIsBranch && (btbIsConditional ? phtTaken : 1'b1);
  logic takenNow; assign takenNow =
    predictedTaken && !btbIsStraddle && !redirectValid && !boot;

  // ---- straddle delayed-apply --------------------------------------------------
  logic        straddlePending;
  logic [31:0] straddleTarget;
  always_ff @(posedge clk) begin
    if (advance) begin
      straddlePending <= predictedTaken && btbIsStraddle && !redirectValid && !boot;
      straddleTarget  <= btbTarget;
    end
  end

  always_ff @(posedge clk) begin
    if (advance) begin
      shadowF1 <= boot || redirectValid || takenNow || straddlePending;
      shadowF2 <= shadowF1;
    end
  end

  // ---- F0 NextPC mux -----------------------------------------------------------
  logic [31:0] combNextPC; assign combNextPC =
    boot                               ? RESET_PC       :
    redirectValid                      ? redirectPC     :
    straddlePending                    ? straddleTarget :
    (predictedTaken && !btbIsStraddle) ? btbTarget      :
  lookupPC;

  logic bhrShift; assign bhrShift = verdictValid && btbHit && btbIsBranch && btbIsConditional;

  always_ff @(posedge clk) begin
    if (advance) nextPC <= combNextPC;

    if (boot)                    branchHistory <= '0;
    else if (redirectValid)      branchHistory <= redirectBHR;
    else if (bhrShift && !stall) branchHistory <= {branchHistory[PHT_INDEX_W-2:0], phtTaken};
  end

  // ---- metadata for the word issued one cycle ago ------------------------------
  logic prevStartHigh, redirectedF1;
  always_ff @(posedge clk) begin
    fetchValid <= !stall;
    if (!stall) begin
      fetchPC       <= nextPC[31:2];
      prevStartHigh <= nextPC[1];
      redirectedF1  <= takenNow || straddlePending;
    end
  end

  logic lowLive, highLive;
  assign lowLive  = ~prevStartHigh;
  assign highLive = ~(takenNow && btbExitLow) && ~straddlePending;

  assign fetchHwValid = redirectedF1 ? 2'b00 : {highLive, lowLive};

endmodule

