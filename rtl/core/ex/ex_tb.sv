// ================================================================================
//  ex_tb -- RF to WB against a value model, the bench plays IQ and payload
// ================================================================================
//  The bench:
//   - Generates uops in program order: R and I ALU ops (add sub and or xor
//   andn orn xnor), lui, auipc, jal, jalr, branches. Sources come from a pool
//   of live physical tags (tag 0 = x0, value 0); x0 sources and unused fields
//   carry random tags, so a stale producer match must be suppressed.
//   - Issues in order with random bubbles, a consumer no earlier than its
//   producer's select + 1 (latency 1). Grant one-hot at s+1 with the branch
//   mask, payload at s+2; idle payload cycles carry random fields.
//   - Snapshots open between uops; resolves come at random, half of them
//   mispredicts that kill every uop with the bit (issued or not); rare
//   commit flushes kill everything. A uop killed at or before its select is
//   not granted (the IQ's job).
//  Checks:
//   - chk_wb: wb_valid and robIndex for every live uop at s+8, nothing else.
//   - chk_result: the RF write at WB carries the model value (forwarding).
//   - chk_rfWrite: the RF write port fires at WB (s+8) only, never for a uop
//   killed before WB or without rd.
//   - chk_taken: a live branch's taken at s+5.
//   - chk_rf: at the end every live tag in the RF holds its model value.
//   - chk_cov: forward distances 1..8 on both operands, kills at s+1..s+8,
//   and reads where the RF still holds a stale value (a leak shows).
//  Phases (reset each): dense, sparse, kill-heavy, mixed. The RF starts
//  with random values in every tag but 0.
// ================================================================================
`include "uop_defs.svh"

/* verilator lint_off WIDTHEXPAND */
/* verilator lint_off WIDTHTRUNC */
module ex_tb;

  logic clk = 1'b0, resetn = 1'b0;
  always #5 clk = !clk;

  logic [7:0]         is_pr_grant = '0;
  logic [3:0]         iq_grantBranchMask = '0;
  logic [3:0]         pr_rf_robIndex;
  logic [5:0]         pr_rf_rs1Tag, pr_rf_rs2Tag, pr_rf_rdTag;
  logic               pr_rf_rdWriteEnable;
  logic [30:0]        pr_rf_pc, pr_rf_seq;
  logic [CLASS_W-1:0] pr_rf_class;
  logic               pr_rf_sub, pr_rf_selArith, pr_rf_selAnd, pr_rf_selOr, pr_rf_selXor;
  logic               pr_rf_sltUnsigned, pr_rf_xIsPC, pr_rf_xIsZero, pr_rf_zIsImm, pr_rf_zIsZero;
  logic               pr_rf_branchUseLt, pr_rf_branchInvert;
  logic [31:0]        pr_rf_immediate;
  logic               ex0_resolveValid = 1'b0, ex0_resolveMispredict = 1'b0, cm_flush = 1'b0;
  logic [1:0]         ex0_resolveSnapshot = '0;
  logic               ex0_ex1_taken, wb_valid, wb_exception, wb_refetch;
  logic [3:0]         wb_robIndex;
  logic [31:0]        wb_badAddress;

  ex u_dut (.*);

  // ---- model -------------------------------------------------------------------
  typedef enum int {OP_ADD, OP_SUB, OP_AND, OP_OR, OP_XOR, OP_ANDN, OP_ORN, OP_XNOR,
                    OP_LUI, OP_AUIPC, OP_JAL, OP_JALR, OP_BRANCH} op_e;
  typedef struct {
    op_e         op;
    bit          imm, rvc;
    bit [5:0]    rs1, rs2, rd;              // rs = 0: x0
    bit          rdWe;
    bit [31:0]   immediate, pc, value;
    bit [2:0]    func3;
    bit          taken;
    bit [3:0]    mask, robIndex;
    longint      s, killAt;
  } uop_t;

  localparam longint NEVER = 64'h1000_0000_0000_0000;

  uop_t        u [int];
  int          prog [$];                    // generated, not selected, in order
  int          nextId;
  bit [31:0]   val [64];
  bit          live [64];                   // readable as a source
  bit          busy [64];                   // allocated (live, in flight or draining)
  longint      readyAt [64];                // producer select + 1
  longint      freeAt [64];
  int          readers [64];                // generated readers not yet past RR
  int          writer [64];
  bit [3:0]    openMask;
  longint      t;
  int          errors;
  int          cov [string];
  int          sel1 = -1, sel2 = -1;        // selected last cycle, granted last cycle
  int          pBubble, pResolve, pMispredict, pFlush, pSnapshot;
  string       covNeed [] = '{"staleX", "staleZ", "flush", "mispredict", "branch", "wb"};

  task automatic fail(string c, string m);
    errors++;
    if (errors <= 20) $display("ERROR %s t=%0d %s", c, t, m);
  endtask

  function automatic int pickTag();
    int c [$];
    for (int k = 0; k < 64; k++) if (live[k]) c.push_back(k);
    return c[$urandom_range(c.size() - 1)];
  endfunction

  function automatic int freeTag();
    int c [$];
    for (int k = 1; k < 64; k++) if (!busy[k] && freeAt[k] <= t) c.push_back(k);
    if (c.size() == 0) return -1;
    return c[$urandom_range(c.size() - 1)];
  endfunction

  function automatic bit [31:0] compute(uop_t x, bit [31:0] a, bit [31:0] b);
    bit [31:0] z;
    z = x.imm ? x.immediate : b;
    case (x.op)
      OP_ADD:    return a + z;
      OP_SUB:    return a - z;
      OP_AND:    return a & z;
      OP_OR:     return a | z;
      OP_XOR:    return a ^ z;
      OP_ANDN:   return a & ~z;
      OP_ORN:    return a | ~z;
      OP_XNOR:   return a ^ ~z;
      OP_LUI:    return x.immediate;
      OP_AUIPC:  return x.pc + x.immediate;
      default:   return x.pc + (x.rvc ? 2 : 4);
    endcase
  endfunction

  // ---- generate one uop --------------------------------------------------------
  function automatic bit newUop();
    uop_t x;
    int   r, rd;
    bit   twoSrc, oneSrc;
    rd = freeTag();
    if (rd < 0) return 0;
    r = $urandom_range(99);
    x.op = r < 40 ? op_e'($urandom_range(7)) : r < 48 ? OP_LUI : r < 54 ? OP_AUIPC :
           r < 60 ? OP_JAL : r < 66 ? OP_JALR : r < 80 ? OP_BRANCH : OP_ADD;
    x.imm   = (x.op <= OP_XOR) && x.op != OP_SUB && $urandom_range(1);
    x.rvc   = $urandom_range(1);
    x.pc    = {$urandom(), 1'b0};
    x.immediate = $urandom_range(3) == 0 ? $urandom : 32'($signed(12'($urandom)));
    x.func3 = $urandom_range(7);
    if (x.op == OP_BRANCH && x.func3[2:1] == 2'b01) x.func3[2:1] = 2'b11;
    twoSrc = x.op <= OP_XNOR && !x.imm || x.op == OP_BRANCH;
    oneSrc = twoSrc || x.op <= OP_XNOR || x.op == OP_JALR;
    x.rs1 = (oneSrc && $urandom_range(9) != 0) ? pickTag() : 0;
    x.rs2 = (twoSrc && $urandom_range(9) != 0) ? pickTag() : 0;
    x.rdWe = x.op != OP_BRANCH && $urandom_range(15) != 0;
    x.rd   = x.rdWe ? rd : $urandom_range(63);
    x.value = compute(x, val[x.rs1], val[x.rs2]);
    case (x.func3)
      3'b000:  x.taken = val[x.rs1] == val[x.rs2];
      3'b001:  x.taken = val[x.rs1] != val[x.rs2];
      3'b100:  x.taken = $signed(val[x.rs1]) <  $signed(val[x.rs2]);
      3'b101:  x.taken = $signed(val[x.rs1]) >= $signed(val[x.rs2]);
      3'b110:  x.taken = val[x.rs1] <  val[x.rs2];
      default: x.taken = val[x.rs1] >= val[x.rs2];
    endcase
    x.mask     = openMask;
    x.robIndex = $urandom_range(15);
    x.s        = NEVER;
    x.killAt   = NEVER;
    if (oneSrc && x.rs1 != 0) readers[x.rs1]++;
    if (twoSrc && x.rs2 != 0) readers[x.rs2]++;
    if (x.rdWe) begin
      busy[rd] = 1; live[rd] = 1; val[rd] = x.value; writer[rd] = nextId; readyAt[rd] = NEVER;
    end
    u[nextId] = x;
    prog.push_back(nextId);
    nextId++;
    // a snapshot opens after this uop
    if ($urandom_range(99) < pSnapshot && openMask != 4'hf) begin
      int k;
      do k = $urandom_range(3); while (openMask[k]);
      openMask[k] = 1;
    end
    return 1;
  endfunction

  function automatic bit usesX(uop_t x); return x.op <= OP_XNOR || x.op == OP_JALR || x.op == OP_BRANCH; endfunction
  function automatic bit usesZ(uop_t x); return x.op <= OP_XNOR && !x.imm || x.op == OP_BRANCH; endfunction

  // ---- kill: every uop carrying bit k (or all) ---------------------------------
  function automatic void kill(int k, bit all);
    foreach (u[id]) begin
      if (u[id].killAt != NEVER) continue;
      if (!all && !u[id].mask[k]) continue;
      if (u[id].s != NEVER && u[id].s + 8 < t) continue;     // already done
      u[id].killAt = t;
      if (u[id].s != NEVER) cov[$sformatf("killAt%0d", t - u[id].s)]++;
      if (u[id].rdWe && writer[u[id].rd] == id) begin
        live[u[id].rd] = 0;
        freeAt[u[id].rd] = t + 12;
        busy[u[id].rd] = 0;
      end
      if (u[id].s == NEVER) begin
        if (usesX(u[id]) && u[id].rs1 != 0) readers[u[id].rs1]--;
        if (usesZ(u[id]) && u[id].rs2 != 0) readers[u[id].rs2]--;
      end
    end
    for (int i = prog.size() - 1; i >= 0; i--) if (u[prog[i]].killAt != NEVER) prog.delete(i);
    if (all) openMask = 0; else openMask[k] = 0;
  endfunction

  // ---- drive the payload of uop id (or garbage) --------------------------------
  task automatic drivePayload(int id);
    uop_t x;
    bit   isAlu;
    if (id < 0) begin
      {pr_rf_robIndex, pr_rf_rs1Tag, pr_rf_rs2Tag, pr_rf_rdTag} = $urandom;
      pr_rf_rdWriteEnable = $urandom; pr_rf_pc = $urandom; pr_rf_seq = $urandom;
      pr_rf_class = 1 << $urandom_range(CLASS_W - 1);
      {pr_rf_sub, pr_rf_selArith, pr_rf_selAnd, pr_rf_selOr, pr_rf_selXor, pr_rf_sltUnsigned,
       pr_rf_xIsPC, pr_rf_xIsZero, pr_rf_zIsImm, pr_rf_zIsZero, pr_rf_branchUseLt,
       pr_rf_branchInvert} = $urandom;
      pr_rf_immediate = $urandom;
      return;
    end
    x = u[id];
    isAlu = x.op <= OP_AUIPC;
    pr_rf_robIndex      = x.robIndex;
    pr_rf_rs1Tag        = (usesX(x) && x.rs1 != 0) ? x.rs1 : $urandom_range(63);
    pr_rf_rs2Tag        = (usesZ(x) && x.rs2 != 0) ? x.rs2 : $urandom_range(63);
    pr_rf_rdTag         = x.rd;
    pr_rf_rdWriteEnable = x.rdWe;
    pr_rf_pc            = x.pc[31:1];
    pr_rf_seq           = 31'((x.pc + (x.rvc ? 2 : 4)) >> 1);
    pr_rf_class         = '0;
    pr_rf_class[isAlu ? CLASS_ALU : x.op == OP_JAL ? CLASS_JAL : x.op == OP_JALR ? CLASS_JALR
                      : CLASS_BRANCH] = 1'b1;
    pr_rf_sub           = x.op == OP_SUB || x.op >= OP_ANDN && x.op <= OP_XNOR || x.op == OP_BRANCH;
    pr_rf_selArith      = x.op == OP_ADD || x.op == OP_SUB || x.op == OP_LUI || x.op == OP_AUIPC
                       || x.op == OP_JALR;
    pr_rf_selAnd        = x.op == OP_AND || x.op == OP_ANDN;
    pr_rf_selOr         = x.op == OP_OR  || x.op == OP_ORN;
    pr_rf_selXor        = x.op == OP_XOR || x.op == OP_XNOR;
    pr_rf_sltUnsigned   = x.op == OP_BRANCH && x.func3[1];
    pr_rf_xIsPC         = x.op == OP_AUIPC;
    pr_rf_zIsImm        = x.imm || x.op == OP_LUI || x.op == OP_AUIPC || x.op == OP_JALR;
    pr_rf_xIsZero       = !(usesX(x) && x.rs1 != 0) && !pr_rf_xIsPC;
    pr_rf_zIsZero       = !(usesZ(x) && x.rs2 != 0) && !pr_rf_zIsImm;
    pr_rf_branchUseLt   = x.func3[2];
    pr_rf_branchInvert  = x.func3[0];
    pr_rf_immediate     = x.immediate;
  endtask

  // ---- one cycle ---------------------------------------------------------------
  task automatic cycle();
    int  sel;
    @(posedge clk); #1;
    t++;

    // ---- checks: WB (s+8) and EX1 (s+5) ----------------------------------------
    begin
      int exp [$];
      foreach (u[id]) if (u[id].s != NEVER && u[id].s + 8 == t && u[id].killAt >= t) exp.push_back(id);
      if (exp.size() > 1) fail("chk_internal", "two uops at WB");
      if (wb_valid !== (exp.size() == 1)) fail("chk_wb", $sformatf("wb_valid %0d exp %0d", wb_valid, exp.size()));
      else if (exp.size() == 1) begin
        uop_t x = u[exp[0]];
        cov["wb"]++;
        if (wb_robIndex !== x.robIndex) fail("chk_wb", $sformatf("robIndex %0d exp %0d", wb_robIndex, x.robIndex));
        if (u_dut.u_regfile.ex3_wb_producer !== x.rdWe) fail("chk_rfWrite", $sformatf("id %0d producer %0d exp %0d", exp[0], u_dut.u_regfile.ex3_wb_producer, x.rdWe));
        else if (x.rdWe && u_dut.u_regfile.ex3_wb_rdTag !== x.rd) fail("chk_rfWrite", $sformatf("tag %0d exp %0d", u_dut.u_regfile.ex3_wb_rdTag, x.rd));
        else if (x.rdWe && u_dut.u_regfile.ex3_wb_result !== x.value)
          fail("chk_result", $sformatf("id %0d op %s value %h exp %h", exp[0], x.op.name(), u_dut.u_regfile.ex3_wb_result, x.value));
      end else if (u_dut.u_regfile.ex3_wb_producer) fail("chk_rfWrite", $sformatf("write tag %0d with no live uop", u_dut.u_regfile.ex3_wb_rdTag));
      foreach (u[id]) if (u[id].s != NEVER && u[id].s + 5 == t && u[id].killAt >= t && u[id].op == OP_BRANCH) begin
        cov["branch"]++;
        if (ex0_ex1_taken !== u[id].taken) fail("chk_taken", $sformatf("id %0d f3 %0d taken %0d exp %0d", id, u[id].func3, ex0_ex1_taken, u[id].taken));
      end
    end

    // ---- drive: grant (selected last cycle), payload (granted last cycle) ------
    is_pr_grant = '0; iq_grantBranchMask = $urandom;
    if (sel1 >= 0 && u[sel1].killAt == NEVER) begin
      is_pr_grant = 8'(1) << $urandom_range(7);
      iq_grantBranchMask = u[sel1].mask;
    end else if (sel1 >= 0) begin cov["killedAtSelect"]++; sel1 = -1; end
    drivePayload(sel2);
    #1;
    if (sel2 >= 0) begin
      uop_t x = u[sel2];
      if (usesX(x) && x.rs1 != 0 && u_dut.rf_rs1Data !== val[x.rs1]) cov["staleX"]++;
      if (usesZ(x) && x.rs2 != 0 && u_dut.rf_rs2Data !== val[x.rs2]) cov["staleZ"]++;
    end
    sel2 = sel1;

    // ---- resolve / flush this cycle --------------------------------------------
    ex0_resolveValid = 0; ex0_resolveMispredict = 0; cm_flush = 0;
    if ($urandom_range(999) < pFlush) begin
      cm_flush = 1; cov["flush"]++;
      kill(0, 1);
    end else if (openMask != 0 && $urandom_range(99) < pResolve) begin
      int k;
      do k = $urandom_range(3); while (!openMask[k]);
      ex0_resolveValid = 1; ex0_resolveSnapshot = k;
      ex0_resolveMispredict = $urandom_range(99) < pMispredict;
      if (ex0_resolveMispredict) begin cov["mispredict"]++; kill(k, 0); end
      else openMask[k] = 0;
      foreach (u[id]) u[id].mask[k] = 0;
    end

    // ---- select this cycle (in order) ------------------------------------------
    sel1 = -1;
    if (prog.size() > 0 && $urandom_range(99) >= pBubble) begin
      uop_t x = u[prog[0]];
      bit ok = 1;
      if (usesX(x) && x.rs1 != 0 && readyAt[x.rs1] > t) ok = 0;
      if (usesZ(x) && x.rs2 != 0 && readyAt[x.rs2] > t) ok = 0;
      if (ok) begin
        sel1 = prog.pop_front();
        u[sel1].s = t;
        if (u[sel1].rdWe) readyAt[u[sel1].rd] = t + 1;
        if (usesX(x) && x.rs1 != 0) begin
          cov[$sformatf("distX%0d", t - u[writer[x.rs1]].s > 8 ? 8 : t - u[writer[x.rs1]].s)]++;
        end
        if (usesZ(x) && x.rs2 != 0) begin
          cov[$sformatf("distZ%0d", t - u[writer[x.rs2]].s > 8 ? 8 : t - u[writer[x.rs2]].s)]++;
        end
      end else cov["waitDep"]++;
    end

    // ---- readers past RR; retire old tags; refill the program ------------------
    foreach (u[id]) if (u[id].s + 3 == t) begin
      if (usesX(u[id]) && u[id].rs1 != 0) readers[u[id].rs1]--;
      if (usesZ(u[id]) && u[id].rs2 != 0) readers[u[id].rs2]--;
    end
    begin
      int c = 0;
      for (int j = 0; j < 64; j++) c += live[j];
      for (int k = 1; k < 64; k++)
      if (c > 24 && live[k] && readers[k] == 0 && u[writer[k]].s != NEVER && u[writer[k]].s + 10 < t
          && $urandom_range(3) == 0) begin
        live[k] = 0; busy[k] = 0; freeAt[k] = t;
      end
    end
    while (prog.size() < 6) if (!newUop()) break;
    foreach (u[id]) if (u[id].s != NEVER && u[id].s + 20 < t || u[id].killAt + 20 < t)
      if (!(u[id].rdWe && writer[u[id].rd] == id && live[u[id].rd])) u.delete(id);
  endtask

  // ---- phases ------------------------------------------------------------------
  task automatic phase(string name, int cycles, int bubble, int res, int mis, int fl, int snap);
    pBubble = bubble; pResolve = res; pMispredict = mis; pFlush = fl; pSnapshot = snap;
    resetn = 0; is_pr_grant = '0; ex0_resolveValid = 0; cm_flush = 0;
    u.delete(); prog.delete(); openMask = 0; sel1 = -1; sel2 = -1;
    for (int k = 0; k < 64; k++) begin
      val[k] = 0; live[k] = k == 0; busy[k] = k == 0; readyAt[k] = 0; freeAt[k] = 0;
      readers[k] = 0; writer[k] = -1;
    end
    // the RF is not reset: rewrite the model from the RF, tags start free
    repeat (3) @(posedge clk);
    for (int k = 1; k < 64; k++) u_dut.u_regfile.rf_regs[k] = $urandom;
    #1 resetn = 1;
    repeat (cycles) cycle();
    // drain, then the RF holds every live tag
    pBubble = 100; pResolve = 0; pFlush = 0;
    repeat (12) cycle();
    for (int k = 0; k < 64; k++)
      if (live[k] && k != 0 && u[writer[k]].s != NEVER && u_dut.u_regfile.rf_regs[k] !== val[k])
        fail("chk_rf", $sformatf("%s tag %0d %h exp %h", name, k, u_dut.u_regfile.rf_regs[k], val[k]));
    $display("phase %-8s done", name);
  endtask

  int seed;
  initial begin
    if (!$value$plusargs("seed=%d", seed)) seed = 1;
    void'($urandom(seed));
    nextId = 0; t = 0; errors = 0;
    phase("dense",  20000,  5, 10, 50,  0, 20);
    phase("sparse", 20000, 50, 10, 50,  0, 20);
    phase("kill",   20000, 20, 40, 70, 10, 50);
    phase("mixed",  40000, 25, 15, 40,  2, 25);
    foreach (cov[k]) $display("  cov %-16s %0d", k, cov[k]);
    for (int d = 1; d <= 8; d++) begin
      if (!cov.exists($sformatf("killAt%0d", d))) fail("chk_cov", $sformatf("killAt%0d", d));
      if (!cov.exists($sformatf("distX%0d", d))) fail("chk_cov", $sformatf("distX%0d", d));
      if (!cov.exists($sformatf("distZ%0d", d))) fail("chk_cov", $sformatf("distZ%0d", d));
    end
    foreach (covNeed[i]) if (!cov.exists(covNeed[i])) fail("chk_cov", covNeed[i]);
    if (errors == 0) $display("PASS  ex");
    else             $display("FAIL  ex  (%0d errors)", errors);
    $finish;
  end

endmodule
