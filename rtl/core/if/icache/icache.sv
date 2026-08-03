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
//    F0 - split the address, arm the memories
//    F1 - reads in flight
//    F2 - tag compare; word, verdict, victim land here
//    F3 - pick way, report, touch PLRU, hand miss to fill engine
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
  logic lookupValidF1, lookupValidF2, lookupValidF3;
  always_ff @(posedge clk) begin
    if (!resetn) begin
      lookupValidF1 <= 1'b0; lookupValidF2 <= 1'b0; lookupValidF3 <= 1'b0;
    end else begin
      lookupValidF1 <= lookupValid;
      lookupValidF2 <= lookupValidF1;
      lookupValidF3 <= lookupValidF2;
    end
  end

  // ---- F0 - split address and arm memories -------------------------------------
  logic [WORDIDX_W-1:0] lookupWordIndex;
  logic [SET_IDX_W-1:0] lookupSet;
  logic [TAG_W-1:0]     lookupTag;
  assign lookupWordIndex = lookupAddr[2 +: WORDIDX_W];
  assign lookupSet       = lookupAddr[OFF_W +: SET_IDX_W];
  assign lookupTag       = lookupAddr[OFF_W+SET_IDX_W +: TAG_W];

  logic [SET_IDX_W-1:0] lookupSetF1;
  logic [TAG_W-1:0]     lookupTagF1;
  always_ff @(posedge clk) begin
    lookupSetF1 <= lookupSet;
    lookupTagF1 <= lookupTag;
  end

  // ---- F1 - reads in flight + memory initialization ----------------------------
  logic [ENTRY_W-1:0] tagEntry [0:WAYS-1];
  generate
    for (way = 0; way < WAYS; way++) begin : g_tagWay
      (* ram_style = "distributed" *) logic [ENTRY_W-1:0] tagMem [0:(1<<SET_IDX_W)-1];
      always_ff @(posedge clk) begin
        if (tagWrEnable[way]) begin
          tagMem[tagWrSet] <= {tagWrValid, tagWrTag};
        end
        tagEntry[way] <= tagMem[lookupSetF1];
      end
    end
  endgenerate

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

  (* ram_style = "distributed" *) logic [2:0] plruMem [0:(1<<SET_IDX_W)-1];
  logic [2:0] lookupState; always_ff @(posedge clk) lookupState <= plruMem[lookupSetF1];

  logic [SET_IDX_W-1:0] lookupSetF2;
  logic [TAG_W-1:0]     lookupTagF2;
  always_ff @(posedge clk) begin
    lookupSetF2 <= lookupSetF1;
    lookupTagF2 <= lookupTagF1;
  end

  // ---- F2 - compare tags, hold everything else ---------------------------------
  logic [WAYS-1:0] matchVec;
  generate
    for (way = 0; way < WAYS; way++) begin : g_compare
      assign matchVec[way] = tagEntry[way][TAG_W] && (tagEntry[way][TAG_W-1:0] == lookupTagF2);
    end
  endgenerate

  logic [WAYS-1:0] hitVecF3;
  logic [31:0]     heldWords [0:WAYS-1];
  logic [2:0]      touchState;
  always_ff @(posedge clk) begin
    hitVecF3   <= matchVec;
    touchState <= lookupState;
  end
  generate
    for (way = 0; way < WAYS; way++) begin : g_hold
      always_ff @(posedge clk) heldWords[way] <= readWord[way];
    end
  endgenerate

  logic [1:0] plruVictim, victimWay;
  assign plruVictim = lookupState[0]
    ? {1'b1, lookupState[2]}
    : {1'b0, lookupState[1]};
  always_ff @(posedge clk) victimWay <= plruVictim;

  logic [SET_IDX_W-1:0] lookupSetF3;
  logic [TAG_W-1:0]     lookupTagF3;
  always_ff @(posedge clk) begin
    lookupSetF3 <= lookupSetF2;
    lookupTagF3 <= lookupTagF2;
  end

  // ---- F3 - pick way and report ------------------------------------------------
  logic [1:0] hitWay;
  assign hit    = (|hitVecF3) && initDone;
  assign hitWay = {hitVecF3[3] | hitVecF3[2], hitVecF3[3] | hitVecF3[1]};

  always_comb begin
    case (hitWay)
      2'd0:    instrWord = heldWords[0];
      2'd1:    instrWord = heldWords[1];
      2'd2:    instrWord = heldWords[2];
      default: instrWord = heldWords[3];
    endcase
  end

  // ---- F3 - aim PLRU tree away from recently used way --------------------------
  logic [2:0] touchNext;
  always_comb begin
    touchNext    = touchState;
    touchNext[0] = ~hitWay[1];
    if (hitWay[1]) touchNext[2] = ~hitWay[0];
    else           touchNext[1] = ~hitWay[0];
  end
  always_ff @(posedge clk) begin
    if (hit) plruMem[lookupSetF3] <= touchNext;
  end

  // ---- fill engine -------------------------------------------------------------
  linefill #(
    .SET_IDX_W(SET_IDX_W), .WIL_W(WIL_W), .TAG_W(TAG_W), .WORDIDX_W(WORDIDX_W)
  ) u_fill (
    .clk, .resetn,
    .missValid (lookupValidF3 && !hit),
    .missTag(lookupTagF3), .missSet(lookupSetF3), .missVictim(victimWay),
    .fillAddr, .fillReq, .fillRData, .fillRValid,
    .dataWrEnable, .dataWrIndex, .dataWrWord,
    .tagWrEnable, .tagWrSet, .tagWrTag, .tagWrValid,
    .initDone, .fillBusy
  );

endmodule

