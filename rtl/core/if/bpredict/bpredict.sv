// ================================================================================
//  PHANTOoOM-32 -- Branch Predictor (gen/arm/cap front-end steering)
// ================================================================================
//  Ties the BTB and the PHT to the branch history and the NextPC mux.
//  Produces nextPC, the address handed to the I-Cache each cycle.
//
//  NextPC priority: reset > backend redirect > pending straddle
//                    > predicted-taken > sequential (PC + 4)
//
//  OUT_REG is a single-tier knob:
//    0 - tier-2 output register implementation, portable
//    1 - tier-3 optimized embedded usage of ECP5 BSRAM output register
//
//  Solo Fmax (ring-of-regs, nextpnr --85k, tw=100, 20 seeds): 135.41 / 140.27 / 144.97
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

  // ---- BTB update --------------------------------------------------------------
  input  logic                   btbWrEnable,
  input  logic [BTB_INDEX_W-1:0] btbWrIndex,
  input  logic [53:0]            btbWrEntry,

  // ---- PHT update --------------------------------------------------------------
  input  logic                   phtWrEnable,
  input  logic [PHT_INDEX_W-1:0] phtWrIndex,
  input  logic [1:0]             phtWrCounter,

  output logic [31:0]            nextPC
);

  // ---- F0 -> lookup address + gshare index -------------------------------------
  logic [31:0]            lookupPC;
  logic [PHT_INDEX_W-1:0] branchHistory;
  logic [PHT_INDEX_W-1:0] gshareIndex;

  assign lookupPC    = nextPC + 32'd4;
  assign gshareIndex = lookupPC[PHT_INDEX_W:1] ^ branchHistory;

  // ---- BTB: target + kind ------------------------------------------------------
  logic        btbHit, btbIsBranch, btbIsConditional, btbIsStraddle;
  logic [31:0] btbTarget;
  btb #(.OUT_REG(OUT_REG), .INDEX_W(BTB_INDEX_W), .TAG_W(TAG_W)) u_btb (
   .clk, .lookupPC,
    .wrEnable(btbWrEnable), .wrIndex(btbWrIndex), .wrEntry(btbWrEntry),
    .hit(btbHit), .isBranch(btbIsBranch), .isConditional(btbIsConditional),
    .isStraddle(btbIsStraddle), .target(btbTarget)
  );

  // ---- PHT: direction ----------------------------------------------------------
  logic phtTaken;
  pht #(.OUT_REG(OUT_REG), .INDEX_W(PHT_INDEX_W)) u_pht (
    .clk, .gshareIndex, .resolveBit(branchHistory[0]),
    .wrEnable(phtWrEnable), .wrIndex(phtWrIndex), .wrCounter(phtWrCounter),
    .takenPrediction(phtTaken)
  );

  // ---- combine branch prediction outcome ---------------------------------------
  logic predictedTaken;
  assign predictedTaken = btbHit && btbIsBranch && (btbIsConditional ? phtTaken : 1'b1);

  // ---- straddle delayed-apply --------------------------------------------------
  logic        straddlePending;
  logic [31:0] straddleTarget;
  always_ff @(posedge clk) begin
    straddlePending <= predictedTaken && btbIsStraddle && !redirectValid && !boot;
    straddleTarget  <= btbTarget;
  end

  // ---- F0 NextPC mux -----------------------------------------------------------
  logic [31:0] combNextPC; assign combNextPC =
    boot                               ? RESET_PC       :
    redirectValid                      ? redirectPC     :
    straddlePending                    ? straddleTarget :
    (predictedTaken && !btbIsStraddle) ? btbTarget      :
  lookupPC;

  always_ff @(posedge clk) begin
    nextPC <= combNextPC;
    if (!redirectValid) branchHistory <= {branchHistory[PHT_INDEX_W-2:0], predictedTaken};
  end

endmodule

