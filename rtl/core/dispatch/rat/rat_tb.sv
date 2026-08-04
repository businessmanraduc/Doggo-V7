// ================================================================================
//  rat_tb -- pending tracks the NEWEST in-flight writer, WAW never frees early,
//  and flush empties everything
// ================================================================================

module rat_tb;
  localparam int W = 4;

  logic         clk = 0, resetn, flush;
  logic [4:0]   rs1Index, rs2Index;
  logic         rs1Pending, rs2Pending;
  logic [W-1:0] rs1Producer, rs2Producer;
  logic         alloc_valid, cmt_valid;
  logic [4:0]   alloc_rdIndex, cmt_rdIndex;
  logic [W-1:0] alloc_robIdx, cmt_robIdx;
  int           errors = 0;

  rat #(.ROB_IDX_W(W)) dut (
    .clk, .resetn, .flush,
    .rs1Index, .rs2Index, .rs1Pending, .rs2Pending, .rs1Producer, .rs2Producer,
    .alloc_valid, .alloc_rdIndex, .alloc_robIdx,
    .cmt_valid, .cmt_rdIndex, .cmt_robIdx
  );

  always #5 clk = ~clk;

  logic         mPend [32];
  logic [W-1:0] mProd [32];

  task automatic fail(input string msg);
    $error("%s", msg);
    errors++;
  endtask

  // check one lookup port pair against the model (producer only while pending)
  task automatic look(input logic [4:0] a, input logic [4:0] b, input string note);
    rs1Index = a; rs2Index = b;
    #1;
    if (rs1Pending !== mPend[a])                 fail({note, ": rs1Pending"});
    if (rs2Pending !== mPend[b])                 fail({note, ": rs2Pending"});
    if (mPend[a] && rs1Producer !== mProd[a])    fail({note, ": rs1Producer"});
    if (mPend[b] && rs2Producer !== mProd[b])    fail({note, ": rs2Producer"});
  endtask

  // one cycle of (optional) alloc and (optional) commit, model kept in step
  task automatic step(
    input logic av, input logic [4:0] ar, input logic [W-1:0] at,
    input logic cv, input logic [4:0] cr, input logic [W-1:0] ct
  );
    alloc_valid = av; alloc_rdIndex = ar; alloc_robIdx = at;
    cmt_valid   = cv; cmt_rdIndex   = cr; cmt_robIdx   = ct;
    @(posedge clk); #1;
    if (cv && mProd[cr] == ct) mPend[cr] = 0;
    if (av) begin mPend[ar] = 1; mProd[ar] = at; end
    alloc_valid = 0; cmt_valid = 0;
  endtask

  initial begin
    resetn = 0; flush = 0;
    alloc_valid = 0; cmt_valid = 0;
    alloc_rdIndex = '0; alloc_robIdx = '0; cmt_rdIndex = '0; cmt_robIdx = '0;
    rs1Index = '0; rs2Index = '0;
    for (int i = 0; i < 32; i++) begin mPend[i] = 0; mProd[i] = '0; end
    @(posedge clk); @(posedge clk);
    #1 resetn = 1;
    @(posedge clk); #1;

    // ---- A: clean after reset --------------------------------------------------
    for (int i = 0; i < 32; i++) look(5'(i), 5'(31 - i), "A");

    // ---- B: allocate, then the right producer forwards -------------------------
    step(1, 5'd5, 4'd3, 0, '0, '0);
    look(5'd5, 5'd6, "B");
    if (!rs1Pending || rs1Producer !== 4'd3) fail("B: x5 not owned by ticket 3");

    // ---- C: WAW -- an older writer must NOT free the register ------------------
    step(1, 5'd5, 4'd7, 0, '0, '0);          // newer writer of x5, ticket 7
    step(0, '0, '0, 1, 5'd5, 4'd3);          // ticket 3 (older) commits
    look(5'd5, 5'd0, "C");
    if (!rs1Pending)             fail("C: WAW commit freed x5 early");
    if (rs1Producer !== 4'd7)    fail("C: producer lost the newer writer");
    step(0, '0, '0, 1, 5'd5, 4'd7);          // the newest commits
    look(5'd5, 5'd0, "C");
    if (rs1Pending)              fail("C: newest commit did not free x5");

    // ---- D: same-edge alloc + commit of one register: alloc wins ---------------
    step(1, 5'd9, 4'd2, 0, '0, '0);
    step(1, 5'd9, 4'd8, 1, 5'd9, 4'd2);      // t2 retires while t8 allocates
    look(5'd9, 5'd0, "D");
    if (!rs1Pending || rs1Producer !== 4'd8) fail("D: alloc did not win the edge");
    step(0, '0, '0, 1, 5'd9, 4'd8);

    // ---- E: flush kills every in-flight writer ---------------------------------
    step(1, 5'd1, 4'd0, 0, '0, '0);
    step(1, 5'd2, 4'd1, 0, '0, '0);
    #1 flush = 1;
    @(posedge clk); #1;
    flush = 0;
    for (int i = 0; i < 32; i++) mPend[i] = 0;
    for (int i = 0; i < 32; i++) look(5'(i), 5'(i), "E");

    // ---- F: random stress, in-order retire stream vs the model -----------------
    begin
      automatic logic [8:0] q[$];              // {rd, ticket} in flight, in order
      automatic logic [W-1:0] nextT = '0;
      for (int k = 0; k < 5000; k++) begin
        automatic logic       av = 1'($urandom()) && (q.size() < 12);
        automatic logic [4:0] ar = 5'($urandom_range(1, 31));
        automatic logic       cv = 1'($urandom()) && (q.size() != 0);
        automatic logic [4:0]   cr = '0;
        automatic logic [W-1:0] ct = '0;
        if (cv) begin
          {cr, ct} = q.pop_front();
        end
        step(av, ar, nextT, cv, cr, ct);
        if (av) begin
          q.push_back({ar, nextT});
          nextT = nextT + 1'b1;
        end
        look(5'($urandom()), 5'($urandom()), "F");
        if (mPend[0]) fail("F: x0 became pending");
      end
    end

    if (errors == 0) $display("PASS  rat");
    else             $fatal(1, "FAIL  rat (%0d errors)", errors);
    $finish;
  end
endmodule
