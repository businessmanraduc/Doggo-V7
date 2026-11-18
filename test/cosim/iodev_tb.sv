// ================================================================================
//  iodev_tb -- random IO bus traffic against a model of the device map
// ================================================================================
module iodev_tb;

  logic clk = 1'b0, resetn = 1'b0;
  always #5 clk = !clk;

  logic        ioValid = 1'b0, ioWrite, ioReady, ioRValid, dv_exit;
  logic [31:2] ioAddr;
  logic [3:0]  ioBe;
  logic [31:0] ioWData, ioRData, dv_irq, dv_exitCode;

  iodev u_dev (.*);

  localparam logic [31:0] IO_BASE = 32'h1000_0000;

  logic [31:0] modelScratch [64];
  logic [31:0] modelCounter = 0, modelFifo = 32'hace1, modelIrq = 0;
  logic [31:0] expectedReads [$];
  longint      modelTimerAt = -1;
  int          reads, writes, errors, stallCycles, timerFires;

  task automatic advanceTimer();
    if (modelTimerAt >= 0 && u_dev.dv_cycle >= modelTimerAt) begin
      modelIrq |= 32'h80;
      modelTimerAt = -1;
      timerFires++;
    end
  endtask

  function automatic logic [31:2] pickAddress();
    int choice = $urandom % 10;
    if (choice < 5) return 30'((IO_BASE + ($urandom % 64) * 4) >> 2);
    if (choice == 5) return 30'((IO_BASE + 32'h100) >> 2);
    if (choice == 6) return 30'((IO_BASE + 32'h104) >> 2);
    if (choice == 7) return 30'((IO_BASE + 32'h108) >> 2);
    if (choice == 8) return 30'((IO_BASE + 32'h10c) >> 2);
    return 30'($urandom >> 2);
  endfunction

  // the model takes the request after the device has run this edge
  task automatic modelRequest();
    logic [31:0] address = {ioAddr, 2'b00};
    logic [31:0] busWord = ioWData & {{8{ioBe[3]}}, {8{ioBe[2]}}, {8{ioBe[1]}}, {8{ioBe[0]}}};
    if (ioWrite) begin
      writes++;
      if (address >= IO_BASE && address < IO_BASE + 256) begin
        for (int b = 0; b < 4; b++)
          if (ioBe[b]) modelScratch[(address - IO_BASE) >> 2][8 * b +: 8] = ioWData[8 * b +: 8];
      end else if (address == IO_BASE + 32'h108) modelIrq = busWord & 32'h888;
      else if (address == IO_BASE + 32'h10c) modelTimerAt = busWord == 0 ? -1 : u_dev.dv_cycle + busWord;
    end else begin
      reads++;
      if (address >= IO_BASE && address < IO_BASE + 256)
        expectedReads.push_back(modelScratch[(address - IO_BASE) >> 2]);
      else if (address == IO_BASE + 32'h100) begin
        modelCounter += 7;
        expectedReads.push_back(modelCounter);
      end
      else if (address == IO_BASE + 32'h104) begin
        modelFifo = (modelFifo >> 1) ^ ((modelFifo & 1) ? 32'hb400 : 0);
        expectedReads.push_back(modelFifo * 32'h9e37_79b1);
      end
      else if (address == IO_BASE + 32'h108) expectedReads.push_back(modelIrq);
      else expectedReads.push_back(0);
    end
  endtask

  initial begin
    for (int i = 0; i < 64; i++) modelScratch[i] = 0;
    repeat (3) @(posedge clk);
    resetn = 1'b1;
    repeat (20000) begin
      @(negedge clk);
      ioValid = 1'b1;
      ioWrite = $urandom % 2;
      ioAddr  = pickAddress();
      ioBe    = $urandom % 16;
      ioWData = $urandom;
      if ({ioAddr, 2'b00} == IO_BASE + 32'h10c) ioWData = $urandom % 40;
      if ({ioAddr, 2'b00} == IO_BASE + 32'h108 && ioWrite) ioWData = $urandom;
      do begin @(posedge clk); if (!ioReady) stallCycles++; end while (!ioReady);
      #1;
      advanceTimer();                // the device fires before it takes a write
      modelRequest();
      @(negedge clk);
      ioValid = 1'b0;
      repeat ($urandom % 3) @(negedge clk);
    end
    repeat (20) @(posedge clk);
    if (expectedReads.size() != 0) begin
      $display("iodev_tb: %0d reads never returned", expectedReads.size());
      errors++;
    end
    $display("iodev_tb: %0d reads, %0d writes, %0d stall cycles, %0d timer fires, %0d errors",
             reads, writes, stallCycles, timerFires, errors);
    $display("%s", errors == 0 && timerFires > 0 ? "PASS" : "FAIL");
    $finish;
  end

  always @(posedge clk) if (resetn) begin
    #2;
    advanceTimer();
    if (ioRValid) begin
      if (expectedReads.size() == 0) begin
        $display("iodev_tb: read data without a read");
        errors++;
      end else begin
        logic [31:0] expected = expectedReads.pop_front();
        if (expected !== ioRData) begin
          if (errors < 5) $display("iodev_tb: read %h, expected %h", ioRData, expected);
          errors++;
        end
      end
    end
    if ((dv_irq & 32'h888) !== modelIrq) begin
      if (errors < 5) $display("iodev_tb: irq lines %h, expected %h", dv_irq, modelIrq);
      errors++;
    end
  end

endmodule
