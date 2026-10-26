// ================================================================================
//  Main Decoder: rest of the decode over R1 and R2, beside rename
// ================================================================================
//  D               RD1           RD2             PreDS
//  predecoder ─┬─► rename R1 ──► rename R2 ──┬─► predisp
//              └─► decoder R1 ─► decoder R2 ─┘
// ================================================================================
//  Everything the predecoder left out: class, latency group, execute controls
//  in the shape their units take, sys op, immediates, illegals.
//
//  Also carries the D fields that rename doesn't need:
//    (pc, meta, branchTarget, seq, call/ret)
//
//  Mechanism:
//    - R1: opcode decodification of both encodings (32-bit and 16-bit) in
//    parallel, merged by rvc, immediate leaves R1 as one-hot format select.
//    - R2: immediate assembly (AND-OR of formats), illegal gating, latency
//    group, serializing, f3-derived controls.
//    - Payload only: no valid/reset. Rename owns valid/flush; each register
//    holds while its stall is high.
//    - Illegal: class + latency + system = 0, uop only traps at the head.
//    - OP and OP-IMM carry instr[31:20] in immediate -> XALU and BITM FUs
//    tell their ops apart by func7 and func3.
// ================================================================================
`include "uop_defs.svh"

module decoder #(
  parameter int MW = 1                      // prediction metadata
) (
  input  logic                 clk,
  // ---- Decode/Rename-1 inter-stage pipeline register ---------------------------
  input  logic [31:0]          d_r1_instr,
  input  logic                 d_r1_rvc,
  input  logic [30:0]          d_r1_pc,
  input  logic [MW-1:0]        d_r1_meta,
  input  logic                 d_r1_rs1Use,
  input  logic                 d_r1_rs2Use,
  input  logic                 d_r1_isCall,
  input  logic                 d_r1_isRet,
  input  logic [30:0]          d_r1_branchTarget,
  input  logic [30:0]          d_r1_seq,
  // ---- inter-stage pipeline register controls ----------------------------------
  input  logic                 stall_r1_r2,
  input  logic                 stall_r2_pds,
  // ---- Rename-2/Dispatch-1 inter-stage pipeline register -----------------------
  output logic [30:0]          r2_pds_pc,
  output logic [MW-1:0]        r2_pds_meta,
  output logic                 r2_pds_isCall,
  output logic                 r2_pds_isRet,
  output logic [30:0]          r2_pds_branchTarget,
  output logic [30:0]          r2_pds_seq,
  output logic                 r2_pds_rvc,
  output logic [CLASS_W-1:0]   r2_pds_class,
  output logic [LATENCY_W-1:0] r2_pds_latency,
  output logic                 r2_pds_sub,
  output logic                 r2_pds_selArith,
  output logic                 r2_pds_selAnd,
  output logic                 r2_pds_selOr,
  output logic                 r2_pds_selXor,
  output logic                 r2_pds_selSlt,
  output logic                 r2_pds_sltUnsigned,  // sltu, sltiu, bltu, bgeu
  output logic                 r2_pds_shiftRight,
  output logic                 r2_pds_shiftArith,
  output logic                 r2_pds_xIsPC,
  output logic                 r2_pds_xIsZero,
  output logic                 r2_pds_zIsImm,
  output logic                 r2_pds_zIsZero,
  output logic                 r2_pds_branchUseLt,  // lt, else eq
  output logic                 r2_pds_branchInvert,
  output logic                 r2_pds_mulSignedA,
  output logic                 r2_pds_mulSignedB,
  output logic                 r2_pds_mulHigh,
  output logic                 r2_pds_divSigned,
  output logic                 r2_pds_divRemainder,
  output logic [2:0]           r2_pds_func3,
  output logic [SYSTEM_W-1:0]  r2_pds_system,
  output logic                 r2_pds_serialising,  // csr/system wait for the head
  output logic [31:0]          r2_pds_immediate,    // csr: {zimm, addr} in [16:0]
  output logic                 r2_pds_illegal
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
  logic                 w_illegal;

  assign w_instr    = d_r1_instr;
  assign w_op       = w_instr[6:2];
  assign w_func3    = w_instr[14:12];
  assign w_func7    = w_instr[31:25];
  assign w_rs2Field = w_instr[24:20];
  assign w_isOp     = w_op == OP_OP;

  always_comb begin
    w_class     = '0;
    w_system    = '0;
    w_immFormat = '0;
    {w_sub, w_selArith, w_selAnd, w_selOr, w_selXor, w_selSlt} = '0;
    {w_sltUnsigned, w_shiftRight, w_shiftArith, w_xIsPC, w_zIsImm} = '0;
    w_illegal   = 1'b0;

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
          w_illegal = w_func3[0] || w_func3[2:1] == 2'b00;
        end else if (w_isOp && w_func7 == 7'b0000101) begin   // min/max
          w_class[CLASS_XALU] = 1'b1; w_sub = 1'b1; w_sltUnsigned = w_func3[0];
          w_illegal = !w_func3[2];
        end else if (w_isOp && w_func7 == 7'b0000111) begin   // czero
          w_class[CLASS_XALU] = 1'b1;
          w_illegal = !(w_func3[2] && w_func3[0]);
        end else if ((w_isOp && w_func7 == 7'b0000100) || ((w_isOp || w_func3[1:0] == 2'b01)
                 && (w_func7 == 7'b0110000 || w_func7 == 7'b0100100
                 ||  w_func7 == 7'b0110100 || w_func7 == 7'b0010100)
        )) begin                                              // zext.h
          w_class[CLASS_BITM] = 1'b1; w_shiftRight = w_func3 == 3'b101;
          case (w_func7)
            7'b0110000: w_illegal = w_func3[1:0] != 2'b01     // rol ror clz ctz cpop sext
              || (!w_isOp && !w_func3[2]  && (w_rs2Field[4:3] != 2'b00
              || w_rs2Field[1:0] == 2'b11 ||  w_rs2Field[2:1] == 2'b11));
            7'b0100100: w_illegal = w_func3[1:0] != 2'b01;    // bclr bext
            7'b0110100: w_illegal = w_func3[1:0] != 2'b01     // binv rev8
              || (w_func3[2] && (w_isOp || w_rs2Field != 5'b11000));
            7'b0010100: w_illegal = w_func3[1:0] != 2'b01     // bset orc.b
              || (w_func3[2] && (w_isOp || w_rs2Field != 5'b00111));
            default:    w_illegal = w_func3 != 3'b100 || w_rs2Field != 5'd0;
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
              w_class[CLASS_ALU] = 1'b1; w_selXor = 1'b1; w_sub = w_isOp && w_func7[5];
            end
            3'b101: begin
              w_class[CLASS_BITM] = 1'b1; w_shiftRight = 1'b1; w_shiftArith = w_func7[5];
            end
            3'b110: begin
              w_class[CLASS_ALU] = 1'b1; w_selOr = 1'b1; w_sub = w_isOp && w_func7[5];
            end
            default: begin
              w_class[CLASS_ALU] = 1'b1; w_selAnd = 1'b1; w_sub = w_isOp && w_func7[5];
            end
          endcase
          if (w_isOp)                                         // sub sra andn orn xnor
            w_illegal = !(w_func7 == 7'd0 || (w_func7 == 7'b0100000
              && (w_func3 == 3'b000 || w_func3[2])));
          else if (w_func3 == 3'b001)
            w_illegal = w_func7 != 7'd0;
          else if (w_func3 == 3'b101)
            w_illegal = !(w_func7 == 7'd0 || w_func7 == 7'b0100000);
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
            default:     w_illegal = 1'b1;
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

  assign c_instr        = d_r1_instr[15:0];
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
        c_zIsImm              = 1'b1; c_illegal = c_instr[12];
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
  logic                 r1_rvc;
  logic [CLASS_W-1:0]   r1_class;
  logic [SYSTEM_W-1:0]  r1_system;
  logic [IMM_W-1:0]     r1_immFormat;
  logic [2:0]           r1_func3;
  logic                 r1_sub, r1_selArith, r1_selAnd, r1_selOr, r1_selXor, r1_selSlt;
  logic                 r1_sltUnsigned, r1_shiftRight, r1_shiftArith;
  logic                 r1_xIsPC, r1_zIsImm, r1_illegal;

  assign r1_rvc         = d_r1_rvc;
  assign r1_class       = r1_rvc ? c_class      : w_class;
  assign r1_system      = r1_rvc ? {{(SYSTEM_W-2){1'b0}}, c_isEbreak, 1'b0} : w_system;
  assign r1_immFormat   = r1_rvc ? c_immFormat  : w_immFormat;
  assign r1_func3       = r1_rvc ? c_func3      : w_func3;
  assign r1_sub         = r1_rvc ? c_sub        : w_sub;
  assign r1_selArith    = r1_rvc ? c_selArith   : w_selArith;
  assign r1_selAnd      = r1_rvc ? c_selAnd     : w_selAnd;
  assign r1_selOr       = r1_rvc ? c_selOr      : w_selOr;
  assign r1_selXor      = r1_rvc ? c_selXor     : w_selXor;
  assign r1_selSlt      = r1_rvc ? 1'b0         : w_selSlt;
  assign r1_sltUnsigned = r1_rvc ? 1'b0         : w_sltUnsigned;
  assign r1_shiftRight  = r1_rvc ? c_shiftRight : w_shiftRight;
  assign r1_shiftArith  = r1_rvc ? c_shiftArith : w_shiftArith;
  assign r1_xIsPC       = r1_rvc ? 1'b0         : w_xIsPC;
  assign r1_zIsImm      = r1_rvc ? c_zIsImm     : w_zIsImm;
  assign r1_illegal     = r1_rvc ? c_illegal    : w_illegal;

  // ---- Rename-1/Rename-2 inter-stage pipeline register -------------------------
  logic [31:0]          r1_r2_instr;
  logic [30:0]          r1_r2_pc, r1_r2_branchTarget, r1_r2_seq;
  logic [MW-1:0]        r1_r2_meta;
  logic                 r1_r2_isCall, r1_r2_isRet;
  logic                 r1_r2_rvc;
  logic [CLASS_W-1:0]   r1_r2_class;
  logic [SYSTEM_W-1:0]  r1_r2_system;
  logic [IMM_W-1:0]     r1_r2_immFormat;
  logic [2:0]           r1_r2_func3;
  logic                 r1_r2_sub, r1_r2_selArith, r1_r2_selAnd, r1_r2_selOr, r1_r2_selXor;
  logic                 r1_r2_selSlt, r1_r2_sltUnsigned, r1_r2_shiftRight, r1_r2_shiftArith;
  logic                 r1_r2_xIsPC, r1_r2_xIsZero, r1_r2_zIsImm, r1_r2_zIsZero;
  logic                 r1_r2_illegal;

  always_ff @(posedge clk) begin
    if (!stall_r1_r2) begin
      r1_r2_instr        <= d_r1_instr;
      r1_r2_pc           <= d_r1_pc;
      r1_r2_meta         <= d_r1_meta;
      r1_r2_isCall       <= d_r1_isCall;
      r1_r2_isRet        <= d_r1_isRet;
      r1_r2_branchTarget <= d_r1_branchTarget;
      r1_r2_seq          <= d_r1_seq;
      r1_r2_rvc          <= r1_rvc;
      r1_r2_class        <= r1_class;
      r1_r2_system       <= r1_system;
      r1_r2_immFormat    <= r1_immFormat;
      r1_r2_func3        <= r1_func3;
      r1_r2_sub          <= r1_sub;
      r1_r2_selArith     <= r1_selArith;
      r1_r2_selAnd       <= r1_selAnd;
      r1_r2_selOr        <= r1_selOr;
      r1_r2_selXor       <= r1_selXor;
      r1_r2_selSlt       <= r1_selSlt;
      r1_r2_sltUnsigned  <= r1_sltUnsigned;
      r1_r2_shiftRight   <= r1_shiftRight;
      r1_r2_shiftArith   <= r1_shiftArith;
      r1_r2_xIsPC        <= r1_xIsPC;
      r1_r2_xIsZero      <= !d_r1_rs1Use && !r1_xIsPC;
      r1_r2_zIsImm       <= r1_zIsImm;
      r1_r2_zIsZero      <= !d_r1_rs2Use && !r1_zIsImm;
      r1_r2_illegal      <= r1_illegal;
    end
  end

  // ---- immediate assembly ------------------------------------------------------
  logic [31:0] r2_instr;
  logic [15:0] r2_c;
  logic [31:0] r2_imm [IMM_W];
  logic [31:0] r2_immediate;

  assign r2_instr = r1_r2_instr;
  assign r2_c     = r1_r2_instr[15:0];

  assign r2_imm[IMM_I]     = {{20{r2_instr[31]}}, r2_instr[31:20]};
  assign r2_imm[IMM_S]     = {{20{r2_instr[31]}}, r2_instr[31:25], r2_instr[11:7]};
  assign r2_imm[IMM_U]     = {r2_instr[31:12], 12'd0};
  assign r2_imm[IMM_CSR]   = {15'd0, r2_instr[19:15], r2_instr[31:20]};
  assign r2_imm[IMM_CI]    = {{27{r2_c[12]}}, r2_c[6:2]};
  assign r2_imm[IMM_CLW]   = {25'd0, r2_c[5], r2_c[12:10], r2_c[6], 2'b00};
  assign r2_imm[IMM_CLWSP] = {24'd0, r2_c[3:2], r2_c[12], r2_c[6:4], 2'b00};
  assign r2_imm[IMM_CSWSP] = {24'd0, r2_c[8:7], r2_c[12:9], 2'b00};
  assign r2_imm[IMM_C4SPN] = {22'd0, r2_c[10:7], r2_c[12:11], r2_c[5], r2_c[6], 2'b00};
  assign r2_imm[IMM_C16SP] = {{23{r2_c[12]}}, r2_c[4:3], r2_c[5], r2_c[2], r2_c[6], 4'd0};
  assign r2_imm[IMM_CLUI]  = {{15{r2_c[12]}}, r2_c[6:2], 12'd0};

  always_comb begin
    r2_immediate = '0;
    for (int k = 0; k < IMM_W; k++)
      r2_immediate = r2_immediate | ({32{r1_r2_immFormat[k]}} & r2_imm[k]);
  end

  // ---- illegal gating and derived fields ---------------------------------------
  logic [CLASS_W-1:0]   r2_class;
  logic [SYSTEM_W-1:0]  r2_system;
  logic [LATENCY_W-1:0] r2_latency;

  assign r2_class  = r1_r2_class  & {CLASS_W{!r1_r2_illegal}};
  assign r2_system = r1_r2_system & {SYSTEM_W{!r1_r2_illegal}};

  assign r2_latency[LATENCY_1]   = r2_class[CLASS_ALU]  || r2_class[CLASS_JAL]
                                || r2_class[CLASS_JALR] || r2_class[CLASS_CSR];
  assign r2_latency[LATENCY_3]   = r2_class[CLASS_BITM] || r2_class[CLASS_XALU];
  assign r2_latency[LATENCY_4]   = r2_class[CLASS_MUL];
  assign r2_latency[LATENCY_5]   = r2_class[CLASS_LOAD];
  assign r2_latency[LATENCY_DIV] = r2_class[CLASS_DIV];

  // ---- Rename-2/Dispatch-1 inter-stage pipeline register -----------------------
  always_ff @(posedge clk) begin
    if (!stall_r2_pds) begin
      r2_pds_pc           <= r1_r2_pc;
      r2_pds_meta         <= r1_r2_meta;
      r2_pds_isCall       <= r1_r2_isCall;
      r2_pds_isRet        <= r1_r2_isRet;
      r2_pds_branchTarget <= r1_r2_branchTarget;
      r2_pds_seq          <= r1_r2_seq;
      r2_pds_rvc          <= r1_r2_rvc;
      r2_pds_class        <= r2_class;
      r2_pds_latency      <= r2_latency;
      r2_pds_sub          <= r1_r2_sub;
      r2_pds_selArith     <= r1_r2_selArith;
      r2_pds_selAnd       <= r1_r2_selAnd;
      r2_pds_selOr        <= r1_r2_selOr;
      r2_pds_selXor       <= r1_r2_selXor;
      r2_pds_selSlt       <= r1_r2_selSlt;
      r2_pds_sltUnsigned  <= r1_r2_sltUnsigned;
      r2_pds_shiftRight   <= r1_r2_shiftRight;
      r2_pds_shiftArith   <= r1_r2_shiftArith;
      r2_pds_xIsPC        <= r1_r2_xIsPC;
      r2_pds_xIsZero      <= r1_r2_xIsZero;
      r2_pds_zIsImm       <= r1_r2_zIsImm;
      r2_pds_zIsZero      <= r1_r2_zIsZero;
      r2_pds_branchUseLt  <= r1_r2_func3[2];
      r2_pds_branchInvert <= r1_r2_func3[0];
      r2_pds_mulSignedA   <= r1_r2_func3[1] ^ r1_r2_func3[0]; // mulh, mulhsu
      r2_pds_mulSignedB   <= r1_r2_func3[1:0] == 2'b01;       // mulh
      r2_pds_mulHigh      <= r1_r2_func3[1:0] != 2'b00;
      r2_pds_divSigned    <= !r1_r2_func3[0];
      r2_pds_divRemainder <= r1_r2_func3[1];
      r2_pds_func3        <= r1_r2_func3;
      r2_pds_system       <= r2_system;
      r2_pds_serialising  <= r2_class[CLASS_CSR] || r2_class[CLASS_SYSTEM];
      r2_pds_immediate    <= r2_immediate;
      r2_pds_illegal      <= r1_r2_illegal;
    end
  end

endmodule

