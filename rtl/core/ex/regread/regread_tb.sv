// ================================================================================
//  regread_tb -- register read against a per-uop architectural model
// ================================================================================
//  The bench plays the payload (one uop or a bubble per cycle in RF), the
//  respipe (producer bits and rd tags RF/RR to EX3/WB, result chain EX1 to
//  CM) and the regfile (written at WB, read in RF). Every uop carries its own
//  result value. Operands are checked against architecture, not against the
//  forward network: the value of the in-flight producer of the source tag, the
//  regfile otherwise, or pc/imm/seq/0.
//  Producer tags are unique among live producers and never a uop's own source;
//  uops without rd and bubbles carry any tag. Kills hit RF..EX3 (WB is never
//  killed): a killed uop stops producing a cycle later, its tag is free again,
//  and every uop that read it dies with it.
//  Checks:
//   - chk_ctrl: the RF/RR ALU controls (selArith forced by a link).
//   - chk_self: selfX/selfZ, the producer one cycle ahead (ALU loop).
//   - chk_x, chk_z: the operands of every live uop in EX0 (self: 0, z not
//   inverted; subtract: z inverted).
//   - chk_cov: every source on both operands, link, pc, imm, zero, use gating
//   on a live tag, non-producer and killed tags, self z subtract.
// ================================================================================
`include "uop_defs.svh"

module regread_tb;

  logic clk = 1'b0;
  always #5 clk = !clk;

  logic [5:0]         pr_rf_rs1Tag = '0, pr_rf_rs2Tag = '0;
  logic [30:0]        pr_rf_pc = '0, pr_rf_seq = '0;
  logic [CLASS_W-1:0] pr_rf_class = '0;
  logic               pr_rf_sub = 1'b0, pr_rf_selArith = 1'b0, pr_rf_selAnd = 1'b0;
  logic               pr_rf_selOr = 1'b0, pr_rf_selXor = 1'b0, pr_rf_sltUnsigned = 1'b0;
  logic               pr_rf_xIsPC = 1'b0, pr_rf_xIsZero = 1'b0;
  logic               pr_rf_zIsImm = 1'b0, pr_rf_zIsZero = 1'b0;
  logic               pr_rf_branchUseLt = 1'b0, pr_rf_branchInvert = 1'b0;
  logic [31:0]        pr_rf_immediate = '0;
  logic [31:0]        rf_rs1Data = '0, rf_rs2Data = '0;
  logic               rf_rr_producer = 1'b0, rr_ex0_producer = 1'b0, ex0_ex1_producer = 1'b0;
  logic               ex1_ex2_producer = 1'b0, ex2_ex3_producer = 1'b0, ex3_wb_producer = 1'b0;
  logic [5:0]         rf_rr_rdTag = '0, rr_ex0_rdTag = '0, ex0_ex1_rdTag = '0;
  logic [5:0]         ex1_ex2_rdTag = '0, ex2_ex3_rdTag = '0, ex3_wb_rdTag = '0;
  logic [31:0]        ex0_ex1_result = '0, ex1_ex2_result = '0, ex2_ex3_result = '0;
  logic [31:0]        ex3_wb_result = '0, wb_cm_result = '0;
  logic               rf_rr_selfX, rf_rr_selfZ, rf_rr_sub, rf_rr_selArith, rf_rr_selAnd;
  logic               rf_rr_selOr, rf_rr_selXor, rf_rr_sltUnsigned;
  logic               rf_rr_branchUseLt, rf_rr_branchInvert;
  logic [31:0]        rr_ex0_x, rr_ex0_z;

  regread u_dut (.*);

  typedef struct {
    bit          valid;
    bit          alive;
    int          id;
    bit          producer;   // rd write enable
    logic [5:0]  rdTag;
    logic [31:0] value;      // its result, EX1 on
    int          srcX, srcZ; // ids of the in-flight producers it read, -1 none
    bit          expSelfX, expSelfZ;
    logic [31:0] expX, expZ;
    logic [7:0]  expCtrl;
  } uop_t;

  uop_t        pipe [8];     // [a]: 0 = RF, 1 = RR, 2 = EX0, 3 = EX1 ... 6 = WB, 7 = CM
  logic [31:0] regs [64];
  bit          killedId [int];
  int          nextId = 0, errors = 0, checks = 0;
  int          cov [string];
  int          pBubble, pKill;
  string       covNeed [] = '{
    "xSelf", "xEx1", "xEx2", "xEx3", "xWb", "xCm", "xRf",
    "zSelf", "zEx1", "zEx2", "zEx3", "zWb", "zCm", "zRf",
    "jal", "jalr", "pc", "imm", "xZero", "zZero", "gateX", "gateZ",
    "notProducer", "killedTag", "killDep", "zSelfSub", "zSub"};

  task automatic fail(string c, string m);
    errors++;
    if (errors <= 20) $display("ERROR %s t=%0t %s", c, $time, m);
  endtask

  function automatic bit live(int a);
    return pipe[a].valid && pipe[a].alive && pipe[a].producer;
  endfunction

  // ---- a source tag in RF: the live producer ahead of it, else the regfile -----
  function automatic void source(logic [5:0] tag, string op, output int id, output int age,
                                 output logic [31:0] value);
    id = -1; age = 0; value = regs[tag];
    for (int a = 1; a <= 6; a++) begin
      if (live(a) && pipe[a].rdTag == tag) begin
        id = pipe[a].id; age = a; value = pipe[a].value;
      end
      if (pipe[a].valid && !pipe[a].producer && pipe[a].rdTag == tag) cov["notProducer"]++;
      if (pipe[a].valid && !pipe[a].alive && pipe[a].producer && pipe[a].rdTag == tag)
        cov["killedTag"]++;
    end
    if (op != "") case (age)
      0: cov[{op, "Rf"}]++;   1: cov[{op, "Self"}]++; 2: cov[{op, "Ex1"}]++;
      3: cov[{op, "Ex2"}]++;  4: cov[{op, "Ex3"}]++;  5: cov[{op, "Wb"}]++;
      6: cov[{op, "Cm"}]++;
    endcase
  endfunction

  function automatic bit tagLive(logic [5:0] tag);
    for (int a = 1; a <= 6; a++) if (live(a) && pipe[a].rdTag == tag) return 1'b1;
    return 1'b0;
  endfunction

  function automatic logic [5:0] pickSource();
    int r = $urandom_range(9);
    if (r < 7) begin
      int a = $urandom_range(1, 6);
      if (pipe[a].valid) return pipe[a].rdTag;  // live, killed or no rd
    end
    return r == 9 ? 6'd0 : 6'($urandom);
  endfunction

  // ---- a new uop or a bubble in RF, with its expectation ------------------------
  task automatic newUop();
    uop_t u = '{default: '0};
    int   kind, idX, idZ, ageX, ageZ;
    bit   useX, useZ, isLink, sub;
    logic [31:0] valX, valZ, opZ;
    logic [5:0]  rd;

    pr_rf_rs1Tag = pickSource();
    pr_rf_rs2Tag = pickSource();
    pr_rf_pc = 31'($urandom); pr_rf_seq = 31'($urandom); pr_rf_immediate = $urandom;
    {pr_rf_selAnd, pr_rf_selOr, pr_rf_selXor} = 3'b000;
    pr_rf_selArith = 1'b0; pr_rf_sub = 1'b0; pr_rf_class = '0;
    {pr_rf_xIsPC, pr_rf_xIsZero, pr_rf_zIsImm, pr_rf_zIsZero} = 4'b0000;
    {pr_rf_sltUnsigned, pr_rf_branchUseLt, pr_rf_branchInvert} = 3'($urandom);

    if ($urandom_range(99) < pBubble) begin
      // garbage fields, nothing in flight
      {pr_rf_xIsPC, pr_rf_xIsZero, pr_rf_zIsImm, pr_rf_zIsZero} = 4'($urandom);
      pr_rf_class = CLASS_W'($urandom);
      pipe[0] = u;
      return;
    end

    // kind: 0 R, 1 I, 2 lui, 3 auipc, 4 jal, 5 jalr, 6 branch, 7 store, 8 x only, 9 z only
    kind = $urandom_range(9);
    u.producer = kind != 6 && kind != 7 && $urandom_range(7) != 0;
    case (kind)
      0: begin pr_rf_class[CLASS_ALU] = 1'b1; pr_rf_sub = 1'($urandom); end
      1:       pr_rf_class[CLASS_ALU] = 1'b1;
      2: begin pr_rf_class[CLASS_ALU] = 1'b1; pr_rf_xIsZero = 1'b1; end
      3: begin pr_rf_class[CLASS_ALU] = 1'b1; pr_rf_xIsPC = 1'b1; end
      4: begin pr_rf_class[CLASS_JAL] = 1'b1; pr_rf_xIsZero = 1'b1; end
      5:       pr_rf_class[CLASS_JALR] = 1'b1;
      6: begin pr_rf_class[CLASS_BRANCH] = 1'b1; pr_rf_sub = 1'b1; end
      7:       pr_rf_class[CLASS_STORE] = 1'b1;
      8: begin pr_rf_class[CLASS_ALU] = 1'b1; pr_rf_zIsZero = 1'b1; end
      9: begin pr_rf_class[CLASS_ALU] = 1'b1; pr_rf_xIsZero = 1'b1; end
    endcase
    pr_rf_zIsImm = kind inside {1, 2, 3, 4, 5, 7};
    if (kind inside {0, 1, 8, 9}) begin
      case ($urandom_range(3))
        0: pr_rf_selArith = 1'b1;  1: pr_rf_selAnd = 1'b1;
        2: pr_rf_selOr    = 1'b1;  3: pr_rf_selXor = 1'b1;
      endcase
    end else pr_rf_selArith = kind != 6 && kind != 7 ? 1'b1 : 1'($urandom);
    if (kind == 4 || kind == 5) begin
      // the decoder sends jal with neither (zIsZero), jalr with both
      {pr_rf_selArith, pr_rf_zIsImm} = {2{1'($urandom)}};
      pr_rf_zIsZero = !pr_rf_zIsImm;
    end

    // a fresh tag: not live, not its own source, never x0
    do rd = 6'($urandom_range(1, 63));
    while (u.producer && (tagLive(rd) || rd == pr_rf_rs1Tag || rd == pr_rf_rs2Tag));
    u.valid = 1'b1; u.alive = 1'b1; u.id = nextId++; u.rdTag = rd; u.value = $urandom;

    isLink = kind == 4 || kind == 5;
    useX   = !pr_rf_xIsPC && !pr_rf_xIsZero && !isLink;
    useZ   = !pr_rf_zIsImm && !pr_rf_zIsZero && !isLink;
    sub    = pr_rf_sub;
    source(pr_rf_rs1Tag, useX ? "x" : "", idX, ageX, valX);
    source(pr_rf_rs2Tag, useZ ? "z" : "", idZ, ageZ, valZ);
    if (!useX && idX >= 0) cov["gateX"]++;
    if (!useZ && idZ >= 0) cov["gateZ"]++;
    if (isLink) cov[kind == 4 ? "jal" : "jalr"]++;
    if (pr_rf_xIsPC) cov["pc"]++;
    if (pr_rf_zIsImm && !isLink) cov["imm"]++;
    if (pr_rf_xIsZero && !isLink) cov["xZero"]++;
    if (pr_rf_zIsZero && !isLink) cov["zZero"]++;

    u.srcX     = useX ? idX : -1;
    u.srcZ     = useZ ? idZ : -1;
    u.expSelfX = useX && ageX == 1;
    u.expSelfZ = useZ && ageZ == 1;
    u.expX     = pr_rf_xIsPC ? {pr_rf_pc, 1'b0} : !useX || u.expSelfX ? 32'd0 : valX;
    opZ        = isLink ? {pr_rf_seq, 1'b0} : pr_rf_zIsImm ? pr_rf_immediate
               : !useZ || u.expSelfZ ? 32'd0 : valZ;
    u.expZ     = u.expSelfZ ? 32'd0 : sub ? ~opZ : opZ;
    if (u.expSelfZ && sub) cov["zSelfSub"]++;
    if (!u.expSelfZ && useZ && sub && idZ >= 0) cov["zSub"]++;
    u.expCtrl  = {pr_rf_sub, pr_rf_selArith | isLink, pr_rf_selAnd, pr_rf_selOr, pr_rf_selXor,
                  pr_rf_sltUnsigned, pr_rf_branchUseLt, pr_rf_branchInvert};
    pipe[0] = u;
  endtask

  // ---- respipe and regfile ports from the model ---------------------------------
  task automatic drivePipe();
    {rf_rr_producer, rr_ex0_producer, ex0_ex1_producer} = {live(1), live(2), live(3)};
    {ex1_ex2_producer, ex2_ex3_producer, ex3_wb_producer} = {live(4), live(5), live(6)};
    rf_rr_rdTag   = pipe[1].valid ? pipe[1].rdTag : 6'($urandom);
    rr_ex0_rdTag  = pipe[2].valid ? pipe[2].rdTag : 6'($urandom);
    ex0_ex1_rdTag = pipe[3].valid ? pipe[3].rdTag : 6'($urandom);
    ex1_ex2_rdTag = pipe[4].valid ? pipe[4].rdTag : 6'($urandom);
    ex2_ex3_rdTag = pipe[5].valid ? pipe[5].rdTag : 6'($urandom);
    ex3_wb_rdTag  = pipe[6].valid ? pipe[6].rdTag : 6'($urandom);
    ex0_ex1_result = pipe[3].valid ? pipe[3].value : $urandom;
    ex1_ex2_result = pipe[4].valid ? pipe[4].value : $urandom;
    ex2_ex3_result = pipe[5].valid ? pipe[5].value : $urandom;
    ex3_wb_result  = pipe[6].valid ? pipe[6].value : $urandom;
    wb_cm_result   = pipe[7].valid ? pipe[7].value : $urandom;
  endtask

  // ---- outputs just before the edge ---------------------------------------------
  task automatic checkOutputs();
    logic [7:0] ctrl = {rf_rr_sub, rf_rr_selArith, rf_rr_selAnd, rf_rr_selOr, rf_rr_selXor,
                        rf_rr_sltUnsigned, rf_rr_branchUseLt, rf_rr_branchInvert};
    if (pipe[1].valid) begin
      checks++;
      if (ctrl !== pipe[1].expCtrl)
        fail("chk_ctrl", $sformatf("%b exp %b", ctrl, pipe[1].expCtrl));
      if ({rf_rr_selfX, rf_rr_selfZ} !== {pipe[1].expSelfX, pipe[1].expSelfZ})
        fail("chk_self", $sformatf("%b%b exp %b%b", rf_rr_selfX, rf_rr_selfZ,
                                   pipe[1].expSelfX, pipe[1].expSelfZ));
    end
    if (pipe[2].valid && pipe[2].alive) begin
      checks++;
      if (rr_ex0_x !== pipe[2].expX)
        fail("chk_x", $sformatf("id %0d %h exp %h", pipe[2].id, rr_ex0_x, pipe[2].expX));
      if (rr_ex0_z !== pipe[2].expZ)
        fail("chk_z", $sformatf("id %0d %h exp %h", pipe[2].id, rr_ex0_z, pipe[2].expZ));
    end
  endtask

  // ---- kills: RF..EX3, then everything that read a killed producer --------------
  task automatic kill();
    bit changed;
    for (int a = 0; a <= 5; a++)
      if (pipe[a].valid && pipe[a].alive && $urandom_range(2) == 0) begin
        pipe[a].alive = 1'b0; killedId[pipe[a].id] = 1'b1;
      end
    do begin
      changed = 1'b0;
      for (int a = 0; a <= 6; a++)
        if (pipe[a].valid && pipe[a].alive &&
            ((pipe[a].srcX >= 0 && killedId.exists(pipe[a].srcX)) ||
             (pipe[a].srcZ >= 0 && killedId.exists(pipe[a].srcZ)))) begin
          pipe[a].alive = 1'b0; killedId[pipe[a].id] = 1'b1; changed = 1'b1;
          cov["killDep"]++;
        end
    end while (changed);
  endtask

  task automatic cycle();
    @(posedge clk); #1;
    newUop();
    drivePipe();
    rf_rs1Data = regs[pr_rf_rs1Tag];
    rf_rs2Data = regs[pr_rf_rs2Tag];
    #7;
    checkOutputs();
    if ($urandom_range(99) < pKill) kill();
    if (live(6)) regs[pipe[6].rdTag] = pipe[6].value;
    for (int a = 7; a >= 1; a--) pipe[a] = pipe[a - 1];
    pipe[0] = '{default: '0};
  endtask

  task automatic phase(string name, int n, int b, int k);
    pBubble = b; pKill = k;
    repeat (n) cycle();
    $display("phase %-8s done, %0d errors so far", name, errors);
  endtask

  int seed;
  initial begin
    if (!$value$plusargs("seed=%d", seed)) seed = 1;
    void'($urandom(seed));
    repeat (64) void'($urandom);
    foreach (pipe[a]) pipe[a] = '{default: '0};
    regs[0] = '0;
    for (int i = 1; i < 64; i++) regs[i] = $urandom;

    //     name      cycles bubble kill
    phase("dense",   50000,    10,   2);
    phase("sparse",  50000,    60,   2);
    phase("kill",    50000,    20,  25);

    foreach (cov[k]) $display("  cov %-12s %0d", k, cov[k]);
    foreach (covNeed[i]) if (!cov.exists(covNeed[i])) fail("chk_cov", covNeed[i]);
    if (errors == 0) $display("PASS  regread (%0d checks)", checks);
    else             $fatal(1, "FAIL  regread (%0d errors)", errors);
    $finish;
  end

endmodule
