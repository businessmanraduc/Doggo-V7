// ================================================================================
//  oe_ref -- reference decode for the OE bench, copied from decoder_tb (class,
//  system, legal, immediate) and predecoder_tb (indices, uses, control flow)
// ================================================================================

  typedef struct {
    bit                  legal, rs1Use, rs2Use;
    logic [CLASS_W-1:0]  cls;
    logic [SYSTEM_W-1:0] sys;
    bit                  sub, arith, andOp, orOp, xorOp, slt, sltU, shR, shA, xPc, zImm;
    logic [2:0]          f3;
    logic [31:0]         imm;
  } dc_t;

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

  function automatic int bopOf(logic [31:0] i);
    for (int k = 0; k < NB; k++) if ((i & BOPS[k].mask) == BOPS[k].match) return k;
    return -1;
  endfunction

  // decode of a 32-bit instruction into the expected uop
  function automatic dc_t dc_decode(logic [31:0] i);
    dc_t        r;
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

  function automatic dc_t dc_reference(logic [31:0] ins, logic rvc);
    logic [32:0] e;
    dc_t        r;
    if (!rvc) return dc_decode(ins);
    e = expand(ins[15:0]);
    r = dc_decode(e[31:0]);
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

  typedef struct {
    bit          legal;
    logic [4:0]  rd, rs1, rs2;
    bit          rdWe, rs1Use, rs2Use;
    bit          isBr, isJal, isJalr, isCall, isRet;
    logic [31:0] off;
  } pd_t;

  function automatic bit isLink(logic [4:0] r);
    return r == 5'd1 || r == 5'd5;
  endfunction

  // decode of a 32-bit instruction by major opcode
  function automatic pd_t pd_decode(logic [31:0] i);
    pd_t r;
    bit   wr, r1, r2;
    r = '{default: '0};
    r.legal = 1'b1;
    r.rd = i[11:7]; r.rs1 = i[19:15]; r.rs2 = i[24:20];
    {wr, r1, r2} = 3'b000;
    case (i[6:0])
      7'b0110111, 7'b0010111: wr = 1'b1;
      7'b1101111: begin
        wr = 1'b1; r.isJal = 1'b1;
        r.off = {{12{i[31]}}, i[19:12], i[20], i[30:21], 1'b0};
      end
      7'b1100111: begin wr = 1'b1; r1 = 1'b1; r.isJalr = 1'b1; end
      7'b1100011: begin
        r1 = 1'b1; r2 = 1'b1; r.isBr = 1'b1;
        r.off = {{20{i[31]}}, i[7], i[30:25], i[11:8], 1'b0};
      end
      7'b0000011, 7'b0010011: begin wr = 1'b1; r1 = 1'b1; end
      7'b0100011: begin r1 = 1'b1; r2 = 1'b1; end
      7'b0110011: begin wr = 1'b1; r1 = 1'b1; r2 = 1'b1; end
      7'b0001111: ;
      7'b1110011: begin
        if (i[14:12] == 3'b100) r.legal = 1'b0;
        else if (i[14:12] != 3'b000) begin wr = 1'b1; r1 = !i[14]; end
      end
      default: r.legal = 1'b0;
    endcase
    r.rdWe   = wr && r.rd != 0;
    r.rs1Use = r1 && r.rs1 != 0;
    r.rs2Use = r2 && r.rs2 != 0;
    r.isCall = (r.isJal || r.isJalr) && isLink(r.rd);
    r.isRet  = r.isJalr && isLink(r.rs1) && !(isLink(r.rd) && r.rd == r.rs1);
    return r;
  endfunction

  function automatic pd_t pd_reference(logic [31:0] ins, logic rvc);
    logic [32:0] e;
    pd_t        r;
    if (!rvc) return pd_decode(ins);
    e = expand(ins[15:0]);
    r = pd_decode(e[31:0]);
    r.legal = r.legal && e[32];
    return r;
  endfunction
