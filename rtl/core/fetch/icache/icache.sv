// ================================================================================
//  PHANTOoOM-32 -- Instruction Cache (4-way set-associative, pipelined hit)
// ================================================================================
//  16 KB, 4 ways, 32-byte lines. Serves one 32-bit word per lookup, one word
//  per cycle, four-cycle pipelined hit.
//  Tags and data lives in BSRAM, replacement state lives in LUTRAM.
//
//    byte addr | tag[24:12] | set[11:5] | word-in-line[4:2] | hw[1] | b[0]
//
//  Stage map (address presented in F0):
//    F0 - split the address, arm the tag blocks and the PLRU
//    F1 - reads in flight, arm the data blocks
//    F2 - tag entries land and are parked, verdict and victim land
//    F3 - tag compare, both inputs registered, words land
//    F4 - pick way, report, touch PLRU, hand miss to fill engine
//
//  A lookup can be disowned at F4 with lookupKill, so a word the frontend no
//  longer wants (wrong path/dead word behind taken branch) never starts a fill.
//
//  Solo Fmax (ring-of-regs, nextpnr --85k, tw=100, 20 seeds): see fmax.md
// ================================================================================
module icache #(
  parameter int SET_IDX_W = 7,
  parameter int WIL_W     = 3,
  parameter int TAG_W     = 13,
  parameter int WORDIDX_W = SET_IDX_W + WIL_W
) (
  input  logic        clk,
  input  logic        resetn,

  // ---- fetch port --------------------------------------------------------------
  input  logic [31:0] lookupAddr,
  input  logic        lookupValid,
  input  logic        lookupKill,
  output logic [31:0] instrWord,
  output logic        hit,
  output logic        fillBusy,

  // ---- memory port -------------------------------------------------------------
  output logic [31:0] fillAddr,
  output logic        fillReq,
  input  logic [31:0] fillRData,
  input  logic        fillRValid
);

  localparam int WAYS    = 4;
  localparam int OFF_W   = WIL_W + 2;
  localparam int ENTRY_W = TAG_W + 1;

  genvar way, blk;

  // ---- fill engine driven wires ------------------------------------------------
  logic [3:0]           tagWrEnable;
  logic [SET_IDX_W-1:0] tagWrSet;
  logic [TAG_W-1:0]     tagWrTag;
  logic                 tagWrValid;
  logic [3:0]           dataWrEnable;
  logic [WORDIDX_W-1:0] dataWrIndex;
  logic [31:0]          dataWrWord;
  logic                 initDone;

  // ---- fetch qualifier, carried F0 to F3 ---------------------------------------
  logic lookupValidF1, lookupValidF2, lookupValidF3, lookupValidF4;
  always_ff @(posedge clk) begin
    if (!resetn) begin
      lookupValidF1 <= 1'b0; lookupValidF2 <= 1'b0;
      lookupValidF3 <= 1'b0; lookupValidF4 <= 1'b0;
    end else begin
      lookupValidF1 <= lookupValid;
      lookupValidF2 <= lookupValidF1;
      lookupValidF3 <= lookupValidF2;
      lookupValidF4 <= lookupValidF3;
    end
  end

  // ---- F0 - split address and arm memories -------------------------------------
  logic [WORDIDX_W-1:0] lookupWordIndex, lookupWordIndexF1;
  logic [SET_IDX_W-1:0] lookupSet,       lookupSetF1;
  logic [TAG_W-1:0]     lookupTag,       lookupTagF1;
  assign lookupWordIndex = lookupAddr[2 +: WORDIDX_W];
  assign lookupSet       = lookupAddr[OFF_W +: SET_IDX_W];
  assign lookupTag       = lookupAddr[OFF_W+SET_IDX_W +: TAG_W];
  always_ff @(posedge clk) begin
    lookupWordIndexF1 <= lookupWordIndex;
    lookupSetF1       <= lookupSet;
    lookupTagF1       <= lookupTag;
  end

  // ---- F1 - reads in flight + memory initialization ----------------------------
  logic [ENTRY_W-1:0] tagEntry [0:WAYS-1];
  generate
    for (way = 0; way < WAYS; way++) begin : g_tagWay
      logic [17:0] tagRaw;
      ebr18 #(.OUT_REG(1'b1), .ADDR_W(SET_IDX_W)) u_tagBlk (
        .clk,                 .wrEnable(tagWrEnable[way]),
        .wrAddr(tagWrSet),    .wrData({{(18-ENTRY_W){1'b0}}, tagWrValid, tagWrTag}),
        .rdAddr(lookupSet),   .readEnable(1'b1), .rdData(tagRaw)
      );
      assign tagEntry[way] = tagRaw[ENTRY_W-1:0];
    end
  endgenerate

  logic [35:0] wrWide; assign wrWide = {4'b0, dataWrWord};
  logic [31:0] readWord [0:WAYS-1];
  generate
    for (way = 0; way < WAYS; way++) begin : g_dataWay
      logic [35:0] rawWord;
      for (blk = 0; blk < 2; blk++) begin : g_block
        ebr18 #(.OUT_REG(1'b1), .ADDR_W(WORDIDX_W)) u_block (
          .clk,                       .wrEnable(dataWrEnable[way]),
          .wrAddr(dataWrIndex),       .wrData(wrWide[blk*18 +: 18]),
          .rdAddr(lookupWordIndexF1), .readEnable(1'b1), .rdData(rawWord[blk*18 +: 18])
        );
      end
      assign readWord[way] = rawWord[31:0];
    end
  endgenerate

  (* ram_style = "distributed" *) logic [2:0] plruMem [0:(1<<SET_IDX_W)-1];
  logic [2:0] lookupState; always_ff @(posedge clk) lookupState <= plruMem[lookupSetF1];

  logic [SET_IDX_W-1:0] lookupSetF2;
  logic [TAG_W-1:0]     lookupTagF2;
  always_ff @(posedge clk) begin
    lookupSetF2 <= lookupSetF1;
    lookupTagF2 <= lookupTagF1;
  end

  // ---- F2 - park the tag read --------------------------------------------------
  logic [ENTRY_W-1:0] tagEntryF3 [0:WAYS-1];
  logic [2:0]         touchStateF3;
  always_ff @(posedge clk) touchStateF3 <= lookupState;
  generate
    for (way = 0; way < WAYS; way++) begin : g_park
      always_ff @(posedge clk) tagEntryF3[way] <= tagEntry[way];
    end
  endgenerate

  logic [1:0] plruVictim, victimWayF3;
  assign plruVictim = lookupState[0]
    ? {1'b1, lookupState[2]}
    : {1'b0, lookupState[1]};
  always_ff @(posedge clk) victimWayF3 <= plruVictim;

  logic [SET_IDX_W-1:0] lookupSetF3;
  logic [TAG_W-1:0]     lookupTagF3;
  always_ff @(posedge clk) begin
    lookupSetF3 <= lookupSetF2;
    lookupTagF3 <= lookupTagF2;
  end

  // ---- F3 - compare tags, both inputs registered -------------------------------
  logic [WAYS-1:0] matchVec;
  generate
    for (way = 0; way < WAYS; way++) begin : g_compare
      tag_cmp #(.TAG_W(TAG_W)) u_cmp (
        .entry(tagEntryF3[way]), .probeTag(lookupTagF3), .match(matchVec[way])
      );
    end
  endgenerate

  logic [WAYS-1:0]      hitVecF4;
  logic [31:0]          heldWords [0:WAYS-1];
  logic [2:0]           touchState;
  logic [1:0]           victimWay;
  logic [SET_IDX_W-1:0] lookupSetF4;
  logic [TAG_W-1:0]     lookupTagF4;
  always_ff @(posedge clk) begin
    hitVecF4    <= matchVec;
    touchState  <= touchStateF3;
    victimWay   <= victimWayF3;
    lookupSetF4 <= lookupSetF3;
    lookupTagF4 <= lookupTagF3;
  end
  generate
    for (way = 0; way < WAYS; way++) begin : g_hold
      always_ff @(posedge clk) heldWords[way] <= readWord[way];
    end
  endgenerate

  // ---- F4 - pick way and report ------------------------------------------------
  logic [1:0] hitWay;
  assign hit    = (|hitVecF4) && initDone;
  assign hitWay = {hitVecF4[3] | hitVecF4[2], hitVecF4[3] | hitVecF4[1]};

  always_comb begin
    case (hitWay)
      2'd0:    instrWord = heldWords[0];
      2'd1:    instrWord = heldWords[1];
      2'd2:    instrWord = heldWords[2];
      default: instrWord = heldWords[3];
    endcase
  end

  // ---- F4 - aim PLRU tree away from recently used way --------------------------
  logic [2:0] touchNext;
  always_comb begin
    touchNext    = touchState;
    touchNext[0] = ~hitWay[1];
    if (hitWay[1]) touchNext[2] = ~hitWay[0];
    else           touchNext[1] = ~hitWay[0];
  end
  always_ff @(posedge clk) begin
    if (hit) plruMem[lookupSetF4] <= touchNext;
  end

  // ---- fill engine -------------------------------------------------------------
  linefill #(
    .SET_IDX_W(SET_IDX_W), .WIL_W(WIL_W), .TAG_W(TAG_W), .WORDIDX_W(WORDIDX_W)
  ) u_fill (
    .clk, .resetn,
    .missValid (lookupValidF4 && !hit && !lookupKill),
    .missTag(lookupTagF4), .missSet(lookupSetF4), .missVictim(victimWay),
    .fillAddr, .fillReq, .fillRData, .fillRValid,
    .dataWrEnable, .dataWrIndex, .dataWrWord,
    .tagWrEnable, .tagWrSet, .tagWrTag, .tagWrValid,
    .initDone, .fillBusy
  );

endmodule


// ================================================================================
//  PHANTOoOM-32 -- Tag Comparator (one cache way)
// ================================================================================
//  Valid bit and tag equality for a single way.
//
//  Needed to be separate so that nextpnr doesn't mix-match different signals
//  into it and doesn't try to falsely optimize its routing by coming up with
//  worse, clustered designs.
// ================================================================================
(* keep_hierarchy *)
module tag_cmp #(
  parameter int TAG_W = 13
) (
  input  logic [TAG_W:0]    entry,
  input  logic [TAG_W-1:0]  probeTag,
  output logic              match
);

  assign match = entry[TAG_W] && (entry[TAG_W-1:0] == probeTag);

endmodule

