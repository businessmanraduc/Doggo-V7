// ================================================================================
//  PHANTOoOM-32 -- 18-bit BSRAM cell (single write / single read)
// ================================================================================
//  Raw DP16KD in x18 mode: one 18-bit word per address, 2^ADDR_W deep.
//  Word address sits in AD[13:4]; sub-word bits AD[3:0] are read-tied-0.
//  On write, ADA0/ADA1 are byte-enables held high for full 18-bit write.
//
//  OUT_REG picks read latency:
//    0 - one cycle
//    1 - two cycles (packs the block's output register)
// ================================================================================
module ebr18 #(
  parameter bit OUT_REG = 1'b0,
  parameter int ADDR_W  = 9
) (
  input  logic              clk,
  input  logic              wrEnable,
  input  logic [ADDR_W-1:0] wrAddr,
  input  logic [17:0]       wrData,
  input  logic [ADDR_W-1:0] rdAddr,
  output logic [17:0]       rdData
);

`ifdef VERILATOR
  // ---- behavioral match --------------------------------------------------------
  (* ram_style = "block_ram" *) logic [17:0] mem [0:(1<<ADDR_W)-1];
  logic [17:0] readInner;
  always_ff @(posedge clk) begin
    if (wrEnable) mem[wrAddr] <= wrData;
    readInner <= mem[rdAddr];
  end
  generate
    if (OUT_REG) begin : g_outReg
      always_ff @(posedge clk) rdData <= readInner;
    end else begin : g_noReg
      assign rdData = readInner;
    end
  endgenerate
`else
  // ---- synthesis ---------------------------------------------------------------
  logic [9:0] wrWord; assign wrWord = {{(10-ADDR_W){1'b0}}, wrAddr};
  logic [9:0] rdWord; assign rdWord = {{(10-ADDR_W){1'b0}}, rdAddr};
  DP16KD #(
    .DATA_WIDTH_A(18), .DATA_WIDTH_B(18),
    .REGMODE_A("NOREG"), .REGMODE_B(OUT_REG ? "OUTREG" : "NOREG"),
    .RESETMODE("SYNC"), .ASYNC_RESET_RELEASE("SYNC"),
    .CSDECODE_A("0b000"), .CSDECODE_B("0b000"),
    .WRITEMODE_A("NORMAL"), .WRITEMODE_B("NORMAL"), .GSR("AUTO")
  ) u_ebr (
    // ---- port A: write (byte enables ADA0/1 high = full word) ------------------
    .CLKA(clk), .CEA(1'b1), .OCEA(1'b1), .WEA(wrEnable), .RSTA(1'b0),
    .CSA0(1'b0), .CSA1(1'b0), .CSA2(1'b0),
    .ADA0(1'b1), .ADA1(1'b1), .ADA2(1'b0), .ADA3(1'b0),
    .ADA4(wrWord[0]), .ADA5(wrWord[1]), .ADA6(wrWord[2]), .ADA7(wrWord[3]),
    .ADA8(wrWord[4]), .ADA9(wrWord[5]), .ADA10(wrWord[6]),.ADA11(wrWord[7]),
    .ADA12(wrWord[8]),.ADA13(wrWord[9]),
    .DIA0(wrData[0]), .DIA1(wrData[1]), .DIA2(wrData[2]), .DIA3(wrData[3]),
    .DIA4(wrData[4]), .DIA5(wrData[5]), .DIA6(wrData[6]), .DIA7(wrData[7]),
    .DIA8(wrData[8]), .DIA9(wrData[9]), .DIA10(wrData[10]),.DIA11(wrData[11]),
    .DIA12(wrData[12]),.DIA13(wrData[13]),.DIA14(wrData[14]),.DIA15(wrData[15]),
    .DIA16(wrData[16]),.DIA17(wrData[17]),
    .DOA0(), .DOA1(), .DOA2(), .DOA3(), .DOA4(), .DOA5(), .DOA6(), .DOA7(),
    .DOA8(), .DOA9(), .DOA10(),.DOA11(),.DOA12(),.DOA13(),.DOA14(),.DOA15(),
    .DOA16(),.DOA17(),
    // ---- port B: read (sub-word AD[3:0] = 0) -----------------------------------
    .CLKB(clk), .CEB(1'b1), .OCEB(1'b1), .WEB(1'b0), .RSTB(1'b0),
    .CSB0(1'b0), .CSB1(1'b0), .CSB2(1'b0),
    .ADB0(1'b0), .ADB1(1'b0), .ADB2(1'b0), .ADB3(1'b0),
    .ADB4(rdWord[0]), .ADB5(rdWord[1]), .ADB6(rdWord[2]), .ADB7(rdWord[3]),
    .ADB8(rdWord[4]), .ADB9(rdWord[5]), .ADB10(rdWord[6]),.ADB11(rdWord[7]),
    .ADB12(rdWord[8]),.ADB13(rdWord[9]),
    .DIB0(1'b0), .DIB1(1'b0), .DIB2(1'b0), .DIB3(1'b0), .DIB4(1'b0), .DIB5(1'b0),
    .DIB6(1'b0), .DIB7(1'b0), .DIB8(1'b0), .DIB9(1'b0), .DIB10(1'b0),.DIB11(1'b0),
    .DIB12(1'b0),.DIB13(1'b0),.DIB14(1'b0),.DIB15(1'b0),.DIB16(1'b0),.DIB17(1'b0),
    .DOB0(rdData[0]), .DOB1(rdData[1]), .DOB2(rdData[2]), .DOB3(rdData[3]),
    .DOB4(rdData[4]), .DOB5(rdData[5]), .DOB6(rdData[6]), .DOB7(rdData[7]),
    .DOB8(rdData[8]), .DOB9(rdData[9]), .DOB10(rdData[10]),.DOB11(rdData[11]),
    .DOB12(rdData[12]),.DOB13(rdData[13]),.DOB14(rdData[14]),.DOB15(rdData[15]),
    .DOB16(rdData[16]),.DOB17(rdData[17])
  );
`endif

endmodule

