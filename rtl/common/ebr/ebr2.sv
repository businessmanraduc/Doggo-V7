// ================================================================================
//  PHANTOoOM-32 -- 2-bit BSRAM cell (single write / single read)
// ================================================================================
//  Raw DP16KD in x2 mode: one 2-bit word per address, 2^ADDR_W deep.
//  Word address sits in AD[13:1], AD0 tied 0.
//
//  OUT_REG picks read latency:
//    0 - one cycle
//    1 - two cycles (packs the block's output register)
// ================================================================================
module ebr2 #(
  parameter bit OUT_REG = 1'b0,
  parameter int ADDR_W  = 13
) (
  input  logic              clk,
  input  logic              wrEnable,
  input  logic [ADDR_W-1:0] wrAddr,
  input  logic [1:0]        wrData,
  input  logic [ADDR_W-1:0] rdAddr,
  output logic [1:0]        rdData
);

`ifdef VERILATOR
  (* ram_style = "block_ram" *) logic [1:0] mem [0:(1<<ADDR_W)-1];
  logic [1:0] readInner;
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
  logic [12:0] wrWord; assign wrWord = {{(13-ADDR_W){1'b0}}, wrAddr};
  logic [12:0] rdWord; assign rdWord = {{(13-ADDR_W){1'b0}}, rdAddr};
  DP16KD #(
    .DATA_WIDTH_A(2), .DATA_WIDTH_B(2),
    .REGMODE_A("NOREG"), .REGMODE_B(OUT_REG ? "OUTREG" : "NOREG"),
    .RESETMODE("SYNC"), .ASYNC_RESET_RELEASE("SYNC"),
    .CSDECODE_A("0b000"), .CSDECODE_B("0b000"),
    .WRITEMODE_A("NORMAL"), .WRITEMODE_B("NORMAL"), .GSR("AUTO")
  ) u_ebr (
    .CLKA(clk), .CEA(1'b1), .OCEA(1'b1), .WEA(wrEnable), .RSTA(1'b0),
    .CSA0(1'b0), .CSA1(1'b0), .CSA2(1'b0),
    .ADA0(1'b0),
    .ADA1(wrWord[0]),  .ADA2(wrWord[1]),  .ADA3(wrWord[2]),  .ADA4(wrWord[3]),
    .ADA5(wrWord[4]),  .ADA6(wrWord[5]),  .ADA7(wrWord[6]),  .ADA8(wrWord[7]),
    .ADA9(wrWord[8]),  .ADA10(wrWord[9]), .ADA11(wrWord[10]),.ADA12(wrWord[11]),
    .ADA13(wrWord[12]),
    .DIA0(wrData[0]), .DIA1(wrData[1]),
    .DIA2(1'b0), .DIA3(1'b0), .DIA4(1'b0), .DIA5(1'b0), .DIA6(1'b0), .DIA7(1'b0),
    .DIA8(1'b0), .DIA9(1'b0), .DIA10(1'b0),.DIA11(1'b0),.DIA12(1'b0),.DIA13(1'b0),
    .DIA14(1'b0),.DIA15(1'b0),.DIA16(1'b0),.DIA17(1'b0),
    .DOA0(), .DOA1(), .DOA2(), .DOA3(), .DOA4(), .DOA5(), .DOA6(), .DOA7(),
    .DOA8(), .DOA9(), .DOA10(),.DOA11(),.DOA12(),.DOA13(),.DOA14(),.DOA15(),
    .DOA16(),.DOA17(),
    .CLKB(clk), .CEB(1'b1), .OCEB(1'b1), .WEB(1'b0), .RSTB(1'b0),
    .CSB0(1'b0), .CSB1(1'b0), .CSB2(1'b0),
    .ADB0(1'b0),
    .ADB1(rdWord[0]),  .ADB2(rdWord[1]),  .ADB3(rdWord[2]),  .ADB4(rdWord[3]),
    .ADB5(rdWord[4]),  .ADB6(rdWord[5]),  .ADB7(rdWord[6]),  .ADB8(rdWord[7]),
    .ADB9(rdWord[8]),  .ADB10(rdWord[9]), .ADB11(rdWord[10]),.ADB12(rdWord[11]),
    .ADB13(rdWord[12]),
    .DIB0(1'b0), .DIB1(1'b0), .DIB2(1'b0), .DIB3(1'b0), .DIB4(1'b0), .DIB5(1'b0),
    .DIB6(1'b0), .DIB7(1'b0), .DIB8(1'b0), .DIB9(1'b0), .DIB10(1'b0),.DIB11(1'b0),
    .DIB12(1'b0),.DIB13(1'b0),.DIB14(1'b0),.DIB15(1'b0),.DIB16(1'b0),.DIB17(1'b0),
    .DOB0(rdData[0]), .DOB1(rdData[1]),
    .DOB2(), .DOB3(), .DOB4(), .DOB5(), .DOB6(), .DOB7(), .DOB8(), .DOB9(),
    .DOB10(),.DOB11(),.DOB12(),.DOB13(),.DOB14(),.DOB15(),.DOB16(),.DOB17()
  );
`endif

endmodule

