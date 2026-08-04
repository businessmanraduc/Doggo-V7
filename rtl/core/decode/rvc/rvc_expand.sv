`include "isa.svh"
// ================================================================================
//  PHANTOoOM-32 -- RVC Expander
// ================================================================================
//  Purely combinational RV32C -> 32-bit expansion.
//
//  Contract: only instr16[1:0] != 2'b11 is fed in. HINTs expand normally;
//  reserved / FPs / RV64-only encodings raise illegal and instr32 is void.
//
//  Solo Fmax (ring-of-regs, nextpnr --85k, tw=100, 20 seeds): 181.82 / 187.93 / 196.66
// ================================================================================
module rvc_expand (
  input  logic [15:0] instr16,  // aligned compressed instruction
  output logic [31:0] instr32,  // expanded 32-bit equivalent
  output logic        illegal   // reserved/unsupported encoding
);

  // ---- register fields ---------------------------------------------------------
  logic [4:0] destReg, srcReg2;
  logic [4:0] srcReg1P, srcReg2P;

  assign destReg  = instr16[11:7];
  assign srcReg2  = instr16[6:2];
  assign srcReg1P = {2'b01, instr16[9:7]};
  assign srcReg2P = {2'b01, instr16[4:2]};

  // ---- immediates --------------------------------------------------------------
  logic [31:0] immCi, immAddi4spn, immLwSw, immJ, immB;
  logic [31:0] immAddi16sp, immLui, immLwsp, immSwsp;

  assign immCi       = {{27{instr16[12]}},    instr16[6:2]};
  assign immLui      = {{15{instr16[12]}},    instr16[6:2],    12'b0};
  assign immLwSw     = {25'b0, instr16[5],    instr16[12:10],  instr16[6],    2'b00};
  assign immAddi4spn = {22'b0, instr16[10:7], instr16[12:11],  instr16[5],    instr16[6],     2'b00};
  assign immAddi16sp = {{23{instr16[12]}},    instr16[4:3],    instr16[5],    instr16[2],     instr16[6], 4'b0};
  assign immB        = {{24{instr16[12]}},    instr16[6:5],    instr16[2],    instr16[11:10], instr16[4:3],  1'b0};
  assign immLwsp     = {24'b0, instr16[3:2],  instr16[12],     instr16[6:4],  2'b00};
  assign immSwsp     = {24'b0, instr16[8:7],  instr16[12:9],   2'b00};
  assign immJ        = {{21{instr16[12]}},    instr16[8],
    instr16[10:9], instr16[6], instr16[7],    instr16[2],
    instr16[11],   instr16[5:3],    1'b0};

  // ---- expansion ---------------------------------------------------------------
  always_comb begin
    instr32 = '0;
    illegal = 1'b0;

    unique case ({instr16[1:0], instr16[15:13]})
      // ---- Q0 ------------------------------------------------------------------
      {CQ0, CF3_ADDI4SPN}: begin
        instr32 = {immAddi4spn[11:0], 5'd2, F3_ADD, srcReg2P, OP_ARITH_I};
        illegal = (immAddi4spn == '0);
      end
      {CQ0, CF3_LW}: begin
        instr32 = {immLwSw[11:0], srcReg1P, F3_LW,  srcReg2P, OP_LOAD};
      end
      {CQ0, CF3_SW}: begin
        instr32 = {immLwSw[11:5], srcReg2P, srcReg1P, F3_SW,  immLwSw[4:0], OP_STORE};
      end

      // ---- Q1 ------------------------------------------------------------------
      {CQ1, CF3_ADDI}: begin
        instr32 = {immCi[11:0], destReg, F3_ADD, destReg, OP_ARITH_I};
      end
      {CQ1, CF3_JAL}: begin
        instr32 = {immJ[20], immJ[10:1], immJ[11], immJ[19:12], 5'd1, OP_JAL};
      end
      {CQ1, CF3_LI}: begin
        instr32 = {immCi[11:0], 5'd0,    F3_ADD, destReg, OP_ARITH_I};
      end
      {CQ1, CF3_LUI}: begin
        if (destReg == 5'd2) instr32 = {immAddi16sp[11:0], 5'd2, F3_ADD, 5'd2, OP_ARITH_I};
        else                 instr32 = {immLui[31:12],destReg, OP_LUI};
        illegal = ({instr16[12], instr16[6:2]} == '0);
      end
      {CQ1, CF3_ARITH}: begin
        unique case (instr16[11:10])
          2'b00: begin
            instr32 = {F7_NORMAL, srcReg2, srcReg1P, F3_SRL, srcReg1P, OP_ARITH_I};
            illegal = instr16[12];
          end
          2'b01: begin
            instr32 = {F7_ALT,    srcReg2, srcReg1P, F3_SRL, srcReg1P, OP_ARITH_I};
            illegal = instr16[12];
          end
          2'b10: begin
            instr32 = {immCi[11:0],        srcReg1P, F3_AND, srcReg1P, OP_ARITH_I};
          end
          2'b11: begin
            unique case (instr16[6:5])
              2'b00: instr32 = {F7_ALT,    srcReg2P, srcReg1P, F3_ADD, srcReg1P, OP_ARITH_R};
              2'b01: instr32 = {F7_NORMAL, srcReg2P, srcReg1P, F3_XOR, srcReg1P, OP_ARITH_R};
              2'b10: instr32 = {F7_NORMAL, srcReg2P, srcReg1P, F3_OR,  srcReg1P, OP_ARITH_R};
              2'b11: instr32 = {F7_NORMAL, srcReg2P, srcReg1P, F3_AND, srcReg1P, OP_ARITH_R};
            endcase
            illegal = instr16[12];
          end
        endcase
      end
      {CQ1, CF3_J}: begin
        instr32 = {immJ[20], immJ[10:1], immJ[11], immJ[19:12], 5'd0, OP_JAL};
      end
      {CQ1, CF3_BEQZ}: begin
        instr32 = {immB[12], immB[10:5], 5'd0, srcReg1P, F3_BEQ, immB[4:1], immB[11], OP_BRANCH};
      end
      {CQ1, CF3_BNEZ}: begin
        instr32 = {immB[12], immB[10:5], 5'd0, srcReg1P, F3_BNE, immB[4:1], immB[11], OP_BRANCH};
      end

      // ---- Q2 ------------------------------------------------------------------
      {CQ2, CF3_SLLI}: begin
        instr32 = {F7_NORMAL, srcReg2, destReg, F3_SLL, destReg, OP_ARITH_I};
        illegal = instr16[12];
      end
      {CQ2, CF3_LWSP}: begin
        instr32 = {immLwsp[11:0], 5'd2, F3_LW, destReg, OP_LOAD};
        illegal = (destReg == '0);
      end
      {CQ2, CF3_MISC}: begin
        if (srcReg2 == '0) begin
          if (!instr16[12]) begin
            instr32 = {12'b0, destReg, F3_JALR, 5'd0, OP_JALR};
            illegal = (destReg == '0);
          end else if (destReg == '0) begin
            instr32 = INSTR_EBREAK;
          end else begin
            instr32 = {12'b0, destReg, F3_JALR, 5'd1, OP_JALR};
          end
        end else begin
          if (!instr16[12]) begin
            instr32 = {F7_NORMAL, srcReg2, 5'd0,    F3_ADD, destReg, OP_ARITH_R};
          end else begin
            instr32 = {F7_NORMAL, srcReg2, destReg, F3_ADD, destReg, OP_ARITH_R};
          end
        end
      end
      {CQ2, CF3_SWSP}: begin
        instr32 = {immSwsp[11:5], srcReg2, 5'd2, F3_SW, immSwsp[4:0], OP_STORE};
      end

      default: illegal = 1'b1;
    endcase
  end

endmodule

