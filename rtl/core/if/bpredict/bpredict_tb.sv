// ================================================================================
//  bpredict_tb -- drives the NextPC loop: boot vector, backend redirect priority,
//  sequential fetch, predicted-taken redirect (uncond + conditional via PHT), and
//  the straddle delayed-apply. Prediction paths are checked by capturing the
//  nextPC stream and searching it (robust to the 2-cycle verdict latency).
// ================================================================================
module bpredict_tb;
  localparam int          BTB_W    = 9;
  localparam int          PHT_W    = 13;
  localparam int          TAG_W    = 11;
  localparam logic [31:0] RESET_PC = 32'h2000_0000;

  logic clk = 0;
  always #5 clk = ~clk;

  logic               boot, redirectValid;
  logic [31:0]        redirectPC;
  logic               btbWrEnable; logic [BTB_W-1:0] btbWrIndex; logic [53:0] btbWrEntry;
  logic               phtWrEnable; logic [PHT_W-1:0] phtWrIndex; logic [1:0]  phtWrCounter;
  logic [31:0]        nextPC;
  int                 errors = 0;

  bpredict #(.OUT_REG(1'b0), .BTB_INDEX_W(BTB_W), .PHT_INDEX_W(PHT_W),
             .TAG_W(TAG_W), .RESET_PC(RESET_PC)) dut (
    .clk, .boot, .redirectValid, .redirectPC,
    .btbWrEnable, .btbWrIndex, .btbWrEntry,
    .phtWrEnable, .phtWrIndex, .phtWrCounter, .nextPC
  );

  // ---- helpers -----------------------------------------------------------------
  function automatic logic [53:0] packEntry(
    input logic v, br, cond, strd, input logic [TAG_W-1:0] tag, input logic [30:0] tgt);
    logic [53:0] e; e = '0;
    e[53]=v; e[52]=br; e[51]=cond; e[50]=strd; e[31+:TAG_W]=tag; e[30:0]=tgt;
    return e;
  endfunction

  function automatic logic [31:0] pcFor(input logic [BTB_W-1:0] idx, input logic [TAG_W-1:0] tag);
    logic [31:0] pc; pc = '0;
    pc[BTB_W:1]           = idx;
    pc[BTB_W+TAG_W:BTB_W+1] = tag;
    return pc;
  endfunction

  task automatic btbWrite(input logic [BTB_W-1:0] idx, input logic [53:0] e);
    @(negedge clk); btbWrEnable=1; btbWrIndex=idx; btbWrEntry=e;
    @(negedge clk); btbWrEnable=0;
  endtask
  task automatic phtWrite(input logic [PHT_W-1:0] idx, input logic [1:0] c);
    @(negedge clk); phtWrEnable=1; phtWrIndex=idx; phtWrCounter=c;
    @(negedge clk); phtWrEnable=0;
  endtask
  task automatic clearBtb();
    for (int i = 0; i < (1<<BTB_W); i++) btbWrite(BTB_W'(i), '0);   // valid=0
  endtask
  task automatic redirectTo(input logic [31:0] pc);
    @(negedge clk); redirectValid=1; redirectPC=pc;
    @(negedge clk); redirectValid=0;
  endtask
  task automatic settle(); repeat (5) @(negedge clk); endtask
  // run sequential in cleared BTB territory until the history register is zero
  task automatic flushBhr();
    redirectTo(32'h3000_0000);
    while (dut.branchHistory !== '0) @(negedge clk);
  endtask

  logic [31:0] trace [0:19];
  task automatic capture(input int n);
    for (int i = 0; i < n; i++) begin @(negedge clk); trace[i] = nextPC; end
  endtask
  function automatic int findFirst(input logic [31:0] v, input int n);
    for (int i = 0; i < n; i++) if (trace[i] === v) return i;
    return -1;
  endfunction

  initial begin
    boot=0; redirectValid=0; btbWrEnable=0; phtWrEnable=0;
    redirectTo(RESET_PC);
    clearBtb();

    // ---- 1. boot forces the reset vector ---------------------------------------
    @(negedge clk); boot=1;
    @(negedge clk); @(negedge clk); boot=0;
    if (nextPC !== RESET_PC) begin $error("boot: nextPC=%h exp %h", nextPC, RESET_PC); errors++; end

    // ---- 2. redirect wins, then sequential fetch -------------------------------
    redirectTo(32'h3000_0000);
    settle();
    capture(6);
    for (int i = 1; i < 6; i++)
      if (trace[i] !== trace[i-1] + 32'd4) begin
        $error("sequential: trace[%0d]=%h trace[%0d]=%h", i, trace[i], i-1, trace[i-1]);
        errors++;
      end

    // ---- 3. unconditional predicted-taken --------------------------------------
    begin
      automatic logic [8:0]  bidx = 9'h055;
      automatic logic [10:0] btag = 11'h123;
      automatic logic [31:0] pcB  = pcFor(bidx, btag);
      automatic logic [31:0] tgt  = 32'h2ABC_0DE0;
      btbWrite(bidx, packEntry(1,1,0,0, btag, tgt[31:1]));
      redirectTo(pcB - 32'd4);
      capture(8);
      if (findFirst(tgt, 8) < 0) begin
        $error("uncond taken: target %h never fetched", tgt); errors++;
      end
    end

    // ---- 4. straddle applies the target one cycle later ------------------------
    begin
      automatic logic [8:0]  bidx = 9'h066;
      automatic logic [10:0] btag = 11'h1AA;
      automatic logic [31:0] pcB  = pcFor(bidx, btag);
      automatic logic [31:0] tgt  = 32'h2BCD_0EE0;
      int hitCyc;
      btbWrite(bidx, packEntry(1,1,0,1, btag, tgt[31:1]));   // straddle=1
      redirectTo(pcB - 32'd4);
      capture(10);
      hitCyc = findFirst(tgt, 10);
      if (hitCyc < 0) begin $error("straddle: target %h never fetched", tgt); errors++; end
    end

    // ---- 5. conditional follows the PHT ----------------------------------------
    begin
      automatic logic [8:0]  bidx = 9'h077;
      automatic logic [10:0] btag = 11'h0C3;
      automatic logic [31:0] pcB  = pcFor(bidx, btag);
      automatic logic [31:0] tgt  = 32'h2CDE_0FF0;
      automatic logic [PHT_W-1:0] pidx = pcB[PHT_W:1];       // bhr flushed to 0
      btbWrite(bidx, packEntry(1,1,1,0, btag, tgt[31:1]));   // conditional

      flushBhr();                       // bhr=0 so gshareIndex = pcB[PHT_W:1]
      phtWrite(pidx, 2'b11);            // strong taken
      redirectTo(pcB - 32'd4);
      capture(8);
      if (findFirst(tgt, 8) < 0) begin $error("cond taken: target %h missing", tgt); errors++; end

      flushBhr();
      phtWrite(pidx, 2'b00);            // strong not-taken
      redirectTo(pcB - 32'd4);
      capture(8);
      if (findFirst(tgt, 8) >= 0) begin $error("cond not-taken: target %h wrongly fetched", tgt); errors++; end
    end

    if (errors == 0) $display("PASS  bpredict");
    else             $fatal(1, "FAIL  bpredict (%0d errors)", errors);
    $finish;
  end
endmodule

