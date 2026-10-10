// ================================================================================
//  decoder_tb -- decoder against an independent reference
// ================================================================================
//  Reference: every 16-bit encoding is expanded to its 32-bit form (spec
//  tables), then the 32-bit form is decoded by opcode, funct3 and funct7 into
//  the expected uop. Both registers (R1/R2, R2/DS1) are modelled cycle by cycle
//  with their own stall. rs1Use/rs2Use are driven as the decoder makes them
//  (x0 folded). Phase 1: all 49152 16-bit encodings. Phase 2: 32-bit vectors,
//  opcodes and funct7 biased. Phase 3: mixed stream under random stalls.
//  Illegal: only class, latency, system, serialising and illegal are checked.
// ================================================================================

`include "uop_defs.svh"

module decoder_tb;

  localparam int MW = 4;

  logic                 clk = 1'b0;
  logic [31:0]          d_r1_instr = 32'h0000_0013;   // nop: 32-bit words end in 11
  logic                 d_r1_rvc = 1'b0;
  logic [30:0]          d_r1_pc = '0;
  logic [MW-1:0]        d_r1_meta = '0;
  logic                 d_r1_rs1Use = 1'b0;
  logic                 d_r1_rs2Use = 1'b0;
  logic                 d_r1_isCall = 1'b0;
  logic                 d_r1_isRet = 1'b0;
  logic [30:0]          d_r1_branchTarget = '0;
  logic [30:0]          d_r1_seq = '0;
  logic                 stall_r1_r2 = 1'b0;
  logic                 stall_r2_ds1 = 1'b0;
  logic [30:0]          r2_ds1_pc, r2_ds1_branchTarget, r2_ds1_seq;
  logic [MW-1:0]        r2_ds1_meta;
  logic                 r2_ds1_isCall, r2_ds1_isRet;
  logic [CLASS_W-1:0]   r2_ds1_class;
  logic [LATENCY_W-1:0] r2_ds1_latency;
  logic                 r2_ds1_sub, r2_ds1_selArith, r2_ds1_selAnd, r2_ds1_selOr, r2_ds1_selXor;
  logic                 r2_ds1_selSlt, r2_ds1_sltUnsigned, r2_ds1_shiftRight, r2_ds1_shiftArith;
  logic                 r2_ds1_xIsPC, r2_ds1_xIsZero, r2_ds1_zIsImm, r2_ds1_zIsZero;
  logic                 r2_ds1_branchUseLt, r2_ds1_branchInvert;
  logic                 r2_ds1_mulSignedA, r2_ds1_mulSignedB, r2_ds1_mulHigh;
  logic                 r2_ds1_divSigned, r2_ds1_divRemainder;
  logic [2:0]           r2_ds1_func3;
  logic [SYSTEM_W-1:0]  r2_ds1_system;
  logic                 r2_ds1_serialising;
  logic [31:0]          r2_ds1_immediate;
  logic                 r2_ds1_illegal;

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

  // decode of a 32-bit instruction into the expected uop
  function automatic ref_t decode(logic [31:0] i);
    ref_t        r;
    logic [2:0]  f3;
    logic [6:0]  f7;
    logic [31:0] iI, iS, iU;
    bit          r1, r2;
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
        if (!i[5]) r.imm = iI;
        if (i[5] && f7 == 7'b0000001) begin
          if (f3[2]) r.cls[CLASS_DIV] = 1;
          else       r.cls[CLASS_MUL] = 1;
        end else begin
          case (f3)
            3'b000: begin r.cls[CLASS_ALU] = 1; r.arith = 1; end
            3'b001: r.cls[CLASS_SHIFT] = 1;
            3'b010: begin r.cls[CLASS_SLT] = 1; r.sub = 1; r.slt = 1; end
            3'b011: begin r.cls[CLASS_SLT] = 1; r.sub = 1; r.slt = 1; r.sltU = 1; end
            3'b100: begin r.cls[CLASS_ALU] = 1; r.xorOp = 1; end
            3'b101: begin r.cls[CLASS_SHIFT] = 1; r.shR = 1; r.shA = f7[5]; end
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
    return r;
  endfunction

  function automatic logic [LATENCY_W-1:0] latencyOf(logic [CLASS_W-1:0] c);
    logic [LATENCY_W-1:0] l;
    l = '0;
    l[LATENCY_1]   = c[CLASS_ALU] || c[CLASS_JAL] || c[CLASS_JALR] || c[CLASS_CSR];
    l[LATENCY_3]   = c[CLASS_SHIFT] || c[CLASS_SLT];
    l[LATENCY_4]   = c[CLASS_MUL];
    l[LATENCY_5]   = c[CLASS_LOAD];
    l[LATENCY_DIV] = c[CLASS_DIV];
    return l;
  endfunction

  // ---- R1/R2 and R2/DS1 register model -----------------------------------------
  typedef struct {
    bit            known;
    ref_t          r;
    logic [31:0]   instr;
    logic          rvc;
    logic [30:0]   pc, branchTarget, seq;
    logic [MW-1:0] meta;
    logic          isCall, isRet;
  } slot_t;

  slot_t m_r1r2 = '{default: '0}, m_r2ds1 = '{default: '0};

  always @(posedge clk) begin
    if (!stall_r1_r2) begin
      m_r1r2.known        <= 1'b1;
      m_r1r2.r            <= reference(d_r1_instr, d_r1_rvc);
      m_r1r2.instr        <= d_r1_instr;
      m_r1r2.rvc          <= d_r1_rvc;
      m_r1r2.pc           <= d_r1_pc;
      m_r1r2.branchTarget <= d_r1_branchTarget;
      m_r1r2.seq          <= d_r1_seq;
      m_r1r2.meta         <= d_r1_meta;
      m_r1r2.isCall       <= d_r1_isCall;
      m_r1r2.isRet        <= d_r1_isRet;
    end
    if (!stall_r2_ds1) m_r2ds1 <= m_r1r2;
  end

  // ---- checks ------------------------------------------------------------------
  int errors = 0;
  int nChk = 0, nIll = 0, nHeld1 = 0, nHeld2 = 0;
  int nClass [CLASS_W];
  int nSys [SYSTEM_W];

  task automatic fail(string name, string what);
    errors++;
    if (errors <= 20)
      $display("ERROR %s: %s  instr=%h rvc=%0d", name, what, m_r2ds1.instr, m_r2ds1.rvc);
  endtask

  ref_t e;

  always @(negedge clk) if (m_r2ds1.known) begin
    e = m_r2ds1.r;
    nHeld1 += int'(stall_r1_r2);
    nHeld2 += int'(stall_r2_ds1);
    if ({r2_ds1_pc, r2_ds1_branchTarget, r2_ds1_seq, r2_ds1_meta, r2_ds1_isCall, r2_ds1_isRet}
        !== {m_r2ds1.pc, m_r2ds1.branchTarget, m_r2ds1.seq, m_r2ds1.meta, m_r2ds1.isCall,
             m_r2ds1.isRet})
      fail("chk_pass", "pass-through fields");
    if (r2_ds1_illegal !== !e.legal) fail("chk_illegal", $sformatf("illegal %0d", r2_ds1_illegal));
    if (!e.legal) begin
      nIll++;
      if (r2_ds1_class !== '0 || r2_ds1_system !== '0)
        fail("chk_illgate", $sformatf("class %b system %b", r2_ds1_class, r2_ds1_system));
      if (r2_ds1_latency !== '0 || r2_ds1_serialising !== 1'b0)
        fail("chk_illgate", $sformatf("latency %b ser %0d", r2_ds1_latency, r2_ds1_serialising));
    end else begin
      nChk++;
      for (int k = 0; k < CLASS_W; k++) nClass[k] += int'(e.cls[k]);
      for (int k = 0; k < SYSTEM_W; k++) nSys[k] += int'(e.sys[k]);
      if (r2_ds1_class !== e.cls)
        fail("chk_class", $sformatf("class %b exp %b", r2_ds1_class, e.cls));
      if (r2_ds1_system !== e.sys)
        fail("chk_system", $sformatf("system %b exp %b", r2_ds1_system, e.sys));
      if (r2_ds1_latency !== latencyOf(e.cls))
        fail("chk_latency", $sformatf("latency %b exp %b", r2_ds1_latency, latencyOf(e.cls)));
      if (r2_ds1_serialising !== (e.cls[CLASS_CSR] || e.cls[CLASS_SYSTEM]))
        fail("chk_serial", $sformatf("serialising %0d", r2_ds1_serialising));
      if ({r2_ds1_sub, r2_ds1_selArith, r2_ds1_selAnd, r2_ds1_selOr, r2_ds1_selXor, r2_ds1_selSlt,
           r2_ds1_sltUnsigned} !== {e.sub, e.arith, e.andOp, e.orOp, e.xorOp, e.slt, e.sltU})
        fail("chk_alu", $sformatf("sub arith and or xor slt sltU %b exp %b",
             {r2_ds1_sub, r2_ds1_selArith, r2_ds1_selAnd, r2_ds1_selOr, r2_ds1_selXor,
              r2_ds1_selSlt, r2_ds1_sltUnsigned}, {e.sub, e.arith, e.andOp, e.orOp, e.xorOp,
              e.slt, e.sltU}));
      if ({r2_ds1_xIsPC, r2_ds1_zIsImm} !== {e.xPc, e.zImm})
        fail("chk_opsel", $sformatf("xIsPC zIsImm %b", {r2_ds1_xIsPC, r2_ds1_zIsImm}));
      if (r2_ds1_xIsZero !== (!e.rs1Use && !e.xPc) || r2_ds1_zIsZero !== (!e.rs2Use && !e.zImm))
        fail("chk_zero", $sformatf("xIsZero zIsZero %b", {r2_ds1_xIsZero, r2_ds1_zIsZero}));
      if (e.cls[CLASS_SHIFT]) begin
        if ({r2_ds1_shiftRight, r2_ds1_shiftArith} !== {e.shR, e.shA})
          fail("chk_shift", $sformatf("right arith %b", {r2_ds1_shiftRight, r2_ds1_shiftArith}));
        if (r2_ds1_immediate[4:0] !== e.imm[4:0])
          fail("chk_imm", $sformatf("shamt %0d exp %0d", r2_ds1_immediate[4:0], e.imm[4:0]));
      end
      if ((e.cls & ((1 << CLASS_ALU) | (1 << CLASS_SLT) | (1 << CLASS_LOAD) | (1 << CLASS_STORE)
                  | (1 << CLASS_JALR) | (1 << CLASS_CSR))) != 0 && r2_ds1_immediate !== e.imm)
        fail("chk_imm", $sformatf("imm %h exp %h", r2_ds1_immediate, e.imm));
      if ((e.cls & ((1 << CLASS_LOAD) | (1 << CLASS_STORE) | (1 << CLASS_BRANCH) | (1 << CLASS_MUL)
                  | (1 << CLASS_DIV) | (1 << CLASS_CSR))) != 0 && r2_ds1_func3 !== e.f3)
        fail("chk_f3", $sformatf("f3 %b exp %b", r2_ds1_func3, e.f3));
      if (e.cls[CLASS_BRANCH] && {r2_ds1_branchUseLt, r2_ds1_branchInvert} !== {e.f3[2], e.f3[0]})
        fail("chk_branch", $sformatf("useLt invert %b", {r2_ds1_branchUseLt, r2_ds1_branchInvert}));
      if (e.cls[CLASS_MUL] && {r2_ds1_mulSignedA, r2_ds1_mulSignedB, r2_ds1_mulHigh}
          !== {e.f3 == 3'b001 || e.f3 == 3'b010, e.f3 == 3'b001, e.f3 != 3'b000})
        fail("chk_mul", $sformatf("sA sB hi %b f3 %b",
             {r2_ds1_mulSignedA, r2_ds1_mulSignedB, r2_ds1_mulHigh}, e.f3));
      if (e.cls[CLASS_DIV] && {r2_ds1_divSigned, r2_ds1_divRemainder}
          !== {e.f3 == 3'b100 || e.f3 == 3'b110, e.f3[1]})
        fail("chk_div", $sformatf("signed rem %b f3 %b",
             {r2_ds1_divSigned, r2_ds1_divRemainder}, e.f3));
    end
  end

  // ---- stimulus ----------------------------------------------------------------
  localparam logic [6:0] OPS [12] = '{7'b0110111, 7'b0010111, 7'b1101111, 7'b1100111,
    7'b1100011, 7'b0000011, 7'b0100011, 7'b0010011, 7'b0110011, 7'b0001111, 7'b1110011,
    7'b0110011};
  localparam logic [31:0] SYS [4] = '{32'h0000_0073, 32'h0010_0073, 32'h3020_0073,
                                      32'h1050_0073};

  function automatic logic [31:0] rand32();
    logic [31:0] i;
    i = $urandom;
    i[1:0] = 2'b11;
    if ($urandom_range(3) != 0) i[6:0] = OPS[$urandom_range(11)];
    case ($urandom_range(3))
      0: i[31:25] = 7'b0000000;
      1: i[31:25] = 7'b0100000;
      2: i[31:25] = 7'b0000001;
      default: ;
    endcase
    if ($urandom_range(3) == 0) i[19:15] = 5'd0;
    if ($urandom_range(3) == 0) i[24:20] = 5'd0;
    if (i[6:0] == 7'b1110011 && $urandom_range(1) != 0) i = SYS[$urandom_range(3)];
    return i;
  endfunction

  task automatic drive(logic [31:0] ins, logic rvc, logic st1, logic st2);
    ref_t r;
    @(negedge clk);
    r = reference(ins, rvc);
    d_r1_instr        = ins;
    d_r1_rvc          = rvc;
    d_r1_rs1Use       = r.rs1Use;
    d_r1_rs2Use       = r.rs2Use;
    d_r1_pc           = 31'($urandom);
    d_r1_meta         = MW'($urandom);
    d_r1_isCall       = 1'($urandom);
    d_r1_isRet        = 1'($urandom);
    d_r1_branchTarget = 31'($urandom);
    d_r1_seq          = 31'($urandom);
    stall_r1_r2       = st1;
    stall_r2_ds1      = st2;
  endtask

  int unsigned seed = 1;
  logic [31:0] ins;
  bit          cov;

  initial begin
    void'($value$plusargs("seed=%d", seed));
    void'($urandom(seed));
    foreach (nClass[k]) nClass[k] = 0;
    foreach (nSys[k]) nSys[k] = 0;

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

    $display("checked %0d legal, %0d illegal, held r1/r2 %0d, held r2/ds1 %0d",
             nChk, nIll, nHeld1, nHeld2);
    $display("class counts %p, system counts %p", nClass, nSys);
    cov = nHeld1 != 0 && nHeld2 != 0 && nIll != 0;
    foreach (nClass[k]) cov = cov && nClass[k] != 0;
    foreach (nSys[k]) cov = cov && nSys[k] != 0;
    if (!cov) begin
      $display("ERROR chk_cov: stimulus misses a case");
      errors++;
    end
    if (errors == 0) $display("PASS  decoder");
    else             $fatal(1, "FAIL  decoder (%0d errors)", errors);
    $finish;
  end

endmodule
