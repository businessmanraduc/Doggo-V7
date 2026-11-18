// ================================================================================
//  phantooom_core_tb -- M2 core in lockstep with Spike (test/cosim)
// ================================================================================
//  The bench is the fetch engine: it hands the image over straight through (M2
//  has no redirects), in seeded bubble modes, and holds f5_d_* while
//  stall_d_r1 is high. Each instruction handed over enters the fetch tap
//  (pc -> encoding) and the in-flight queue. Each cm_valid becomes one event:
//  encoding from the fetch tap, rd value from the RF at cm_rdTag, the M2
//  snapshot. Mid-run resets with work in flight start the program again.
//  Checks:
//   - cosim: every event against Spike.
//   - chk_order: each retire is the oldest instruction in flight.
//   - chk_rvc: cm_rvc equals the size handed over.
//   - chk_quiet: no exception, refetch, illegal, load, store, serialising or
//     system bit; cm_flush low.
//   - chk_stallEarly: stall_d_r1 holds within a cycle while f5_d_* change.
//   - chk_hang: no retire for HANG cycles with work in flight.
//   - chk_drain: the whole program retired, nothing after.
//  Plusargs: +bin= +end=<hex> [+seed= +bubble= +resets= +cov= +maxcyc=]
// ================================================================================
`include "uop_defs.svh"

module phantooom_core_tb;

  import "DPI-C" function int cosim_init(input string bin, input int ramBase, input int ramSize,
    input int entry, input string logPath);
  import "DPI-C" function int cosim_finish(input int nextPc, input int checkPc);

  localparam int RAM_BASE = 32'h8000_0000, RAM_SIZE = 32'h0200_0000, HANG = 3000;

  logic clk = 1'b0;
  always #5 clk = !clk;

  // ---- DUT ---------------------------------------------------------------------
  logic                resetn = 1'b0;
  logic                f5_d_valid = 1'b0, f5_d_rvc = 1'b0;
  logic [31:0]         f5_d_instr = '0;
  logic [30:0]         f5_d_pc = '0;
  logic [0:0]          f5_d_meta = '0;
  logic                stall_d_r1;
  logic                cm_valid, cm_exception, cm_refetch, cm_flush;
  logic [4:0]          cm_rdIndex;
  logic [5:0]          cm_rdTag, cm_rdOldTag;
  logic                cm_rdWriteEnable;
  logic [30:0]         cm_pc;
  logic                cm_rvc;
  logic [SYSTEM_W-1:0] cm_system;
  logic                cm_illegal, cm_serialising, cm_isLoad, cm_isStore;
  logic [31:0]         cm_badAddress;

  phantooom_core #(.MW(1)) u_dut (.*);

  // ---- cosim_order (no pending loads, IO or interrupts in M2) ------------------
  logic        rt_valid = 1'b0, rt_pend = 1'b0, lv_valid = 1'b0;
  logic [1:0]  rt_kind = '0, rt_memKind = '0;
  logic [31:0] rt_pc = '0, rt_insn = '0, rt_rdVal = '0;
  logic [31:0] rt_memAddr = '0, rt_memRdata = '0, rt_memWdata = '0;
  logic [4:0]  rt_rd = '0, rt_cause = '0;
  logic [2:0]  rt_memSize = '0;
  logic [31:0] rt_mip = '0, dv_lines = '0, lv_rdVal = '0, lv_word = '0;
  logic [31:0] rt_snap [9];
  logic        co_fail;
  int          co_queued;

  cosim_order u_order (.*);

  // ---- bench state -------------------------------------------------------------
  byte unsigned image [int];
  logic [31:0]  fetchTap [int];
  int           inFlight [$];
  int           errors = 0, endPc, fetchPc, programLength;
  int           bubblePct, bubbleMode, modeCyclesLeft, gapCyclesLeft;
  longint       cycleCount = 0, idleCycles = 0;
  int           eventCount = 0, retiredInRun = 0, retiredTotal = 0, retireStreak = 0, stallStreak = 0;
  logic         stallNow = 1'b0, stallAtEdge = 1'b0, running = 1'b0;
  int           cov [string];
  string        bin, covPath;

  function automatic void fail(string check, string message);
    errors++;
    if (errors <= 20) $display("ERROR %s t=%0t %s", check, $time, message);
  endfunction

  function automatic logic [31:0] imageWord(int address);
    return {image[address + 3], image[address + 2], image[address + 1], image[address]};
  endfunction

  // ---- mnemonic of an encoding (the M2 profile's set) --------------------------
  function automatic string mnemonic(logic [31:0] i, bit rvc);
    if (rvc) case ({i[1:0], i[15:13]})
      5'b00_000: return "c.addi4spn";
      5'b01_000: return i[15:0] == 16'h0001 ? "c.nop" : "c.addi";
      5'b01_001: return "c.jal";
      5'b01_010: return "c.li";
      5'b01_011: return i[11:7] == 5'd2 ? "c.addi16sp" : "c.lui";
      5'b01_100: return i[11:10] == 2'b10 ? "c.andi" : i[11:10] != 2'b11 ? "c.shift" :
                        i[6:5] == 2'b00 ? "c.sub" : i[6:5] == 2'b01 ? "c.xor" :
                        i[6:5] == 2'b10 ? "c.or" : "c.and";
      5'b01_101: return "c.j";
      5'b10_100: return i[6:2] == 5'd0 ? "c.jr" : i[12] ? "c.add" : "c.mv";
      default:   return "c.other";
    endcase
    case (i[6:0])
      7'b0110111: return "lui";
      7'b0010111: return "auipc";
      7'b1101111: return "jal";
      7'b0010011: case (i[14:12])
        3'b000: return "addi";  3'b100: return "xori";
        3'b110: return "ori";   3'b111: return "andi";
        default: return "other";
      endcase
      7'b0110011: case ({i[31:25], i[14:12]})
        10'b0000000_000: return "add";   10'b0100000_000: return "sub";
        10'b0000000_100: return "xor";   10'b0100000_100: return "xnor";
        10'b0000000_110: return "or";    10'b0100000_110: return "orn";
        10'b0000000_111: return "and";   10'b0100000_111: return "andn";
        default: return "other";
      endcase
      default: return "other";
    endcase
  endfunction

  // ---- fetch engine ------------------------------------------------------------
  function automatic bit bubble();
    if (modeCyclesLeft == 0) begin
      bubbleMode     = $urandom_range(3);
      modeCyclesLeft = $urandom_range(400, 50);
    end
    modeCyclesLeft--;
    if (gapCyclesLeft > 0) begin gapCyclesLeft--; return 1'b1; end
    case (bubbleMode)
      0: return 1'b0;                                       // dense
      1: return $urandom_range(99) < bubblePct;              // the run's base rate
      2: return $urandom_range(99) < 60;                     // sparse
      default: begin                                        // bursts of long gaps
        if ($urandom_range(99) < 5) gapCyclesLeft = $urandom_range(30, 1);
        return 1'b0;
      end
    endcase
  endfunction

  task automatic fetchNext();
    f5_d_valid = fetchPc != endPc && !bubble();
    f5_d_meta  = 1'($urandom);
    if (f5_d_valid) begin
      f5_d_instr = imageWord(fetchPc);                      // rvc: upper half is the next bytes
      f5_d_rvc   = f5_d_instr[1:0] != 2'b11;
      f5_d_pc    = fetchPc[31:1];
      fetchPc   += f5_d_rvc ? 2 : 4;
    end else begin
      f5_d_instr = $urandom;
      f5_d_rvc   = 1'($urandom);
      f5_d_pc    = 31'($urandom);
    end
  endtask

  // ---- one cycle: handoff at the edge, new inputs after the stall sample -------
  task automatic cycle();
    @(posedge clk); #1;
    cycleCount++;
    if (running && f5_d_valid && !stallAtEdge) begin
      int handoffPc = {f5_d_pc, 1'b0};
      fetchTap[handoffPc] = f5_d_rvc ? {16'h0, f5_d_instr[15:0]} : f5_d_instr;
      inFlight.push_back(handoffPc);
      cov[mnemonic(fetchTap[handoffPc], f5_d_rvc)]++;
      if (!f5_d_rvc && f5_d_instr[11:7] == 5'd0 && f5_d_instr[6:0] != 7'b1101111) cov["x0dest"]++;
    end
    if (running && f5_d_valid && stallAtEdge) cov["stallHeld"]++;
    stallStreak = stallAtEdge && f5_d_valid ? stallStreak + 1 : 0;
    if (stallStreak == 8) cov["longStall"]++;
    stallNow = stall_d_r1;
    #1;
    if (!running) f5_d_valid = 1'b0;
    else if (!(f5_d_valid && stallAtEdge)) fetchNext();
    #6;
    if (running && stall_d_r1 !== stallNow) fail("chk_stallEarly", "stall_d_r1 moved within the cycle");
    stallAtEdge = stall_d_r1;
  endtask

  // ---- retire tap: cm_* are flops, read on the negative edge -------------------
  always @(negedge clk) begin
    rt_valid = 1'b0;
    if (running && cm_flush) fail("chk_quiet", "cm_flush");
    if (running && cm_valid) begin
      int retirePc = {cm_pc, 1'b0};
      if (cm_exception || cm_refetch || cm_illegal || cm_isLoad || cm_isStore ||
          cm_serialising || |cm_system)
        fail("chk_quiet", $sformatf("pc %h exc %b ref %b ill %b ld %b st %b ser %b sys %b", retirePc,
             cm_exception, cm_refetch, cm_illegal, cm_isLoad, cm_isStore, cm_serialising, cm_system));
      if (inFlight.size() == 0)
        fail("chk_order", $sformatf("retire %h with nothing handed over", retirePc));
      else if (inFlight[0] != retirePc)
        fail("chk_order", $sformatf("retire %h, oldest handed %h", retirePc, inFlight[0]));
      else begin
        void'(inFlight.pop_front());
        if (cm_rvc !== (fetchTap[retirePc][1:0] != 2'b11))
          fail("chk_rvc", $sformatf("pc %h cm_rvc %b", retirePc, cm_rvc));
      end
      eventCount++;
      retiredInRun++;
      rt_valid = 1'b1;
      rt_pc    = retirePc;
      rt_insn  = fetchTap.exists(retirePc) ? fetchTap[retirePc] : 32'h0;
      rt_rd    = cm_rdWriteEnable ? cm_rdIndex : 5'd0;
      rt_rdVal = cm_rdWriteEnable ? u_dut.u_ex.u_regfile.rf_regs[cm_rdTag] : 32'h0;
      rt_snap  = '{32'h0000_1800, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'(eventCount), 32'h0};
      retireStreak++;
      if (retireStreak == 16) cov["retireRun16"]++;
      idleCycles = 0;
    end else begin
      retireStreak = 0;
      if (inFlight.size() != 0) idleCycles++;
    end
  end

  // ---- one run: reset, Spike set up, fetch to _end or to the abort point -------
  task automatic run(int abortAfter);
    longint runStart;
    running = 1'b0;
    resetn = 1'b0;
    repeat ($urandom_range(4, 1)) cycle();
    fetchTap.delete();
    inFlight.delete();
    eventCount = 0; retiredInRun = 0; idleCycles = 0; stallAtEdge = 1'b0;
    modeCyclesLeft = 0; gapCyclesLeft = 0;
    if (cosim_init(bin, RAM_BASE, RAM_SIZE, RAM_BASE, "") != 0) $fatal(1, "cosim_init");
    fetchPc = RAM_BASE;
    @(posedge clk); #1 resetn = 1'b1; running = 1'b1;
    runStart = cycleCount;
    forever begin
      cycle();
      if (co_fail || errors > 20) break;
      if (idleCycles > HANG) begin
        fail("chk_hang", $sformatf("%0d in flight", inFlight.size()));
        break;
      end
      if (abortAfter > 0 && retiredInRun >= abortAfter) begin
        if (inFlight.size() != 0) cov["resetInFlight"]++;
        break;
      end
      if (abortAfter == 0 && fetchPc == endPc && !f5_d_valid && inFlight.size() == 0) break;
    end
    if (abortAfter == 0 && !co_fail) begin
      repeat (32) cycle();
      if (inFlight.size() != 0) fail("chk_drain", $sformatf("%0d never retired", inFlight.size()));
      if (retiredInRun != programLength)
        fail("chk_drain", $sformatf("retired %0d of %0d", retiredInRun, programLength));
    end
    retiredTotal += retiredInRun;
    $display("run: %0d retired in %0d cycles (IPC %0.3f)%s", retiredInRun, cycleCount - runStart,
             real'(retiredInRun) / real'(cycleCount - runStart),
             abortAfter > 0 ? ", reset with work in flight" : "");
  endtask

  int seed, resets, maxCycles, file, imageSize, address;
  byte unsigned imageByte;
  initial begin
    if (!$value$plusargs("bin=%s", bin)) $fatal(1, "+bin=");
    if (!$value$plusargs("end=%h", endPc)) $fatal(1, "+end=");
    if (!$value$plusargs("seed=%d", seed)) seed = 1;
    if (!$value$plusargs("bubble=%d", bubblePct)) bubblePct = 10;
    if (!$value$plusargs("resets=%d", resets)) resets = 2;
    if (!$value$plusargs("cov=%s", covPath)) covPath = "";
    if (!$value$plusargs("maxcyc=%d", maxCycles)) maxCycles = 2000000;
    void'($urandom(seed));
    file = $fopen(bin, "rb");
    if (file == 0) $fatal(1, "cannot open %s", bin);
    imageSize = 0;
    while ($fread(imageByte, file) == 1) begin image[RAM_BASE + imageSize] = imageByte; imageSize++; end
    $fclose(file);
    for (int k = 0; k < 4; k++) image[RAM_BASE + imageSize + k] = 8'h0;
    programLength = 0;
    address = RAM_BASE;
    while (address != endPc) begin address += (image[address] & 3) != 3 ? 2 : 4; programLength++; end

    fork
      begin
        for (int r = 0; r < resets && !co_fail && errors == 0; r++)
          run($urandom_range(programLength * 9 / 10, 1));
        if (!co_fail && errors == 0) run(0);
      end
      begin
        wait (cycleCount > maxCycles);
        fail("chk_hang", "maxcyc");
      end
    join_any

    if (covPath != "") begin
      file = $fopen(covPath, "w");
      foreach (cov[key]) $fdisplay(file, "%s %0d", key, cov[key]);
      $fclose(file);
    end
    if (cosim_finish(endPc, !co_fail && errors == 0 && retiredInRun == programLength) != 0 || co_fail)
      fail("cosim", "lockstep mismatch");
    if (errors == 0) $display("PASS  phantooom_core (%0d retired, %0d resets)", retiredTotal, resets);
    else             $display("FAIL  phantooom_core (%0d errors)", errors);
    $finish;
  end

endmodule
