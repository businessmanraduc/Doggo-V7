// ================================================================================
//  refdut_tb -- stand-in core (refdut.cc) -> cosim_order -> cosim.cc
// ================================================================================
//  Retires the stand-in's events at a random rate, cacheable loads pending at a
//  random rate (IO loads always, 0042), late values after a random delay.
//  Plusargs: +bin= [+entry= +tohost= (hex)] [+seed= +irq= +drift= +rtpct= +pendpct=
//  +maxlate= +maxcyc=] [+fault= +faultat= +svfault= +expectfail +nooverride
//  +noprofile] [+reflog= +duplog= +cov=]
// ================================================================================
module refdut_tb;

  import "DPI-C" function int refdut_init(input string bin, input int ramBase, input int ramSize,
    input int entry, input int tohost, input int seed, input int rate, input int drift,
    input string logPath);
  import "DPI-C" function int refdut_next(output int kind, output int pc, output int insn,
    output int rd, output int rdVal, output int memKind, output int memAddr, output int memSize,
    output int memRdata, output int memWdata, output int cause, output int mip, output int snap[9]);
  import "DPI-C" function void refdut_fault(input int kind, input int at);
  import "DPI-C" function int refdut_faultHit();
  import "DPI-C" function int refdut_exitCode();
  import "DPI-C" function int refdut_pc();
  import "DPI-C" function int refdut_lines();
  import "DPI-C" function int cosim_init(input string bin, input int ramBase, input int ramSize,
    input int entry, input string logPath);
  import "DPI-C" function int cosim_finish(input int nextPc, input int checkPc);
  import "DPI-C" function void cosim_report(input string path);
  import "DPI-C" function void cosim_knob(input string name, input int v);

  localparam int RAM_BASE = 32'h8000_0000, RAM_SIZE = 32'h0200_0000;

  logic clk = 1'b0, resetn = 1'b0;
  always #5 clk = !clk;

  logic        rt_valid, rt_pend, lv_valid;
  logic [1:0]  rt_kind, rt_memKind;
  logic [31:0] rt_pc, rt_insn, rt_rdVal, rt_memAddr, rt_memRdata, rt_memWdata;
  logic [4:0]  rt_rd, rt_cause;
  logic [2:0]  rt_memSize;
  logic [31:0] rt_mip, rt_snap [9];
  logic [31:0] lv_rdVal, lv_word, dv_lines = '0;
  logic        co_fail;
  int          co_queued;

  cosim_order u_order (.*);

  string bin, refLog, dutLog, covPath;
  int    entry, tohost, seed, irqRate, driftRate, retirePct, pendPct, maxLate, maxCycles;
  int    fault, faultAt, svFault;
  bit    expectFail;

  // the stand-in's next event, held until it retires
  bit    haveNext, programEnded, lateSpurious;
  int    nextKind, nextPc, nextInsn, nextRd, nextRdVal, nextMemKind, nextMemAddr, nextMemSize;
  int    nextMemRdata, nextMemWdata, nextCause, nextMip, nextSnap [9];
  // the pending load
  bit    loadPending;
  int    lateAt, pendingRdVal, pendingWord;
  int    cycle, pendingLoads, pendingIoLoads, lateInRetireCycle, svFaultDone;

  function automatic bit inRam(int address);
    return address >= RAM_BASE && address < RAM_BASE + RAM_SIZE;
  endfunction

  initial begin
    if (!$value$plusargs("bin=%s", bin)) $fatal(1, "+bin= missing");
    if (!$value$plusargs("entry=%h", entry)) entry = RAM_BASE;
    if (!$value$plusargs("tohost=%h", tohost)) tohost = 0;
    if (!$value$plusargs("seed=%d", seed)) seed = 1;
    if (!$value$plusargs("irq=%d", irqRate)) irqRate = 0;
    if (!$value$plusargs("drift=%d", driftRate)) driftRate = 0;
    if (!$value$plusargs("rtpct=%d", retirePct)) retirePct = 70;
    if (!$value$plusargs("pendpct=%d", pendPct)) pendPct = 20;
    if (!$value$plusargs("maxlate=%d", maxLate)) maxLate = 30;
    if (!$value$plusargs("fault=%d", fault)) fault = 0;
    if (!$value$plusargs("faultat=%d", faultAt)) faultAt = 0;
    if (!$value$plusargs("svfault=%d", svFault)) svFault = 0;
    if (!$value$plusargs("maxcyc=%d", maxCycles)) maxCycles = 50_000_000;
    if (!$value$plusargs("reflog=%s", refLog)) refLog = "";
    if (!$value$plusargs("duplog=%s", dutLog)) dutLog = "";
    expectFail = $test$plusargs("expectfail");
    void'($urandom(seed));
    if (refdut_init(bin, RAM_BASE, RAM_SIZE, entry, tohost, seed, irqRate, driftRate, dutLog) != 0)
      $fatal(1, "refdut_init");
    if ($test$plusargs("nooverride")) cosim_knob("override", 0);
    if ($test$plusargs("noprofile")) cosim_knob("profile", 0);
    if (cosim_init(bin, RAM_BASE, RAM_SIZE, entry, refLog) != 0) $fatal(1, "cosim_init");
    if (fault != 0) refdut_fault(fault, faultAt);
    rt_valid = 1'b0;
    lv_valid = 1'b0;
    repeat (3) @(posedge clk);
    resetn = 1'b1;
  end

  // ---- retire and late ports, driven on the negative edge ----------------------
  always @(negedge clk) if (resetn) begin
    rt_valid = 1'b0;
    rt_pend  = 1'b0;
    lv_valid = 1'b0;
    lateSpurious = 1'b0;
    cycle++;
    if (loadPending && cycle >= lateAt) begin
      if (!(svFault == 2 && svFaultDone == 0)) begin
        lv_valid = 1'b1;
        lv_rdVal = pendingRdVal ^ ((svFault == 1 && svFaultDone == 0) ? 1 : 0);
        lv_word  = pendingWord ^ ((svFault == 5 && svFaultDone == 0 && pendingIoLoads > 0) ? 32'h10 : 0);
        if (svFault == 1 || (svFault == 5 && pendingIoLoads > 0)) svFaultDone = 1;
      end else begin
        svFaultDone = 1;
      end
      loadPending = 1'b0;
    end
    if (svFault == 3 && svFaultDone == 0 && cycle >= 200 && !loadPending && !lv_valid) begin
      lv_valid = 1'b1;
      svFaultDone = 1;
      lateSpurious = 1'b1;
    end
    if (!haveNext && !programEnded) begin
      if (refdut_next(nextKind, nextPc, nextInsn, nextRd, nextRdVal, nextMemKind, nextMemAddr,
                      nextMemSize, nextMemRdata, nextMemWdata, nextCause, nextMip, nextSnap) != 0)
        programEnded = 1'b1;
      dv_lines = refdut_lines();
      haveNext = 1'b1;
    end
    // an IO load behind a pending load waits
    if (haveNext && !lateSpurious && $urandom % 100 < retirePct &&
        !(nextKind == 0 && nextMemKind == 1 && !inRam(nextMemAddr) && loadPending &&
          !(svFault == 4 && svFaultDone == 0))) begin
      haveNext = 1'b0;
      rt_valid = 1'b1;
      rt_kind = nextKind[1:0]; rt_pc = nextPc; rt_insn = nextInsn; rt_rd = nextRd[4:0];
      rt_rdVal = nextRdVal; rt_memKind = nextMemKind[1:0]; rt_memAddr = nextMemAddr;
      rt_memSize = nextMemSize[2:0]; rt_memRdata = nextMemRdata; rt_memWdata = nextMemWdata;
      rt_cause = nextCause[4:0]; rt_mip = nextMip;
      if (svFault == 7 && svFaultDone == 0 && (nextMip & 32'h800)) begin
        rt_mip = nextMip & ~32'h800;
        svFaultDone = 1;
      end
      for (int i = 0; i < 9; i++) rt_snap[i] = nextSnap[i];
      if (nextKind == 0 && nextMemKind == 1 && (!loadPending || (svFault == 4 && svFaultDone == 0)) &&
          (!inRam(nextMemAddr) || $urandom % 100 < pendPct)) begin
        if (loadPending) svFaultDone = 1;
        rt_pend      = 1'b1;
        loadPending  = 1'b1;
        pendingRdVal = nextRdVal;
        pendingWord  = nextMemRdata;
        rt_rdVal     = 32'hdead_beef;
        rt_memRdata  = 32'hdead_beef;
        lateAt       = cycle + $urandom % maxLate;
        pendingLoads++;
        if (!inRam(nextMemAddr)) pendingIoLoads++;
      end
    end
    if (loadPending && cycle >= lateAt && !lv_valid && svFault != 2) begin
      lv_valid = 1'b1;
      lv_rdVal = pendingRdVal ^ ((svFault == 1 && svFaultDone == 0) ? 1 : 0);
      lv_word  = pendingWord;
      if (svFault == 1) svFaultDone = 1;
      loadPending = 1'b0;
      lateInRetireCycle++;
    end
  end

  // ---- end of program ----------------------------------------------------------
  always @(posedge clk) begin
    int failed, exitCode;
    if (co_fail || (programEnded && !haveNext && !loadPending && co_queued == 0 && !rt_valid) ||
        cycle > maxCycles) begin
      @(posedge clk);
      failed = cosim_finish(refdut_pc() + ((svFault == 6) ? 4 : 0),
                            int'(programEnded && !co_fail && co_queued == 0));
      exitCode = refdut_exitCode();
      if ($value$plusargs("cov=%s", covPath)) cosim_report(covPath);
      if (programEnded && loadPending) failed = 1;
      if (!programEnded) begin
        $display("refdut_tb: program did not end (%0d cycles)", cycle);
        failed = 1;
      end
      if (co_queued != 0 && !co_fail) begin
        $display("refdut_tb: %0d events never reached the checker (pending load not resolved)",
                 co_queued);
        failed = 1;
      end
      $write("refdut_tb: %0d pending loads (%0d IO, %0d late value in the retire cycle), ",
             pendingLoads, pendingIoLoads, lateInRetireCycle);
      $display("exit code %0d, fault hit %0d/%0d", exitCode, refdut_faultHit(), svFaultDone);
      if (expectFail && failed != 0)  $display("PASS (expected failure seen)");
      else if (expectFail)            $display("FAIL (expected a failure, none seen)");
      else if (failed == 0 && exitCode == (tohost != 0 ? 1 : 0)) $display("PASS");
      else                            $display("FAIL");
      $finish;
    end
  end

endmodule
