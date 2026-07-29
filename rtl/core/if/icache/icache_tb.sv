// ================================================================================
//  icache_tb -- fill lines by hand, then read them back through the pipelined hit
//  path: hit verdict, way selection, tag miss, invalidation, PLRU rotation.
// ================================================================================
module icache_tb;
  localparam int SET_IDX_W = 7;
  localparam int WORDIDX_W = 10;
  localparam int TAG_W     = 13;
  localparam int SETS      = 1 << SET_IDX_W;
  localparam int LATENCY   = 3;

  logic clk = 0;
  always #5 clk = ~clk;

  logic [3:0]           dataWrEnable;
  logic [WORDIDX_W-1:0] dataWrIndex;
  logic [31:0]          dataWrWord;
  logic [3:0]           tagWrEnable;
  logic [SET_IDX_W-1:0] tagWrSet;
  logic [TAG_W-1:0]     tagWrTag;
  logic                 tagWrValid;

  logic [31:0] lookupAddr;
  logic [31:0] instrWord;
  logic        hit;
  logic [1:0]  victimWay;
  int          errors = 0;

  icache dut (
    .clk, .lookupAddr,
    .dataWrEnable, .dataWrIndex, .dataWrWord,
    .tagWrEnable,  .tagWrSet, .tagWrTag, .tagWrValid,
    .instrWord, .hit, .victimWay
  );

  // ---- address field helpers ---------------------------------------------------
  function automatic logic [WORDIDX_W-1:0] wordIndexOf(input logic [31:0] a);
    return a[2 +: WORDIDX_W];
  endfunction
  function automatic logic [SET_IDX_W-1:0] setOf(input logic [31:0] a);
    return a[5 +: SET_IDX_W];
  endfunction
  function automatic logic [TAG_W-1:0] tagOf(input logic [31:0] a);
    return a[12 +: TAG_W];
  endfunction

  // ---- boot sweep: the reason valid can live inside the tag word ---------------
  task automatic invalidateAll();
    for (int s = 0; s < SETS; s++) begin
      @(negedge clk);
      tagWrEnable = 4'hF; tagWrSet = SET_IDX_W'(s); tagWrTag = '0; tagWrValid = 1'b0;
    end
    @(negedge clk); tagWrEnable = 4'h0;
  endtask

  // ---- place one word of one line into one way ---------------------------------
  task automatic fillWord(input logic [31:0] a, input logic [31:0] w, input int way);
    @(negedge clk);
    dataWrEnable = 4'(1 << way); dataWrIndex = wordIndexOf(a); dataWrWord = w;
    @(negedge clk); dataWrEnable = 4'h0;
  endtask

  task automatic validateLine(input logic [31:0] a, input int way);
    @(negedge clk);
    tagWrEnable = 4'(1 << way); tagWrSet = setOf(a); tagWrTag = tagOf(a);
    tagWrValid  = 1'b1;
    @(negedge clk); tagWrEnable = 4'h0;
  endtask

  // ---- one lookup, verdict LATENCY cycles later --------------------------------
  task automatic checkLookup(
    input logic [31:0] a, input logic eHit, input logic [31:0] eWord, input string note);
    @(negedge clk); lookupAddr = a;
    repeat (LATENCY) @(negedge clk);
    if (hit !== eHit) begin
      $error("%-26s addr=%h hit=%b (exp %b)", note, a, hit, eHit);
      errors++;
    end else if (eHit && instrWord !== eWord) begin
      $error("%-26s addr=%h word=%h (exp %h)", note, a, instrWord, eWord);
      errors++;
    end
  endtask

  initial begin
    dataWrEnable = '0; tagWrEnable = '0; tagWrValid = '0;
    dataWrIndex  = '0; dataWrWord  = '0; tagWrSet = '0; tagWrTag = '0;
    lookupAddr   = '0;

    invalidateAll();

    // ---- everything invalid after the sweep ------------------------------------
    checkLookup(32'h0000_1000, 1'b0, 32'h0, "post-sweep miss");
    checkLookup(32'h0012_3400, 1'b0, 32'h0, "post-sweep miss 2");

    // ---- one line into way 0 ---------------------------------------------------
    fillWord(32'h0000_1000, 32'hDEAD_BEEF, 0);
    validateLine(32'h0000_1000, 0);
    checkLookup(32'h0000_1000, 1'b1, 32'hDEAD_BEEF, "way0 hit");

    // ---- same set, different tag: still a miss ---------------------------------
    checkLookup(32'h0010_1000, 1'b0, 32'h0, "same set, other tag");

    // ---- a second word inside the same line ------------------------------------
    fillWord(32'h0000_1004, 32'h1234_5678, 0);
    checkLookup(32'h0000_1004, 1'b1, 32'h1234_5678, "word 1 of line");
    checkLookup(32'h0000_1000, 1'b1, 32'hDEAD_BEEF, "word 0 still there");

    // ---- the other three ways of the same set ----------------------------------
    fillWord(32'h0010_1000, 32'hAAAA_0001, 1); validateLine(32'h0010_1000, 1);
    fillWord(32'h0020_1000, 32'hAAAA_0002, 2); validateLine(32'h0020_1000, 2);
    fillWord(32'h0030_1000, 32'hAAAA_0003, 3); validateLine(32'h0030_1000, 3);
    checkLookup(32'h0000_1000, 1'b1, 32'hDEAD_BEEF, "4-way: pick way0");
    checkLookup(32'h0010_1000, 1'b1, 32'hAAAA_0001, "4-way: pick way1");
    checkLookup(32'h0020_1000, 1'b1, 32'hAAAA_0002, "4-way: pick way2");
    checkLookup(32'h0030_1000, 1'b1, 32'hAAAA_0003, "4-way: pick way3");
    checkLookup(32'h0040_1000, 1'b0, 32'h0,         "4-way: fifth tag misses");

    // ---- invalidating the way kills the hit ------------------------------------
    @(negedge clk);
    tagWrEnable = 4'b0001; tagWrSet = setOf(32'h0000_1000); tagWrTag = '0;
    tagWrValid  = 1'b0;
    @(negedge clk); tagWrEnable = 4'h0;
    checkLookup(32'h0000_1000, 1'b0, 32'h0, "invalidated way0");

    // ---- back-to-back lookups: the pipe holds one word per cycle ---------------
    checkStreaming();

    // ---- PLRU walks away from whatever was just touched ------------------------
    checkVictimRotation();

    // ---- random sweep ----------------------------------------------------------
    randomSweep();

    if (errors == 0) $display("PASS  icache  (latency %0d)", LATENCY);
    else             $fatal(1, "FAIL  icache (%0d errors)", errors);
    $finish;
  end

  // ---- four addresses issued on consecutive cycles, four words back to back ----
  task automatic checkStreaming();
    logic [31:0] base;
    int          idx;
    base = 32'h0004_0000;
    for (int k = 0; k < 4; k++) begin
      fillWord(base + 32'(k * 4), 32'h5150_0000 + 32'(k), 0);
    end
    validateLine(base, 0);

    for (int k = 0; k < 4 + LATENCY; k++) begin
      @(negedge clk);
      if (k >= LATENCY) begin
        idx = k - LATENCY;
        if (hit !== 1'b1 || instrWord !== 32'h5150_0000 + 32'(idx)) begin
          $error("stream word %0d: hit=%b word=%h (exp %h)",
                 idx, hit, instrWord, 32'h5150_0000 + 32'(idx));
          errors++;
        end
      end
      if (k < 4) lookupAddr = base + 32'(k * 4);
    end
  endtask

  // ---- after touching a way, the victim must point somewhere else --------------
  task automatic checkVictimRotation();
    logic [31:0] base;
    logic [31:0] a;
    base = 32'h0080_0000;
    for (int way = 0; way < 4; way++) begin
      a = base | (32'(way) << 12);
      fillWord(a, 32'hC0DE_0000 + 32'(way), way);
      validateLine(a, way);
      checkLookup(a, 1'b1, 32'hC0DE_0000 + 32'(way), $sformatf("plru touch way%0d", way));
      checkLookup(a, 1'b1, 32'hC0DE_0000 + 32'(way), $sformatf("plru reread way%0d", way));
      if (victimWay === 2'(way)) begin
        $error("plru: victim still points at the way just touched (%0d)", way);
        errors++;
      end
    end
  endtask

  // ---- random fills, read straight back ----------------------------------------
  task automatic randomSweep();
    logic [31:0] a;
    logic [31:0] w;
    int          way;
    for (int k = 0; k < 200; k++) begin
      way = $urandom_range(0, 3);
      a   = {7'b0, 13'(k), 7'h55, 3'($urandom()), 2'b00};
      w   = $urandom();
      fillWord(a, w, way);
      validateLine(a, way);
      checkLookup(a, 1'b1, w, $sformatf("rand a=%h way%0d", a, way));
    end
  endtask

endmodule
