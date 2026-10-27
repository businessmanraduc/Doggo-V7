// ================================================================================
//  decoder_tb -- decoder against an independent reference
// ================================================================================
//  Reference: every 16-bit encoding is expanded to its 32-bit form (spec
//  tables), then the 32-bit form is decoded by opcode, funct3 and funct7 into
//  the expected uop. Both registers (D1/D2, D2/PreDS) are modelled cycle by
//  cycle with their own stall. rs1Use/rs2Use are driven as the decoder makes
//  them (x0 folded). Phase 1: all 49152 16-bit encodings. Phase 2: 32-bit
//  vectors, opcodes and funct7 biased. Phase 3: mixed stream under random
//  stalls. Illegal: only class, latency, system, serialising and illegal are
//  checked. Zba/Zbb/Zbs/Zicond come from a mask/match table; every entry
//  must be hit.
// ================================================================================

`include "uop_defs.svh"

module decoder_tb;

  localparam int MW = 4;

  logic                 clk = 1'b0;
  logic [31:0]          d_d1_instr = 32'h0000_0013;   // nop: 32-bit words end in 11
  logic                 d_d1_rvc = 1'b0;
  logic [30:0]          d_d1_pc = '0;
  logic [MW-1:0]        d_d1_meta = '0;
  logic                 d_d1_rs1Use = 1'b0;
  logic                 d_d1_rs2Use = 1'b0;
  logic                 d_d1_isCall = 1'b0;
  logic                 d_d1_isRet = 1'b0;
  logic [30:0]          d_d1_branchTarget = '0;
  logic [30:0]          d_d1_seq = '0;
  logic                 stall_d1_d2 = 1'b0;
  logic                 stall_d2_pds = 1'b0;
  logic [30:0]          d2_pds_pc, d2_pds_branchTarget, d2_pds_seq;
  logic [MW-1:0]        d2_pds_meta;
  logic                 d2_pds_isCall, d2_pds_isRet, d2_pds_rvc;
  logic [CLASS_W-1:0]   d2_pds_class;
  logic [LATENCY_W-1:0] d2_pds_latency;
  logic                 d2_pds_sub, d2_pds_selArith, d2_pds_selAnd, d2_pds_selOr, d2_pds_selXor;
  logic                 d2_pds_selSlt, d2_pds_sltUnsigned, d2_pds_shiftRight, d2_pds_shiftArith;
  logic                 d2_pds_xIsPC, d2_pds_xIsZero, d2_pds_zIsImm, d2_pds_zIsZero;
  logic                 d2_pds_branchUseLt, d2_pds_branchInvert;
  logic                 d2_pds_mulSignedA, d2_pds_mulSignedB, d2_pds_mulHigh;
  logic                 d2_pds_divSigned, d2_pds_divRemainder;
  logic [2:0]           d2_pds_func3;
  logic [SYSTEM_W-1:0]  d2_pds_system;
  logic                 d2_pds_serialising;
  logic [31:0]          d2_pds_immediate;
  logic                 d2_pds_illegal;

  decoder #(.MW(MW)) u_dut (.*);

  always #5 clk = ~clk;

  // ---- reference ---------------------------------------------------------------
  typedef struct {
    bit                  legal, rs1Use, rs2Use;
    logic [CLASS_W-1:0]  cls;
    logic [SYSTEM_W-1:0] sys;
    bit                  sub, arith, andOp, orOp, xorOp, slt, sltU, shR, shA, xPc, zImm;
    logic [2:0]          f3;
    logic [31:0]         imm;
  } ref_t;

  function automatic logic [31:0] encI(logic [11:0] imm, logic [4:0] rs1, logic [2:0] f3,
                                       logic [4:0] rd, logic [6:0] op);
    return {imm, rs1, f3, rd, op};
  endfunction

  function automatic logic [31:0] encR(logic [6:0] f7, logic [4:0] rs2, logic [4:0] rs1,
                                       logic [2:0] f3, logic [4:0] rd, logic [6:0] op);
    return {f7, rs2, rs1, f3, rd, op};
  endfunction

  function automatic logic [31:0] encS(logic [11:0] imm, logic [4:0] rs2, logic [4:0] rs1,
                                       logic [2:0] f3);
    return {imm[11:5], rs2, rs1, f3, imm[4:0], 7'b0100011};
  endfunction

  function automatic logic [31:0] encB(logic [12:0] imm, logic [4:0] rs2, logic [4:0] rs1,
                                       logic [2:0] f3);
    return {imm[12], imm[10:5], rs2, rs1, f3, imm[4:1], imm[11], 7'b1100011};
  endfunction

  function automatic logic [31:0] encJ(logic [20:0] imm, logic [4:0] rd);
    return {imm[20], imm[10:1], imm[11], imm[19:12], rd, 7'b1101111};
  endfunction

  // RV32C expansion; returns {legal, instruction}
  function automatic logic [32:0] expand(logic [15:0] c);
    logic [4:0]  rdF, rs2F, rdP, rs2P;
    logic [11:0] imm6, u;
    logic [20:0] jo;
    logic [12:0] bo;
    logic [5:0]  sh;
    rdF  = c[11:7];
    rs2F = c[6:2];
    rdP  = {2'b01, c[9:7]};
    rs2P = {2'b01, c[4:2]};
    imm6 = {{6{c[12]}}, c[12], c[6:2]};
    sh   = {c[12], c[6:2]};
    jo = '0;
    jo[11] = c[12]; jo[4] = c[11]; jo[9:8] = c[10:9]; jo[10] = c[8];
    jo[6] = c[7]; jo[7] = c[6]; jo[3:1] = c[5:3]; jo[5] = c[2];
    jo[20:12] = {9{c[12]}};
    bo = '0;
    bo[8] = c[12]; bo[4:3] = c[11:10]; bo[7:6] = c[6:5]; bo[2:1] = c[4:3]; bo[5] = c[2];
    bo[12:9] = {4{c[12]}};
    u = '0;
    case ({c[15:13], c[1:0]})
      5'b000_00: begin
        u[5:4] = c[12:11]; u[9:6] = c[10:7]; u[2] = c[6]; u[3] = c[5];
        return {u != 0, encI(u, 5'd2, 3'b000, rs2P, 7'b0010011)};
      end
      5'b010_00: begin
        u[5:3] = c[12:10]; u[2] = c[6]; u[6] = c[5];
        return {1'b1, encI(u, rdP, 3'b010, rs2P, 7'b0000011)};
      end
      5'b110_00: begin
        u[5:3] = c[12:10]; u[2] = c[6]; u[6] = c[5];
        return {1'b1, encS(u, rs2P, rdP, 3'b010)};
      end
      5'b000_01: return {1'b1, encI(imm6, rdF, 3'b000, rdF, 7'b0010011)};
      5'b001_01: return {1'b1, encJ(jo, 5'd1)};
      5'b010_01: return {1'b1, encI(imm6, 5'd0, 3'b000, rdF, 7'b0010011)};
      5'b011_01: begin
        if (rdF == 5'd2) begin
          u[9] = c[12]; u[4] = c[6]; u[6] = c[5]; u[8:7] = c[4:3]; u[5] = c[2];
          u[11:10] = {2{c[12]}};
          return {sh != 0, encI(u, 5'd2, 3'b000, 5'd2, 7'b0010011)};
        end
        return {sh != 0, {{14{c[12]}}, c[12], c[6:2], rdF, 7'b0110111}};
      end
      5'b100_01: begin
        case (c[11:10])
          2'b00: return {!c[12], encR(7'b0000000, sh[4:0], rdP, 3'b101, rdP, 7'b0010011)};
          2'b01: return {!c[12], encR(7'b0100000, sh[4:0], rdP, 3'b101, rdP, 7'b0010011)};
          2'b10: return {1'b1, encI(imm6, rdP, 3'b111, rdP, 7'b0010011)};
          default: begin
            case (c[6:5])
              2'b00: return {!c[12], encR(7'b0100000, rs2P, rdP, 3'b000, rdP, 7'b0110011)};
              2'b01: return {!c[12], encR(7'b0000000, rs2P, rdP, 3'b100, rdP, 7'b0110011)};
              2'b10: return {!c[12], encR(7'b0000000, rs2P, rdP, 3'b110, rdP, 7'b0110011)};
              default: return {!c[12], encR(7'b0000000, rs2P, rdP, 3'b111, rdP, 7'b0110011)};
            endcase
          end
        endcase
      end
      5'b101_01: return {1'b1, encJ(jo, 5'd0)};
      5'b110_01: return {1'b1, encB(bo, 5'd0, rdP, 3'b000)};
      5'b111_01: return {1'b1, encB(bo, 5'd0, rdP, 3'b001)};
      5'b000_10: return {!c[12], encR(7'b0000000, sh[4:0], rdF, 3'b001, rdF, 7'b0010011)};
      5'b010_10: begin
        u[5] = c[12]; u[4:2] = c[6:4]; u[7:6] = c[3:2];
        return {rdF != 0, encI(u, 5'd2, 3'b010, rdF, 7'b0000011)};
      end
      5'b100_10: begin
        if (!c[12]) begin
          if (rs2F == 0) return {rdF != 0, encI(12'd0, rdF, 3'b000, 5'd0, 7'b1100111)};
          return {1'b1, encR(7'b0000000, rs2F, 5'd0, 3'b000, rdF, 7'b0110011)};
        end
        if (rs2F == 0 && rdF == 0) return {1'b1, 32'h0010_0073};
        if (rs2F == 0) return {1'b1, encI(12'd0, rdF, 3'b000, 5'd1, 7'b1100111)};
        return {1'b1, encR(7'b0000000, rs2F, rdF, 3'b000, rdF, 7'b0110011)};
      end
      5'b110_10: begin
        u[5:2] = c[12:9]; u[7:6] = c[8:7];
        return {1'b1, encS(u, rs2F, 5'd2, 3'b010)};
      end
      default: return {1'b0, 32'd0};
    endcase
  endfunction

  // ---- Zba Zbb Zbs Zicond: mask/match from the spec encoding tables ------------
  localparam int K_ALUN = 0, K_SHADD = 1, K_MINMAX = 2, K_CZERO = 3, K_SHIFT = 4;
  localparam logic [31:0] M_R = 32'hFE00707F, M_U = 32'hFFF0707F;
  localparam int NB = 36;
  typedef struct { string name; logic [31:0] mask, match; int kind; } bop_t;

`define MT(f7, rs2, f3, op) {f7, rs2, 5'd0, f3, 5'd0, op}

  localparam logic [6:0] RR = 7'b0110011, RI = 7'b0010011;
  bop_t BOPS [NB] = '{
    '{"sh1add",    M_R, `MT(7'b0010000, 5'd0, 3'b010, RR), K_SHADD},
    '{"sh2add",    M_R, `MT(7'b0010000, 5'd0, 3'b100, RR), K_SHADD},
    '{"sh3add",    M_R, `MT(7'b0010000, 5'd0, 3'b110, RR), K_SHADD},
    '{"andn",      M_R, `MT(7'b0100000, 5'd0, 3'b111, RR), K_ALUN},
    '{"orn",       M_R, `MT(7'b0100000, 5'd0, 3'b110, RR), K_ALUN},
    '{"xnor",      M_R, `MT(7'b0100000, 5'd0, 3'b100, RR), K_ALUN},
    '{"clz",       M_U, `MT(7'b0110000, 5'd0, 3'b001, RI), K_SHIFT},
    '{"ctz",       M_U, `MT(7'b0110000, 5'd1, 3'b001, RI), K_SHIFT},
    '{"cpop",      M_U, `MT(7'b0110000, 5'd2, 3'b001, RI), K_SHIFT},
    '{"sext.b",    M_U, `MT(7'b0110000, 5'd4, 3'b001, RI), K_SHIFT},
    '{"sext.h",    M_U, `MT(7'b0110000, 5'd5, 3'b001, RI), K_SHIFT},
    '{"zext.h",    M_U, `MT(7'b0000100, 5'd0, 3'b100, RR), K_SHIFT},
    '{"min",       M_R, `MT(7'b0000101, 5'd0, 3'b100, RR), K_MINMAX},
    '{"minu",      M_R, `MT(7'b0000101, 5'd0, 3'b101, RR), K_MINMAX},
    '{"max",       M_R, `MT(7'b0000101, 5'd0, 3'b110, RR), K_MINMAX},
    '{"maxu",      M_R, `MT(7'b0000101, 5'd0, 3'b111, RR), K_MINMAX},
    '{"rol",       M_R, `MT(7'b0110000, 5'd0, 3'b001, RR), K_SHIFT},
    '{"ror",       M_R, `MT(7'b0110000, 5'd0, 3'b101, RR), K_SHIFT},
    '{"rori",      M_R, `MT(7'b0110000, 5'd0, 3'b101, RI), K_SHIFT},
    '{"rev8",      M_U, `MT(7'b0110100, 5'b11000, 3'b101, RI), K_SHIFT},
    '{"orc.b",     M_U, `MT(7'b0010100, 5'b00111, 3'b101, RI), K_SHIFT},
    '{"bclr",      M_R, `MT(7'b0100100, 5'd0, 3'b001, RR), K_SHIFT},
    '{"bclri",     M_R, `MT(7'b0100100, 5'd0, 3'b001, RI), K_SHIFT},
    '{"bext",      M_R, `MT(7'b0100100, 5'd0, 3'b101, RR), K_SHIFT},
    '{"bexti",     M_R, `MT(7'b0100100, 5'd0, 3'b101, RI), K_SHIFT},
    '{"binv",      M_R, `MT(7'b0110100, 5'd0, 3'b001, RR), K_SHIFT},
    '{"binvi",     M_R, `MT(7'b0110100, 5'd0, 3'b001, RI), K_SHIFT},
    '{"bset",      M_R, `MT(7'b0010100, 5'd0, 3'b001, RR), K_SHIFT},
    '{"bseti",     M_R, `MT(7'b0010100, 5'd0, 3'b001, RI), K_SHIFT},
    '{"czero.eqz", M_R, `MT(7'b0000111, 5'd0, 3'b101, RR), K_CZERO},
    '{"czero.nez", M_R, `MT(7'b0000111, 5'd0, 3'b111, RR), K_CZERO},
    // base neighbours, so near misses are also counted
    '{"sub",       M_R, `MT(7'b0100000, 5'd0, 3'b000, RR), -1},
    '{"sra",       M_R, `MT(7'b0100000, 5'd0, 3'b101, RR), -1},
    '{"srai",      M_R, `MT(7'b0100000, 5'd0, 3'b101, RI), -1},
    '{"slli",      M_R, `MT(7'b0000000, 5'd0, 3'b001, RI), -1},
    '{"srli",      M_R, `MT(7'b0000000, 5'd0, 3'b101, RI), -1}
  };
  int nB [NB];

  function automatic int bopOf(logic [31:0] i);
    for (int k = 0; k < NB; k++) if ((i & BOPS[k].mask) == BOPS[k].match) return k;
    return -1;
  endfunction

  // decode of a 32-bit instruction into the expected uop
  function automatic ref_t decode(logic [31:0] i);
    ref_t        r;
    logic [2:0]  f3;
    logic [6:0]  f7;
    logic [31:0] iI, iS, iU;
    bit          r1, r2;
    int          b;
    r  = '{default: '0};
    r.legal = 1'b1;
    f3 = i[14:12];
    f7 = i[31:25];
    r.f3 = f3;
    iI = {{20{i[31]}}, i[31:20]};
    iS = {{20{i[31]}}, i[31:25], i[11:7]};
    iU = {i[31:12], 12'd0};
    {r1, r2} = 2'b00;
    case (i[6:0])
      7'b0110111: begin r.cls[CLASS_ALU] = 1; r.arith = 1; r.zImm = 1; r.imm = iU; end
      7'b0010111: begin
        r.cls[CLASS_ALU] = 1; r.arith = 1; r.zImm = 1; r.xPc = 1; r.imm = iU;
      end
      7'b1101111: r.cls[CLASS_JAL] = 1;
      7'b1100111: begin
        r.cls[CLASS_JALR] = 1; r.arith = 1; r.zImm = 1; r.imm = iI; r1 = 1;
        r.legal = f3 == 3'b000;
      end
      7'b1100011: begin
        r.cls[CLASS_BRANCH] = 1; r.sub = 1; r.sltU = f3[1]; r1 = 1; r2 = 1;
        r.legal = f3 != 3'b010 && f3 != 3'b011;
      end
      7'b0000011: begin
        r.cls[CLASS_LOAD] = 1; r.imm = iI; r1 = 1;
        r.legal = f3 inside {3'b000, 3'b001, 3'b010, 3'b100, 3'b101};
      end
      7'b0100011: begin
        r.cls[CLASS_STORE] = 1; r.imm = iS; r1 = 1; r2 = 1;
        r.legal = f3 inside {3'b000, 3'b001, 3'b010};
      end
      7'b0010011, 7'b0110011: begin
        r1 = 1;
        r2 = i[5];
        r.zImm = !i[5];
        r.imm  = iI;
        b = bopOf(i);
        if (b >= 0 && BOPS[b].kind >= 0) begin
          case (BOPS[b].kind)
            K_ALUN: begin
              r.cls[CLASS_ALU] = 1; r.sub = 1;
              r.andOp = f3 == 3'b111; r.orOp = f3 == 3'b110; r.xorOp = f3 == 3'b100;
            end
            K_SHADD, K_CZERO: r.cls[CLASS_XALU] = 1;
            K_MINMAX: begin r.cls[CLASS_XALU] = 1; r.sub = 1; r.sltU = f3[0]; end
            default:  begin r.cls[CLASS_BITM] = 1; r.shR = f3 == 3'b101; end
          endcase
        end else if (i[5] && f7 == 7'b0000001) begin
          if (f3[2]) r.cls[CLASS_DIV] = 1;
          else       r.cls[CLASS_MUL] = 1;
        end else begin
          case (f3)
            3'b000: begin r.cls[CLASS_ALU] = 1; r.arith = 1; end
            3'b001: r.cls[CLASS_BITM] = 1;
            3'b010: begin r.cls[CLASS_XALU] = 1; r.sub = 1; r.slt = 1; end
            3'b011: begin r.cls[CLASS_XALU] = 1; r.sub = 1; r.slt = 1; r.sltU = 1; end
            3'b100: begin r.cls[CLASS_ALU] = 1; r.xorOp = 1; end
            3'b101: begin r.cls[CLASS_BITM] = 1; r.shR = 1; r.shA = f7[5]; end
            3'b110: begin r.cls[CLASS_ALU] = 1; r.orOp = 1; end
            default: begin r.cls[CLASS_ALU] = 1; r.andOp = 1; end
          endcase
          if (i[5]) begin
            if (f7 == 7'b0100000 && f3 == 3'b000) r.sub = 1;
            else if (!(f7 == 7'b0000000 || (f7 == 7'b0100000 && f3 == 3'b101))) r.legal = 0;
          end else if (f3 == 3'b001) r.legal = f7 == 7'b0000000;
          else if (f3 == 3'b101) r.legal = f7 == 7'b0000000 || f7 == 7'b0100000;
        end
      end
      7'b0001111: begin
        r.cls[CLASS_SYSTEM] = 1;
        r.sys[SYSTEM_FENCE]  = f3 == 3'b000;
        r.sys[SYSTEM_FENCEI] = f3 == 3'b001;
        r.legal = f3 == 3'b000 || f3 == 3'b001;
      end
      7'b1110011: begin
        if (f3 == 3'b000) begin
          r.cls[CLASS_SYSTEM] = 1;
          case (i)
            32'h0000_0073: r.sys[SYSTEM_ECALL]  = 1;
            32'h0010_0073: r.sys[SYSTEM_EBREAK] = 1;
            32'h3020_0073: r.sys[SYSTEM_MRET]   = 1;
            32'h1050_0073: r.sys[SYSTEM_WFI]    = 1;
            default:       r.legal = 0;
          endcase
        end else begin
          r.cls[CLASS_CSR] = 1; r.imm = {15'd0, i[19:15], i[31:20]}; r1 = !f3[2];
          r.legal = f3 != 3'b100;
        end
      end
      default: r.legal = 0;
    endcase
    r.rs1Use = r1 && i[19:15] != 5'd0;
    r.rs2Use = r2 && i[24:20] != 5'd0;
    return r;
  endfunction

  function automatic ref_t reference(logic [31:0] ins, logic rvc);
    logic [32:0] e;
    ref_t        r;
    if (!rvc) return decode(ins);
    e = expand(ins[15:0]);
    r = decode(e[31:0]);
    r.legal = r.legal && e[32];
    if (e[6:0] == 7'b0110011) r.imm = '0;     // 16-bit R-type: ALU only, no funct7
    return r;
  endfunction

  function automatic logic [LATENCY_W-1:0] latencyOf(logic [CLASS_W-1:0] c);
    logic [LATENCY_W-1:0] l;
    l = '0;
    l[LATENCY_1]   = c[CLASS_ALU] || c[CLASS_JAL] || c[CLASS_JALR] || c[CLASS_CSR];
    l[LATENCY_3]   = c[CLASS_BITM] || c[CLASS_XALU];
    l[LATENCY_4]   = c[CLASS_MUL];
    l[LATENCY_5]   = c[CLASS_LOAD];
    l[LATENCY_DIV] = c[CLASS_DIV];
    return l;
  endfunction

  // ---- D1/D2 and D2/PreDS register model ---------------------------------------
  typedef struct {
    bit            known;
    ref_t          r;
    logic [31:0]   instr;
    logic          rvc;
    logic [30:0]   pc, branchTarget, seq;
    logic [MW-1:0] meta;
    logic          isCall, isRet;
  } slot_t;

  slot_t m_r1r2 = '{default: '0}, m_r2pds = '{default: '0};

  always @(posedge clk) begin
    if (!stall_d1_d2) begin
      m_r1r2.known        <= 1'b1;
      m_r1r2.r            <= reference(d_d1_instr, d_d1_rvc);
      m_r1r2.instr        <= d_d1_instr;
      m_r1r2.rvc          <= d_d1_rvc;
      m_r1r2.pc           <= d_d1_pc;
      m_r1r2.branchTarget <= d_d1_branchTarget;
      m_r1r2.seq          <= d_d1_seq;
      m_r1r2.meta         <= d_d1_meta;
      m_r1r2.isCall       <= d_d1_isCall;
      m_r1r2.isRet        <= d_d1_isRet;
    end
    if (!stall_d2_pds) m_r2pds <= m_r1r2;
  end

  // ---- checks ------------------------------------------------------------------
  int errors = 0;
  int nChk = 0, nIll = 0, nHeld1 = 0, nHeld2 = 0;
  int nClass [CLASS_W];
  int nSys [SYSTEM_W];

  task automatic fail(string name, string what);
    errors++;
    if (errors <= 20)
      $display("ERROR %s: %s  instr=%h rvc=%0d", name, what, m_r2pds.instr, m_r2pds.rvc);
  endtask

  ref_t e;

  always @(negedge clk) if (m_r2pds.known) begin
    e = m_r2pds.r;
    nHeld1 += int'(stall_d1_d2);
    nHeld2 += int'(stall_d2_pds);
    if ({d2_pds_pc, d2_pds_branchTarget, d2_pds_seq, d2_pds_meta, d2_pds_isCall, d2_pds_isRet,
         d2_pds_rvc}
        !== {m_r2pds.pc, m_r2pds.branchTarget, m_r2pds.seq, m_r2pds.meta, m_r2pds.isCall,
             m_r2pds.isRet, m_r2pds.rvc})
      fail("chk_pass", "pass-through fields");
    if (d2_pds_illegal !== !e.legal) fail("chk_illegal", $sformatf("illegal %0d", d2_pds_illegal));
    if (!e.legal) begin
      nIll++;
      if (d2_pds_class !== '0 || d2_pds_system !== '0)
        fail("chk_illgate", $sformatf("class %b system %b", d2_pds_class, d2_pds_system));
      if (d2_pds_latency !== '0 || d2_pds_serialising !== 1'b0)
        fail("chk_illgate", $sformatf("latency %b ser %0d", d2_pds_latency, d2_pds_serialising));
    end else begin
      nChk++;
      for (int k = 0; k < CLASS_W; k++) nClass[k] += int'(e.cls[k]);
      if (!m_r2pds.rvc && bopOf(m_r2pds.instr) >= 0) nB[bopOf(m_r2pds.instr)]++;
      for (int k = 0; k < SYSTEM_W; k++) nSys[k] += int'(e.sys[k]);
      if (d2_pds_class !== e.cls)
        fail("chk_class", $sformatf("class %b exp %b", d2_pds_class, e.cls));
      if (d2_pds_system !== e.sys)
        fail("chk_system", $sformatf("system %b exp %b", d2_pds_system, e.sys));
      if (d2_pds_latency !== latencyOf(e.cls))
        fail("chk_latency", $sformatf("latency %b exp %b", d2_pds_latency, latencyOf(e.cls)));
      if (d2_pds_serialising !== (e.cls[CLASS_CSR] || e.cls[CLASS_SYSTEM]))
        fail("chk_serial", $sformatf("serialising %0d", d2_pds_serialising));
      if ({d2_pds_sub, d2_pds_selArith, d2_pds_selAnd, d2_pds_selOr, d2_pds_selXor, d2_pds_selSlt,
           d2_pds_sltUnsigned} !== {e.sub, e.arith, e.andOp, e.orOp, e.xorOp, e.slt, e.sltU})
        fail("chk_alu", $sformatf("sub arith and or xor slt sltU %b exp %b",
             {d2_pds_sub, d2_pds_selArith, d2_pds_selAnd, d2_pds_selOr, d2_pds_selXor,
              d2_pds_selSlt, d2_pds_sltUnsigned}, {e.sub, e.arith, e.andOp, e.orOp, e.xorOp,
              e.slt, e.sltU}));
      if ({d2_pds_xIsPC, d2_pds_zIsImm} !== {e.xPc, e.zImm})
        fail("chk_opsel", $sformatf("xIsPC zIsImm %b", {d2_pds_xIsPC, d2_pds_zIsImm}));
      if (d2_pds_xIsZero !== (!e.rs1Use && !e.xPc) || d2_pds_zIsZero !== (!e.rs2Use && !e.zImm))
        fail("chk_zero", $sformatf("xIsZero zIsZero %b", {d2_pds_xIsZero, d2_pds_zIsZero}));
      if (e.cls[CLASS_BITM]) begin
        if ({d2_pds_shiftRight, d2_pds_shiftArith} !== {e.shR, e.shA})
          fail("chk_shift", $sformatf("right arith %b", {d2_pds_shiftRight, d2_pds_shiftArith}));
        // 16-bit shifts: shamt only, funct7 field reads 0 (direction in the flags)
        if (m_r2pds.rvc ? d2_pds_immediate[11:0] !== {7'd0, e.imm[4:0]}
                        : d2_pds_immediate[11:0] !== e.imm[11:0])
          fail("chk_imm", $sformatf("shift imm %h exp %h", d2_pds_immediate[11:0], e.imm[11:0]));
      end
      if ((e.cls & ((1 << CLASS_ALU) | (1 << CLASS_XALU) | (1 << CLASS_LOAD) | (1 << CLASS_STORE)
                  | (1 << CLASS_JALR) | (1 << CLASS_CSR))) != 0 && d2_pds_immediate !== e.imm)
        fail("chk_imm", $sformatf("imm %h exp %h", d2_pds_immediate, e.imm));
      if ((e.cls & ((1 << CLASS_LOAD) | (1 << CLASS_STORE) | (1 << CLASS_BRANCH) | (1 << CLASS_MUL)
                  | (1 << CLASS_DIV) | (1 << CLASS_CSR) | (1 << CLASS_XALU) | (1 << CLASS_BITM)))
          != 0 && d2_pds_func3 !== e.f3)
        fail("chk_f3", $sformatf("f3 %b exp %b", d2_pds_func3, e.f3));
      if (e.cls[CLASS_BRANCH] && {d2_pds_branchUseLt, d2_pds_branchInvert} !== {e.f3[2], e.f3[0]})
        fail("chk_branch", $sformatf("useLt invert %b", {d2_pds_branchUseLt, d2_pds_branchInvert}));
      if (e.cls[CLASS_MUL] && {d2_pds_mulSignedA, d2_pds_mulSignedB, d2_pds_mulHigh}
          !== {e.f3 == 3'b001 || e.f3 == 3'b010, e.f3 == 3'b001, e.f3 != 3'b000})
        fail("chk_mul", $sformatf("sA sB hi %b f3 %b",
             {d2_pds_mulSignedA, d2_pds_mulSignedB, d2_pds_mulHigh}, e.f3));
      if (e.cls[CLASS_DIV] && {d2_pds_divSigned, d2_pds_divRemainder}
          !== {e.f3 == 3'b100 || e.f3 == 3'b110, e.f3[1]})
        fail("chk_div", $sformatf("signed rem %b f3 %b",
             {d2_pds_divSigned, d2_pds_divRemainder}, e.f3));
    end
  end

  // ---- stimulus ----------------------------------------------------------------
  localparam logic [6:0] OPS [12] = '{7'b0110111, 7'b0010111, 7'b1101111, 7'b1100111,
    7'b1100011, 7'b0000011, 7'b0100011, 7'b0010011, 7'b0110011, 7'b0001111, 7'b1110011,
    7'b0110011};
  localparam logic [31:0] SYS [4] = '{32'h0000_0073, 32'h0010_0073, 32'h3020_0073,
                                      32'h1050_0073};

  localparam logic [6:0] BF7 [8] = '{7'b0010000, 7'b0000101, 7'b0000111, 7'b0110000,
    7'b0100100, 7'b0110100, 7'b0010100, 7'b0000100};
  localparam logic [6:0] ALLF7 [11] = '{7'b0000000, 7'b0100000, 7'b0000001, 7'b0010000,
    7'b0000101, 7'b0000111, 7'b0110000, 7'b0100100, 7'b0110100, 7'b0010100, 7'b0000100};
  localparam logic [4:0] BRS2 [10] = '{5'd1, 5'd2, 5'd3, 5'd4, 5'd5, 5'd6, 5'd7, 5'd8,
    5'b11000, 5'b10111};

  function automatic logic [31:0] rand32();
    logic [31:0] i;
    int          k;
    i = $urandom;
    i[1:0] = 2'b11;
    if ($urandom_range(3) != 0) i[6:0] = OPS[$urandom_range(11)];
    case ($urandom_range(5))
      0: i[31:25] = 7'b0000000;
      1: i[31:25] = 7'b0100000;
      2: i[31:25] = 7'b0000001;
      3: i[31:25] = BF7[$urandom_range(7)];
      4: begin                                  // one or two bits off a known funct7
        i[31:25] = ALLF7[$urandom_range(10)] ^ (7'd1 << $urandom_range(6));
        if ($urandom_range(1) == 0) i[31:25] = i[31:25] ^ (7'd1 << $urandom_range(6));
      end
      default: ;
    endcase
    if ($urandom_range(3) == 0) i[19:15] = 5'd0;
    if ($urandom_range(3) == 0) i[24:20] = 5'd0;
    else if ($urandom_range(3) == 0) i[24:20] = BRS2[$urandom_range(9)];
    if ($urandom_range(3) == 0) begin           // exact B op, free fields random
      k = $urandom_range(NB - 1);
      i = ($urandom & ~BOPS[k].mask) | BOPS[k].match;
      k = 7 + $urandom_range(24);
      if ($urandom_range(1) == 0) i[k] = !i[k];                     // near miss
    end
    if (i[6:0] == 7'b1110011 && $urandom_range(1) != 0) i = SYS[$urandom_range(3)];
    return i;
  endfunction

  task automatic drive(logic [31:0] ins, logic rvc, logic st1, logic st2);
    ref_t r;
    @(negedge clk);
    r = reference(ins, rvc);
    d_d1_instr        = ins;
    d_d1_rvc          = rvc;
    d_d1_rs1Use       = r.rs1Use;
    d_d1_rs2Use       = r.rs2Use;
    d_d1_pc           = 31'($urandom);
    d_d1_meta         = MW'($urandom);
    d_d1_isCall       = 1'($urandom);
    d_d1_isRet        = 1'($urandom);
    d_d1_branchTarget = 31'($urandom);
    d_d1_seq          = 31'($urandom);
    stall_d1_d2       = st1;
    stall_d2_pds      = st2;
  endtask

  int unsigned seed = 1;
  logic [31:0] ins;
  bit          cov;

  initial begin
    void'($value$plusargs("seed=%d", seed));
    void'($urandom(seed));
    foreach (nClass[k]) nClass[k] = 0;
    foreach (nSys[k]) nSys[k] = 0;
    foreach (nB[k]) nB[k] = 0;

    for (int k = 0; k < 65536; k++) begin
      if (k[1:0] == 2'b11) continue;
      drive({16'($urandom), 16'(k)}, 1'b1, 1'b0, 1'b0);
    end

    repeat (500000) drive(rand32(), 1'b0, 1'b0, 1'b0);

    repeat (200000) begin
      if ($urandom_range(1) != 0) begin
        ins = $urandom;
        if (ins[1:0] == 2'b11) ins[1:0] = 2'b01;
        drive(ins, 1'b1, $urandom_range(3) == 0, $urandom_range(3) == 0);
      end else begin
        drive(rand32(), 1'b0, $urandom_range(3) == 0, $urandom_range(3) == 0);
      end
    end
    drive(32'h0000_0013, 1'b0, 1'b0, 1'b0);
    @(negedge clk);

    $display("checked %0d legal, %0d illegal, held d1/d2 %0d, held d2/pds %0d",
             nChk, nIll, nHeld1, nHeld2);
    $display("class counts %p, system counts %p", nClass, nSys);
    cov = nHeld1 != 0 && nHeld2 != 0 && nIll != 0;
    foreach (nClass[k]) cov = cov && nClass[k] != 0;
    foreach (nSys[k]) cov = cov && nSys[k] != 0;
    foreach (nB[k]) begin
      if (nB[k] == 0) $display("uncovered %s", BOPS[k].name);
      cov = cov && nB[k] != 0;
    end
    $display("b ops min hits %0d", nB.min()[0]);
    if (!cov) begin
      $display("ERROR chk_cov: stimulus misses a case");
      errors++;
    end
    if (errors == 0) $display("PASS  decoder");
    else             $fatal(1, "FAIL  decoder (%0d errors)", errors);
    $finish;
  end

endmodule
