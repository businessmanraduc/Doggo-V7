// ================================================================================
//  iodev -- test devices on the 0042 IO bus, same map as refdut.cc (sim only)
// ================================================================================
//  0x1000_0000 scratch, 64 words       0x1000_0108 irq lines (bits 3, 7, 11)
//  0x1000_0100 counter, +7 per read    0x1000_010c irq timer, MTIP after N cycles
//  0x1000_0104 fifo, LFSR per read     0x1000_0110 console byte
//  0x1000_0114 exit word               else reads 0, writes dropped
//  Random ready stalls (STALL %) and read latency (0..LAT), read data in order.
//  Register writes take the bus word with disabled lanes zeroed.
// ================================================================================
module iodev #(
  parameter int STALL = 30,
  parameter int LAT   = 6
) (
  input  logic        clk,
  input  logic        resetn,
  input  logic        ioValid,
  input  logic        ioWrite,
  input  logic [31:2] ioAddr,
  input  logic [3:0]  ioBe,
  input  logic [31:0] ioWData,
  output logic        ioReady,
  output logic        ioRValid,
  output logic [31:0] ioRData,
  output logic [31:0] dv_irq,
  output logic        dv_exit,
  output logic [31:0] dv_exitCode
);

  localparam logic [31:0] IO_BASE  = 32'h1000_0000;
  localparam logic [31:0] IRQ_MASK = 32'h888;

  logic [31:0] dv_scratch [64];
  logic [31:0] dv_irqLines;
  logic [31:0] dv_counter, dv_fifo;
  longint      dv_timerAt;
  longint      dv_cycle;
  string       dv_consoleLine;

  typedef struct { logic [31:0] data; longint readyAt; } read_t;
  read_t dv_reads [$];

  always @(posedge clk) begin
    if (!resetn) begin
      for (int i = 0; i < 64; i++) dv_scratch[i] = 0;
      dv_counter = 0; dv_fifo = 32'hace1; dv_timerAt = -1; dv_cycle = 0;
      dv_irqLines = 0;
      dv_reads.delete();
      dv_irq <= 0; dv_exit <= 0; dv_exitCode <= 0;
      ioReady <= 0; ioRValid <= 0;
    end else begin
      logic [31:0] address, readData, busWord;
      dv_cycle++;
      if (dv_timerAt >= 0 && dv_cycle >= dv_timerAt) begin dv_irqLines |= 32'h80; dv_timerAt = -1; end
      if (ioValid && ioReady) begin
        address = {ioAddr, 2'b00};
        busWord = ioWData & {{8{ioBe[3]}}, {8{ioBe[2]}}, {8{ioBe[1]}}, {8{ioBe[0]}}};
        if (ioWrite) begin
          if (address >= IO_BASE && address < IO_BASE + 256) begin
            for (int b = 0; b < 4; b++)
              if (ioBe[b]) dv_scratch[(address - IO_BASE) >> 2][8 * b +: 8] = ioWData[8 * b +: 8];
          end else if (address == IO_BASE + 32'h108) begin
            dv_irqLines = busWord & IRQ_MASK;
          end else if (address == IO_BASE + 32'h10c) begin
            dv_timerAt = busWord == 0 ? -1 : dv_cycle + longint'(busWord);
          end else if (address == IO_BASE + 32'h110) begin
            for (int b = 0; b < 4; b++)
              if (ioBe[b]) begin
                if (ioWData[8 * b +: 8] == 8'h0a) begin
                  $display("console: %s", dv_consoleLine);
                  dv_consoleLine = "";
                end else begin
                  dv_consoleLine = {dv_consoleLine, string'(ioWData[8 * b +: 8])};
                end
              end
          end else if (address == IO_BASE + 32'h114) begin
            dv_exit <= 1;
            dv_exitCode <= busWord;
          end
        end else begin
          if (address >= IO_BASE && address < IO_BASE + 256)
            readData = dv_scratch[(address - IO_BASE) >> 2];
          else if (address == IO_BASE + 32'h100) begin dv_counter += 7; readData = dv_counter; end
          else if (address == IO_BASE + 32'h104) begin
            dv_fifo = (dv_fifo >> 1) ^ ((dv_fifo & 1) ? 32'hb400 : 0);
            readData = dv_fifo * 32'h9e37_79b1;
          end
          else if (address == IO_BASE + 32'h108) readData = dv_irqLines;
          else readData = 0;
          dv_reads.push_back('{readData, dv_cycle + 1 + $urandom % (LAT + 1)});
        end
      end
      ioRValid <= 0;
      if (dv_reads.size() > 0 && dv_reads[0].readyAt <= dv_cycle) begin
        read_t oldest = dv_reads.pop_front();
        ioRValid <= 1;
        ioRData <= oldest.data;
      end
      ioReady <= $urandom % 100 >= STALL;
      dv_irq <= dv_irqLines;
    end
  end

endmodule
