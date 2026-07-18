`include "isa.svh"
// ================================================================================
//  PHANTOoOM-32 -- 32-bit legality checker
// ================================================================================
//  Purely combinational verdict on a native 32-bit instruction: is this an
//  exactly-legal RV32IM + Zicsr encoding?
//  Lives in parallel with the RVC expander (which owns the compressed space)
//
//  Solo Fmax (ring-of-regs, nextpnr --85k, tw=100, 20 seeds): 165.76 / 186.22 / 194.06
// ================================================================================
module legal32 (
  input  logic [31:0] instr,
  output logic        illegal
);

  logic [6:0] opcode;
  logic [2:0] func3;
  logic [6:0] func7;

  assign opcode = instr[6:0];
  assign func3  = instr[14:12];
  assign func7  = instr[31:25];

  always_comb begin
    unique case (opcode)
      OP_LUI, OP_AUIPC, OP_JAL: illegal = 1'b0;

      OP_JALR:   illegal = (func3 != F3_JALR);
      OP_BRANCH: illegal = (func3[2:1] == 2'b01);
      OP_LOAD:   illegal = (func3[1:0] == 2'b11) || (func3 == 3'b110);
      OP_STORE:  illegal = func3[2] || (func3[1:0] == 2'b11);

      OP_ARITH_I: begin
        unique case (func3)
          F3_SLL:  illegal = (func7 != F7_NORMAL);
          F3_SRL:  illegal = (func7 != F7_NORMAL && func7 != F7_ALT);
          default: illegal = 1'b0;
        endcase
      end

      OP_ARITH_R: begin
        if (func7 == F7_MULDIV) illegal = 1'b0;
        else begin
          unique case (func3)
            F3_ADD, F3_SRL: illegal = (func7 != F7_NORMAL && func7 != F7_ALT);
            default:        illegal = (func7 != F7_NORMAL);
          endcase
        end
      end

      OP_FENCE: illegal = (func3[2:1] != 2'b00);

      OP_SYSTEM: begin
        if (func3 == F3_PRIV) begin
          illegal = (instr != INSTR_ECALL)
                 && (instr != INSTR_EBREAK)
                 && (instr != INSTR_MRET)
                 && (instr != INSTR_WFI);
        end else begin
          illegal = (func3 == 3'b100);
        end
      end

      default: illegal = 1'b1;
    endcase

    illegal = illegal || (instr[1:0] != 2'b11);
  end

endmodule

