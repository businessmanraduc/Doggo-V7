`include "isa.svh"
// =================================================================================
//  alu_tb -- directed edge cases (hand-computed) + randomized model sweep
// =================================================================================

module alu_tb;
  logic [31:0] lhs, rhs, result;
  aluOp_t      op;
  int          errors = 0;

  alu dut (.lhs, .rhs, .op, .result);

  function automatic logic [31:0] model(
    input aluOp_t      o,
    input logic [31:0] a,
    input logic [31:0] b
  );
    case (o)
      ALU_ADD:   return a + b;
      ALU_SUB:   return a - b;
      ALU_AND:   return a & b;
      ALU_OR:    return a | b;
      ALU_XOR:   return a ^ b;
      ALU_SLT:   return ($signed(a) < $signed(b)) ? 32'd1 : 32'd0;
      ALU_SLTU:  return (a < b) ? 32'd1 : 32'd0;
      ALU_PASSB: return b;
    endcase
  endfunction

  task automatic check(
    input aluOp_t      o,
    input logic [31:0] a,
    input logic [31:0] b,
    input logic [31:0] want,
    input string       note
  );
    op = o; lhs = a; rhs = b;
    #1;
    if (result !== want) begin
      $error("%-16s %s lhs=%h rhs=%h -> %h, want %h", note, o.name(), a, b, result, want);
      errors++;
    end
  endtask

  initial begin
    // ---- add / sub: wrap-around at the 32-bit boundary --------------------------
    check(ALU_ADD,  32'd0,         32'd0,         32'd0,         "add zero");
    check(ALU_ADD,  32'h1234_5678, 32'h8765_4321, 32'h9999_9999, "add plain");
    check(ALU_ADD,  32'hFFFF_FFFF, 32'd1,         32'd0,         "add wrap");
    check(ALU_SUB,  32'd0,         32'd1,         32'hFFFF_FFFF, "sub borrow");
    check(ALU_SUB,  32'h9999_9999, 32'h8765_4321, 32'h1234_5678, "sub plain");

    // ---- bitwise ----------------------------------------------------------------
    check(ALU_AND,  32'hF0F0_F0F0, 32'hFF00_FF00, 32'hF000_F000, "and");
    check(ALU_OR,   32'hF0F0_F0F0, 32'h0F0F_0F0F, 32'hFFFF_FFFF, "or");
    check(ALU_XOR,  32'hFFFF_FFFF, 32'hAAAA_AAAA, 32'h5555_5555, "xor");

    // ---- set-if-less-than: signed/unsigned --------------------------------------
    check(ALU_SLT,  32'hFFFF_FFFF, 32'd1,         32'd1,         "slt -1 < 1");
    check(ALU_SLT,  32'd1,         32'hFFFF_FFFF, 32'd0,         "slt 1 < -1");
    check(ALU_SLT,  32'd5,         32'd5,         32'd0,         "slt equal");
    check(ALU_SLT,  32'h8000_0000, 32'h7FFF_FFFF, 32'd1,         "slt min < max");
    check(ALU_SLTU, 32'hFFFF_FFFF, 32'd1,         32'd0,         "sltu max < 1");
    check(ALU_SLTU, 32'd1,         32'hFFFF_FFFF, 32'd1,         "sltu 1 < max");
    check(ALU_SLTU, 32'd5,         32'd5,         32'd0,         "sltu equal");

    // ---- pass-through ignores lhs entirely --------------------------------------
    check(ALU_PASSB, 32'hDEAD_BEEF, 32'h1234_5000, 32'h1234_5000, "passb");

    // ---- randomized sweep over all 8 encodings ----------------------------------
    for (int i = 0; i < 5000; i++) begin
      automatic logic [31:0] a = $urandom();
      automatic logic [31:0] b = $urandom();
      automatic aluOp_t      o = aluOp_t'($urandom_range(0, 7));
      check(o, a, b, model(o, a, b), "random");
    end

    if (errors == 0) $display("PASS  alu");
    else             $fatal(1, "FAIL  alu (%0d errors)", errors);
    $finish;
  end
endmodule
