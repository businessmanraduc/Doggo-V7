// ================================================================================
//  ras_tb -- drives the stack one applied verdict per cycle and checks the top
//  the predictor would have steered a return to.
// ================================================================================
module ras_tb;
  localparam int DEPTH = 8;
  localparam int PTR_W = 3;

  logic clk = 0;
  always #5 clk = ~clk;

  logic             boot, restore, enable, push, pop;
  logic [PTR_W-1:0] restorePtr;
  logic [31:0]      pushAddr;
  logic [31:0]      top;
  logic [PTR_W-1:0] ptr;

  int errors = 0;

  ras #(.DEPTH(DEPTH), .PTR_W(PTR_W)) dut (
    .clk, .boot, .restore, .restorePtr, .enable, .push, .pop, .pushAddr, .top, .ptr
  );

  initial begin
    #100000;
    $fatal(1, "FAIL  ras: watchdog fired");
  end

  // ---- one cycle of the applied verdict ----------------------------------------
  task automatic doPush(input logic [31:0] addr);
    enable = 1'b1; push = 1'b1; pop = 1'b0; pushAddr = addr;
    @(negedge clk);
    push = 1'b0;
  endtask

  task automatic doPop();
    enable = 1'b1; push = 1'b0; pop = 1'b1;
    @(negedge clk);
    pop = 1'b0;
  endtask

  task automatic doPark(input int cycles);
    enable = 1'b0; push = 1'b1; pop = 1'b0;   // a verdict held across the park
    repeat (cycles) @(negedge clk);
    enable = 1'b1; push = 1'b0;
  endtask

  task automatic doRestore(input logic [PTR_W-1:0] p);
    restore = 1'b1; restorePtr = p;
    @(negedge clk);
    restore = 1'b0;
  endtask

  task automatic doBoot();
    boot = 1'b1; restore = 1'b0; enable = 1'b1; push = 1'b0; pop = 1'b0;
    pushAddr = '0; restorePtr = '0;
    @(negedge clk);
    boot = 1'b0;
  endtask

  task automatic expectTop(input logic [31:0] want, input string note);
    if (top !== want) begin
      $error("%-34s top=%h (expected %h)", note, top, want); errors++;
    end
  endtask

  task automatic expectPtr(input logic [PTR_W-1:0] want, input string note);
    if (ptr !== want) begin
      $error("%-34s ptr=%0d (expected %0d)", note, ptr, want); errors++;
    end
  endtask

  // ---- A - boot clears the stack -----------------------------------------------
  task automatic checkBoot();
    doPush(32'h0000_1111);
    doBoot();
    expectPtr(3'd0,        "A: boot clears the pointer");
    expectTop(32'h0000_0000, "A: boot clears the top");
  endtask

  // ---- B - one call, one return ------------------------------------------------
  task automatic checkPushPop();
    doBoot();
    doPush(32'h0000_2004);
    expectTop(32'h0000_2004, "B: top is the pushed address");
    expectPtr(3'd1,          "B: pointer moved up");
    doPop();
    expectPtr(3'd0,          "B: pointer moved back down");
  endtask

  // ---- C - nesting unwinds in LIFO order, which needs the memory ----------------
  task automatic checkNesting();
    doBoot();
    doPush(32'h0000_3004);
    doPush(32'h0000_3104);
    doPush(32'h0000_3204);
    expectTop(32'h0000_3204, "C: top is the innermost call");
    doPop();
    expectTop(32'h0000_3104, "C: pops to the middle call");
    doPop();
    expectTop(32'h0000_3004, "C: pops to the outer call");
    expectPtr(3'd1,          "C: pointer unwound");
  endtask

  // ---- D - a park holds a verdict without applying it twice --------------------
  task automatic checkParkHolds();
    doBoot();
    doPush(32'h0000_4004);
    doPark(4);                         // push held high, enable low
    expectTop(32'h0000_4004, "D: park did not re-push");
    expectPtr(3'd1,          "D: park did not move the pointer");
  endtask

  // ---- E - a checkpoint restores contents, not just depth -----------------------
  //  The pop after the restore has to reach something pushed BEFORE the wrong
  //  path, or the top-of-stack flop answers it and the memory is never read.
  task automatic checkCheckpointRestoresContents();
    logic [PTR_W-1:0] mark;
    doBoot();
    doPush(32'h0000_5004);             // outer call, the one we must get back
    doPush(32'h0000_5104);             // inner call
    mark = ptr;                        // snapshot taken between the pushes
    doPush(32'h0000_5EE4);             // wrong path
    doPush(32'h0000_5FF4);             // wrong path
    doRestore(mark);
    expectPtr(mark,          "E: pointer restored");
    expectTop(32'h0000_5104, "E: top rebuilt from memory");
    doPop();
    expectTop(32'h0000_5004, "E: pops past the restore to the outer call");
  endtask

  // ---- F - a wrong-path push does not corrupt a live entry ---------------------
  task automatic checkWrongPathLeavesLiveEntries();
    logic [PTR_W-1:0] mark;
    doBoot();
    doPush(32'h0000_6004);
    mark = ptr;
    doPush(32'h0000_6EE4);             // wrong path, lands above the live entry
    doRestore(mark);
    expectTop(32'h0000_6004, "F: live entry survived the wrong path");
    expectPtr(mark,          "F: pointer back to the live depth");
  endtask

  initial begin
    boot = 1'b0; restore = 1'b0; enable = 1'b1;
    push = 1'b0; pop = 1'b0; pushAddr = '0; restorePtr = '0;
    @(negedge clk);

    checkBoot();
    checkPushPop();
    checkNesting();
    checkParkHolds();
    checkCheckpointRestoresContents();
    checkWrongPathLeavesLiveEntries();

    if (errors == 0) $display("PASS  ras");
    else             $fatal(1, "FAIL  ras (%0d errors)", errors);
    $finish;
  end

endmodule
