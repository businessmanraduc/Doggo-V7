// ================================================================================
//  PHANTOoOM-32 -- Branch Target Buffer (tagged, BSRAM, two-word banked)
// ================================================================================
//  Answers two fetch words per cycle so the predictor can fill FTQ faster
//  than the fetch engine drains it.
//
//  ---- banking ------------------------------------------------------------------
//  Bank 0 holds words with PC[2]=0, bank 1 holds PC[2]=1. A pair {A, A+4} always
//  straddles one of each whichever way it is aligned.
//
//    pcA[2]=0    A -> bank 0 @ pcA[11:3]   B -> bank 1 @ pcB[11:3]
//    pcA[2]=1    A -> bank 1 @ pcA[11:3]   B -> bank 0 @ pcB[11:3]
//
//  ---- entry --------------------------------------------------------------------
//    53       52       51        50         49    48-46    45      44     43      42    41-31  30-0
//  {valid, isBranch, isCond, isStraddle, exitLow, 00..0, cOnHit, tOnHit, isRet, isCall,  tag, target}
//
//  Solo Fmax (ring-of-regs, nextpnr --85k, tw=100, 20 seeds): see fmax.md
// ================================================================================
module btb #(
  parameter int INDEX_W = 9,
  parameter int TAG_W   = 11
) (
  input  logic               clk,
  input  logic               readEnable,

  // ---- lookup: one word pair ---------------------------------------------------
  input  logic [31:0]        lookupPcA,
  input  logic [31:0]        lookupPcB,

  // ---- update: one resolved branch ---------------------------------------------
  input  logic               wrEnable,
  input  logic               wrBank,
  input  logic [INDEX_W-1:0] wrIndex,
  input  logic [53:0]        wrEntry,

  // ---- verdict for slot A (two cycles after lookup) ----------------------------
  output logic               tagMatchA,
  output logic               takenOnHitA,
  output logic               condOnHitA,
  output logic               isStraddleA,
  output logic               exitAfterLowA,
  output logic               isCallA,
  output logic               isReturnA,
  output logic [31:0]        targetA,

  // ---- verdict for slot B ------------------------------------------------------
  output logic               tagMatchB,
  output logic               takenOnHitB,
  output logic               condOnHitB,
  output logic               isStraddleB,
  output logic               exitAfterLowB,
  output logic               isCallB,
  output logic               isReturnB,
  output logic [31:0]        targetB
);

  // ---- entry field positions ---------------------------------------------------
  localparam int TARGET_LSB   = 0;
  localparam int TAG_LSB      = 31;
  localparam int CALL_BIT     = 42;
  localparam int RETURN_BIT   = 43;
  localparam int TAKEN_ON_HIT = 44;
  localparam int COND_ON_HIT  = 45;
  localparam int EXIT_BIT     = 49;
  localparam int STRADDLE_BIT = 50;
  localparam int COND_BIT     = 51;
  localparam int BRANCH_BIT   = 52;
  localparam int VALID_BIT    = 53;

  localparam int INDEX_LSB    = 3;
  localparam int TAG_MSB      = INDEX_W + TAG_W + 2;
  localparam int TAG_LSB_PC   = INDEX_W + 3;

  // ---- split pair across banks -------------------------------------------------
  
  logic               slotAIsOdd;
  logic [INDEX_W-1:0] indexA,   indexB;
  logic [TAG_W-1:0]   tagA,     tagB;
  logic [INDEX_W-1:0] addrEven, addrOdd;

  assign slotAIsOdd = lookupPcA[2];
  assign indexA     = lookupPcA[INDEX_W+2 : INDEX_LSB];
  assign indexB     = lookupPcB[INDEX_W+2 : INDEX_LSB];
  assign tagA       = lookupPcA[TAG_MSB   : TAG_LSB_PC];
  assign tagB       = lookupPcB[TAG_MSB   : TAG_LSB_PC];

  assign addrEven   = slotAIsOdd ? indexB : indexA;
  assign addrOdd    = slotAIsOdd ? indexA : indexB;

  // ---- storage: two banks, three 18-bit blocks each ----------------------------
  logic [53:0] rawEven, rawOdd;
  genvar blk;
  generate
    for (blk = 0; blk < 3; blk++) begin : g_even
      ebr18 #(.OUT_REG(1'b1), .ADDR_W(INDEX_W)) u_block (
        .clk, .wrEnable(wrEnable && !wrBank), .wrAddr(wrIndex),
        .wrData(wrEntry[blk*18 +: 18]),
        .rdAddr(addrEven), .readEnable, .rdData(rawEven[blk*18 +: 18])
      );
    end
    for (blk = 0; blk < 3; blk++) begin : g_odd
      ebr18 #(.OUT_REG(1'b1), .ADDR_W(INDEX_W)) u_block (
        .clk, .wrEnable(wrEnable && wrBank), .wrAddr(wrIndex),
        .wrData(wrEntry[blk*18 +: 18]),
        .rdAddr(addrOdd), .readEnable, .rdData(rawOdd[blk*18 +: 18])
      );
    end
  endgenerate

  // ---- carry tags and swap through the two-cycle read --------------------------
  logic [TAG_W-1:0] tagA_P1, tagA_P2, tagB_P1, tagB_P2;
  logic             swap_P1, swap_P2;
  always_ff @(posedge clk) begin
    if (readEnable) begin
      tagA_P1 <= tagA; tagA_P2 <= tagA_P1;
      tagB_P1 <= tagB; tagB_P2 <= tagB_P1;
      swap_P1 <= slotAIsOdd;
      swap_P2 <= swap_P1;
    end
  end

  // ---- put banks back in program order -----------------------------------------
  logic [53:0] entryA, entryB;
  assign entryA = swap_P2 ? rawOdd : rawEven;
  assign entryB = swap_P2 ? rawEven : rawOdd;

  // ---- unpack ------------------------------------------------------------------
  assign takenOnHitA   = entryA[TAKEN_ON_HIT];
  assign condOnHitA    = entryA[COND_ON_HIT];
  assign isStraddleA   = entryA[STRADDLE_BIT];
  assign exitAfterLowA = entryA[EXIT_BIT];
  assign isCallA       = entryA[CALL_BIT];
  assign isReturnA     = entryA[RETURN_BIT];
  assign targetA       = {entryA[TARGET_LSB +: 31], 1'b0};
  assign tagMatchA     = (entryA[TAG_LSB +: TAG_W] == tagA_P2);

  assign takenOnHitB   = entryB[TAKEN_ON_HIT];
  assign condOnHitB    = entryB[COND_ON_HIT];
  assign isStraddleB   = entryB[STRADDLE_BIT];
  assign exitAfterLowB = entryB[EXIT_BIT];
  assign isCallB       = entryB[CALL_BIT];
  assign isReturnB     = entryB[RETURN_BIT];
  assign targetB       = {entryB[TARGET_LSB +: 31], 1'b0};
  assign tagMatchB     = (entryB[TAG_LSB +: TAG_W] == tagB_P2);

endmodule

