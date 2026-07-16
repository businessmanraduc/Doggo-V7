`include "isa.svh"
// ================================================================================
//  rvc_expand_tb -- every RV32C instruction, random fields spec-encoded on both
//  sides, plus known byte-exact pairs and the reserved/illegal space
// ================================================================================

module rvc_expand_tb;
  localparam int N = 300;

  logic [15:0] instr16;
  logic [31:0] instr32;
  logic        illegal;
  int          errors = 0;

  rvc_expand dut (.instr16, .instr32, .illegal);

  task automatic check(
    input logic [15:0] c,
    input logic [31:0] want,
    input string       note
  );
    instr16 = c; #1;
    if (illegal || instr32 !== want) begin
      $error("%-16s c=%h -> %h illegal=%b, want %h", note, c, instr32, illegal, want);
      errors++;
    end
  endtask

  task automatic checkIllegal(input logic [15:0] c, input string note);
    instr16 = c; #1;
    if (!illegal) begin
      $error("%-16s c=%h -> %h, want illegal", note, c, instr32);
      errors++;
    end
  endtask

  // x8..x15 from a 3-bit prime field
  function automatic logic [4:0] xp(input logic [2:0] r);
    return {2'b01, r};
  endfunction

  function automatic logic [31:0] encI(
    input logic [11:0] imm, input logic [4:0] rs1,
    input logic [2:0]  f3,  input logic [4:0] rd, input logic [6:0] op
  );
    return {imm, rs1, f3, rd, op};
  endfunction

  function automatic logic [31:0] encR(
    input logic [6:0] f7, input logic [4:0] rs2, input logic [4:0] rs1,
    input logic [2:0] f3, input logic [4:0] rd
  );
    return {f7, rs2, rs1, f3, rd, OP_ARITH_R};
  endfunction

  function automatic logic [31:0] encS(
    input logic [11:0] imm, input logic [4:0] rs2, input logic [4:0] rs1
  );
    return {imm[11:5], rs2, rs1, F3_SW, imm[4:0], OP_STORE};
  endfunction

  function automatic logic [31:0] encB(
    input logic [12:0] imm, input logic [4:0] rs1, input logic [2:0] f3
  );
    return {imm[12], imm[10:5], 5'd0, rs1, f3, imm[4:1], imm[11], OP_BRANCH};
  endfunction

  function automatic logic [31:0] encJ(input logic [20:0] imm, input logic [4:0] rd);
    return {imm[20], imm[10:1], imm[11], imm[19:12], rd, OP_JAL};
  endfunction

  initial begin
    // ---- known byte-exact pairs (checked against binutils disassembly) -----------
    check(16'h0001, NOP_INSTR,     "c.nop");
    check(16'h8082, 32'h0000_8067, "c.jr ra (ret)");
    check(16'h852E, 32'h00B0_0533, "c.mv a0,a1");
    check(16'h9002, INSTR_EBREAK,  "c.ebreak");
    check(16'h4505, 32'h0010_0513, "c.li a0,1");
    check(16'hA001, 32'h0000_006F, "c.j .+0");

    // ---- Q0: random field sweeps --------------------------------------------------
    for (int k = 0; k < N; k++) begin
      automatic logic [9:0] u  = {8'($urandom()), 2'b00};   // nzuimm[9:2] << 2
      automatic logic [6:0] w  = {5'($urandom()), 2'b00};   // uimm[6:2] << 2
      automatic logic [2:0] ra = 3'($urandom());
      automatic logic [2:0] rb = 3'($urandom());
      if (u == '0) u = 10'h004;

      check({CF3_ADDI4SPN, u[5:4], u[9:6], u[2], u[3], ra, CQ0},
            encI({2'b00, u}, 5'd2, F3_ADD, xp(ra), OP_ARITH_I), "c.addi4spn");
      check({CF3_LW, w[5:3], ra, w[2], w[6], rb, CQ0},
            encI({5'b0, w}, xp(ra), F3_LW, xp(rb), OP_LOAD), "c.lw");
      check({CF3_SW, w[5:3], ra, w[2], w[6], rb, CQ0},
            encS({5'b0, w}, xp(rb), xp(ra)), "c.sw");
    end

    // ---- Q1: random field sweeps --------------------------------------------------
    for (int k = 0; k < N; k++) begin
      automatic logic [5:0]  i6  = 6'($urandom());
      automatic logic [4:0]  rd  = 5'($urandom());
      automatic logic [2:0]  ra  = 3'($urandom());
      automatic logic [2:0]  rb  = 3'($urandom());
      automatic logic [4:0]  sh  = 5'($urandom());
      automatic logic [11:0] off = {11'($urandom()), 1'b0};  // CJ offset[11:1] << 1
      automatic logic [8:0]  bo  = {8'($urandom()), 1'b0};   // CB offset[8:1] << 1
      automatic logic [5:0]  nz  = (i6 != '0) ? i6 : 6'h01;

      check({CF3_ADDI, i6[5], rd, i6[4:0], CQ1},
            encI({{6{i6[5]}}, i6}, rd, F3_ADD, rd, OP_ARITH_I), "c.addi");
      check({CF3_JAL, off[11], off[4], off[9:8], off[10], off[6], off[7], off[3:1], off[5], CQ1},
            encJ({{9{off[11]}}, off}, 5'd1), "c.jal");
      check({CF3_LI, i6[5], rd, i6[4:0], CQ1},
            encI({{6{i6[5]}}, i6}, 5'd0, F3_ADD, rd, OP_ARITH_I), "c.li");
      check({CF3_LUI, nz[5], 5'd2, nz[0], nz[2], nz[4:3], nz[1], CQ1},
            encI({{2{nz[5]}}, nz, 4'b0}, 5'd2, F3_ADD, 5'd2, OP_ARITH_I), "c.addi16sp");
      if (rd != 5'd2)
        check({CF3_LUI, nz[5], rd, nz[4:0], CQ1},
              {{{14{nz[5]}}, nz}, rd, OP_LUI}, "c.lui");
      check({CF3_ARITH, 1'b0, 2'b00, ra, sh, CQ1},
            encI({F7_NORMAL, sh}, xp(ra), F3_SRL, xp(ra), OP_ARITH_I), "c.srli");
      check({CF3_ARITH, 1'b0, 2'b01, ra, sh, CQ1},
            encI({F7_ALT, sh}, xp(ra), F3_SRL, xp(ra), OP_ARITH_I), "c.srai");
      check({CF3_ARITH, i6[5], 2'b10, ra, i6[4:0], CQ1},
            encI({{6{i6[5]}}, i6}, xp(ra), F3_AND, xp(ra), OP_ARITH_I), "c.andi");
      check({CF3_ARITH, 1'b0, 2'b11, ra, 2'b00, rb, CQ1},
            encR(F7_ALT,    xp(rb), xp(ra), F3_ADD, xp(ra)), "c.sub");
      check({CF3_ARITH, 1'b0, 2'b11, ra, 2'b01, rb, CQ1},
            encR(F7_NORMAL, xp(rb), xp(ra), F3_XOR, xp(ra)), "c.xor");
      check({CF3_ARITH, 1'b0, 2'b11, ra, 2'b10, rb, CQ1},
            encR(F7_NORMAL, xp(rb), xp(ra), F3_OR,  xp(ra)), "c.or");
      check({CF3_ARITH, 1'b0, 2'b11, ra, 2'b11, rb, CQ1},
            encR(F7_NORMAL, xp(rb), xp(ra), F3_AND, xp(ra)), "c.and");
      check({CF3_J, off[11], off[4], off[9:8], off[10], off[6], off[7], off[3:1], off[5], CQ1},
            encJ({{9{off[11]}}, off}, 5'd0), "c.j");
      check({CF3_BEQZ, bo[8], bo[4:3], ra, bo[7:6], bo[2:1], bo[5], CQ1},
            encB({{4{bo[8]}}, bo}, xp(ra), F3_BEQ), "c.beqz");
      check({CF3_BNEZ, bo[8], bo[4:3], ra, bo[7:6], bo[2:1], bo[5], CQ1},
            encB({{4{bo[8]}}, bo}, xp(ra), F3_BNE), "c.bnez");
    end

    // ---- Q2: random field sweeps --------------------------------------------------
    for (int k = 0; k < N; k++) begin
      automatic logic [4:0] rd  = 5'($urandom());
      automatic logic [4:0] rs2 = 5'($urandom());
      automatic logic [4:0] sh  = 5'($urandom());
      automatic logic [7:0] off = {6'($urandom()), 2'b00};   // offset[7:2] << 2
      automatic logic [4:0] nz  = (rd != '0) ? rd : 5'd1;

      check({CF3_SLLI, 1'b0, rd, sh, CQ2},
            encI({F7_NORMAL, sh}, rd, F3_SLL, rd, OP_ARITH_I), "c.slli");
      check({CF3_LWSP, off[5], nz, off[4:2], off[7:6], CQ2},
            encI({4'b0, off}, 5'd2, F3_LW, nz, OP_LOAD), "c.lwsp");
      check({CF3_MISC, 1'b0, nz, 5'd0, CQ2},
            encI(12'b0, nz, F3_JALR, 5'd0, OP_JALR), "c.jr");
      check({CF3_MISC, 1'b1, nz, 5'd0, CQ2},
            encI(12'b0, nz, F3_JALR, 5'd1, OP_JALR), "c.jalr");
      if (rs2 != '0) begin
        check({CF3_MISC, 1'b0, rd, rs2, CQ2},
              encR(F7_NORMAL, rs2, 5'd0, F3_ADD, rd), "c.mv");
        check({CF3_MISC, 1'b1, rd, rs2, CQ2},
              encR(F7_NORMAL, rs2, rd, F3_ADD, rd), "c.add");
      end
      check({CF3_SWSP, off[5:2], off[7:6], rs2, CQ2},
            encS({4'b0, off}, rs2, 5'd2), "c.swsp");
    end

    // ---- reserved / unsupported space ----------------------------------------------
    checkIllegal(16'h0000,                                         "all zeros");
    checkIllegal({CF3_ADDI4SPN, 8'b0, 3'd5, CQ0},                  "c.addi4spn imm=0");
    checkIllegal({3'b001, 11'h2A5, CQ0},                           "c.fld");
    checkIllegal({3'b011, 11'h2A5, CQ0},                           "c.flw");
    checkIllegal({3'b100, 11'h2A5, CQ0},                           "q0 f3=100");
    checkIllegal({3'b101, 11'h2A5, CQ0},                           "c.fsd");
    checkIllegal({3'b111, 11'h2A5, CQ0},                           "c.fsw");
    checkIllegal({CF3_LUI, 1'b0, 5'd5, 5'b0, CQ1},                 "c.lui imm=0");
    checkIllegal({CF3_LUI, 1'b0, 5'd2, 5'b0, CQ1},                 "c.addi16sp imm=0");
    checkIllegal({CF3_ARITH, 1'b1, 2'b00, 3'd1, 5'h0A, CQ1},       "c.srli shamt[5]");
    checkIllegal({CF3_ARITH, 1'b1, 2'b01, 3'd1, 5'h0A, CQ1},       "c.srai shamt[5]");
    checkIllegal({CF3_ARITH, 1'b1, 2'b11, 3'd2, 2'b00, 3'd3, CQ1}, "c.subw");
    checkIllegal({CF3_ARITH, 1'b1, 2'b11, 3'd2, 2'b01, 3'd3, CQ1}, "c.addw");
    checkIllegal({CF3_SLLI, 1'b1, 5'd3, 5'h0A, CQ2},               "c.slli shamt[5]");
    checkIllegal({CF3_LWSP, 1'b0, 5'd0, 3'b001, 2'b00, CQ2},       "c.lwsp rd=0");
    checkIllegal({CF3_MISC, 1'b0, 5'd0, 5'd0, CQ2},                "c.jr rs1=0");
    checkIllegal({3'b001, 11'h2A5, CQ2},                           "c.fldsp");
    checkIllegal({3'b011, 11'h2A5, CQ2},                           "c.flwsp");
    checkIllegal({3'b101, 11'h2A5, CQ2},                           "c.fsdsp");
    checkIllegal({3'b111, 11'h2A5, CQ2},                           "c.fswsp");

    if (errors == 0) $display("PASS  rvc_expand");
    else             $fatal(1, "FAIL  rvc_expand (%0d errors)", errors);
    $finish;
  end
endmodule
