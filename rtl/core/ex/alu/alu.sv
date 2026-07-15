`include "isa.svh"
// =================================================================================
//  PHANTOoOM-32 -- ALU
// =================================================================================
//  Purely combinational add / logic / compare unit.
//
//  Operand A: rs1/pc
//  Operand B: rs2/imm
//  Opcode:    3-bit operation select, every encoding legal
//
//  Solo Fmax (ring-of-regs, nextpnr --85k, tw=100, 20 seeds): 175.07 / 183.17 / 192.83
// =================================================================================
module alu (
  input  logic [31:0] lhs,      // operand A (rs1 or PC)
  input  logic [31:0] rhs,      // operand B (rs2 or imm)
  input  aluOp_t      op,       // operation select
  output logic [31:0] result    // outcome result
);

  always_comb begin
    case (op)
      ALU_ADD:   result = lhs + rhs;
      ALU_SUB:   result = lhs - rhs;

      ALU_AND:   result = lhs & rhs;
      ALU_OR:    result = lhs | rhs;
      ALU_XOR:   result = lhs ^ rhs;

      ALU_SLT:   result = ($signed(lhs) < $signed(rhs)) ? 32'd1 : 32'd0;
      ALU_SLTU:  result = (lhs < rhs)                   ? 32'd1 : 32'd0;

      ALU_PASSB: result = rhs;
    endcase
  end

endmodule
