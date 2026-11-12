// ================================================================================
//  alu_tb -- ALU against a per-uop architectural model
// ================================================================================
//  The bench plays regread: each cycle one uop or a bubble enters RR (the
//  rf_rr controls), and the uop of the cycle before gets its operands
//  (rr_ex0_x/z) the way regread delivers them: self -> 0, otherwise the value,
//  z inverted when sub and not self. Self is set only when the uop one cycle
//  ahead writes rd (not after a branch or a bubble). Bubbles carry random
//  controls, self bits and operands.
//  Every uop is checked against architecture: its operands are the true values
//  (the producer's result on self), its result is the RV op on them.
//  Checks:
//   - chk_result: add/sub/and/or/xor/andn/orn/xnor results in EX1.
//   - chk_taken: beq/bne/blt/bge/bltu/bgeu in EX1.
//   - chk_cov: every op, self on x/z/both per class, both outcomes of every
//   branch, signed and unsigned compares across the sign, self subtract,
//   carry across a control copy boundary, a uop after a bubble.
// ================================================================================
module alu_tb;

  logic clk = 1'b0;
  always #5 clk = !clk;

  logic        rf_rr_selfX = 1'b0, rf_rr_selfZ = 1'b0, rf_rr_sub = 1'b0;
  logic        rf_rr_selArith = 1'b0, rf_rr_selAnd = 1'b0, rf_rr_selOr = 1'b0;
  logic        rf_rr_selXor = 1'b0, rf_rr_sltUnsigned = 1'b0;
  logic        rf_rr_branchUseLt = 1'b0, rf_rr_branchInvert = 1'b0;
  logic [31:0] rr_ex0_x = '0, rr_ex0_z = '0;
  logic [31:0] ex0_ex1_result;
  logic        ex0_ex1_taken;

  alu u_dut (.*);

  localparam int ADD = 0, SUB = 1, AND = 2, OR = 3, XOR = 4, ANDN = 5, ORN = 6, XNOR = 7;
  localparam int BEQ = 8, BNE = 9, BLT = 10, BGE = 11, BLTU = 12, BGEU = 13, NKIND = 14;

  typedef struct {
    bit          valid;
    int          kind;
    bit          selfX, selfZ;
    logic [9:0]  ctrl;       // {selfX, selfZ, sub, selArith, selAnd, selOr, selXor,
                             //  sltUnsigned, branchUseLt, branchInvert}
    logic [31:0] x, z;       // what regread delivers
    logic [31:0] value;      // result (rd writers)
    bit          taken;      // branches
  } uop_t;

  uop_t        pipe [3];     // 0 = RR, 1 = EX0, 2 = EX1
  int          errors = 0, checks = 0;
  int          pBubble, pSelf, pEdge;
  int          cov [string];
  string       covNeed [] = '{
    "add", "sub", "and", "or", "xor", "andn", "orn", "xnor",
    "beq", "bne", "blt", "bge", "bltu", "bgeu",
    "arithSelfX", "arithSelfZ", "arithSelfXZ", "logicSelfX", "logicSelfZ", "logicSelfXZ",
    "branchSelfX", "branchSelfZ", "branchSelfXZ",
    "beq1", "beq0", "bne1", "bne0", "blt1", "blt0", "bge1", "bge0",
    "bltu1", "bltu0", "bgeu1", "bgeu0", "signedSignDiff", "unsignedSignDiff",
    "subSelfZ", "carryCopy", "afterBubble"
  };
  string       name [NKIND] = '{
    "add", "sub", "and", "or", "xor", "andn", "orn", "xnor",
    "beq", "bne", "blt", "bge", "bltu", "bgeu"
  };

  function automatic void fail(string chk, string msg);
    errors++;
    if (errors <= 20) $display("ERROR %s t=%0t %s", chk, $time, msg);
  endfunction

  function automatic logic [31:0] pick();
    if ($urandom_range(99) >= pEdge) return $urandom;
    case ($urandom_range(5))
      0: return 32'h8000_0000 + 32'($urandom_range(4)) - 32'd2;
      1: return 32'($urandom_range(4)) - 32'd2;
      2: return 32'h0000_00ff << (8 * $urandom_range(2));
      3: return 32'h7fff_ffff - 32'($urandom_range(2));
      default: return $urandom & 32'h0000_ffff;
    endcase
  endfunction

  // ---- a new uop (or bubble) in RR, its operands for EX0 ------------------------
  task automatic newUop();
    uop_t        u = '{default: '0};
    bit          canSelf = pipe[0].valid && pipe[0].kind < BEQ;
    bit          sub, isBranch;
    logic [31:0] xv, zv, xa, za;
    if ($urandom_range(99) < pBubble) begin
      u.ctrl = 10'($urandom);
      u.selfX = u.ctrl[9]; u.selfZ = u.ctrl[8];
      u.x = $urandom; u.z = $urandom;
      pipe[0] = u;
      return;
    end
    u.valid = 1'b1;
    u.kind  = $urandom_range(NKIND - 1);
    isBranch = u.kind >= BEQ;
    sub = u.kind == SUB || (u.kind >= ANDN && u.kind <= XNOR) || isBranch;
    u.selfX = canSelf && $urandom_range(99) < pSelf;
    u.selfZ = canSelf && $urandom_range(99) < pSelf;
    xv = pick();
    case ($urandom_range(3))
      0: zv = xv;
      1: zv = xv + 32'($urandom_range(2)) - 32'd1;
      default: zv = pick();
    endcase
    xa = u.selfX ? pipe[0].value : xv;
    za = u.selfZ ? pipe[0].value : zv;
    u.x = u.selfX ? 32'd0 : xv;
    u.z = u.selfZ ? 32'd0 : (zv ^ {32{sub}});
    u.ctrl = {u.selfX, u.selfZ, sub, u.kind == ADD || u.kind == SUB,
              u.kind == AND || u.kind == ANDN, u.kind == OR || u.kind == ORN,
              u.kind == XOR || u.kind == XNOR, u.kind == BLTU || u.kind == BGEU,
              u.kind >= BLT, u.kind == BNE || u.kind == BGE || u.kind == BGEU};
    case (u.kind)
      ADD:  u.value = xa + za;
      SUB:  u.value = xa - za;
      AND:  u.value = xa & za;
      OR:   u.value = xa | za;
      XOR:  u.value = xa ^ za;
      ANDN: u.value = xa & ~za;
      ORN:  u.value = xa | ~za;
      XNOR: u.value = ~(xa ^ za);
      BEQ:  u.taken = xa == za;
      BNE:  u.taken = xa != za;
      BLT:  u.taken = $signed(xa) <  $signed(za);
      BGE:  u.taken = $signed(xa) >= $signed(za);
      BLTU: u.taken = xa <  za;
      BGEU: u.taken = xa >= za;
      default: ;
    endcase
    // coverage
    cov[name[u.kind]]++;
    if (u.selfX || u.selfZ) begin
      string cls = isBranch ? "branch" : (u.kind <= SUB ? "arith" : "logic");
      cov[{cls, u.selfX && u.selfZ ? "SelfXZ" : (u.selfX ? "SelfX" : "SelfZ")}]++;
    end
    if (isBranch) cov[$sformatf("%s%0d", name[u.kind], u.taken)]++;
    if (isBranch && xa[31] != za[31])
      cov[u.kind == BLTU || u.kind == BGEU ? "unsignedSignDiff" :
          (u.kind == BLT || u.kind == BGE) ? "signedSignDiff" : "eqSignDiff"]++;
    if (u.selfZ && sub) cov["subSelfZ"]++;
    if (u.kind == ADD && ((xa & 32'hff) + (za & 32'hff)) > 32'hff) cov["carryCopy"]++;
    if (!pipe[0].valid && pipe[0].ctrl[9:8] != 2'b00) cov["afterBubble"]++;
    pipe[0] = u;
  endtask

  task automatic drive();
    {rf_rr_selfX, rf_rr_selfZ, rf_rr_sub, rf_rr_selArith, rf_rr_selAnd, rf_rr_selOr,
     rf_rr_selXor, rf_rr_sltUnsigned, rf_rr_branchUseLt, rf_rr_branchInvert} = pipe[0].ctrl;
    rr_ex0_x = pipe[1].x;
    rr_ex0_z = pipe[1].z;
  endtask

  // ---- outputs just before the edge ---------------------------------------------
  task automatic checkOutputs();
    if (!pipe[2].valid) return;
    checks++;
    if (pipe[2].kind < BEQ) begin
      if (ex0_ex1_result !== pipe[2].value)
        fail("chk_result", $sformatf("%s %h exp %h", name[pipe[2].kind],
                                     ex0_ex1_result, pipe[2].value));
    end else if (ex0_ex1_taken !== pipe[2].taken)
      fail("chk_taken", $sformatf("%s %b exp %b", name[pipe[2].kind],
                                  ex0_ex1_taken, pipe[2].taken));
  endtask

  task automatic cycle();
    @(posedge clk); #1;
    pipe[2] = pipe[1];
    pipe[1] = pipe[0];
    newUop();
    drive();
    #7;
    checkOutputs();
  endtask

  task automatic phase(string label, int n, int b, int s, int e);
    pBubble = b; pSelf = s; pEdge = e;
    repeat (n) cycle();
    $display("phase %-8s done, %0d errors so far", label, errors);
  endtask

  int seed;
  initial begin
    if (!$value$plusargs("seed=%d", seed)) seed = 1;
    void'($urandom(seed));
    repeat (64) void'($urandom);
    foreach (pipe[a]) pipe[a] = '{default: '0};

    //     label     cycles bubble self edge
    phase("dense",   60000,     5,  50,  30);
    phase("sparse",  60000,    50,  30,  30);
    phase("edge",    60000,    10,  20,  90);

    foreach (cov[k]) $display("  cov %-16s %0d", k, cov[k]);
    foreach (covNeed[i]) if (!cov.exists(covNeed[i])) fail("chk_cov", covNeed[i]);
    if (errors == 0) $display("PASS  alu (%0d checks)", checks);
    else             $fatal(1, "FAIL  alu (%0d errors)", errors);
    $finish;
  end

endmodule
