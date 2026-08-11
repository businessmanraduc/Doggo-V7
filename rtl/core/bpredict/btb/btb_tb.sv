// ================================================================================
//  btb_tb -- presents word pairs at both alignments and holds the banked BTB to
//  the two verdicts it should hand back, in program order.
// ================================================================================
module btb_tb;
  localparam int INDEX_W = 9;
  localparam int TAG_W   = 11;

  logic clk = 0;
  always #5 clk = ~clk;

  logic               readEnable;
  logic [31:0]        lookupPcA, lookupPcB;
  logic               wrEnable, wrBank;
  logic [INDEX_W-1:0] wrIndex;
  logic [53:0]        wrEntry;
  logic               tagMatchA, takenOnHitA, condOnHitA, isStraddleA;
  logic               exitAfterLowA, isCallA, isReturnA;
  logic [31:0]        targetA;
  logic               tagMatchB, takenOnHitB, condOnHitB, isStraddleB;
  logic               exitAfterLowB, isCallB, isReturnB;
  logic [31:0]        targetB;

  int errors = 0;

  btb #(.INDEX_W(INDEX_W), .TAG_W(TAG_W)) dut (
    .clk, .readEnable, .lookupPcA, .lookupPcB,
    .wrEnable, .wrBank, .wrIndex, .wrEntry,
    .tagMatchA, .takenOnHitA, .condOnHitA, .isStraddleA,
    .exitAfterLowA, .isCallA, .isReturnA, .targetA,
    .tagMatchB, .takenOnHitB, .condOnHitB, .isStraddleB,
    .exitAfterLowB, .isCallB, .isReturnB, .targetB
  );

  initial begin
    #500000;
    $fatal(1, "FAIL  btb: watchdog fired");
  end

  // ---- how a word address maps onto the banks ----------------------------------
  function automatic logic               bankOf  (input logic [31:0] pc); return pc[2];     endfunction
  function automatic logic [INDEX_W-1:0] indexOf (input logic [31:0] pc); return pc[11:3];  endfunction
  function automatic logic [TAG_W-1:0]   tagOf   (input logic [31:0] pc); return pc[22:12]; endfunction

  function automatic logic [31:0] pcFor(input logic bank, input logic [INDEX_W-1:0] idx,
                                        input logic [TAG_W-1:0] tag);
    logic [31:0] pc;
    pc = '0;
    pc[2]     = bank;
    pc[11:3]  = idx;
    pc[22:12] = tag;
    return pc;
  endfunction

  function automatic logic [53:0] packEntry(
    input logic v, br, cond, strd, exitLow, call, ret,
    input logic [TAG_W-1:0] tag, input logic [30:0] tgt);
    logic [53:0] e;
    e = '0;
    e[53] = v; e[52] = br; e[51] = cond; e[50] = strd; e[49] = exitLow;
    e[45] = v && br &&  cond;   // condOnHit
    e[44] = v && br && !cond;   // takenOnHit
    e[43] = ret; e[42] = call;
    e[31 +: TAG_W] = tag; e[30:0] = tgt;
    return e;
  endfunction

  // ---- install one entry at the word address it belongs to ---------------------
  task automatic install(input logic [31:0] pc, input logic [53:0] e);
    @(negedge clk);
    wrEnable = 1'b1; wrBank = bankOf(pc); wrIndex = indexOf(pc); wrEntry = e;
    @(negedge clk);
    wrEnable = 1'b0;
  endtask

  task automatic installBranch(input logic [31:0] pc, input logic [31:0] tgt,
                               input logic cond, strd, exitLow, call, ret);
    install(pc, packEntry(1'b1, 1'b1, cond, strd, exitLow, call, ret,
                          tagOf(pc), tgt[31:1]));
  endtask

  // ---- present a pair and check both verdicts ----------------------------------
  task automatic checkPair(
    input logic [31:0] pcA,
    input logic eFireA, eCondA, input logic [31:0] eTgtA,
    input logic eFireB, eCondB, input logic [31:0] eTgtB,
    input string note);
    logic fireA, fireB;
    @(negedge clk);
    lookupPcA = pcA; lookupPcB = pcA + 32'd4;
    @(negedge clk);          // arm
    @(negedge clk);          // verdict valid
    fireA = tagMatchA && (takenOnHitA || condOnHitA);
    fireB = tagMatchB && (takenOnHitB || condOnHitB);
    if (fireA !== eFireA) begin
      $error("%-30s pcA=%h slot A fires=%b (expected %b)",
             note, pcA, fireA, eFireA); errors++;
    end else if (eFireA && (condOnHitA !== eCondA || targetA !== eTgtA)) begin
      $error("%-30s pcA=%h slot A cond=%b(exp %b) tgt=%h(exp %h)",
             note, pcA, condOnHitA, eCondA, targetA, eTgtA); errors++;
    end else if (fireB !== eFireB) begin
      $error("%-30s pcA=%h slot B fires=%b (expected %b)",
             note, pcA, fireB, eFireB); errors++;
    end else if (eFireB && (condOnHitB !== eCondB || targetB !== eTgtB)) begin
      $error("%-30s pcA=%h slot B cond=%b(exp %b) tgt=%h(exp %h)",
             note, pcA, condOnHitB, eCondB, targetB, eTgtB); errors++;
    end
  endtask

  // ---- A - an even-aligned pair, both slots live -------------------------------
  task automatic checkEvenAligned();
    logic [31:0] pcA, pcB;
    pcA = pcFor(1'b0, 9'd8, 11'h123);
    pcB = pcA + 32'd4;
    installBranch(pcA, 32'h0011_1110, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0);
    installBranch(pcB, 32'h0022_2220, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0);
    checkPair(pcA, 1'b1, 1'b0, 32'h0011_1110,
                   1'b1, 1'b1, 32'h0022_2220, "A: even pair, both live");
  endtask

  // ---- B - an odd-aligned pair, so the slots come out of the other banks --------
  task automatic checkOddAligned();
    logic [31:0] pcA, pcB;
    pcA = pcFor(1'b1, 9'd20, 11'h0AB);      // odd word: A is in bank 1
    pcB = pcA + 32'd4;                      // carries into the next index, bank 0
    installBranch(pcA, 32'h0033_3330, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0);
    installBranch(pcB, 32'h0044_4440, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0);
    checkPair(pcA, 1'b1, 1'b1, 32'h0033_3330,
                   1'b1, 1'b0, 32'h0044_4440, "B: odd pair, banks swapped");
  endtask

  // ---- C - the swap is real: the same two entries read at the other alignment ---
  //  Presenting pcB as the A slot must hand back pcB's entry in slot A, not pcA's.
  task automatic checkSwapNotAliased();
    logic [31:0] pcA;
    pcA = pcFor(1'b0, 9'd40, 11'h1C3);
    installBranch(pcA,           32'h0055_5550, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0);
    installBranch(pcA + 32'd4,   32'h0066_6660, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0);
    checkPair(pcA,         1'b1, 1'b0, 32'h0055_5550,
                           1'b1, 1'b1, 32'h0066_6660, "C: read as an even pair");
    checkPair(pcA + 32'd4, 1'b1, 1'b1, 32'h0066_6660,
                           1'b0, 1'b0, 32'h0,         "C: same words, odd start");
  endtask

  // ---- D - one slot hits, the other misses on its tag --------------------------
  task automatic checkOneSlotMisses();
    logic [31:0] pcA;
    pcA = pcFor(1'b0, 9'd60, 11'h2AB);
    installBranch(pcA, 32'h0077_7770, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0);
    // nothing installed for pcA+4, so slot B must read as a clean miss
    checkPair(pcA, 1'b1, 1'b0, 32'h0077_7770,
                   1'b0, 1'b0, 32'h0, "D: A hits, B misses");
    // and the mirror: an entry whose tag belongs to a different address
    checkPair(pcFor(1'b0, 9'd60, 11'h2AC), 1'b0, 1'b0, 32'h0,
                                           1'b0, 1'b0, 32'h0, "D: wrong tag misses");
  endtask

  // ---- E - a valid non-branch, and an invalid entry, both read as no-fire ------
  task automatic checkNonFiring();
    logic [31:0] pcA;
    pcA = pcFor(1'b0, 9'd80, 11'h0FF);
    install(pcA, packEntry(1'b1, 1'b0, 0,0,0,0,0, tagOf(pcA), 31'h0011_1111));
    install(pcA + 32'd4,
            packEntry(1'b0, 1'b1, 0,0,0,0,0, tagOf(pcA + 32'd4), 31'h0022_2222));
    checkPair(pcA, 1'b0, 1'b0, 32'h0, 1'b0, 1'b0, 32'h0, "E: non-branch and invalid");
  endtask

  // ---- F - call and return bits survive in either slot -------------------------
  task automatic checkCallReturnBits();
    logic [31:0] pcA;
    pcA = pcFor(1'b0, 9'd100, 11'h1C4);
    installBranch(pcA,         32'h0088_8880, 1'b0, 1'b0, 1'b0, 1'b1, 1'b0);
    installBranch(pcA + 32'd4, 32'h0099_9990, 1'b0, 1'b0, 1'b0, 1'b0, 1'b1);
    checkPair(pcA, 1'b1, 1'b0, 32'h0088_8880,
                   1'b1, 1'b0, 32'h0099_9990, "F: call/return pair");
    if (isCallA !== 1'b1 || isReturnA !== 1'b0) begin
      $error("F: slot A call=%b ret=%b (expected 1/0)", isCallA, isReturnA); errors++;
    end
    if (isCallB !== 1'b0 || isReturnB !== 1'b1) begin
      $error("F: slot B call=%b ret=%b (expected 0/1)", isCallB, isReturnB); errors++;
    end
  endtask

  // ---- G - straddle and exit bits survive --------------------------------------
  task automatic checkStraddleExitBits();
    logic [31:0] pcA;
    pcA = pcFor(1'b0, 9'd120, 11'h1D5);
    installBranch(pcA,         32'h00AA_AAA0, 1'b1, 1'b1, 1'b0, 1'b0, 1'b0);
    installBranch(pcA + 32'd4, 32'h00BB_BBB0, 1'b1, 1'b0, 1'b1, 1'b0, 1'b0);
    checkPair(pcA, 1'b1, 1'b1, 32'h00AA_AAA0,
                   1'b1, 1'b1, 32'h00BB_BBB0, "G: straddle/exit pair");
    if (isStraddleA !== 1'b1 || exitAfterLowA !== 1'b0) begin
      $error("G: slot A strd=%b exit=%b (expected 1/0)",
             isStraddleA, exitAfterLowA); errors++;
    end
    if (isStraddleB !== 1'b0 || exitAfterLowB !== 1'b1) begin
      $error("G: slot B strd=%b exit=%b (expected 0/1)",
             isStraddleB, exitAfterLowB); errors++;
    end
  endtask

  // ---- I - the pair straddles a tag boundary, so the slots need their own tags -
  //  pcB only carries into a different tag at the very top of a bank. Everywhere
  //  else the two tags are equal and comparing B against A's tag is invisible.
  task automatic checkTagBoundary();
    logic [31:0] pcA, pcB;
    pcA = pcFor(1'b1, 9'd511, 11'h100);     // top odd word of tag 0x100
    pcB = pcA + 32'd4;                      // rolls into index 0 of tag 0x101
    if (tagOf(pcA) == tagOf(pcB)) begin
      $error("I: the boundary case did not straddle a tag"); errors++;
    end
    installBranch(pcA, 32'h00CC_CCC0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0);
    installBranch(pcB, 32'h00DD_DDD0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0);
    checkPair(pcA, 1'b1, 1'b0, 32'h00CC_CCC0,
                   1'b1, 1'b0, 32'h00DD_DDD0, "I: pair across a tag boundary");
  endtask

  // ---- J - a moving lookup stream, so the read latency has to be right ---------
  //  checkPair holds one address still for three cycles, which makes a tag delayed
  //  by one stage indistinguishable from two. This changes it every cycle.
  task automatic expectNow(input logic [31:0] eTgtA, eTgtB, input string note);
    logic fireA, fireB;
    fireA = tagMatchA && (takenOnHitA || condOnHitA);
    fireB = tagMatchB && (takenOnHitB || condOnHitB);
    if (!fireA || targetA !== eTgtA) begin
      $error("%-30s slot A fires=%b tgt=%h (expected 1 / %h)",
             note, fireA, targetA, eTgtA); errors++;
    end else if (!fireB || targetB !== eTgtB) begin
      $error("%-30s slot B fires=%b tgt=%h (expected 1 / %h)",
             note, fireB, targetB, eTgtB); errors++;
    end
  endtask

  task automatic checkMovingStream();
    logic [31:0] pc [0:3];
    logic [31:0] tA [0:3];
    logic [31:0] tB [0:3];
    for (int k = 0; k < 4; k++) begin
      //  Alternating alignment, so the bank swap has to be delayed by the same
      //  two stages as the tags rather than one.
      pc[k] = pcFor(1'(k[0]), INDEX_W'(200 + k*3), 11'(11'h300 + k));
      tA[k] = 32'h0100_0000 + 32'(k) * 32'h0000_1000;
      tB[k] = 32'h0200_0000 + 32'(k) * 32'h0000_1000;
      installBranch(pc[k],           tA[k], 1'b0, 1'b0, 1'b0, 1'b0, 1'b0);
      installBranch(pc[k] + 32'd4,   tB[k], 1'b0, 1'b0, 1'b0, 1'b0, 1'b0);
    end
    @(negedge clk); lookupPcA = pc[0]; lookupPcB = pc[0] + 32'd4;
    @(negedge clk); lookupPcA = pc[1]; lookupPcB = pc[1] + 32'd4;
    @(negedge clk); lookupPcA = pc[2]; lookupPcB = pc[2] + 32'd4;
    expectNow(tA[0], tB[0], "J: stream word 0");
    @(negedge clk); lookupPcA = pc[3]; lookupPcB = pc[3] + 32'd4;
    expectNow(tA[1], tB[1], "J: stream word 1");
    @(negedge clk);
    expectNow(tA[2], tB[2], "J: stream word 2");
    @(negedge clk);
    expectNow(tA[3], tB[3], "J: stream word 3");
  endtask

  // ---- H - every entry in both banks is reachable and distinct -----------------
  task automatic checkFullSweep();
    logic [TAG_W-1:0] refTag [0:(1<<INDEX_W)-1][0:1];
    logic [30:0]      refTgt [0:(1<<INDEX_W)-1][0:1];
    logic [31:0]      pcA;
    for (int i = 0; i < (1<<INDEX_W); i++) begin
      for (int b = 0; b < 2; b++) begin
        refTag[i][b] = TAG_W'($urandom());
        refTgt[i][b] = 31'($urandom());
        install(pcFor(1'(b), INDEX_W'(i), refTag[i][b]),
                packEntry(1'b1, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0,
                          refTag[i][b], refTgt[i][b]));
      end
    end
    //  Read each even word as slot A. Slot B is the odd word of the same index,
    //  which only fires when its independently random tag happens to agree.
    for (int i = 0; i < (1<<INDEX_W); i++) begin
      pcA = pcFor(1'b0, INDEX_W'(i), refTag[i][0]);
      checkPair(pcA, 1'b1, 1'b0, {refTgt[i][0], 1'b0},
                     (refTag[i][1] == refTag[i][0]), 1'b0, {refTgt[i][1], 1'b0},
                     $sformatf("H: sweep idx=%0d", i));
    end
  endtask

  initial begin
    readEnable = 1'b1; wrEnable = 1'b0; wrBank = 1'b0; wrIndex = '0; wrEntry = '0;
    lookupPcA = '0; lookupPcB = '0;
    @(negedge clk);

    checkEvenAligned();
    checkOddAligned();
    checkSwapNotAliased();
    checkOneSlotMisses();
    checkNonFiring();
    checkCallReturnBits();
    checkStraddleExitBits();
    checkTagBoundary();
    checkMovingStream();
    checkFullSweep();

    if (errors == 0) $display("PASS  btb");
    else             $fatal(1, "FAIL  btb (%0d errors)", errors);
    $finish;
  end

endmodule
