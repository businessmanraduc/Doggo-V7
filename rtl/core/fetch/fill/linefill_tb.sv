// ================================================================================
//  linefill_tb -- drives the engine against a fake memory that streams a burst,
//  and checks the boot sweep, the burst walk, write ordering and the drain.
// ================================================================================
module linefill_tb;
  localparam int SET_IDX_W = 7;
  localparam int WIL_W     = 3;
  localparam int TAG_W     = 13;
  localparam int WORDIDX_W = 10;
  localparam int SETS      = 1 << SET_IDX_W;

  logic clk = 0;
  always #5 clk = ~clk;

  logic                 resetn;
  logic                 missValid;
  logic [TAG_W-1:0]     missTag;
  logic [SET_IDX_W-1:0] missSet;
  logic [1:0]           missVictim;
  logic [31:0]          fillAddr;
  logic                 fillReq;
  logic [31:0]          fillRData;
  logic                 fillRValid;
  logic [3:0]           dataWrEnable;
  logic [WORDIDX_W-1:0] dataWrIndex;
  logic [31:0]          dataWrWord;
  logic [3:0]           tagWrEnable;
  logic [SET_IDX_W-1:0] tagWrSet;
  logic [TAG_W-1:0]     tagWrTag;
  logic                 tagWrValid;
  logic                 initDone;
  logic                 fillBusy;

  int errors = 0;

  // ---- watchdog: fail loudly instead of hanging --------------------------------
  initial begin
    #500000;
    $fatal(1, "FAIL  linefill: watchdog fired, the FSM is stuck (state=%0d)", dut.state);
  end

  linefill dut (
    .clk, .resetn,
    .missValid, .missTag, .missSet, .missVictim,
    .fillAddr, .fillReq, .fillRData, .fillRValid,
    .dataWrEnable, .dataWrIndex, .dataWrWord,
    .tagWrEnable, .tagWrSet, .tagWrTag, .tagWrValid,
    .initDone, .fillBusy
  );

  // ---- scoreboard of what the engine wrote -------------------------------------
  logic        sweptValid [0:SETS-1][0:3];
  int          sweepWrites = 0;
  int          dataWrites  = 0;
  logic [31:0] dataSeen    [0:7];
  int          dataIdxSeen [0:7];
  int          tagWrites   = 0;
  int          lastDataCycle = -1;
  int          tagCycle      = -1;
  int          cycle = 0;

  always_ff @(posedge clk) begin
    cycle <= cycle + 1;
    if (tagWrEnable != 4'b0 && !tagWrValid) begin
      sweepWrites++;
      for (int w = 0; w < 4; w++) if (tagWrEnable[w]) sweptValid[tagWrSet][w] <= 1'b0;
    end
    if (dataWrEnable != 4'b0) begin
      dataSeen[dataWrites]    <= dataWrWord;
      dataIdxSeen[dataWrites] <= int'(dataWrIndex);
      dataWrites++;
      lastDataCycle <= cycle;
    end
    if (tagWrEnable != 4'b0 && tagWrValid) begin
      tagWrites++;
      tagCycle <= cycle;
    end
  end

  // ---- fake memory: 8 beats in order once fillReq goes up ----------------------
  task automatic serveBurst(input logic [31:0] base, input int gapCycles);
    repeat (gapCycles) @(negedge clk);
    for (int k = 0; k < 8; k++) begin
      @(negedge clk);
      fillRValid = 1'b1;
      fillRData  = base + 32'(k);
      @(negedge clk);
      fillRValid = 1'b0;      // deliberately gappy: beats are not back to back
    end
  endtask

  initial begin
    resetn = 0; missValid = 0; missTag = '0; missSet = '0; missVictim = '0;
    fillRValid = 0; fillRData = '0;
    for (int s = 0; s < SETS; s++) for (int w = 0; w < 4; w++) sweptValid[s][w] = 1'b1;

    repeat (3) @(negedge clk);
    resetn = 1;

    // ---- the boot sweep must clear every set of every way ----------------------
    if (initDone !== 1'b0) begin
      $error("initDone high before the sweep finished"); errors++;
    end
    wait (initDone === 1'b1);
    @(negedge clk);
    for (int s = 0; s < SETS; s++)
      for (int w = 0; w < 4; w++)
        if (sweptValid[s][w] !== 1'b0) begin
          $error("sweep missed set %0d way %0d", s, w); errors++;
        end
    if (sweepWrites != SETS) begin
      $error("sweep took %0d writes, expected %0d", sweepWrites, SETS); errors++;
    end

    // ---- a miss should launch exactly one burst --------------------------------
    @(negedge clk);
    missValid = 1'b1; missTag = 13'h1A5; missSet = 7'h33; missVictim = 2'd2;
    @(negedge clk);
    missValid = 1'b0;

    wait (fillReq === 1'b1);
    if (fillAddr !== {7'b0, 13'h1A5, 7'h33, 5'b0}) begin
      $error("fillAddr=%h wrong", fillAddr); errors++;
    end
    if (fillBusy !== 1'b1) begin $error("fillBusy low during fill"); errors++; end

    serveBurst(32'hBEEF_0000, 2);

    wait (fillBusy === 1'b0);
    @(negedge clk);

    // ---- eight words, ascending, into the victim way ---------------------------
    if (dataWrites != 8) begin
      $error("wrote %0d data words, expected 8", dataWrites); errors++;
    end
    for (int k = 0; k < 8; k++) begin
      if (dataSeen[k] !== 32'hBEEF_0000 + 32'(k)) begin
        $error("beat %0d data=%h", k, dataSeen[k]); errors++;
      end
      if (dataIdxSeen[k] != int'({7'h33, 3'(k)})) begin
        $error("beat %0d index=%0d expected %0d", k, dataIdxSeen[k],
               int'({7'h33, 3'(k)})); errors++;
      end
    end

    // ---- exactly one validating tag write, and it came LAST --------------------
    if (tagWrites != 1) begin
      $error("%0d validating tag writes, expected 1", tagWrites); errors++;
    end
    if (tagCycle <= lastDataCycle) begin
      $error("tag written at cycle %0d, not after last data at %0d",
             tagCycle, lastDataCycle); errors++;
    end

    // ---- a stale miss during the drain must be ignored -------------------------
    checkDrainIgnoresStaleMiss();

    // ---- a miss arriving mid-fill must not start a second burst ----------------
    checkNoNestedFill();

    if (errors == 0) $display("PASS  linefill");
    else             $fatal(1, "FAIL  linefill (%0d errors)", errors);
    $finish;
  end

  // ---- the three drain cycles exist to swallow in-flight stale misses ----------
  task automatic checkDrainIgnoresStaleMiss();
    int writesBefore;
    @(negedge clk);
    missValid = 1'b1; missTag = 13'h0C1; missSet = 7'h11; missVictim = 2'd0;
    @(negedge clk); missValid = 1'b0;
    wait (fillReq === 1'b1);
    serveBurst(32'h1111_0000, 0);
    // now inside TAG/DRAIN: throw a stale miss at it
    @(negedge clk);
    writesBefore = dataWrites;
    missValid    = 1'b1; missTag = 13'h0C1; missSet = 7'h11; missVictim = 2'd1;
    @(negedge clk); missValid = 1'b0;
    wait (fillBusy === 1'b0);
    repeat (4) @(negedge clk);
    if (dataWrites != writesBefore) begin
      $error("a miss during TAG/DRAIN started another fill (%0d new writes)",
             dataWrites - writesBefore);
      errors++;
    end
  endtask

  // ---- one outstanding fill only -----------------------------------------------
  task automatic checkNoNestedFill();
    logic [31:0] addrDuring;
    @(negedge clk);
    missValid = 1'b1; missTag = 13'h044; missSet = 7'h05; missVictim = 2'd3;
    @(negedge clk); missValid = 1'b0;
    wait (fillReq === 1'b1);
    addrDuring = fillAddr;
    @(negedge clk);
    missValid = 1'b1; missTag = 13'h777; missSet = 7'h7F; missVictim = 2'd0;
    @(negedge clk); missValid = 1'b0;
    if (fillAddr !== addrDuring) begin
      $error("fillAddr moved mid-burst: %h -> %h", addrDuring, fillAddr);
      errors++;
    end
    serveBurst(32'h4444_0000, 0);
    // the fill that completes must be the FIRST one, not the interloper
    wait (dut.state === dut.S_TAG);
    if (dut.fillSet !== 7'h05 || dut.fillTag !== 13'h044 || dut.fillWay !== 2'd3) begin
      $error("the interloping miss hijacked the fill: set=%h tag=%h way=%0d",
             dut.fillSet, dut.fillTag, dut.fillWay);
      errors++;
    end
    wait (fillBusy === 1'b0);
  endtask

endmodule

