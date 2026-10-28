// ================================================================================
//  oe_tb -- D to IQ/ROB against a golden program model and an execute stub
// ================================================================================
//  The bench plays fetch, execute and the register file:
//   - Fetch: a lazily generated program (mem[pc]), one instruction per cycle
//   into F5, holds on stall_d_r1, random bubbles. On the correct path a
//   golden model runs every instruction as it is fetched; a branch/jalr is
//   predicted right with predAccuracy, else fetch goes down the wrong path
//   until the resolve. A trap or refetch instruction also leaves the path
//   until its commit flush. Redirects start the cycle after the kill.
//   - Semantics (bench only): rd = H(pc, rs1, rs2, imm); jal/jalr rd = seq;
//   branch taken = bit 5 of H; jalr target = 0x8000_0000 + H[19:1].
//   - Execute stub: grant seen at s+1, payload at s+2 (s = select cycle);
//   reads the physical register model by tag, writes rd, resolve at s+4,
//   completion at s+8. Killed uops are dropped (the respipe's job).
//  Checks:
//   - chk_ready: a source is read no earlier than producer select + latency.
//   - chk_payload: pc, class, immediate, seq, branch target, rd enable.
//   - chk_target: a correct-path resolve finds the golden next pc.
//   - chk_deadIssue: no grant for a uop killed at or before its select.
//   - chk_commit: in order, correct path only, pc/rd/value/trap/refetch.
//   - chk_drain: after the stream stops, everything commits; retirement map
//   holds the golden registers, spec map equals it, 64 tags all accounted.
//   - chk_watchdog: no commit for 400 cycles with work outstanding.
//  Phases (reset each): alu, control, system, mixed, dense, sparse.
// ================================================================================
`include "uop_defs.svh"

/* verilator lint_off WIDTHEXPAND */
/* verilator lint_off WIDTHTRUNC */
/* verilator lint_off UNUSEDSIGNAL */
module oe_tb;

  localparam int MW = 32;

  logic                 clk = 1'b0;
  logic                 resetn = 1'b0;
  logic                 f5_d_valid = 1'b0;
  logic [31:0]          f5_d_instr = '0;
  logic                 f5_d_rvc = 1'b0;
  logic [30:0]          f5_d_pc = '0;
  logic [MW-1:0]        f5_d_meta = '0;
  logic                 stall_d_r1;
  logic                 ex_resolveValid = 1'b0;
  logic [1:0]           ex_resolveSnapshot = '0;
  logic                 ex_resolveMispredict = 1'b0;
  logic [3:0]           ex_resolveRobIndex = '0;
  logic                 wb_valid = 1'b0;
  logic [3:0]           wb_robIndex = '0;
  logic                 wb_exception = 1'b0;
  logic                 wb_refetch = 1'b0;
  logic [31:0]          wb_badAddress = '0;
  logic [7:0]           is_pr_grant;
  logic [3:0]           iq_grantBranchMask;
  logic [3:0]           pr_rf_robIndex;
  logic [5:0]           pr_rf_rs1Tag, pr_rf_rs2Tag, pr_rf_rdTag;
  logic                 pr_rf_rdWriteEnable;
  logic [1:0]           pr_rf_snapshot;
  logic [30:0]          pr_rf_pc;
  logic [MW-1:0]        pr_rf_meta;
  logic                 pr_rf_isCall, pr_rf_isRet;
  logic [30:0]          pr_rf_branchTarget, pr_rf_seq;
  logic [CLASS_W-1:0]   pr_rf_class;
  logic                 pr_rf_sub, pr_rf_selArith, pr_rf_selAnd, pr_rf_selOr, pr_rf_selXor;
  logic                 pr_rf_selSlt, pr_rf_sltUnsigned, pr_rf_shiftRight, pr_rf_shiftArith;
  logic                 pr_rf_xIsPC, pr_rf_xIsZero, pr_rf_zIsImm, pr_rf_zIsZero;
  logic                 pr_rf_branchUseLt, pr_rf_branchInvert;
  logic                 pr_rf_mulSignedA, pr_rf_mulSignedB, pr_rf_mulHigh;
  logic                 pr_rf_divSigned, pr_rf_divRemainder;
  logic [2:0]           pr_rf_func3;
  logic [31:0]          pr_rf_immediate;
  logic                 cm_valid, cm_exception, cm_refetch, cm_flush;
  logic [4:0]           cm_rdIndex;
  logic [5:0]           cm_rdTag, cm_rdOldTag;
  logic                 cm_rdWriteEnable;
  logic [30:0]          cm_pc;
  logic                 cm_rvc;
  logic [SYSTEM_W-1:0]  cm_system;
  logic                 cm_illegal, cm_serialising, cm_isLoad, cm_isStore;
  logic [31:0]          cm_badAddress;

  oe #(.MW(MW)) u_dut (.*);

  always #5 clk = ~clk;

`include "oe_ref.svh"

  // ---- bench semantics ---------------------------------------------------------
  function automatic logic [31:0] H(logic [31:0] pc, logic [31:0] a, logic [31:0] b,
                                    logic [31:0] imm);
    logic [31:0] x;
    x = pc ^ 32'h9E37_79B9;
    x = (x ^ a) * 32'h85EB_CA6B;
    x = x ^ (x >> 13);
    x = (x + {b[15:0], b[31:16]}) * 32'hC2B2_AE35;
    x = x ^ (x >> 16) ^ imm;
    x = x * 32'h27D4_EB2F;
    return x ^ (x >> 15);
  endfunction

  // defined immediate bits, as decoder_tb checks them
  function automatic logic [31:0] immOf(logic [CLASS_W-1:0] cls, bit rvc, logic [31:0] imm);
    if ((cls & ((1 << CLASS_ALU) | (1 << CLASS_XALU) | (1 << CLASS_LOAD) | (1 << CLASS_STORE)
               | (1 << CLASS_JALR) | (1 << CLASS_CSR))) != 0) return imm;
    if (cls[CLASS_BITM]) return rvc ? {27'd0, imm[4:0]} : {20'd0, imm[11:0]};
    return '0;
  endfunction

  localparam int K_OTHER = 0, K_BRANCH = 1, K_JAL = 2, K_JALR = 3;

  // value written to rd and the next pc
  function automatic void sem(int kind, logic [31:0] pc, logic [31:0] seq, logic [31:0] target,
                              logic [31:0] imm, logic [31:0] a, logic [31:0] b,
                              output logic [31:0] value, output logic [31:0] next);
    logic [31:0] h;
    h = H(pc, a, b, imm);
    value = h;
    next  = seq;
    case (kind)
      K_BRANCH: next = h[5] ? target : seq;
      K_JAL:    begin value = seq; next = target; end
      K_JALR:   begin value = seq; next = 32'h8000_0000 | (h & 32'h000F_FFFE); end
      default:  ;
    endcase
  endfunction

  // ---- program memory and per-instruction records ------------------------------
  typedef struct {
    logic [31:0] instr;
    bit          rvc;
  } word_t;
  word_t mem [logic [31:0]];
  int    visits [logic [31:0]];             // a hot pc is rewritten: no endless loops

  typedef struct {
    logic [31:0] pc, instr, seq, target;
    bit          rvc;
    dc_t         dc;
    pd_t         pd;
    int          kind;
    bit          skip, exc, refetch, resolves;
    bit          onPath;
    logic [31:0] predNext, goldNext, value;
    bit          dead, executed;
    longint      killAt;
  } rec_t;
  rec_t   rec [int];
  int     inflight [$];                     // fetched, not committed or killed, oldest first
  int     golden [$];                       // correct-path ids awaiting commit
  int     deadIds [$];
  int     nextId;

  // ---- golden and stub state ---------------------------------------------------
  logic [31:0] arch [32];
  logic [31:0] prf [64];
  longint      readyAt [64];
  localparam longint NEVER = 64'h7FFF_FFFF_FFFF_FFFF;
  localparam longint TRAPTAG = -1;          // rd of a skip uop: never written

  typedef struct {
    int     id;
    longint s;
    logic [3:0] robIndex;
    logic [1:0] snapshot;
    bit     mispredict;
    logic [31:0] next;
  } ev_t;
  ev_t    resolveQ [$];
  ev_t    wbQ [$];

  // ---- run state ---------------------------------------------------------------
  longint t;
  int     errors;
  int     cov [string];
  longint lastCommit;
  int     scale;                            // +scale=n shortens every phase
  bit     noSquash;                         // +nosquash: variants without bubble squash
  int     phStart;
  bit     prPending;                        // a grant was seen last cycle
  bit     expR2, expPds;                    // a bubble must be filled at this edge
  longint prSelect;

  // fetch
  logic [31:0] fePc;
  bit          feOnPath, fePresenting, feStop, fePresStall;
  int          fePresId;

  // phase knobs
  string  phName;
  int     pRvc, pBranch, pJal, pJalr, pSys, pIll, pBubble, predAccuracy, nRegs, pLong;

  function automatic void fail(string name, string what);
    errors++;
    cov[{"FAIL_", name}]++;
    if (errors <= 25) $display("ERROR %s [%s t=%0d]: %s", name, phName, t, what);
  endfunction

  function automatic int lengthOf(bit rvc);
    return rvc ? 2 : 4;
  endfunction

  // ---- instruction generator ---------------------------------------------------
  function automatic logic [4:0] pickReg();
    if ($urandom_range(15) == 0) return 5'd0;
    return 5'($urandom_range(nRegs - 1) + 1);
  endfunction

  function automatic logic [31:0] gen32();
    logic [31:0] i;
    logic [4:0]  rd, rs1, rs2;
    int          k, r;
    rd = pickReg(); rs1 = pickReg(); rs2 = pickReg();
    r = $urandom_range(99);
    if (r < pBranch) begin
      k = $urandom_range(5);
      return encB(13'($signed($urandom_range(64)) - 32) << 1, rs2, rs1,
                  k == 0 ? 3'b000 : k == 1 ? 3'b001 : k == 2 ? 3'b100 :
                  k == 3 ? 3'b101 : k == 4 ? 3'b110 : 3'b111);
    end
    r -= pBranch;
    if (r < pJal)  return encJ(21'($signed($urandom_range(256)) - 128) << 1,
                               $urandom_range(2) == 0 ? 5'd1 : rd);
    r -= pJal;
    if (r < pJalr) return encI(12'($urandom), rs1, 3'b000, $urandom_range(2) == 0 ? 5'd1 : rd,
                               7'b1100111);
    r -= pJalr;
    if (r < pSys) begin
      case ($urandom_range(9))
        0: return 32'h0000_0073;                                   // ecall
        1: return 32'h0010_0073;                                   // ebreak
        2: return 32'h3020_0073;                                   // mret
        3: return 32'h1050_0073;                                   // wfi
        4: return encI(12'h0FF, 5'd0, 3'b000, 5'd0, 7'b0001111);   // fence
        5: return encI(12'h000, 5'd0, 3'b001, 5'd0, 7'b0001111);   // fence.i
        default: begin                                             // csr
          k = $urandom_range(5);
          return encI(12'($urandom), rs1, k < 3 ? 3'(k + 1) : 3'(k + 2), rd, 7'b1110011);
        end
      endcase
    end
    r -= pSys;
    if (r < pIll) begin
      i = $urandom;
      i[1:0] = 2'b11;
      return i;
    end
    // compute: ALU, shifts and B ops, slt, mul, loads, stores, lui/auipc
    case ($urandom_range(pLong ? 11 : 6))
      0, 1: begin
        k = $urandom_range(7);
        i = encR(k == 0 && $urandom_range(1) ? 7'b0100000 : 7'b0000000, rs2, rs1, 3'(k), rd,
                 7'b0110011);
        if (k == 1 || k == 5) i[30] = k == 5 && $urandom_range(1);
      end
      2, 3: begin
        k = $urandom_range(7);
        i = encI(12'($urandom), rs1, 3'(k), rd, 7'b0010011);
        if (k == 1) i[31:25] = 7'b0000000;
        if (k == 5) i[31:25] = $urandom_range(1) ? 7'b0100000 : 7'b0000000;
      end
      4: i = {20'($urandom), rd, $urandom_range(1) ? 7'b0110111 : 7'b0010111};
      5, 6: begin                                                   // B ops, kinds only
        do k = $urandom_range(NB - 1); while (BOPS[k].kind < 0);
        i = ($urandom & ~BOPS[k].mask) | BOPS[k].match;
        i[11:7] = rd; i[19:15] = rs1;
        if (BOPS[k].mask == M_R && i[6:0] == 7'b0110011) i[24:20] = rs2;
      end
      7, 8: i = encR(7'b0000001, rs2, rs1, 3'($urandom_range(3)), rd, 7'b0110011);  // mul
      9, 10: begin
        k = $urandom_range(4);
        i = encI(12'($urandom), rs1, k == 3 ? 3'b100 : k == 4 ? 3'b101 : 3'(k), rd, 7'b0000011);
      end
      default: i = encS(12'($urandom), rs2, rs1, 3'($urandom_range(2)));
    endcase
    return i;
  endfunction

  function automatic logic [15:0] gen16();
    logic [15:0] c;
    c = 16'($urandom);
    if (c[1:0] == 2'b11) c[1:0] = 2'($urandom_range(2));
    // registers into the active set where the format has a full field
    if (nRegs < 31 && $urandom_range(1)) begin
      c[11:7] = pickReg();
      if (c[1:0] == 2'b10) c[6:2] = pickReg();
    end
    return c;
  endfunction

  // classify; returns 0 if the phase does not allow it
  function automatic bit classify(logic [31:0] ins, bit rvc, ref rec_t x);
    x.dc = dc_reference(ins, rvc);
    x.pd = pd_reference(ins, rvc);
    x.instr = ins;
    x.rvc   = rvc;
    x.kind  = x.dc.cls[CLASS_BRANCH] ? K_BRANCH : x.dc.cls[CLASS_JAL] ? K_JAL :
              x.dc.cls[CLASS_JALR] ? K_JALR : K_OTHER;
    x.skip     = !x.dc.legal || x.dc.cls[CLASS_SYSTEM];
    x.exc      = !x.dc.legal || x.dc.sys[SYSTEM_ECALL] || x.dc.sys[SYSTEM_EBREAK];
    x.refetch  = x.dc.legal && (x.dc.sys[SYSTEM_MRET] || x.dc.sys[SYSTEM_FENCEI]);
    x.resolves = x.dc.legal && (x.kind == K_BRANCH || x.kind == K_JALR);
    if (x.dc.legal && x.dc.cls[CLASS_DIV]) return 0;               // slot sd: M6
    if (!x.dc.legal && pIll == 0) return 0;
    if (x.dc.legal && (x.dc.cls[CLASS_SYSTEM] || x.dc.cls[CLASS_CSR]) && pSys == 0) return 0;
    if (x.dc.legal && x.kind != K_OTHER && pBranch + pJal + pJalr == 0) return 0;
    if (x.dc.legal && x.kind == K_JAL && $signed(x.pd.off) <= 0) return 0;  // no endless loops
    return 1;
  endfunction

  function automatic word_t fetchWord(logic [31:0] pc);
    word_t  w;
    rec_t   x;
    if (mem.exists(pc) && visits[pc] < 32) begin
      visits[pc]++;
      return mem[pc];
    end
    if (mem.exists(pc)) cov["rewrite"]++;
    visits[pc] = 1;
    do begin
      w.rvc   = $urandom_range(99) < pRvc;
      w.instr = w.rvc ? {16'($urandom), gen16()} : gen32();
    end while (!classify(w.instr, w.rvc, x));
    mem[pc] = w;
    return w;
  endfunction

  // ---- fetch one instruction: golden step on the correct path ------------------
  function automatic int fetchOne();
    word_t       w;
    rec_t        x;
    int          id;
    logic [31:0] a, b, value, next;
    w = fetchWord(fePc);
    void'(classify(w.instr, w.rvc, x));
    x.pc     = fePc;
    x.seq    = fePc + lengthOf(w.rvc);
    x.target = fePc + x.pd.off;
    x.onPath = feOnPath;
    x.dead   = 0;
    x.executed = 0;
    x.killAt = NEVER;
    x.value  = '0;
    if (feOnPath && !x.skip) begin
      a = x.pd.rs1Use ? arch[x.pd.rs1] : '0;
      b = x.pd.rs2Use ? arch[x.pd.rs2] : '0;
      sem(x.kind, x.pc, x.seq, x.target, immOf(x.dc.cls, x.rvc, x.dc.imm), a, b, value, next);
      x.value    = value;
      x.goldNext = next;
      if (x.pd.rdWe) arch[x.pd.rd] = value;
    end else begin
      x.goldNext = x.seq;
    end
    // prediction: jal followed; branch/jalr right with predAccuracy on the path
    case (x.kind)
      K_JAL:   x.predNext = x.target;
      K_BRANCH, K_JALR: begin
        if (!x.dc.legal)                                   x.predNext = x.seq;
        else if (feOnPath && $urandom_range(99) < predAccuracy) x.predNext = x.goldNext;
        else if (feOnPath)                                 x.predNext =
          x.kind == K_BRANCH ? (x.goldNext == x.target ? x.seq : x.target) :
          (x.goldNext == x.seq ? x.seq + 4 : x.seq);
        else                                               x.predNext = x.seq;
      end
      default: x.predNext = x.seq;
    endcase
    id = nextId++;
    rec[id] = x;
    inflight.push_back(id);
    if (feOnPath) begin
      golden.push_back(id);
      if (x.exc || x.refetch) begin feOnPath = 0; cov["trapFetch"]++; end
      else if (x.predNext != x.goldNext) begin feOnPath = 0; cov["divergeFetch"]++; end
    end
    fePc = x.predNext;
    return id;
  endfunction

  // ---- kill everything younger than id at cycle t ------------------------------
  function automatic void killAfter(int id);
    while (inflight.size() > 0 && inflight[$] > id) begin
      int k = inflight.pop_back();
      rec[k].dead   = 1;
      rec[k].killAt = t;
      deadIds.push_back(k);
      if (rec[k].onPath) fail("chk_killPath", $sformatf("correct-path id %0d killed by %0d", k, id));
    end
    while (golden.size() > 0 && golden[$] > id) void'(golden.pop_back());
  endfunction

  // ---- one cycle ---------------------------------------------------------------
  task automatic step();
    bit          kill;
    logic [31:0] redirect;
    bit          redirectOnPath;
    @(posedge clk); #1;
    t++;
    kill = 0;
    if (fePresenting && f5_d_valid && !fePresStall) fePresenting = 0;   // taken at this edge
    ex_resolveValid      = 1'b0;
    ex_resolveMispredict = 1'b0;
    wb_valid             = 1'b0;

    // ---- commit ----------------------------------------------------------------
    if (cm_valid) begin
      int id;
      lastCommit = t;
      cov["commit"]++;
      if (golden.size() == 0 || inflight.size() == 0 || inflight[0] != golden[0]) begin
        fail("chk_commit", $sformatf("commit pc %h with nothing expected", {cm_pc, 1'b0}));
      end else begin
        id = golden.pop_front();
        void'(inflight.pop_front());
        if ({cm_pc, 1'b0} !== rec[id].pc)
          fail("chk_commit", $sformatf("pc %h exp %h", {cm_pc, 1'b0}, rec[id].pc));
        else if (cm_exception !== rec[id].exc || cm_refetch !== (rec[id].refetch && !rec[id].exc))
          fail("chk_commit", $sformatf("pc %h exc %0d refetch %0d exp %0d %0d", rec[id].pc,
               cm_exception, cm_refetch, rec[id].exc, rec[id].refetch));
        else if (!rec[id].exc) begin
          if (cm_rdWriteEnable !== rec[id].pd.rdWe)
            fail("chk_commit", $sformatf("pc %h rdWe %0d exp %0d", rec[id].pc, cm_rdWriteEnable,
                 rec[id].pd.rdWe));
          else if (rec[id].pd.rdWe && cm_rdIndex !== rec[id].pd.rd)
            fail("chk_commit", $sformatf("pc %h rd %0d exp %0d", rec[id].pc, cm_rdIndex, rec[id].pd.rd));
          else if (rec[id].pd.rdWe && prf[cm_rdTag] !== rec[id].value)
            fail("chk_commit", $sformatf("pc %h instr %h x%0d tag %0d value %h exp %h", rec[id].pc,
                 rec[id].instr, cm_rdIndex, cm_rdTag, prf[cm_rdTag], rec[id].value));
        end
        if (!rec[id].skip && !rec[id].executed)
          fail("chk_commit", $sformatf("pc %h committed without executing", rec[id].pc));
        if (cm_flush !== (rec[id].exc || rec[id].refetch))
          fail("chk_commit", $sformatf("pc %h flush %0d", rec[id].pc, cm_flush));
        if (cm_flush) begin
          cov[rec[id].exc ? "flushException" : "flushRefetch"]++;
          kill = 1;
          redirect = rec[id].seq;
          redirectOnPath = 1;
          killAfter(id);
        end
        rec.delete(id);
      end
    end else if (cm_flush) fail("chk_commit", "flush without commit");

    // ---- RF: payload of last cycle's grant -------------------------------------
    if (prPending) begin
      int id;
      id = int'(pr_rf_meta);
      if (!rec.exists(id)) fail("chk_payload", $sformatf("unknown meta %0d", id));
      else if (rec[id].dead && rec[id].killAt <= prSelect)
        fail("chk_deadIssue", $sformatf("id %0d killed at %0d selected at %0d", id,
             rec[id].killAt, prSelect));
      else if (!rec[id].dead) begin
        rec_t        x;
        logic [31:0] a, b, value, next;
        longint      lat;
        x = rec[id];
        if (x.skip) fail("chk_payload", $sformatf("skip uop %h issued", x.instr));
        if ({pr_rf_pc, 1'b0} !== x.pc || pr_rf_class !== x.dc.cls
            || immOf(x.dc.cls, x.rvc, pr_rf_immediate) !== immOf(x.dc.cls, x.rvc, x.dc.imm) || {pr_rf_seq, 1'b0} !== x.seq
            || pr_rf_rdWriteEnable !== x.pd.rdWe || pr_rf_robIndex === 4'bx
            || ((x.kind == K_BRANCH || x.kind == K_JAL) && {pr_rf_branchTarget, 1'b0} !== x.target))
          fail("chk_payload", $sformatf("id %0d pc %h/%h class %b/%b imm %h/%h", id,
               {pr_rf_pc, 1'b0}, x.pc, pr_rf_class, x.dc.cls, pr_rf_immediate, x.dc.imm));
        if (x.pd.rs1Use && readyAt[pr_rf_rs1Tag] == TRAPTAG) begin
          if (x.onPath) fail("chk_ready", $sformatf("id %0d reads the rd of a trapping uop", id));
          cov["readsTrapTag"]++;
        end else if (x.pd.rs1Use && readyAt[pr_rf_rs1Tag] > prSelect)
          fail("chk_ready", $sformatf("id %0d %h rs1 x%0d tag %0d ready %0d selected %0d", id, x.instr,
               x.pd.rs1, pr_rf_rs1Tag, readyAt[pr_rf_rs1Tag], prSelect));
        if (x.pd.rs2Use && readyAt[pr_rf_rs2Tag] == TRAPTAG) begin
          if (x.onPath) fail("chk_ready", $sformatf("id %0d reads the rd of a trapping uop", id));
          cov["readsTrapTag"]++;
        end else if (x.pd.rs2Use && readyAt[pr_rf_rs2Tag] > prSelect)
          fail("chk_ready", $sformatf("id %0d %h rs2 x%0d tag %0d ready %0d selected %0d", id, x.instr,
               x.pd.rs2, pr_rf_rs2Tag, readyAt[pr_rf_rs2Tag], prSelect));
        if (x.pd.rs1Use && readyAt[pr_rf_rs1Tag] == prSelect) cov["tightRs1"]++;
        if (x.pd.rs2Use && readyAt[pr_rf_rs2Tag] == prSelect) cov["tightRs2"]++;
        a = x.pd.rs1Use ? prf[pr_rf_rs1Tag] : '0;
        b = x.pd.rs2Use ? prf[pr_rf_rs2Tag] : '0;
        sem(x.kind, {pr_rf_pc, 1'b0}, {pr_rf_seq, 1'b0}, {pr_rf_branchTarget, 1'b0},
            immOf(x.dc.cls, x.rvc, pr_rf_immediate), a, b, value, next);
        lat = x.dc.cls[CLASS_LOAD] ? 5 : x.dc.cls[CLASS_MUL] ? 4 :
              (x.dc.cls[CLASS_BITM] || x.dc.cls[CLASS_XALU]) ? 3 : 1;
        cov[$sformatf("issueL%0d", lat)]++;
        if (pr_rf_rdWriteEnable) begin
          prf[pr_rf_rdTag]     = value;
          readyAt[pr_rf_rdTag] = prSelect + lat;
        end
        rec[id].executed = 1;
        wbQ.push_back('{id, prSelect, pr_rf_robIndex, pr_rf_snapshot, 0, next});
        if (x.resolves) begin
          bit mis = next != x.predNext;
          if (x.onPath && next != x.goldNext)
            fail("chk_target", $sformatf("id %0d pc %h next %h exp %h", id, x.pc, next, x.goldNext));
          resolveQ.push_back('{id, prSelect, pr_rf_robIndex, pr_rf_snapshot, mis, next});
        end
      end else cov["droppedAtRf"]++;
    end

    // ---- IS/PR: grant ----------------------------------------------------------
    prPending = is_pr_grant != 0;
    prSelect  = t - 1;
    if (is_pr_grant != 0 && !$onehot(is_pr_grant)) fail("chk_grant", $sformatf("%b", is_pr_grant));

    // ---- EX: resolve at s+4 ----------------------------------------------------
    while (resolveQ.size() > 0 && resolveQ[0].s + 4 <= t) begin
      ev_t e = resolveQ.pop_front();
      if (e.s + 4 < t) fail("chk_internal", "late resolve");
      if (rec.exists(e.id) && !rec[e.id].dead && !kill) begin
        ex_resolveValid      = 1'b1;
        ex_resolveSnapshot   = e.snapshot;
        ex_resolveMispredict = e.mispredict;
        ex_resolveRobIndex   = e.robIndex;
        cov["resolve"]++;
        if (e.mispredict) begin
          cov[rec[e.id].onPath ? "mispredictPath" : "mispredictWrongPath"]++;
          kill = 1;
          redirect = e.next;
          redirectOnPath = rec[e.id].onPath;
          killAfter(e.id);
        end
      end else cov["resolveDropped"]++;
    end

    // ---- completion at s+8 -----------------------------------------------------
    while (wbQ.size() > 0 && wbQ[0].s + 8 <= t) begin
      ev_t e = wbQ.pop_front();
      if (rec.exists(e.id) && !rec[e.id].dead) begin
        wb_valid    = 1'b1;
        wb_robIndex = e.robIndex;
        cov["wb"]++;
      end else cov["wbDropped"]++;
    end

    // ---- DS: a new rd tag is not ready -----------------------------------------
    if (u_dut.ds_fire && u_dut.pds_ds_rdWriteEnable)
      readyAt[u_dut.pds_ds_rdTag] = (u_dut.pds_ds_illegal || u_dut.pds_ds_class[CLASS_SYSTEM]) ? TRAPTAG : NEVER;
    if (u_dut.ds_fire && kill) cov["fireInKill"]++;
    if (u_dut.stall_pds_ds) cov["stallDs"]++;
    if (u_dut.ds_fire && u_dut.pds_ds_serialising) cov["serialFire"]++;

    // ---- bubble squash: a stage with a bubble takes the uop behind it ----------
    if (expR2 && !u_dut.r2_pds_valid && !noSquash) fail("chk_squash", "R2 bubble not filled");
    if (expPds && !u_dut.pds_ds_valid && !noSquash) fail("chk_squash", "PreDS bubble not filled");
    #1;
    expR2  = !u_dut.r2_pds_valid && u_dut.u_rename.r1_r2_valid && !u_dut.flush_d_r1;
    expPds = !u_dut.pds_ds_valid && u_dut.r2_pds_valid && !u_dut.flush_d_r1;
    if (expR2 && u_dut.stall_pds_ds) cov["squashR2"]++;

    // ---- fetch -----------------------------------------------------------------
    #1;
    if (stall_d_r1) cov["stallD"]++;
    if (kill) begin
      fePresenting = 0;
      fePc         = redirect;
      feOnPath     = redirectOnPath;
    end
    if (!kill && !fePresenting && !feStop && $urandom_range(99) >= pBubble) begin
      fePresId     = fetchOne();
      fePresenting = 1;
    end
    f5_d_valid = fePresenting && !kill;
    if (fePresenting) begin
      f5_d_instr = rec[fePresId].instr;
      f5_d_rvc   = rec[fePresId].rvc;
      f5_d_pc    = rec[fePresId].pc[31:1];
      f5_d_meta  = MW'(fePresId);
    end
    #0 fePresStall = stall_d_r1;

    // ---- housekeeping ----------------------------------------------------------
    while (deadIds.size() > 0 && rec[deadIds[0]].killAt + 40 < t) begin
      int k = deadIds.pop_front();
      rec.delete(k);
    end
    if (inflight.size() > 0 && t - lastCommit > 400) begin
      fail("chk_watchdog", $sformatf("no commit since %0d, %0d in flight, oldest pc %h", lastCommit,
           inflight.size(), rec[inflight[0]].pc));
      lastCommit = t;
    end
  endtask

  // ---- drain and final state ---------------------------------------------------
  task automatic drainCheck();
    bit [63:0] seen;
    feStop = 1;
    for (int c = 0; c < 2000 && (inflight.size() > 0 || !u_dut.rob_empty || fePresenting); c++) step();
    for (int c = 0; c < 20; c++) step();
    if (inflight.size() > 0 || golden.size() > 0)
      fail("chk_drain", $sformatf("%0d in flight, %0d golden left", inflight.size(), golden.size()));
    seen = '0;
    for (int r = 0; r < 32; r++) begin
      logic [5:0] tg = u_dut.u_rename.rn_retireMap[r];
      if (r > 0 && prf[tg] !== arch[r])
        fail("chk_drain", $sformatf("x%0d tag %0d value %h exp %h", r, tg, prf[tg], arch[r]));
      if (u_dut.u_rename.rn_map[r] !== tg)
        fail("chk_drain", $sformatf("x%0d map %0d retire %0d", r, u_dut.u_rename.rn_map[r], tg));
      if (seen[tg]) fail("chk_drain", $sformatf("tag %0d mapped twice", tg));
      seen[tg] = 1;
    end
    for (int k = 0; k < 32; k++) begin
      logic [5:0] tg = u_dut.u_rename.fl_ram[k];
      if (seen[tg]) fail("chk_drain", $sformatf("free tag %0d also live", tg));
      seen[tg] = 1;
    end
    if (seen != '1) fail("chk_drain", $sformatf("tags missing %h", ~seen));
    if (u_dut.u_rename.fl_tail - u_dut.u_rename.fl_head != 6'd32
        || u_dut.u_rename.fl_head != u_dut.u_rename.fl_commitHead)
      fail("chk_drain", $sformatf("free list head %0d commitHead %0d tail %0d",
           u_dut.u_rename.fl_head, u_dut.u_rename.fl_commitHead, u_dut.u_rename.fl_tail));
    if (!u_dut.rob_empty) fail("chk_drain", "ROB not empty");
  endtask

  // ---- phase -------------------------------------------------------------------
  task automatic phase(string name, int cycles, int rvc_, int br, int jal, int jalr, int sys,
                       int ill, int bubble, int acc, int regs, int lng);
    phName = name;
    pRvc = rvc_; pBranch = br; pJal = jal; pJalr = jalr; pSys = sys; pIll = ill;
    pBubble = bubble; predAccuracy = acc; nRegs = regs; pLong = lng;
    mem.delete();
    visits.delete();
    rec.delete();
    inflight.delete(); golden.delete(); deadIds.delete(); resolveQ.delete(); wbQ.delete();
    for (int r = 0; r < 32; r++) arch[r] = r == 0 ? '0 : $urandom;
    for (int k = 0; k < 64; k++) begin
      prf[k]     = k < 32 ? arch[k] : $urandom;
      readyAt[k] = 0;
    end
    fePc = 32'h8000_0000; feOnPath = 1; fePresenting = 0; feStop = 0; fePresStall = 0;
    prPending = 0; expR2 = 0; expPds = 0;
    f5_d_valid = 0; ex_resolveValid = 0; wb_valid = 0;
    resetn = 0;
    repeat (3) @(posedge clk);
    #1 resetn = 1;
    lastCommit = t;
    phStart = cov.exists("commit") ? cov["commit"] : 0;
    for (int c = 0; c < cycles / scale; c++) step();
    drainCheck();
    $display("phase %-8s commits %0d  ipc %0.3f", name, cov["commit"], real'(cov["commit"] - phStart) / real'(cycles / scale));
  endtask

  initial begin
    int seed;
    if (!$value$plusargs("seed=%d", seed)) seed = 1;
    if (!$value$plusargs("scale=%d", scale)) scale = 1;
    noSquash = $test$plusargs("nosquash");
    void'($urandom(seed));
    t = 0; errors = 0; nextId = 0;
    //     name       cycles  rvc  br jal jalr sys ill bub acc regs long
    phase("alu",      30000,  30,  0,  0,  0,  0,  0, 10,  90,  8,  1);
    phase("control",  30000,  30, 15,  4,  4,  0,  0, 10,  80,  8,  1);
    phase("system",   30000,  30,  4,  2,  2,  6,  2, 10,  85,  8,  1);
    phase("mixed",    60000,  40,  8,  3,  3,  2,  1, 15,  85, 12,  1);
    phase("dense",    30000,  20, 10,  2,  2,  1,  0,  0,  70,  3,  1);
    phase("sparse",   30000,  20,  6,  2,  2,  1,  0,  5,  90, 31,  0);

    begin
      string need [] = '{"commit", "wb", "resolve", "mispredictPath", "mispredictWrongPath",
        "flushException", "flushRefetch", "stallD", "stallDs", "serialFire", "fireInKill",
        "tightRs1", "tightRs2", "issueL1", "issueL3", "issueL4", "issueL5", "droppedAtRf",
        "wbDropped", "resolveDropped", "squashR2", "readsTrapTag"};
      foreach (need[i]) if (!cov.exists(need[i]) || cov[need[i]] < 20)
        fail("coverage", $sformatf("%s = %0d", need[i], cov.exists(need[i]) ? cov[need[i]] : 0));
    end
    foreach (cov[k]) $display("  cov %-22s %0d", k, cov[k]);
    if (errors == 0) $display("PASS  oe");
    else             $display("FAIL  oe  (%0d errors)", errors);
    $finish;
  end

endmodule
