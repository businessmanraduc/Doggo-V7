// ================================================================================
//  PHANTOoOM-32 -- Pattern History Table (gshare, BSRAM)
// ================================================================================
//  Direction predictor. 2-bit saturating counters; counter[1] is the prediction.
//  Two BSRAM copies form the precompute-both pair, such that resolveBit selects
//  between the two half-word conditionals.
//
//  OUT_REG flips the read register:
//    0 - block + fabric flop
//    1 - register packed in the block itself
//
//  Solo Fmax (ring-of-regs, nextpnr --85k, tw=100, 20 seeds): 149.10 / 150.04 / 152.84
// ================================================================================
module pht #(
  parameter bit OUT_REG = 1'b0,
  parameter int INDEX_W = 13
) (
  input  logic               clk,

  // ---- lookup: gshare index + late resolve bit ---------------------------------
  input  logic [INDEX_W-1:0] gshareIndex,
  input  logic               resolveBit,

  // ---- update: one resolved branch ---------------------------------------------
  input  logic               wrEnable,
  input  logic [INDEX_W-1:0] wrIndex,
  input  logic [1:0]         wrCounter,

  output logic               takenPrediction
);

  logic [INDEX_W-1:0] alternateIndex;
  assign alternateIndex = gshareIndex ^ {{(INDEX_W-1){1'b0}}, 1'b1};

  // ---- two precompute-both copies ----------------------------------------------
  logic [1:0] primaryCounterRaw, alternateCounterRaw;
  ebr2 #(.OUT_REG(OUT_REG), .ADDR_W(INDEX_W)) u_primary (
    .clk, .wrEnable, .wrAddr(wrIndex), .wrData(wrCounter),
    .rdAddr(gshareIndex),   .rdData(primaryCounterRaw)
  );
  ebr2 #(.OUT_REG(OUT_REG), .ADDR_W(INDEX_W)) u_alternate (
    .clk, .wrEnable, .wrAddr(wrIndex), .wrData(wrCounter),
    .rdAddr(alternateIndex), .rdData(alternateCounterRaw)
  );

  // ---- counters + resolve bit --------------------------------------------------
  logic [1:0] primaryCounter, alternateCounter;
  logic       resolveQ1,      resolveQ2;
  always_ff @(posedge clk) begin
    resolveQ1 <= resolveBit;
    resolveQ2 <= resolveQ1;
  end
  generate
    if (!OUT_REG) begin : g_alignReg
      always_ff @(posedge clk) begin
        primaryCounter   <= primaryCounterRaw;
        alternateCounter <= alternateCounterRaw;
      end
    end else begin : g_alignDirect
      assign primaryCounter   = primaryCounterRaw;
      assign alternateCounter = alternateCounterRaw;
    end
  endgenerate

  logic [1:0] chosenCounter;
  assign chosenCounter   = resolveQ2 ? alternateCounter : primaryCounter;
  assign takenPrediction = chosenCounter[1];

endmodule

