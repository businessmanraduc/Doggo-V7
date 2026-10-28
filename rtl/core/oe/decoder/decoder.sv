// ================================================================================
//  Main Decoder: rest of the decode over D1 and D2, beside rename
// ================================================================================
//  D               RD1           RD2             PreDS
//  predecoder ─┬─► rename R1 ──► rename R2 ──┬─► predisp
//              └─► decoder D1 ─► decoder D2 ─┘
// ================================================================================
//  Everything the predecoder left out: class, latency group, execute controls
//  in the shape their units take, sys op, immediates, illegals.
//
//  Also carries the D fields that rename doesn't need:
//    (pc, meta, branchTarget, seq, call/ret)
//
//  Mechanism:
//    - D1: opcode decodification of both encodings (32-bit and 16-bit) in
//    parallel, merged by rvc, immediate leaves D1 as one-hot format select.
//    - D2: immediate assembly (AND-OR of formats), illegal merge by rvc,
//    latency group, serializing, f3-derived controls.
//    - D2 skid: beside rename's, selected by rename's rd2_skidValid.
//    - Payload only: no valid/reset. Rename owns valid/flush; each register
//    holds while its stall is high.
//    - Illegal: 32-bit check split in 3 flops, OR on all 3 in D2.
//    - OP and OP-IMM carry instr[31:20] in immediate -> XALU and BITM FUs
//    tell their ops apart by func7 and func3.
// ================================================================================
`include "uop_defs.svh"

module decoder #(
  parameter int MW = 1                      // prediction metadata
) (
  input  logic                 clk,
  // ---- Decode/Decode-1 inter-stage pipeline register ---------------------------
  input  logic [31:0]          d_d1_instr,
  input  logic                 d_d1_rvc,
  input  logic [30:0]          d_d1_pc,
  input  logic [MW-1:0]        d_d1_meta,
  input  logic                 d_d1_rs1Use,
  input  logic                 d_d1_rs2Use,
  input  logic                 d_d1_isCall,
  input  logic                 d_d1_isRet,
  input  logic [30:0]          d_d1_branchTarget,
  input  logic [30:0]          d_d1_seq,
  // ---- inter-stage pipeline register controls ----------------------------------
  input  logic                 stall_d1_d2,
  input  logic                 stall_d2_pds,
  input  logic                 rd2_skidValid,
  // ---- Decode-2/Dispatch-1 inter-stage pipeline register -----------------------
  output logic [30:0]          d2_pds_pc,
  output logic [MW-1:0]        d2_pds_meta,
  output logic                 d2_pds_isCall,
  output logic                 d2_pds_isRet,
  output logic [30:0]          d2_pds_branchTarget,
  output logic [30:0]          d2_pds_seq,
  output logic                 d2_pds_rvc,
  output logic [CLASS_W-1:0]   d2_pds_class,
  output logic [LATENCY_W-1:0] d2_pds_latency,
  output logic                 d2_pds_sub,
  output logic                 d2_pds_selArith,
  output logic                 d2_pds_selAnd,
  output logic                 d2_pds_selOr,
  output logic                 d2_pds_selXor,
  output logic                 d2_pds_selSlt,
  output logic                 d2_pds_sltUnsigned,  // sltu, sltiu, bltu, bgeu
  output logic                 d2_pds_shiftRight,
  output logic                 d2_pds_shiftArith,
  output logic                 d2_pds_xIsPC,
  output logic                 d2_pds_xIsZero,
  output logic                 d2_pds_zIsImm,
  output logic                 d2_pds_zIsZero,
  output logic                 d2_pds_branchUseLt,  // lt, else eq
  output logic                 d2_pds_branchInvert,
  output logic                 d2_pds_mulSignedA,
  output logic                 d2_pds_mulSignedB,
  output logic                 d2_pds_mulHigh,
  output logic                 d2_pds_divSigned,
  output logic                 d2_pds_divRemainder,
  output logic [2:0]           d2_pds_func3,
  output logic [SYSTEM_W-1:0]  d2_pds_system,
  output logic                 d2_pds_serialising,  // csr/system wait for the head
  output logic [31:0]          d2_pds_immediate,    // csr: {zimm, addr} in [16:0]
  output logic                 d2_pds_illegal
);

  // ---- 32-bit opcodes (instr[6:2]) ---------------------------------------------
  localparam logic [4:0] OP_LOAD     = 5'b00000;
  localparam logic [4:0] OP_MISC_MEM = 5'b00011;
  localparam logic [4:0] OP_IMM      = 5'b00100;
  localparam logic [4:0] OP_AUIPC    = 5'b00101;
  localparam logic [4:0] OP_STORE    = 5'b01000;
  localparam logic [4:0] OP_OP       = 5'b01100;
  localparam logic [4:0] OP_LUI      = 5'b01101;
  localparam logic [4:0] OP_BRANCH   = 5'b11000;
  localparam logic [4:0] OP_JALR     = 5'b11001;
  localparam logic [4:0] OP_JAL      = 5'b11011;
  localparam logic [4:0] OP_SYSTEM   = 5'b11100;

  // ---- immediate formats (one-hot select, none = 0) ----------------------------
  localparam int IMM_I     = 0;
  localparam int IMM_S     = 1;
  localparam int IMM_U     = 2;
  localparam int IMM_CSR   = 3;
  localparam int IMM_CI    = 4;
  localparam int IMM_CLW   = 5;
  localparam int IMM_CLWSP = 6;
  localparam int IMM_CSWSP = 7;
  localparam int IMM_C4SPN = 8;
  localparam int IMM_C16SP = 9;
  localparam int IMM_CLUI  = 10;
  localparam int IMM_W     = 11;

  // ---- 32-bit path -------------------------------------------------------------
  logic [31:0]          w_instr;
  logic [4:0]           w_op;
  logic [2:0]           w_func3;
  logic [6:0]           w_func7;
  logic [4:0]           w_rs2Field;
  logic                 w_isOp;
  logic [CLASS_W-1:0]   w_class;
  logic [SYSTEM_W-1:0]  w_system;
  logic [IMM_W-1:0]     w_immFormat;
  logic                 w_sub, w_selArith, w_selAnd, w_selOr, w_selXor, w_selSlt;
  logic                 w_sltUnsigned, w_shiftRight, w_shiftArith, w_xIsPC, w_zIsImm;
  logic                 w_illegal, w_illegalAlu, w_illegalSys;

  assign w_instr    = d_d1_instr;
  assign w_op       = w_instr[6:2];
  assign w_func3    = w_instr[14:12];
  assign w_func7    = w_instr[31:25];
  assign w_rs2Field = w_instr[24:20];
  assign w_isOp     = w_op == OP_OP;

  always_comb begin
    w_class      = '0;
    w_system     = '0;
    w_immFormat  = '0;
    {w_sub, w_selArith, w_selAnd, w_selOr, w_selXor, w_selSlt} = '0;
    {w_sltUnsigned, w_shiftRight, w_shiftArith, w_xIsPC, w_zIsImm} = '0;
    w_illegal    = 1'b0;
    w_illegalAlu = 1'b0;
    w_illegalSys = 1'b0;

    case (w_op)
      OP_LUI, OP_AUIPC: begin
        w_class[CLASS_ALU]   = 1'b1;  w_selArith = 1'b1; w_zIsImm = 1'b1;
        w_immFormat[IMM_U]   = 1'b1;  w_xIsPC    = w_op == OP_AUIPC;
      end
      OP_JAL: begin
        w_class[CLASS_JAL]   = 1'b1;
      end
      OP_JALR: begin
        w_class[CLASS_JALR]   = 1'b1; w_selArith = 1'b1; w_zIsImm = 1'b1;
        w_immFormat[IMM_I]    = 1'b1; w_illegal  = w_func3 != 3'b000;
      end
      OP_BRANCH: begin
        w_class[CLASS_BRANCH] = 1'b1; w_sub = 1'b1; w_sltUnsigned = w_func3[1];
        w_illegal = w_func3[2:1] == 2'b01;
      end
      OP_LOAD: begin
        w_class[CLASS_LOAD]   = 1'b1; w_immFormat[IMM_I] = 1'b1;
        w_illegal = w_func3 == 3'b011 || w_func3[2:1] == 2'b11;
      end
      OP_STORE: begin
        w_class[CLASS_STORE]  = 1'b1; w_immFormat[IMM_S] = 1'b1;
        w_illegal = w_func3[2] || w_func3[1:0] == 2'b11;
      end
      OP_IMM, OP_OP: begin
        w_zIsImm           = w_op == OP_IMM;
        w_immFormat[IMM_I] = 1'b1;
        if (w_isOp && w_func7 == 7'b0000001) begin
          w_class[w_func3[2] ? CLASS_DIV : CLASS_MUL] = 1'b1;
        end else if (w_isOp && w_func7 == 7'b0010000) begin   // shXadd
          w_class[CLASS_XALU] = 1'b1;
          w_illegalAlu = w_func3[0] || w_func3[2:1] == 2'b00;
        end else if (w_isOp && w_func7 == 7'b0000101) begin   // min/max
          w_class[CLASS_XALU] = 1'b1; w_sub = 1'b1; w_sltUnsigned = w_func3[0];
          w_illegalAlu = !w_func3[2];
        end else if (w_isOp && w_func7 == 7'b0000111) begin   // czero
          w_class[CLASS_XALU] = 1'b1;
          w_illegalAlu = !(w_func3[2] && w_func3[0]);
        end else if ((w_isOp && w_func7 == 7'b0000100) || ((w_isOp || w_func3[1:0] == 2'b01)
                 && (w_func7 == 7'b0110000 || w_func7 == 7'b0100100
                 ||  w_func7 == 7'b0110100 || w_func7 == 7'b0010100)
        )) begin                                              // zext.h
          w_class[CLASS_BITM] = 1'b1; w_shiftRight = w_func3 == 3'b101;
          case (w_func7)
            7'b0110000: w_illegalAlu = w_func3[1:0] != 2'b01  // rol ror clz ctz cpop sext
              || (!w_isOp && !w_func3[2]  && (w_rs2Field[4:3] != 2'b00
              || w_rs2Field[1:0] == 2'b11 ||  w_rs2Field[2:1] == 2'b11));
            7'b0100100: w_illegalAlu = w_func3[1:0] != 2'b01; // bclr bext
            7'b0110100: w_illegalAlu = w_func3[1:0] != 2'b01  // binv rev8
              || (w_func3[2] && (w_isOp || w_rs2Field != 5'b11000));
            7'b0010100: w_illegalAlu = w_func3[1:0] != 2'b01  // bset orc.b
              || (w_func3[2] && (w_isOp || w_rs2Field != 5'b00111));
            default:    w_illegalAlu = w_func3 != 3'b100 || w_rs2Field != 5'd0;
          endcase
        end else begin
          case (w_func3)
            3'b000: begin
              w_class[CLASS_ALU] = 1'b1; w_selArith = 1'b1;
              w_sub = w_isOp && w_func7[5];
            end
            3'b001: begin
              w_class[CLASS_BITM] = 1'b1;
            end
            3'b010: begin
              w_class[CLASS_XALU] = 1'b1; w_sub = 1'b1; w_selSlt = 1'b1;
            end
            3'b011: begin
              w_class[CLASS_XALU] = 1'b1; w_sub = 1'b1; w_selSlt = 1'b1; w_sltUnsigned = 1'b1;
            end
            3'b100: begin
              w_class[CLASS_ALU]  = 1'b1; w_selXor = 1'b1; w_sub = w_isOp && w_func7[5];
            end
            3'b101: begin
              w_class[CLASS_BITM] = 1'b1; w_shiftRight = 1'b1; w_shiftArith = w_func7[5];
            end
            3'b110: begin
              w_class[CLASS_ALU]  = 1'b1; w_selOr = 1'b1; w_sub = w_isOp && w_func7[5];
            end
            default: begin
              w_class[CLASS_ALU]  = 1'b1; w_selAnd = 1'b1; w_sub = w_isOp && w_func7[5];
            end
          endcase
          if (w_isOp)                                         // sub sra andn orn xnor
            w_illegalAlu = !(w_func7 == 7'd0 || (w_func7 == 7'b0100000
              && (w_func3 == 3'b000 || w_func3[2])));
          else if (w_func3 == 3'b001)
            w_illegalAlu = w_func7 != 7'd0;
          else if (w_func3 == 3'b101)
            w_illegalAlu = !(w_func7 == 7'd0 || w_func7 == 7'b0100000);
        end
      end
      OP_MISC_MEM: begin
        w_class[CLASS_SYSTEM]   = 1'b1;
        w_system[SYSTEM_FENCE]  = w_func3 == 3'b000;
        w_system[SYSTEM_FENCEI] = w_func3 == 3'b001;
        w_illegal = w_func3[2:1] != 2'b00;
      end
      OP_SYSTEM: begin
        if (w_func3 == 3'b000) begin
          w_class[CLASS_SYSTEM] = 1'b1;
          case (w_instr[31:7])
            25'h0000000: w_system[SYSTEM_ECALL]  = 1'b1;
            25'h0002000: w_system[SYSTEM_EBREAK] = 1'b1;
            25'h0604000: w_system[SYSTEM_MRET]   = 1'b1;
            25'h020A000: w_system[SYSTEM_WFI]    = 1'b1;
            default:     w_illegalSys = 1'b1;
          endcase
        end else begin
          w_class[CLASS_CSR] = 1'b1; w_immFormat[IMM_CSR] = 1'b1;
          w_illegal = w_func3 == 3'b100;
        end
      end
      default: w_illegal = 1'b1;
    endcase
  end

  // ---- 16-bit path -------------------------------------------------------------
  logic [15:0]        c_instr;
  logic [4:0]         c_rdIndexFull, c_rs2IndexFull;
  logic [2:0]         c_func3;
  logic [CLASS_W-1:0] c_class;
  logic [IMM_W-1:0]   c_immFormat;
  logic               c_sub, c_selArith, c_selAnd, c_selOr, c_selXor;
  logic               c_shiftRight, c_shiftArith, c_zIsImm, c_isEbreak, c_illegal;

  assign c_instr        = d_d1_instr[15:0];
  assign c_rdIndexFull  = c_instr[11:7];
  assign c_rs2IndexFull = c_instr[6:2];

  always_comb begin
    c_class     = '0;
    c_immFormat = '0;
    c_func3     = 3'b010;
    {c_sub, c_selArith, c_selAnd, c_selOr, c_selXor} = '0;
    {c_shiftRight, c_shiftArith, c_zIsImm, c_isEbreak} = '0;
    c_illegal   = 1'b0;

    case ({c_instr[15:13], c_instr[1:0]})
      5'b000_00: begin
        c_class[CLASS_ALU]   = 1'b1; c_immFormat[IMM_C4SPN] = 1'b1;
        c_selArith           = 1'b1; c_zIsImm = 1'b1;
        c_illegal = c_instr[12:5] == 8'd0;
      end
      5'b010_00: begin                    // c.lw
        c_class[CLASS_LOAD]  = 1'b1; c_immFormat[IMM_CLW]   = 1'b1;
      end
      5'b110_00: begin                    // c.sw
        c_class[CLASS_STORE] = 1'b1; c_immFormat[IMM_CLW]   = 1'b1;
      end
      5'b000_01, 5'b010_01: begin         // c.addi, c.li
        c_class[CLASS_ALU]   = 1'b1; c_immFormat[IMM_CI]    = 1'b1;
        c_selArith           = 1'b1; c_zIsImm               = 1'b1;
      end
      5'b001_01, 5'b101_01: begin         // c.jal c.j
        c_class[CLASS_JAL]   = 1'b1;
      end
      5'b011_01: begin                    // c.addi16sp, c.lui
        c_class[CLASS_ALU]   = 1'b1; c_immFormat[IMM_C16SP] = c_rdIndexFull == 5'd2;
        c_selArith           = 1'b1; c_immFormat[IMM_CLUI]  = c_rdIndexFull != 5'd2;
        c_zIsImm             = 1'b1; c_illegal = {c_instr[12], c_instr[6:2]} == 6'd0;
      end
      5'b100_01: begin                    // c.srli .. c.and
        case (c_instr[11:10])
          2'b00, 2'b01: begin             // c.srli, c.srai
            c_class[CLASS_BITM]  = 1'b1; c_immFormat[IMM_CI] = 1'b1;
            c_shiftRight         = 1'b1; c_shiftArith = c_instr[10];
            c_zIsImm             = 1'b1; c_illegal    = c_instr[12];
            c_func3            = 3'b101;
          end
          2'b10: begin                    // c.andi
            c_class[CLASS_ALU]   = 1'b1; c_immFormat[IMM_CI] = 1'b1;
            c_selAnd             = 1'b1; c_zIsImm            = 1'b1;
          end
          default: begin                  // c.sub, c.xor, c.or, c.and
            c_class[CLASS_ALU]   = 1'b1;
            c_illegal = c_instr[12];
            case (c_instr[6:5])
              2'b00:   begin c_selArith = 1'b1; c_sub = 1'b1; end
              2'b01:   begin c_selXor   = 1'b1;               end
              2'b10:   begin c_selOr    = 1'b1;               end
              default: begin c_selAnd   = 1'b1;               end
            endcase
          end
        endcase
      end
      5'b110_01, 5'b111_01: begin         // c.beqz, c.bnez
        c_class[CLASS_BRANCH] = 1'b1; c_func3 = {2'b00, c_instr[13]};
        c_sub                 = 1'b1;
      end
      5'b000_10: begin                    // c.slli
        c_class[CLASS_BITM]   = 1'b1; c_immFormat[IMM_CI]    = 1'b1;
        c_zIsImm              = 1'b1; c_illegal       = c_instr[12];
        c_func3             = 3'b001;
      end
      5'b010_10: begin                    // c.lwsp
        c_class[CLASS_LOAD]   = 1'b1; c_immFormat[IMM_CLWSP] = 1'b1;
        c_illegal = c_rdIndexFull == 5'd0;
      end
      5'b100_10: begin
        if (c_rs2IndexFull != 5'd0) begin // c.mv, c.add
          c_class[CLASS_ALU]    = 1'b1; c_selArith = 1'b1;
        end else if (c_instr[12] && c_rdIndexFull == 5'd0) begin
          c_class[CLASS_SYSTEM] = 1'b1; c_isEbreak = 1'b1;
        end else begin                    // c.jr, c.jalr
          c_class[CLASS_JALR]   = 1'b1; c_selArith = 1'b1;
          c_illegal = c_rdIndexFull == 5'd0;
          c_zIsImm  = 1'b1;
        end
      end
      5'b110_10: begin                    // c.swsp
        c_class[CLASS_STORE]    = 1'b1; c_immFormat[IMM_CSWSP] = 1'b1;
      end
      default: c_illegal = 1'b1;          // FP, reserved
    endcase
  end

  // ---- merge -------------------------------------------------------------------
  logic                 d1_rvc;
  logic [CLASS_W-1:0]   d1_class;
  logic [SYSTEM_W-1:0]  d1_system;
  logic [IMM_W-1:0]     d1_immFormat;
  logic [2:0]           d1_func3;
  logic                 d1_sub, d1_selArith, d1_selAnd, d1_selOr, d1_selXor, d1_selSlt;
  logic                 d1_sltUnsigned, d1_shiftRight, d1_shiftArith;
  logic                 d1_xIsPC, d1_zIsImm;

  assign d1_rvc         = d_d1_rvc;
  assign d1_class       = d1_rvc ? c_class      : w_class;
  assign d1_system      = d1_rvc ? {{(SYSTEM_W-2){1'b0}}, c_isEbreak, 1'b0} : w_system;
  assign d1_immFormat   = d1_rvc ? c_immFormat  : w_immFormat;
  assign d1_func3       = d1_rvc ? c_func3      : w_func3;
  assign d1_sub         = d1_rvc ? c_sub        : w_sub;
  assign d1_selArith    = d1_rvc ? c_selArith   : w_selArith;
  assign d1_selAnd      = d1_rvc ? c_selAnd     : w_selAnd;
  assign d1_selOr       = d1_rvc ? c_selOr      : w_selOr;
  assign d1_selXor      = d1_rvc ? c_selXor     : w_selXor;
  assign d1_selSlt      = d1_rvc ? 1'b0         : w_selSlt;
  assign d1_sltUnsigned = d1_rvc ? 1'b0         : w_sltUnsigned;
  assign d1_shiftRight  = d1_rvc ? c_shiftRight : w_shiftRight;
  assign d1_shiftArith  = d1_rvc ? c_shiftArith : w_shiftArith;
  assign d1_xIsPC       = d1_rvc ? 1'b0         : w_xIsPC;
  assign d1_zIsImm      = d1_rvc ? c_zIsImm     : w_zIsImm;

  // ---- Decode-1/Decode-2 inter-stage pipeline register -------------------------
  logic [31:0]          d1_d2_instr;
  logic [30:0]          d1_d2_pc, d1_d2_branchTarget, d1_d2_seq;
  logic [MW-1:0]        d1_d2_meta;
  logic                 d1_d2_isCall, d1_d2_isRet;
  logic                 d1_d2_rvc;
  logic [CLASS_W-1:0]   d1_d2_class;
  logic [SYSTEM_W-1:0]  d1_d2_system;
  logic [IMM_W-1:0]     d1_d2_immFormat;
  logic [2:0]           d1_d2_func3;
  logic                 d1_d2_sub, d1_d2_selArith, d1_d2_selAnd, d1_d2_selOr, d1_d2_selXor;
  logic                 d1_d2_selSlt, d1_d2_sltUnsigned, d1_d2_shiftRight, d1_d2_shiftArith;
  logic                 d1_d2_xIsPC, d1_d2_xIsZero, d1_d2_zIsImm, d1_d2_zIsZero;
  logic                 d1_d2_illegalW, d1_d2_illegalAlu, d1_d2_illegalSys, d1_d2_illegalC;

  always_ff @(posedge clk) begin
    if (!stall_d1_d2) begin
      d1_d2_instr        <= d_d1_instr;
      d1_d2_pc           <= d_d1_pc;
      d1_d2_meta         <= d_d1_meta;
      d1_d2_isCall       <= d_d1_isCall;
      d1_d2_isRet        <= d_d1_isRet;
      d1_d2_branchTarget <= d_d1_branchTarget;
      d1_d2_seq          <= d_d1_seq;
      d1_d2_rvc          <= d1_rvc;
      d1_d2_class        <= d1_class;
      d1_d2_system       <= d1_system;
      d1_d2_immFormat    <= d1_immFormat;
      d1_d2_func3        <= d1_func3;
      d1_d2_sub          <= d1_sub;
      d1_d2_selArith     <= d1_selArith;
      d1_d2_selAnd       <= d1_selAnd;
      d1_d2_selOr        <= d1_selOr;
      d1_d2_selXor       <= d1_selXor;
      d1_d2_selSlt       <= d1_selSlt;
      d1_d2_sltUnsigned  <= d1_sltUnsigned;
      d1_d2_shiftRight   <= d1_shiftRight;
      d1_d2_shiftArith   <= d1_shiftArith;
      d1_d2_xIsPC        <= d1_xIsPC;
      d1_d2_xIsZero      <= !d_d1_rs1Use && !d1_xIsPC;
      d1_d2_zIsImm       <= d1_zIsImm;
      d1_d2_zIsZero      <= !d_d1_rs2Use && !d1_zIsImm;
      d1_d2_illegalW     <= w_illegal;
      d1_d2_illegalAlu   <= w_illegalAlu;
      d1_d2_illegalSys   <= w_illegalSys;
      d1_d2_illegalC     <= c_illegal;
    end
  end

  // ---- immediate assembly ------------------------------------------------------
  logic [31:0] d2_instr;
  logic [15:0] d2_c;
  logic [31:0] d2_imm [IMM_W];
  logic [31:0] d2_immediate;

  assign d2_instr = d1_d2_instr;
  assign d2_c     = d1_d2_instr[15:0];

  assign d2_imm[IMM_I]     = {{20{d2_instr[31]}}, d2_instr[31:20]};
  assign d2_imm[IMM_S]     = {{20{d2_instr[31]}}, d2_instr[31:25], d2_instr[11:7]};
  assign d2_imm[IMM_U]     = {d2_instr[31:12], 12'd0};
  assign d2_imm[IMM_CSR]   = {15'd0, d2_instr[19:15], d2_instr[31:20]};
  assign d2_imm[IMM_CI]    = {{27{d2_c[12]}}, d2_c[6:2]};
  assign d2_imm[IMM_CLW]   = {25'd0, d2_c[5], d2_c[12:10], d2_c[6], 2'b00};
  assign d2_imm[IMM_CLWSP] = {24'd0, d2_c[3:2], d2_c[12], d2_c[6:4], 2'b00};
  assign d2_imm[IMM_CSWSP] = {24'd0, d2_c[8:7], d2_c[12:9], 2'b00};
  assign d2_imm[IMM_C4SPN] = {22'd0, d2_c[10:7], d2_c[12:11], d2_c[5], d2_c[6], 2'b00};
  assign d2_imm[IMM_C16SP] = {{23{d2_c[12]}}, d2_c[4:3], d2_c[5], d2_c[2], d2_c[6], 4'd0};
  assign d2_imm[IMM_CLUI]  = {{15{d2_c[12]}}, d2_c[6:2], 12'd0};

  always_comb begin
    d2_immediate = '0;
    for (int k = 0; k < IMM_W; k++)
      d2_immediate = d2_immediate | ({32{d1_d2_immFormat[k]}} & d2_imm[k]);
  end

  // ---- illegal gating and derived fields ---------------------------------------
  logic                 d2_illegal;
  logic [CLASS_W-1:0]   d2_class;
  logic [SYSTEM_W-1:0]  d2_system;
  logic [LATENCY_W-1:0] d2_latency;

  assign d2_illegal = d1_d2_rvc ? d1_d2_illegalC
    : (d1_d2_illegalW | d1_d2_illegalAlu | d1_d2_illegalSys);
  assign d2_class   = d1_d2_class  & {CLASS_W {!d2_illegal}};
  assign d2_system  = d1_d2_system & {SYSTEM_W{!d2_illegal}};

  assign d2_latency[LATENCY_1]   = d2_class[CLASS_ALU]  || d2_class[CLASS_JAL]
                                || d2_class[CLASS_JALR] || d2_class[CLASS_CSR];
  assign d2_latency[LATENCY_3]   = d2_class[CLASS_BITM] || d2_class[CLASS_XALU];
  assign d2_latency[LATENCY_4]   = d2_class[CLASS_MUL];
  assign d2_latency[LATENCY_5]   = d2_class[CLASS_LOAD];
  assign d2_latency[LATENCY_DIV] = d2_class[CLASS_DIV];

  // ---- D2 skid: catches D1/D2 while PreDS stalls -------------------------------
  localparam int D2W = 31 + MW + 1 + 1 + 31 + 31 + 1 + CLASS_W + LATENCY_W
                     + 9 + 4 + 2 + 3 + 2 + 3 + SYSTEM_W + 1 + 32 + 1;
  logic [D2W-1:0] d2_next, d2_skid, d2_load;

  assign d2_next = {
    d1_d2_pc,           d1_d2_meta,     d1_d2_isCall, d1_d2_isRet,
    d1_d2_branchTarget, d1_d2_seq,      d1_d2_rvc,    d2_class,    d2_latency,
    d1_d2_sub,          d1_d2_selArith, d1_d2_selAnd, d1_d2_selOr, d1_d2_selXor,
    d1_d2_selSlt,       d1_d2_sltUnsigned, d1_d2_shiftRight, d1_d2_shiftArith,
    d1_d2_xIsPC,        d1_d2_xIsZero,  d1_d2_zIsImm, d1_d2_zIsZero,
    d1_d2_func3[2],     d1_d2_func3[0],
    d1_d2_func3[1]    ^ d1_d2_func3[0], d1_d2_func3[1:0] == 2'b01, d1_d2_func3[1:0] != 2'b00,
    !d1_d2_func3[0],    d1_d2_func3[1],
    d1_d2_func3,        d2_system,      d2_class[CLASS_CSR] || d2_class[CLASS_SYSTEM],
    d2_immediate,       d2_illegal
  };

  always_ff @(posedge clk) if (!rd2_skidValid)
         d2_skid <= d2_next;
  assign d2_load  = rd2_skidValid ? d2_skid : d2_next;

  // ---- Decode-2/Dispatch-1 inter-stage pipeline register -----------------------
  always_ff @(posedge clk) begin
    if (!stall_d2_pds) {
      d2_pds_pc,           d2_pds_meta,     d2_pds_isCall, d2_pds_isRet,
      d2_pds_branchTarget, d2_pds_seq,      d2_pds_rvc,    d2_pds_class, d2_pds_latency,
      d2_pds_sub,          d2_pds_selArith, d2_pds_selAnd, d2_pds_selOr, d2_pds_selXor,
      d2_pds_selSlt,       d2_pds_sltUnsigned, d2_pds_shiftRight, d2_pds_shiftArith,
      d2_pds_xIsPC,        d2_pds_xIsZero,  d2_pds_zIsImm, d2_pds_zIsZero,
      d2_pds_branchUseLt,  d2_pds_branchInvert,
      d2_pds_mulSignedA,   d2_pds_mulSignedB, d2_pds_mulHigh,
      d2_pds_divSigned,    d2_pds_divRemainder,
      d2_pds_func3,        d2_pds_system,   d2_pds_serialising,
      d2_pds_immediate,    d2_pds_illegal
    } <= d2_load;
  end

endmodule

