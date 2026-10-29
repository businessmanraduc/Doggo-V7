// ================================================================================
//  rf_tb -- register file against a 64-entry model
// ================================================================================
//  Random writes (enable on and off) and two independent random reads per
//  cycle; reads favour the tags written in the last two cycles.
//  Checks:
//   - chk_init: every entry reads 0 before the first write.
//   - chk_read: both ports return the model value; a write is seen from the
//   next cycle on, never in its own cycle.
//   - chk_cov: same-cycle and next-cycle reads of a written tag, on both ports.
// ================================================================================

module rf_tb;

  logic clk = 1'b0;
  always #5 clk = !clk;

  logic        ex7_wb_producer = 1'b0;
  logic [5:0]  ex7_wb_rdTag = '0, pr_rf_rs1Tag = '0, pr_rf_rs2Tag = '0;
  logic [31:0] ex7_wb_result = '0;
  logic [31:0] rf_rs1Data, rf_rs2Data;

  rf u_dut (.*);

  logic [31:0] model [64];
  int          errors = 0;
  int          cov [string];
  logic [5:0]  last [2];

  task automatic fail(string c, string m);
    errors++;
    if (errors <= 20) $display("ERROR %s %s", c, m);
  endtask

  function automatic logic [5:0] pick();
    int r = $urandom_range(9);
    return r < 3 ? last[0] : r < 5 ? last[1] : 6'($urandom);
  endfunction

  int seed;
  initial begin
    if (!$value$plusargs("seed=%d", seed)) seed = 1;
    void'($urandom(seed));

    // ---- init: all 64 entries read 0 -------------------------------------------
    for (int k = 0; k < 64; k += 2) begin
      pr_rf_rs1Tag = 6'(k); pr_rf_rs2Tag = 6'(k + 1);
      #1;
      if (rf_rs1Data !== '0 || rf_rs2Data !== '0)
        fail("chk_init", $sformatf("tags %0d %0d read %h %h", k, k + 1, rf_rs1Data, rf_rs2Data));
    end
    for (int k = 0; k < 64; k++) model[k] = '0;
    last = '{6'd0, 6'd0};

    repeat (200000) begin
      @(posedge clk); #1;
      // the write driven last cycle is now in the array
      if (ex7_wb_producer) model[ex7_wb_rdTag] = ex7_wb_result;
      last[1] = last[0];
      last[0] = ex7_wb_rdTag;

      // drive this cycle: a write (lands at the next edge) and two reads
      ex7_wb_producer = $urandom_range(3) != 0;
      ex7_wb_rdTag    = 6'($urandom);
      ex7_wb_result   = $urandom;
      pr_rf_rs1Tag    = $urandom_range(3) == 0 ? ex7_wb_rdTag : pick();
      pr_rf_rs2Tag    = $urandom_range(3) == 0 ? ex7_wb_rdTag : pick();
      #1;
      if (rf_rs1Data !== model[pr_rf_rs1Tag])
        fail("chk_read", $sformatf("rs1 tag %0d %h exp %h", pr_rf_rs1Tag, rf_rs1Data, model[pr_rf_rs1Tag]));
      if (rf_rs2Data !== model[pr_rf_rs2Tag])
        fail("chk_read", $sformatf("rs2 tag %0d %h exp %h", pr_rf_rs2Tag, rf_rs2Data, model[pr_rf_rs2Tag]));
      if (ex7_wb_producer && pr_rf_rs1Tag == ex7_wb_rdTag) cov["sameCycle1"]++;
      if (ex7_wb_producer && pr_rf_rs2Tag == ex7_wb_rdTag) cov["sameCycle2"]++;
      if (pr_rf_rs1Tag == last[0]) cov["nextCycle1"]++;
      if (pr_rf_rs2Tag == last[0]) cov["nextCycle2"]++;
      if (!ex7_wb_producer) cov["noWrite"]++;
    end

    foreach (cov[k]) $display("  cov %-12s %0d", k, cov[k]);
    if (!cov.exists("sameCycle1") || !cov.exists("sameCycle2") || !cov.exists("nextCycle1")
        || !cov.exists("nextCycle2") || !cov.exists("noWrite")) fail("chk_cov", "missing bin");
    if (errors == 0) $display("PASS  rf");
    else             $display("FAIL  rf  (%0d errors)", errors);
    $finish;
  end

endmodule
