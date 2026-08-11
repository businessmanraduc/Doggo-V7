// ================================================================================
//  PHANTOoOM-32 -- Pattern History Table (gshare, BSRAM, two-word)
// ================================================================================
//  Direction predictor. 2-bit saturating counters, counter[1] is the prediction.
//  Answers both words of a fetch pair per cycle.
//
//  ---- precompute-both ----------------------------------------------------------
//  One bit of the history is never known when the lookup is armed: the direction
//  of a branch is still in the predictor's own pipeline. So each port reads
//  the table twice, at index and index^1, and the caller picks between them
//  once the bit is known.
//
//  Contract:
//    - the caller forms the index with the pending direction taken as 0, so
//      that index^1 is the same lookup with it taken as one
//    - resolve is consumed live at the output, two cycles after the index
//
//  Delaying resolve makes the selector equal to the bit already folded into
//  the index, so the two cancel: the chosen entry ends up at index[0] = pc[0]
//  whatever the history did.
//
//  Solo Fmax (ring-of-regs, nextpnr --85k, tw=100, 20 seeds): see fmax.md
// ================================================================================
module pht #(
  parameter int INDEX_W = 13
) (
  input  logic                clk,
  input  logic                readEnable,

  // ---- lookup: one index per slot, pending direction taken as zero -------------
  input  logic [INDEX_W-1:0]  indexA,
  input  logic [INDEX_W-1:0]  indexB,

  // ---- pending directions, live, two cycles after the indices ------------------
  input  logic                resolveA,
  input  logic                resolveB,

  // ---- update: one resolved branch ---------------------------------------------
  input  logic                wrEnable,
  input  logic [INDEX_W-1:0]  wrIndex,
  input  logic [1:0]          wrCounter,

  output logic                takenA,
  output logic                takenB
);

  logic [INDEX_W-1:0] altIndexA, altIndexB;
  assign altIndexA = indexA ^ {{(INDEX_W-1){1'b0}}, 1'b1};
  assign altIndexB = indexB ^ {{(INDEX_W-1){1'b0}}, 1'b1};

  // ---- four copies of one table: two slots, two candidates each ----------------
  logic [1:0] primaryA, alternateA, primaryB, alternateB;

  ebr2 #(.OUT_REG(1'b1), .ADDR_W(INDEX_W)) u_primaryA (
    .clk, .wrEnable, .wrAddr(wrIndex), .wrData(wrCounter),
    .rdAddr(indexA),    .readEnable, .rdData(primaryA)
  );
  ebr2 #(.OUT_REG(1'b1), .ADDR_W(INDEX_W)) u_alternateA (
    .clk, .wrEnable, .wrAddr(wrIndex), .wrData(wrCounter),
    .rdAddr(altIndexA), .readEnable, .rdData(alternateA)
  );
  ebr2 #(.OUT_REG(1'b1), .ADDR_W(INDEX_W)) u_primaryB (
    .clk, .wrEnable, .wrAddr(wrIndex), .wrData(wrCounter),
    .rdAddr(indexB),    .readEnable, .rdData(primaryB)
  );
  ebr2 #(.OUT_REG(1'b1), .ADDR_W(INDEX_W)) u_alternateB (
    .clk, .wrEnable, .wrAddr(wrIndex), .wrData(wrCounter),
    .rdAddr(altIndexB), .readEnable, .rdData(alternateB)
  );

  // ---- pick once the pending direction is known --------------------------------
  logic [1:0] counterA, counterB;
  assign counterA = resolveA ? alternateA : primaryA;
  assign counterB = resolveB ? alternateB : primaryB;

  assign takenA = counterA[1];
  assign takenB = counterB[1];

endmodule

