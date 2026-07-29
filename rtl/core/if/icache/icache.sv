// ================================================================================
//  PHANTOoOM-32 -- Instruction Cache (4-way set-associative, pipelined hit)
// ================================================================================
//  16 KB, 4 ways, 32-byte lines. Serves one 32-bit word per lookup, one word
//  per cycle, three-cycle hit.
//  Data lives in BSRAM, tags and replacement state live in LUTRAM.
//
//    byte addr | tag[24:12] | set[11:5] | word-in-line[4:2] | hw[1] | b[0]
//
//  Stage map (address presented in F0):
//    F0 - address fields captured: BSRAM address register, lookupSetQ1, tag delay
//    F1 - BSRAM read and tag LUTRAM read in flight
//    F2 - tag compare; word and predict both land at F2/F3 edge
//    F3 - registered verdict drives way mux, instrWord out
//
//  Solo Fmax (ring-of-regs, nextpnr --85k, tw=100, 20 seeds): 158.68 / 169.47 / 178.00
// ================================================================================
module icache #(
  parameter int SET_IDX_W = 7,
  parameter int WIL_W     = 3,
  parameter int TAG_W     = 13,
  parameter int WORDIDX_W = SET_IDX_W + WIL_W
) (
  input  logic                 clk,
  input  logic [31:0]          lookupAddr,

  // ---- fill write, driven by miss engine ---------------------------------------
  input  logic [3:0]           dataWrEnable,
  input  logic [WORDIDX_W-1:0] dataWrIndex,
  input  logic [31:0]          dataWrWord,
  input  logic [3:0]           tagWrEnable,
  input  logic [SET_IDX_W-1:0] tagWrSet,
  input  logic [TAG_W-1:0]     tagWrTag,
  input  logic                 tagWrValid,

  // ---- read verdict ------------------------------------------------------------
  output logic [31:0]          instrWord,
  output logic                 hit,
  output logic [1:0]           victimWay
);

  localparam int WAYS    = 4;
  localparam int OFF_W   = WIL_W + 2;
  localparam int ENTRY_W = TAG_W + 1;

  // ---- address fields ----------------------------------------------------------
  logic [WORDIDX_W-1:0] lookupWordIndex;
  logic [SET_IDX_W-1:0] lookupSet;
  logic [TAG_W-1:0]     lookupTag;
  assign lookupWordIndex = lookupAddr[2 +: WORDIDX_W];
  assign lookupSet       = lookupAddr[OFF_W +: SET_IDX_W];
  assign lookupTag       = lookupAddr[OFF_W+SET_IDX_W +: TAG_W];

  // ---- lookup pipeline ---------------------------------------------------------
  logic [SET_IDX_W-1:0] lookupSetQ1;
  logic [SET_IDX_W-1:0] lookupSetQ2;
  logic [SET_IDX_W-1:0] lookupSetQ3;
  logic [TAG_W-1:0]     lookupTagQ1;
  logic [TAG_W-1:0]     lookupTagQ2;
  always_ff @(posedge clk) begin
    lookupSetQ1 <= lookupSet;
    lookupSetQ2 <= lookupSetQ1;
    lookupSetQ3 <= lookupSetQ2;
    lookupTagQ1 <= lookupTag;
    lookupTagQ2 <= lookupTagQ1;
  end

  // ---- tags + valid storage: one LUTRAM per way, compare in F2 -----------------
  logic [WAYS-1:0] matchVec;
  genvar way, blk;
  generate
    for (way = 0; way < WAYS; way++) begin : g_tagWay
      (* ram_style = "distributed" *) logic [ENTRY_W-1:0] tagMem [0:(1<<SET_IDX_W)-1];

      logic [ENTRY_W-1:0] entryQ2;
      always_ff @(posedge clk) begin
        if (tagWrEnable[way]) begin
          tagMem[tagWrSet] <= {tagWrValid, tagWrTag};
        end
        entryQ2 <= tagMem[lookupSetQ1];
      end

      assign matchVec[way] = entryQ2[TAG_W] && (entryQ2[TAG_W-1:0] == lookupTagQ2);
    end
  endgenerate

  // ---- data storage: two ebr18 per way, word valid in F2 -----------------------
  logic [35:0] wrWide; assign wrWide = {4'b0, dataWrWord};
  logic [31:0] readWord [0:WAYS-1];
  generate
    for (way = 0; way < WAYS; way++) begin : g_dataWay
      logic [35:0] rawWord;
      for (blk = 0; blk < 2; blk++) begin : g_block
        ebr18 #(.OUT_REG(1'b1), .ADDR_W(WORDIDX_W)) u_block (
          .clk,                     .wrEnable(dataWrEnable[way]),
          .wrAddr(dataWrIndex),     .wrData(wrWide[blk*18 +: 18]),
          .rdAddr(lookupWordIndex), .rdData(rawWord[blk*18 +: 18])
        );
      end

      assign readWord[way] = rawWord[31:0];
    end
  endgenerate

  // ---- verdict + cache word: available in F3 -----------------------------------
  logic [WAYS-1:0] hitVecQ;
  logic [31:0]     heldWord [0:WAYS-1];

  always_ff @(posedge clk) begin
    hitVecQ <= matchVec;
  end
  generate
    for (way = 0; way < WAYS; way++) begin : g_hold
      always_ff @(posedge clk) begin
        heldWord[way] <= readWord[way];
      end
    end
  endgenerate

  logic [1:0] hitWay;
  assign hit    = |hitVecQ;
  assign hitWay = {hitVecQ[3] | hitVecQ[2], hitVecQ[3] | hitVecQ[1]};

  // ---- way mux -----------------------------------------------------------------
  always_comb begin
    case (hitWay)
      2'd0:    instrWord = heldWord[0];
      2'd1:    instrWord = heldWord[1];
      2'd2:    instrWord = heldWord[2];
      default: instrWord = heldWord[3];
    endcase
  end

  // ---- tree PLRU ---------------------------------------------------------------
  (*  ram_style = "distributed" *) logic [2:0] plruMem [0:(1<<SET_IDX_W)-1];
  logic [2:0] lookupState, touchState, touchNext;
  always_ff @(posedge clk) begin
    lookupState <= plruMem[lookupSetQ1];
    touchState  <= lookupState;
  end

  always_comb begin
    touchNext    = touchState;
    touchNext[0] = ~hitWay[1];
    if (hitWay[1]) begin
      touchNext[2] = ~hitWay[0];
    end else begin
      touchNext[1] = ~hitWay[0];
    end
  end
  always_ff @(posedge clk) begin
    if (hit) begin
      plruMem[lookupSetQ3] <= touchNext;
    end
  end

  // ---- victim, lined up with hit verdict ---------------------------------------
  logic [1:0] plruVictim;
  assign plruVictim = lookupState[0]
    ? {1'b1, lookupState[2]}
    : {1'b0, lookupState[1]};
  always_ff @(posedge clk) begin
    victimWay <= plruVictim;
  end

endmodule

