// =================================================================================
//  add_smoke_tb -- self-checking bench for the registered adder
// =================================================================================

module add_smoke_tb;
  logic        clk = 0;
  logic [31:0] a, b, out;
  int          errors = 0;

  add_smoke #(.W(32)) dut (.clk, .a, .b, .out);

  always #5 clk = ~clk;

  task automatic check(input [31:0] xa, input [31:0] xb);
    a = xa; b = xb;
    @(posedge clk); @(posedge clk); #1;
    if (out !== (xa + xb)) begin
      $error("%h + %h = %h, expected %h", xa, xb, out, xa + xb);
      errors++;
    end
  endtask

  initial begin
    check(32'd0,          32'd0);
    check(32'd1,          32'd2);
    check(32'hFFFF_FFFF,  32'd1);
    check(32'h1234_5678,  32'h8765_4321);
    check(32'hDEAD_BEEF,  32'hCAFE_F00D);
    if (errors == 0) $display("PASS  add_smoke");
    else             $fatal(1, "FAIL  add_smoke (%0d errors)", errors);
    $finish;
  end
endmodule

