`include "isa.svh"
// =================================================================================
//  shifter_tb -- directed edge cases (hand-computed) + randomized model sweep
//  every check drives fresh inputs each cycle, so the pipe is exercised at rate
// =================================================================================

module shifter_tb;
  logic        clk = 0;
  logic [31:0] operand, result;
  logic [4:0]  amount;
  shiftOp_t    op;
  int          errors = 0;

  shifter dut (.clk, .operand, .amount, .op, .result);

  always #5 clk = ~clk;

  function automatic logic [31:0] model(
    input shiftOp_t    o,
    input logic [31:0] v,
    input logic [4:0]  a
  );
    case (o)
      SHIFT_SLL: return v << a;
      SHIFT_SRA: return 32'($signed(v) >>> a);
      default:   return v >> a;
    endcase
  endfunction

  // apply now, sample one register stage later
  task automatic check(
    input shiftOp_t    o,
    input logic [31:0] v,
    input logic [4:0]  a,
    input logic [31:0] want,
    input string       note
  );
    op = o; operand = v; amount = a;
    @(posedge clk); #1;
    if (result !== want) begin
      $error("%-20s %s v=%h amt=%0d -> %h, want %h", note, o.name(), v, a, result, want);
      errors++;
    end
  endtask

  initial begin
    // ---- left: coarse/fine boundaries of the {amount[4:3], amount[2:0]} split ---
    check(SHIFT_SLL, 32'd1, 5'd0,  32'h0000_0001, "sll by 0");
    check(SHIFT_SLL, 32'd1, 5'd1,  32'h0000_0002, "sll by 1");
    check(SHIFT_SLL, 32'd1, 5'd7,  32'h0000_0080, "sll by 7 fine max");
    check(SHIFT_SLL, 32'd1, 5'd8,  32'h0000_0100, "sll by 8 coarse only");
    check(SHIFT_SLL, 32'd1, 5'd9,  32'h0000_0200, "sll by 9 both");
    check(SHIFT_SLL, 32'd1, 5'd16, 32'h0001_0000, "sll by 16");
    check(SHIFT_SLL, 32'd1, 5'd24, 32'h0100_0000, "sll by 24");
    check(SHIFT_SLL, 32'd1, 5'd31, 32'h8000_0000, "sll by 31");
    check(SHIFT_SLL, 32'hFFFF_FFFF, 5'd16, 32'hFFFF_0000, "sll bleed out");

    // ---- logical right: zero fill, never sign fill ------------------------------
    check(SHIFT_SRL, 32'h8000_0000, 5'd1,  32'h4000_0000, "srl by 1");
    check(SHIFT_SRL, 32'h8000_0000, 5'd31, 32'h0000_0001, "srl by 31");
    check(SHIFT_SRL, 32'hFFFF_FFFF, 5'd16, 32'h0000_FFFF, "srl zero fill");
    check(SHIFT_SRL, 32'h8000_0000, 5'd8,  32'h0080_0000, "srl by 8 coarse");
    check(SHIFT_SRL, 32'hDEAD_BEEF, 5'd0,  32'hDEAD_BEEF, "srl by 0");

    // ---- arithmetic right: sign fill across BOTH stages -------------------------
    check(SHIFT_SRA, 32'h8000_0000, 5'd0,  32'h8000_0000, "sra by 0");
    check(SHIFT_SRA, 32'h8000_0000, 5'd1,  32'hC000_0000, "sra by 1");
    check(SHIFT_SRA, 32'h8000_0000, 5'd8,  32'hFF80_0000, "sra by 8 coarse");
    check(SHIFT_SRA, 32'h8000_0000, 5'd16, 32'hFFFF_8000, "sra by 16");
    check(SHIFT_SRA, 32'h8000_0000, 5'd24, 32'hFFFF_FF80, "sra by 24");
    check(SHIFT_SRA, 32'h8000_0000, 5'd31, 32'hFFFF_FFFF, "sra by 31");
    check(SHIFT_SRA, 32'hFFFF_FFFF, 5'd31, 32'hFFFF_FFFF, "sra all ones");
    check(SHIFT_SRA, 32'h4000_0000, 5'd1,  32'h2000_0000, "sra positive");
    check(SHIFT_SRA, 32'h7FFF_FFFF, 5'd31, 32'h0000_0000, "sra max positive");

    // ---- randomized full-rate sweep ---------------------------------------------
    for (int i = 0; i < 5000; i++) begin
      automatic logic [31:0] v = $urandom();
      automatic logic [4:0]  a = 5'($urandom_range(0, 31));
      automatic shiftOp_t    o = shiftOp_t'($urandom_range(0, 2));
      check(o, v, a, model(o, v, a), "random");
    end

    if (errors == 0) $display("PASS  shifter");
    else             $fatal(1, "FAIL  shifter (%0d errors)", errors);
    $finish;
  end
endmodule

