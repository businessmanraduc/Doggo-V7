`include "uop.svh"
// ================================================================================
//  decoder_tb -- every RV32IM + Zicsr instruction: random fields, whole-uop
//  golden compare (every field checked every time).
// ================================================================================

module decoder_tb;
  localparam int N = 200;

  logic [31:0] instr, pc;
  logic        isCompressed, illegal;
  uop_t        uop;
  int          errors = 0;

  decoder dut (.instr, .pc, .isCompressed, .illegal, .uop);

  // drive one instruction, patch the always-extracted fields, compare whole uop
  task automatic chk(input logic [31:0] i, input uop_t want, input string note);
    automatic logic [31:0] p = 32'($urandom());
    automatic logic        c = 1'($urandom());
    instr = i; pc = p; isCompressed = c; illegal = 0;
    want.pc = p;  want.isCompressed = c;
    want.rs1Index = i[19:15];  want.rs2Index = i[24:20];  want.rdIndex = i[11:7];
    #1;
    if (uop !== want) begin
      $error("%-14s instr=%h\n  uop  = %h\n  want = %h", note, i, uop, want);
      errors++;
    end
  endtask

  // ---- 32-bit format assemblers ------------------------------------------------
  function automatic logic [31:0] encI(
    input logic [11:0] imm, input logic [4:0] rs1Index,
    input logic [2:0]  f3,  input logic [4:0] rd, input logic [6:0] op
  );
    return {imm, rs1Index, f3, rd, op};
  endfunction

  function automatic logic [31:0] encR(
    input logic [6:0] f7, input logic [4:0] rs2Index, input logic [4:0] rs1Index,
    input logic [2:0] f3, input logic [4:0] rd
  );
    return {f7, rs2Index, rs1Index, f3, rd, OP_ARITH_R};
  endfunction

  function automatic logic [31:0] encS(
    input logic [11:0] imm, input logic [4:0] rs2Index, input logic [4:0] rs1Index,
    input logic [2:0] f3
  );
    return {imm[11:5], rs2Index, rs1Index, f3, imm[4:0], OP_STORE};
  endfunction

  function automatic logic [31:0] encB(
    input logic [12:0] imm, input logic [4:0] rs2Index, input logic [4:0] rs1Index,
    input logic [2:0] f3
  );
    return {imm[12], imm[10:5], rs2Index, rs1Index, f3, imm[4:1], imm[11], OP_BRANCH};
  endfunction

  // ---- one task per format class, N random draws each --------------------------
  task automatic tAluImm(input logic [2:0] f3, input aluOp_t op);
    for (int k = 0; k < N; k++) begin
      automatic logic [11:0] i12 = 12'($urandom());
      automatic logic [4:0]  rs1Index = 5'($urandom()), rd = 5'($urandom());
      automatic uop_t w = '0;
      w.fu = FU_ALU;  w.subOp = op;
      w.rs1Used = 1;  w.regWrite = (rd != 0);  w.immUsed = 1;
      w.imm = {{20{i12[11]}}, i12};
      chk(encI(i12, rs1Index, f3, rd, OP_ARITH_I), w, {"alu-imm ", op.name()});
    end
  endtask

  task automatic tShiftImm(input logic [2:0] f3, input logic [6:0] f7,
                           input shiftOp_t op);
    for (int k = 0; k < N; k++) begin
      automatic logic [4:0] sh = 5'($urandom());
      automatic logic [4:0] rs1Index = 5'($urandom()), rd = 5'($urandom());
      automatic uop_t w = '0;
      w.fu = FU_SHIFTER;  w.subOp = {1'b0, op};
      w.rs1Used = 1;  w.regWrite = (rd != 0);  w.immUsed = 1;
      w.imm = {{20{f7[6]}}, f7, sh};
      chk(encI({f7, sh}, rs1Index, f3, rd, OP_ARITH_I), w, {"shift-imm ", op.name()});
    end
  endtask

  task automatic tAluReg(input logic [2:0] f3, input logic [6:0] f7,
                         input aluOp_t op);
    for (int k = 0; k < N; k++) begin
      automatic logic [4:0] rs1Index = 5'($urandom()), rs2Index = 5'($urandom()), rd = 5'($urandom());
      automatic uop_t w = '0;
      w.fu = FU_ALU;  w.subOp = op;
      w.rs1Used = 1;  w.rs2Used = 1;  w.regWrite = (rd != 0);
      chk(encR(f7, rs2Index, rs1Index, f3, rd), w, {"alu-reg ", op.name()});
    end
  endtask

  task automatic tShiftReg(input logic [2:0] f3, input logic [6:0] f7,
                           input shiftOp_t op);
    for (int k = 0; k < N; k++) begin
      automatic logic [4:0] rs1Index = 5'($urandom()), rs2Index = 5'($urandom()), rd = 5'($urandom());
      automatic uop_t w = '0;
      w.fu = FU_SHIFTER;  w.subOp = {1'b0, op};
      w.rs1Used = 1;  w.rs2Used = 1;  w.regWrite = (rd != 0);
      chk(encR(f7, rs2Index, rs1Index, f3, rd), w, {"shift-reg ", op.name()});
    end
  endtask

  task automatic tMulDiv(input logic [2:0] f3);
    for (int k = 0; k < N; k++) begin
      automatic logic [4:0] rs1Index = 5'($urandom()), rs2Index = 5'($urandom()), rd = 5'($urandom());
      automatic uop_t w = '0;
      w.fu = FU_MULDIV;  w.subOp = f3;
      w.rs1Used = 1;  w.rs2Used = 1;  w.regWrite = (rd != 0);
      chk(encR(F7_MULDIV, rs2Index, rs1Index, f3, rd), w, "muldiv");
    end
  endtask

  task automatic tLoad(input logic [2:0] f3);
    for (int k = 0; k < N; k++) begin
      automatic logic [11:0] i12 = 12'($urandom());
      automatic logic [4:0]  rs1Index = 5'($urandom()), rd = 5'($urandom());
      automatic uop_t w = '0;
      w.fu = FU_LSU;  w.subOp = f3;
      w.rs1Used = 1;  w.regWrite = (rd != 0);  w.immUsed = 1;
      w.imm = {{20{i12[11]}}, i12};
      chk(encI(i12, rs1Index, f3, rd, OP_LOAD), w, "load");
    end
  endtask

  task automatic tStore(input logic [2:0] f3);
    for (int k = 0; k < N; k++) begin
      automatic logic [11:0] i12 = 12'($urandom());
      automatic logic [4:0]  rs1Index = 5'($urandom()), rs2Index = 5'($urandom());
      automatic uop_t w = '0;
      w.fu = FU_LSU;  w.subOp = f3;  w.isStore = 1;
      w.rs1Used = 1;  w.rs2Used = 1;  w.immUsed = 1;
      w.imm = {{20{i12[11]}}, i12};
      chk(encS(i12, rs2Index, rs1Index, f3), w, "store");
    end
  endtask

  task automatic tBranch(input logic [2:0] f3);
    for (int k = 0; k < N; k++) begin
      automatic logic [12:0] b13 = {12'($urandom()), 1'b0};
      automatic logic [4:0]  rs1Index = 5'($urandom()), rs2Index = 5'($urandom());
      automatic uop_t w = '0;
      w.fu = FU_BRANCH;  w.subOp = f3;
      w.rs1Used = 1;  w.rs2Used = 1;
      w.imm = {{19{b13[12]}}, b13};
      chk(encB(b13, rs2Index, rs1Index, f3), w, "branch");
    end
  endtask

  task automatic tCsr(input logic [2:0] f3);
    for (int k = 0; k < N; k++) begin
      automatic logic [11:0] addr = 12'($urandom());
      automatic logic [4:0]  rs1Index = 5'($urandom()), rd = 5'($urandom());
      automatic uop_t w = '0;
      w.fu = FU_SYS;  w.subOp = f3;
      w.csrUseZimm = f3[2];  w.rs1Used = !f3[2];  w.regWrite = (rd != 0);
      w.imm = {{20{addr[11]}}, addr};
      chk(encI(addr, rs1Index, f3, rd, OP_SYSTEM), w, "csr");
    end
  endtask

  initial begin
    // ---- U / J formats ---------------------------------------------------------
    for (int k = 0; k < N; k++) begin
      automatic logic [19:0] u20 = 20'($urandom());
      automatic logic [20:0] j21 = {20'($urandom()), 1'b0};
      automatic logic [4:0]  rd  = 5'($urandom()), rs1Index = 5'($urandom());
      automatic logic [11:0] i12 = 12'($urandom());
      automatic uop_t w;

      w = '0;  w.fu = FU_ALU;  w.subOp = ALU_PASSB;
      w.immUsed = 1;  w.regWrite = (rd != 0);  w.imm = {u20, 12'b0};
      chk({u20, rd, OP_LUI}, w, "lui");

      w = '0;  w.fu = FU_ALU;  w.subOp = ALU_ADD;
      w.pcUsed = 1;  w.immUsed = 1;  w.regWrite = (rd != 0);  w.imm = {u20, 12'b0};
      chk({u20, rd, OP_AUIPC}, w, "auipc");

      w = '0;  w.fu = FU_BRANCH;  w.subOp = SUBOP_JAL;
      w.regWrite = (rd != 0);  w.imm = {{11{j21[20]}}, j21};
      chk({j21[20], j21[10:1], j21[11], j21[19:12], rd, OP_JAL}, w, "jal");

      w = '0;  w.fu = FU_BRANCH;  w.subOp = SUBOP_JALR;
      w.rs1Used = 1;  w.regWrite = (rd != 0);  w.imm = {{20{i12[11]}}, i12};
      chk(encI(i12, rs1Index, F3_JALR, rd, OP_JALR), w, "jalr");
    end

    // ---- every op-imm / op-reg / muldiv ----------------------------------------
    tAluImm(F3_ADD, ALU_ADD);    tAluImm(F3_SLT, ALU_SLT);  tAluImm(F3_SLTU, ALU_SLTU);
    tAluImm(F3_XOR, ALU_XOR);    tAluImm(F3_OR, ALU_OR);    tAluImm(F3_AND, ALU_AND);
    tShiftImm(F3_SLL, F7_NORMAL, SHIFT_SLL);
    tShiftImm(F3_SRL, F7_NORMAL, SHIFT_SRL);
    tShiftImm(F3_SRL, F7_ALT,    SHIFT_SRA);
    tAluReg(F3_ADD, F7_NORMAL, ALU_ADD);   tAluReg(F3_ADD, F7_ALT, ALU_SUB);
    tAluReg(F3_SLT, F7_NORMAL, ALU_SLT);   tAluReg(F3_SLTU, F7_NORMAL, ALU_SLTU);
    tAluReg(F3_XOR, F7_NORMAL, ALU_XOR);   tAluReg(F3_OR, F7_NORMAL, ALU_OR);
    tAluReg(F3_AND, F7_NORMAL, ALU_AND);
    tShiftReg(F3_SLL, F7_NORMAL, SHIFT_SLL);
    tShiftReg(F3_SRL, F7_NORMAL, SHIFT_SRL);
    tShiftReg(F3_SRL, F7_ALT,    SHIFT_SRA);
    tMulDiv(F3_MUL);   tMulDiv(F3_MULH);  tMulDiv(F3_MULHSU);  tMulDiv(F3_MULHU);
    tMulDiv(F3_DIV);   tMulDiv(F3_DIVU);  tMulDiv(F3_REM);     tMulDiv(F3_REMU);

    // ---- memory / branch / csr -------------------------------------------------
    tLoad(F3_LB);  tLoad(F3_LH);  tLoad(F3_LW);  tLoad(F3_LBU);  tLoad(F3_LHU);
    tStore(F3_SB); tStore(F3_SH); tStore(F3_SW);
    tBranch(F3_BEQ);  tBranch(F3_BNE);  tBranch(F3_BLT);
    tBranch(F3_BGE);  tBranch(F3_BLTU); tBranch(F3_BGEU);
    tCsr(F3_CSRRW);  tCsr(F3_CSRRS);  tCsr(F3_CSRRC);
    tCsr(F3_CSRRWI); tCsr(F3_CSRRSI); tCsr(F3_CSRRCI);

    // ---- fence / system --------------------------------------------------------
    for (int k = 0; k < N; k++) begin
      automatic logic [11:0] hi = 12'($urandom());
      automatic logic [4:0]  rs1Index = 5'($urandom()), rd = 5'($urandom());
      automatic uop_t w;
      w = '0;  w.fu = FU_SYS;
      chk({hi, rs1Index, 3'b000, rd, OP_FENCE}, w, "fence");
      w.isFenceI = 1;
      chk({hi, rs1Index, 3'b001, rd, OP_FENCE}, w, "fence.i");
    end
    begin
      automatic uop_t w;
      w = '0;  w.fu = FU_SYS;  w.excValid = 1;  w.excCause = TRAP_ECALL_M;
      chk(INSTR_ECALL, w, "ecall");
      w = '0;  w.fu = FU_SYS;  w.excValid = 1;  w.excCause = TRAP_BREAKPOINT;
      chk(INSTR_EBREAK, w, "ebreak");
      w = '0;  w.fu = FU_SYS;  w.isMret = 1;
      chk(INSTR_MRET, w, "mret");
      w = '0;  w.fu = FU_SYS;  w.isWfi = 1;
      chk(INSTR_WFI, w, "wfi");
    end

    // ---- illegal from the frontend wins over a legal encoding ------------------
    begin
      instr = encI(12'h001, 5'd1, F3_ADD, 5'd2, OP_ARITH_I);
      pc = 32'hCAFE_0000; isCompressed = 1; illegal = 1;
      #1;
      if (!uop.excValid || uop.excCause != TRAP_ILLEGAL_INSTR
          || uop.rs1Used || uop.regWrite || uop.pc != 32'hCAFE_0000) begin
        $error("illegal override broken (%h)", uop);
        errors++;
      end
      illegal = 0;
    end

    if (errors == 0) $display("PASS  decoder");
    else             $fatal(1, "FAIL  decoder (%0d errors)", errors);
    $finish;
  end
endmodule

