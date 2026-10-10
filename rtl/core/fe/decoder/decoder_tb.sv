// ================================================================================
//  decoder_tb -- decoder against an independent reference
// ================================================================================
//  Reference: every 16-bit encoding is expanded to its 32-bit form (spec
//  tables, offsets scattered bit by bit), then decoded by major opcode. The
//  D/R1 register is modelled cycle by cycle (valid, stall, flush, reset).
//  Phase 1: all 49152 16-bit encodings. Phase 2: 32-bit vectors, opcodes and
//  link registers biased. Phase 3: mixed stream under random stall and flush.
//  Fields of illegal encodings are don't-care; indices only when used.
// ================================================================================

module decoder_tb;

  localparam int MW = 4;

  logic          clk = 1'b0;
  logic          resetn = 1'b0;
  logic          f5_d_valid = 1'b0;
  logic [31:0]   f5_d_instr = '0;
  logic          f5_d_rvc = 1'b0;
  logic [30:0]   f5_d_pc = '0;
  logic [MW-1:0] f5_d_meta = '0;
  logic          stall_d_r1 = 1'b0;
  logic          flush_d_r1 = 1'b0;
  logic          d_r1_valid;
  logic [31:0]   d_r1_instr;
  logic          d_r1_rvc;
  logic [30:0]   d_r1_pc;
  logic [MW-1:0] d_r1_meta;
  logic [4:0]    d_r1_rs1Index, d_r1_rs2Index, d_r1_rdIndex;
  logic          d_r1_rs1Use, d_r1_rs2Use, d_r1_rdWriteEnable;
  logic          d_r1_isBranch, d_r1_isJal, d_r1_isJalr, d_r1_isCall, d_r1_isRet;
  logic [30:0]   d_r1_branchTarget, d_r1_seq;

  decoder #(.MW(MW)) u_dut (.*);

  always #5 clk = ~clk;

  // ---- reference ---------------------------------------------------------------
  typedef struct {
    bit          legal;
    logic [4:0]  rd, rs1, rs2;
    bit          rdWe, rs1Use, rs2Use;
    bit          isBr, isJal, isJalr, isCall, isRet;
    logic [31:0] off;
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

  function automatic bit isLink(logic [4:0] r);
    return r == 5'd1 || r == 5'd5;
  endfunction

  // decode of a 32-bit instruction by major opcode
  function automatic ref_t decode(logic [31:0] i);
    ref_t r;
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

  function automatic ref_t reference(logic [31:0] ins, logic rvc);
    logic [32:0] e;
    ref_t        r;
    if (!rvc) return decode(ins);
    e = expand(ins[15:0]);
    r = decode(e[31:0]);
    r.legal = r.legal && e[32];
    return r;
  endfunction

  // ---- D/R1 register model -----------------------------------------------------
  logic          m_valid = 1'b0;
  ref_t          m_ref;
  logic [31:0]   m_instr;
  logic          m_rvc;
  logic [30:0]   m_pc;
  logic [MW-1:0] m_meta;

  always @(posedge clk) begin
    if (!resetn || flush_d_r1) m_valid <= 1'b0;
    else if (!stall_d_r1)      m_valid <= f5_d_valid;
    if (!stall_d_r1) begin
      m_ref   <= reference(f5_d_instr, f5_d_rvc);
      m_instr <= f5_d_instr;
      m_rvc   <= f5_d_rvc;
      m_pc    <= f5_d_pc;
      m_meta  <= f5_d_meta;
    end
  end

  // ---- checks ------------------------------------------------------------------
  int errors = 0;
  int nChk = 0, nIll = 0, nCall = 0, nRet = 0, nCallRet = 0, nFold = 0, nTgt = 0, nHeld = 0;

  task automatic fail(string name, string what);
    errors++;
    if (errors <= 20)
      $display("ERROR %s: %s  instr=%h rvc=%0d pc=%h", name, what, m_instr, m_rvc, m_pc);
  endtask

  always @(negedge clk) if (resetn) begin
    if (d_r1_valid !== m_valid) fail("chk_valid", $sformatf("valid %0d exp %0d", d_r1_valid, m_valid));
    if (m_valid) begin
      if (stall_d_r1) nHeld++;
      if ({d_r1_instr, d_r1_rvc, d_r1_pc, d_r1_meta} !== {m_instr, m_rvc, m_pc, m_meta})
        fail("chk_pass", "pass-through fields");
      if (d_r1_seq !== m_pc + (m_rvc ? 31'd1 : 31'd2))
        fail("chk_seq", $sformatf("seq %h", d_r1_seq));
      if (!m_ref.legal) nIll++;
      else begin
        nChk++;
        if (d_r1_rdWriteEnable !== m_ref.rdWe)     fail("chk_rdWe", $sformatf("rdWe %0d", d_r1_rdWriteEnable));
        if (d_r1_rs1Use !== m_ref.rs1Use) fail("chk_rs1Use", $sformatf("rs1Use %0d", d_r1_rs1Use));
        if (d_r1_rs2Use !== m_ref.rs2Use) fail("chk_rs2Use", $sformatf("rs2Use %0d", d_r1_rs2Use));
        if (m_ref.rdWe && d_r1_rdIndex !== m_ref.rd)
          fail("chk_rd", $sformatf("rd %0d exp %0d", d_r1_rdIndex, m_ref.rd));
        if (m_ref.rs1Use && d_r1_rs1Index !== m_ref.rs1)
          fail("chk_rs1", $sformatf("rs1 %0d exp %0d", d_r1_rs1Index, m_ref.rs1));
        if (m_ref.rs2Use && d_r1_rs2Index !== m_ref.rs2)
          fail("chk_rs2", $sformatf("rs2 %0d exp %0d", d_r1_rs2Index, m_ref.rs2));
        if ({d_r1_isBranch, d_r1_isJal, d_r1_isJalr} !== {m_ref.isBr, m_ref.isJal, m_ref.isJalr})
          fail("chk_cf", $sformatf("br/jal/jalr %b", {d_r1_isBranch, d_r1_isJal, d_r1_isJalr}));
        if ({d_r1_isCall, d_r1_isRet} !== {m_ref.isCall, m_ref.isRet})
          fail("chk_ras", $sformatf("call/ret %b exp %b", {d_r1_isCall, d_r1_isRet},
                                    {m_ref.isCall, m_ref.isRet}));
        if ((m_ref.isBr || m_ref.isJal) && d_r1_branchTarget !== m_pc + m_ref.off[31:1])
          fail("chk_tgt", $sformatf("brTgt %h exp %h", d_r1_branchTarget, m_pc + m_ref.off[31:1]));
        nCall    += int'(m_ref.isCall);
        nRet     += int'(m_ref.isRet);
        nCallRet += int'(m_ref.isCall && m_ref.isRet);
        nTgt     += int'(m_ref.isBr || m_ref.isJal);
        nFold    += int'(!m_ref.rdWe && !m_ref.isBr && m_instr[6:0] != 7'b0100011 && m_ref.rd == 0);
      end
    end
  end

  // ---- stimulus ----------------------------------------------------------------
  localparam logic [6:0] OPS [11] = '{7'b0110111, 7'b0010111, 7'b1101111, 7'b1100111,
    7'b1100011, 7'b0000011, 7'b0100011, 7'b0010011, 7'b0110011, 7'b0001111, 7'b1110011};

  function automatic logic [4:0] pickReg();
    case ($urandom_range(3))
      0: return 5'd0;
      1: return 5'd1;
      2: return 5'd5;
      default: return 5'($urandom);
    endcase
  endfunction

  function automatic logic [31:0] rand32();
    logic [31:0] i;
    i = $urandom;
    i[1:0] = 2'b11;
    if ($urandom_range(3) != 0) i[6:0] = OPS[$urandom_range(10)];
    if ($urandom_range(1) != 0) begin
      i[11:7]  = pickReg();
      i[19:15] = pickReg();
    end
    return i;
  endfunction

  task automatic drive(logic v, logic [31:0] ins, logic rvc, logic st, logic fl);
    @(negedge clk);
    f5_d_valid = v;
    f5_d_instr = ins;
    f5_d_rvc   = rvc;
    f5_d_pc    = 31'($urandom);
    f5_d_meta  = MW'($urandom);
    stall_d_r1 = st;
    flush_d_r1 = fl;
  endtask

  int unsigned seed = 1;
  logic [31:0] ins;

  initial begin
    void'($value$plusargs("seed=%d", seed));
    void'($urandom(seed));
    repeat (3) @(negedge clk);
    resetn = 1'b1;

    for (int k = 0; k < 65536; k++) begin
      if (k[1:0] == 2'b11) continue;
      drive(1'b1, {16'($urandom), 16'(k)}, 1'b1, 1'b0, 1'b0);
    end

    repeat (1000000) drive(1'b1, rand32(), 1'b0, 1'b0, 1'b0);

    repeat (200000) begin
      if ($urandom_range(1) != 0) begin
        ins = $urandom;
        if (ins[1:0] == 2'b11) ins[1:0] = 2'b01;
        drive($urandom_range(9) != 0, ins, 1'b1, $urandom_range(3) == 0, $urandom_range(19) == 0);
      end else begin
        drive($urandom_range(9) != 0, rand32(), 1'b0, $urandom_range(3) == 0,
              $urandom_range(19) == 0);
      end
      if ($urandom_range(9999) == 0) resetn = 1'b0;
      else resetn = 1'b1;
    end
    drive(1'b0, '0, 1'b0, 1'b0, 1'b0);
    @(negedge clk);

    $display("checked %0d legal, %0d illegal, call %0d, ret %0d, call+ret %0d, x0 rd %0d, tgt %0d, held %0d",
             nChk, nIll, nCall, nRet, nCallRet, nFold, nTgt, nHeld);
    if (nCallRet == 0 || nRet == 0 || nHeld == 0) begin
      $display("ERROR chk_cov: stimulus misses a case");
      errors++;
    end
    if (errors == 0) $display("PASS  decoder");
    else             $fatal(1, "FAIL  decoder (%0d errors)", errors);
    $finish;
  end

endmodule
