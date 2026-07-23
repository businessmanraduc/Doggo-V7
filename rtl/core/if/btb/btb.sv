// ================================================================================
//  PHANTOoOM-32 -- Branch Target Buffer (tagged, BSRAM)
// ================================================================================
//  Caches whether a predictable branch lives on a fetch word address, and
//  where it redirects to. Three BSRAM blocks hold one 54-bit entry:
//
//    { valid, isBranch, isConditional, isStraddle, tag[TAG_W], target[31:1] }
//
//  OUT_REG flips the read register:
//    0 - block + fabric flop
//    1 - register packed in the block itself
//
//  Solo Fmax (ring-of-regs, nextpnr --85k, tw=100, 20 seeds): 143.99 / 144.90 / 145.50
// ================================================================================
module btb #(
  parameter bit OUT_REG = 1'b0,
  parameter int INDEX_W = 9,
  parameter int TAG_W   = 11
) (
  input  logic               clk,
  input  logic [31:0]        lookupPC,

  // ---- update: one resolved branch ---------------------------------------------
  input  logic               wrEnable,
  input  logic [INDEX_W-1:0] wrIndex,
  input  logic [53:0]        wrEntry,

  // ---- verdict (two cycles after lookupPC) -------------------------------------
  output logic               hit,
  output logic               isBranch,
  output logic               isConditional,
  output logic               isStraddle,
  output logic [31:0]        target
);

  // ---- entry field positions ---------------------------------------------------
  localparam int TARGET_LSB   = 0;
  localparam int TAG_LSB      = 31;
  localparam int STRADDLE_BIT = 50;
  localparam int COND_BIT     = 51;
  localparam int BRANCH_BIT   = 52;
  localparam int VALID_BIT    = 53;

  logic [INDEX_W-1:0] readAddr;  assign readAddr  = lookupPC[INDEX_W:1];
  logic [TAG_W-1:0]   lookupTag; assign lookupTag = lookupPC[INDEX_W+TAG_W : INDEX_W+1];

  // ---- storage: three 18-bit blocks --------------------------------------------
  logic [53:0] rawEntry;
  genvar blk;
  generate
    for (blk = 0; blk < 3; blk++) begin : g_block
      ebr18 #(.OUT_REG(OUT_REG), .ADDR_W(INDEX_W)) u_block (
        .clk, .wrEnable,   .wrAddr(wrIndex), .wrData(wrEntry[blk*18 +: 18]),
        .rdAddr(readAddr), .rdData(rawEntry[blk*18 +: 18])
      );
    end
  endgenerate

  // ---- align entry + tag to the two-cycle read ---------------------------------
  logic [53:0]      entry;
  logic [TAG_W-1:0] lookupTagQ1;
  logic [TAG_W-1:0] lookupTagQ2;
  logic [TAG_W-1:0] compareTag;
  always_ff @(posedge clk) lookupTagQ1 <= lookupTag;
  always_ff @(posedge clk) lookupTagQ2 <= lookupTagQ1;
  generate
    if (!OUT_REG) begin : g_fabricReg
      logic [53:0] entryQ;
      always_ff @(posedge clk) begin
        entryQ <= rawEntry;
      end
      assign entry = entryQ;
    end else begin : g_packedReg
      assign entry = rawEntry;
    end
  endgenerate
  assign compareTag = lookupTagQ2;

  // ---- unpack + tag check ------------------------------------------------------
  assign isBranch      = entry[BRANCH_BIT];
  assign isConditional = entry[COND_BIT];
  assign isStraddle    = entry[STRADDLE_BIT];
  assign target        = {entry[TARGET_LSB +: 31], 1'b0};
  assign hit           = entry[VALID_BIT] && (entry[TAG_LSB +: TAG_W] == compareTag);

endmodule

