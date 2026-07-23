// ================================================================================
//  btb_tb -- write entries, read them back through the two-cycle tagged read:
//  hit/miss on the tag, field unpacking, and a full-index random sweep.
// ================================================================================
module btb_tb;
  localparam int INDEX_W = 9;
  localparam int TAG_W   = 11;

  logic clk = 0;
  always #5 clk = ~clk;

  logic [31:0]        lookupPC;
  logic               wrEnable;
  logic [INDEX_W-1:0] wrIndex;
  logic [53:0]        wrEntry;
  logic               hit, isBranch, isConditional, isStraddle;
  logic [31:0]        target;
  int                 errors = 0;

  btb #(.OUT_REG(1'b0), .INDEX_W(INDEX_W), .TAG_W(TAG_W)) dut (
    .clk, .lookupPC, .wrEnable, .wrIndex, .wrEntry,
    .hit, .isBranch, .isConditional, .isStraddle, .target
  );

  // ---- reference model ---------------------------------------------------------
  logic [53:0]        refEntry [0:(1<<INDEX_W)-1];
  logic [TAG_W-1:0]   refTag   [0:(1<<INDEX_W)-1];

  function automatic logic [53:0] packEntry(
    input logic v, br, cond, strd, input logic [TAG_W-1:0] tag, input logic [30:0] tgt);
    logic [53:0] e;
    e = '0;
    e[53] = v; e[52] = br; e[51] = cond; e[50] = strd;
    e[31 +: TAG_W] = tag; e[30:0] = tgt;
    return e;
  endfunction

  function automatic logic [31:0] pcFor(input logic [INDEX_W-1:0] idx, input logic [TAG_W-1:0] tag);
    logic [31:0] pc;
    pc = '0;
    pc[INDEX_W:1]              = idx;
    pc[INDEX_W+TAG_W:INDEX_W+1] = tag;
    return pc;
  endfunction

  task automatic doWrite(input logic [INDEX_W-1:0] idx, input logic [53:0] e);
    @(negedge clk); wrEnable = 1; wrIndex = idx; wrEntry = e;
    @(negedge clk); wrEnable = 0;
  endtask

  // present lookupPC, wait the two-cycle read, then check against expectation
  task automatic checkRead(
    input logic [31:0] pc, input logic eHit, eBr, eCond, eStrd,
    input logic [31:0] eTgt, input string note);
    @(negedge clk); lookupPC = pc;
    @(negedge clk);            // arm
    @(negedge clk);            // verdict valid
    if (hit !== eHit ||
        (eHit && (isBranch !== eBr || isConditional !== eCond ||
                  isStraddle !== eStrd || target !== eTgt))) begin
      $error("%-20s pc=%h  hit=%b(exp %b) br=%b cond=%b strd=%b tgt=%h(exp %h)",
             note, pc, hit, eHit, isBranch, isConditional, isStraddle, target, eTgt);
      errors++;
    end
  endtask

  initial begin
    wrEnable = 0; lookupPC = '0;

    // ---- directed: one known entry, hit and tag-miss ---------------------------
    doWrite(9'd7, packEntry(1, 1, 0, 0, 11'h123, 31'h0055_5555));
    checkRead(pcFor(9'd7, 11'h123), 1, 1, 0, 0, 32'h00AA_AAAA, "hit unconditional");
    checkRead(pcFor(9'd7, 11'h124), 0, 0, 0, 0, 32'h0,         "tag miss");

    // ---- directed: conditional + straddle flags survive ------------------------
    doWrite(9'd42, packEntry(1, 1, 1, 1, 11'h2AB, 31'h0012_3456));
    checkRead(pcFor(9'd42, 11'h2AB), 1, 1, 1, 1, 32'h0024_68AC, "cond+straddle");

    // ---- directed: valid=0 reads as a clean miss -------------------------------
    doWrite(9'd100, packEntry(0, 1, 0, 0, 11'h0FF, 31'h7FFF_FFFF));
    checkRead(pcFor(9'd100, 11'h0FF), 0, 0, 0, 0, 32'h0, "valid=0 miss");

    // ---- full-index random sweep -----------------------------------------------
    for (int i = 0; i < (1<<INDEX_W); i++) begin
      refTag[i]   = TAG_W'($urandom());
      refEntry[i] = packEntry(1'b1, 1'($urandom()), 1'($urandom()), 1'($urandom()),
                              refTag[i], 31'($urandom()));
      doWrite(INDEX_W'(i), refEntry[i]);
    end
    for (int i = 0; i < (1<<INDEX_W); i++) begin
      checkRead(pcFor(INDEX_W'(i), refTag[i]), 1,
             refEntry[i][52], refEntry[i][51], refEntry[i][50],
             {refEntry[i][30:0], 1'b0}, $sformatf("sweep idx=%0d", i));
      // a mismatched tag on the same slot must miss
      checkRead(pcFor(INDEX_W'(i), refTag[i] ^ 11'h555), 0, 0, 0, 0, 32'h0,
             $sformatf("sweep miss idx=%0d", i));
    end

    if (errors == 0) $display("PASS  btb");
    else             $fatal(1, "FAIL  btb (%0d errors)", errors);
    $finish;
  end
endmodule

