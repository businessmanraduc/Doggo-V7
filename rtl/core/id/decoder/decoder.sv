`include "uop.svh"
// ================================================================================
//  PHANTOoOM-32 -- Decoder
// ================================================================================
//  Purely combinational RV32IM + Zicsr decode;
//  one 32-bit instruction in, one uop out.
//  The instruction stream arrives pre-validated, this module caries NO
//  legality tree.
//
//  Solo Fmax (ring-of-regs, nextpnr --85k, tw=100, 20 seeds): 164.77 / 176.62 / 190.33
// ================================================================================
module decoder (
  input  logic [31:0] instr,
  input  logic [31:0] pc,
  input  logic        isCompressed,
  input  logic        illegal,
  output uop_t        uop
);

  logic [6:0] opcode;
  logic [2:0] func3;
  logic [6:0] func7;

  assign opcode = instr[6:0];
  assign func3  = instr[14:12];
  assign func7  = instr[31:25];

  // ---- immediate extraction ----------------------------------------------------
  logic [31:0] immI, immS, immB, immU, immJ;

  assign immI = {{20{instr[31]}}, instr[31:20]};
  assign immS = {{20{instr[31]}}, instr[31:25], instr[11:7]};
  assign immB = {{19{instr[31]}}, instr[31],    instr[7],     instr[30:25], instr[11:8],  1'b0};
  assign immU = {instr[31:12], 12'b0};
  assign immJ = {{11{instr[31]}}, instr[31],    instr[19:12], instr[20],    instr[30:21], 1'b0};

  // ---- decode ------------------------------------------------------------------
  always_comb begin
    uop               = '0;
    uop.pc            = pc;
    uop.isCompressed  = isCompressed;
    uop.rs1Index  = instr[19:15];
    uop.rs2Index  = instr[24:20];
    uop.rdIndex       = instr[11:7];

    unique case (opcode)
      OP_LUI: begin
        uop.fu       = FU_ALU;    uop.subOp = ALU_PASSB;  uop.immUsed = 1'b1;
        uop.regWrite = 1'b1;      uop.imm   = immU;
      end
      OP_AUIPC: begin
        uop.fu       = FU_ALU;    uop.subOp = ALU_ADD;    uop.immUsed = 1'b1;
        uop.regWrite = 1'b1;      uop.imm   = immU;       uop.pcUsed  = 1'b1;
      end

      OP_JAL: begin
        uop.fu       = FU_BRANCH; uop.subOp = SUBOP_JAL;
        uop.regWrite = 1'b1;      uop.imm   = immJ;
      end
      OP_JALR: begin
        uop.fu       = FU_BRANCH; uop.subOp = SUBOP_JALR; uop.rs1Used = 1'b1;
        uop.regWrite = 1'b1;      uop.imm   = immI;
      end
      OP_BRANCH: begin
        uop.fu       = FU_BRANCH; uop.subOp = func3;      uop.rs1Used = 1'b1;
        uop.rs2Used  = 1'b1;      uop.imm   = immB;
      end

      OP_LOAD: begin
        uop.fu       = FU_LSU;    uop.subOp = func3;      uop.immUsed = 1'b1;
        uop.regWrite = 1'b1;      uop.imm   = immI;       uop.rs1Used = 1'b1;
      end
      OP_STORE: begin
        uop.fu       = FU_LSU;    uop.subOp = func3;      uop.immUsed = 1'b1;
        uop.rs1Used  = 1'b1;      uop.imm   = immS;       uop.rs2Used = 1'b1;
        uop.isStore  = 1'b1;
      end

      OP_ARITH_I: begin
        uop.rs1Used  = 1'b1;      uop.imm   = immI;       uop.immUsed = 1'b1;
        uop.regWrite = 1'b1;
        unique case (func3)
          F3_SLL:  begin uop.fu = FU_SHIFTER; uop.subOp = {1'b0, SHIFT_SLL}; end
          F3_SRL: begin
            uop.fu = FU_SHIFTER;
            uop.subOp = {1'b0, (func7 == F7_ALT) ? SHIFT_SRA : SHIFT_SRL};
          end
          F3_ADD:  begin uop.fu = FU_ALU;     uop.subOp = ALU_ADD;           end
          F3_SLT:  begin uop.fu = FU_ALU;     uop.subOp = ALU_SLT;           end
          F3_SLTU: begin uop.fu = FU_ALU;     uop.subOp = ALU_SLTU;          end
          F3_XOR:  begin uop.fu = FU_ALU;     uop.subOp = ALU_XOR;           end
          F3_OR:   begin uop.fu = FU_ALU;     uop.subOp = ALU_OR;            end
          F3_AND:  begin uop.fu = FU_ALU;     uop.subOp = ALU_AND;           end
        endcase
      end

      OP_ARITH_R: begin
        uop.regWrite = 1'b1;      uop.rs1Used = 1'b1;     uop.rs2Used = 1'b1;
        if (func7 == F7_MULDIV) begin
          uop.fu = FU_MULDIV;     uop.subOp   = func3;
        end else begin
          unique case (func3)
            F3_ADD: begin
              uop.fu    = FU_ALU;
              uop.subOp = (func7 == F7_ALT) ? ALU_SUB : ALU_ADD;
            end
            F3_SLL:  begin uop.fu = FU_SHIFTER; uop.subOp = {1'b0, SHIFT_SLL}; end
            F3_SRL: begin
              uop.fu    = FU_SHIFTER;
              uop.subOp = {1'b0, (func7 == F7_ALT) ? SHIFT_SRA : SHIFT_SRL};
            end
            F3_SLT:  begin uop.fu = FU_ALU;     uop.subOp = ALU_SLT;           end
            F3_SLTU: begin uop.fu = FU_ALU;     uop.subOp = ALU_SLTU;          end
            F3_XOR:  begin uop.fu = FU_ALU;     uop.subOp = ALU_XOR;           end
            F3_OR:   begin uop.fu = FU_ALU;     uop.subOp = ALU_OR;            end
            F3_AND:  begin uop.fu = FU_ALU;     uop.subOp = ALU_AND;           end
          endcase
        end
      end

      OP_FENCE: begin
        uop.fu       = FU_SYS;
        uop.isFenceI = func3[0];
      end

      OP_SYSTEM: begin
        uop.fu       = FU_SYS;
        if (func3 == F3_PRIV) begin
          unique case (instr[31:20])
            12'h000: begin uop.excValid = 1'b1; uop.excCause = TRAP_ECALL_M;    end
            12'h001: begin uop.excValid = 1'b1; uop.excCause = TRAP_BREAKPOINT; end
            12'h302: begin uop.isMret   = 1'b1;                                 end
            12'h105: begin uop.isWfi    = 1'b1;                                 end
            default: ;
          endcase
        end else begin
          uop.subOp = func3; uop.csrUseZimm = func3[2]; uop.rs1Used = !func3[2];
          uop.imm   = immI;  uop.regWrite   = 1'b1;
        end
      end

      default: ;
    endcase

    if (uop.rdIndex == '0) uop.regWrite = 1'b0;

    if (illegal) begin
      uop.rs1Used  = 1'b0;
      uop.rs2Used  = 1'b0;
      uop.regWrite = 1'b0;
      uop.isStore  = 1'b0;
      uop.isMret   = 1'b0;
      uop.isWfi    = 1'b0;
      uop.isFenceI = 1'b0;
      uop.excValid = 1'b1;
      uop.excCause = TRAP_ILLEGAL_INSTR;
    end
  end

endmodule

