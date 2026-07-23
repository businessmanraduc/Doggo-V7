// ================================================================================
//  pht_tb -- write counters, read them back through the two-cycle precompute-both
//  path: resolveBit=0 picks index, resolveBit=1 picks index^1, taken = counter[1].
// ================================================================================
module pht_tb;
  localparam int INDEX_W = 13;

  logic clk = 0;
  always #5 clk = ~clk;

  logic [INDEX_W-1:0] gshareIndex;
  logic               resolveBit;
  logic               wrEnable;
  logic [INDEX_W-1:0] wrIndex;
  logic [1:0]         wrCounter;
  logic               taken;
  int                 errors = 0;

  pht #(.OUT_REG(1'b0), .INDEX_W(INDEX_W)) dut (
    .clk, .gshareIndex, .resolveBit,
    .wrEnable, .wrIndex, .wrCounter, .takenPrediction(taken)
  );

  task automatic doWrite(input logic [INDEX_W-1:0] idx, input logic [1:0] c);
    @(negedge clk); wrEnable = 1; wrIndex = idx; wrCounter = c;
    @(negedge clk); wrEnable = 0;
  endtask

  task automatic checkLookup(
    input logic [INDEX_W-1:0] g, input logic sel, input logic eTaken, input string note);
    @(negedge clk); gshareIndex = g; resolveBit = sel;
    @(negedge clk);            // arm
    @(negedge clk);            // verdict valid
    if (taken !== eTaken) begin
      $error("%-24s g=%h sel=%b taken=%b(exp %b)", note, g, sel, taken, eTaken);
      errors++;
    end
  endtask

  initial begin
    wrEnable = 0; gshareIndex = '0; resolveBit = 0;

    // ---- directed: the resolve bit selects index vs index^1 --------------------
    doWrite(13'h100, 2'b11);        // strong-taken at 0x100
    doWrite(13'h101, 2'b00);        // strong-not-taken at 0x101 (= 0x100 ^ 1)
    checkLookup(13'h100, 1'b0, 1'b1, "sel0 -> index");
    checkLookup(13'h100, 1'b1, 1'b0, "sel1 -> index^1");
    checkLookup(13'h101, 1'b0, 1'b0, "sel0 other side");
    checkLookup(13'h101, 1'b1, 1'b1, "sel1 other side");

    // ---- directed: only counter[1] is the prediction ---------------------------
    doWrite(13'h200, 2'b01); doWrite(13'h201, 2'b10);
    checkLookup(13'h200, 1'b0, 1'b0, "counter 01 -> not taken");
    checkLookup(13'h201, 1'b0, 1'b1, "counter 10 -> taken");

    // ---- random sweep ----------------------------------------------------------
    for (int k = 0; k < 300; k++) begin
      automatic logic [INDEX_W-1:0] g  = INDEX_W'($urandom());
      automatic logic [1:0]         cg = 2'($urandom());
      automatic logic [1:0]         ca = 2'($urandom());
      doWrite(g,            cg);
      doWrite(g ^ 13'h1,    ca);
      checkLookup(g, 1'b0, cg[1], $sformatf("rand sel0 g=%h", g));
      checkLookup(g, 1'b1, ca[1], $sformatf("rand sel1 g=%h", g));
    end

    if (errors == 0) $display("PASS  pht");
    else             $fatal(1, "FAIL  pht (%0d errors)", errors);
    $finish;
  end
endmodule

