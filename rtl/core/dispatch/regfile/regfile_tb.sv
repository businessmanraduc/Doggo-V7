// ================================================================================
//  regfile_tb -- random write/read stress against a mirror array; x0 reads as
//  zero always, and a same-edge write is invisible to that cycle's readers
// ================================================================================

module regfile_tb;
  logic        clk = 0;
  logic [4:0]  rs1Index, rs2Index, wrIndex;
  logic [31:0] rs1Data, rs2Data, wrData;
  logic        wrEnable;
  int          errors = 0;

  regfile dut (.clk, .rs1Index, .rs2Index, .rs1Data, .rs2Data,
               .wrEnable, .wrIndex, .wrData);

  always #5 clk = ~clk;

  logic [31:0] model [32];

  task automatic fail(input string msg);
    $error("%s", msg);
    errors++;
  endtask

  function automatic logic [31:0] expect_(input logic [4:0] idx);
    return (idx == 0) ? 32'b0 : model[idx];
  endfunction

  initial begin
    wrEnable = 0; wrData = '0; wrIndex = '0; rs1Index = '0; rs2Index = '0;
    for (int i = 1; i < 32; i++) begin   // seed every register once
      @(posedge clk); #1;
      wrEnable = 1; wrIndex = 5'(i); wrData = {27'($urandom()), 5'(i)};
      model[i] = wrData;
      @(posedge clk); #1;
      wrEnable = 0;
    end

    // ---- A: every register reads back what the model holds ---------------------
    for (int i = 0; i < 32; i++) begin
      rs1Index = 5'(i); rs2Index = 5'(31 - i);
      #1;
      if (rs1Data !== expect_(5'(i)))      fail($sformatf("A: rs1 x%0d", i));
      if (rs2Data !== expect_(5'(31 - i))) fail($sformatf("A: rs2 x%0d", 31 - i));
    end

    // ---- B: a same-edge write is invisible until the next cycle ----------------
    rs1Index = 5'd7;
    wrEnable = 1; wrIndex = 5'd7; wrData = 32'hFEED_0007;
    #1;
    if (rs1Data !== model[7]) fail("B: same-edge write leaked to the reader");
    @(posedge clk); #1;
    model[7] = 32'hFEED_0007;
    wrEnable = 0;
    #1;
    if (rs1Data !== 32'hFEED_0007) fail("B: write did not land");

    // ---- C: x0 is zero even against a contract-breaking write ------------------
    wrEnable = 1; wrIndex = 5'd0; wrData = 32'hBAD0_BAD0;
    @(posedge clk); #1;
    wrEnable = 0; rs1Index = 5'd0; rs2Index = 5'd0;
    #1;
    if (rs1Data !== 32'b0 || rs2Data !== 32'b0) fail("C: x0 not hardwired zero");

    // ---- D: random stress against the mirror -----------------------------------
    for (int k = 0; k < 5000; k++) begin
      automatic logic       we = 1'($urandom());
      automatic logic [4:0] wi = 5'($urandom());
      automatic logic [31:0] wd = 32'($urandom());
      rs1Index = 5'($urandom()); rs2Index = 5'($urandom());
      wrEnable = we && (wi != 0); wrIndex = wi; wrData = wd;
      #1;
      if (rs1Data !== expect_(rs1Index)) fail("D: rs1 vs model");
      if (rs2Data !== expect_(rs2Index)) fail("D: rs2 vs model");
      @(posedge clk); #1;
      if (wrEnable) model[wi] = wd;
    end

    if (errors == 0) $display("PASS  regfile");
    else             $fatal(1, "FAIL  regfile (%0d errors)", errors);
    $finish;
  end
endmodule
