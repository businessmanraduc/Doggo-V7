// ================================================================================
//  PHANTOoOM-32 -- Branch Predict Engine
// ================================================================================
//  Runs free of the fetch engine. Resolves one word pair per cycle and writes
//  finished fetch targets into the FTQ for the fetch engine to take them at
//  its own pace.
//
//  --- stage map -----------------------------------------------------------------
//    P0  nextPC issued as a pair {pcA, pcA+4}. Both BTB banks and both PHT slots
//        are armed, and the history and stack pointer are snapshotted.
//    P1  reads in flight, snapshots ride along.
//    P2  entries and counters land. Both verdicts are formed, then registered.
//    P3  the verdict is applied: NextPC mux, history shift, stack push/pop, and
//        one finished FTQ entry is written for the pair issued at P0.
//
//  ---- slot priority ------------------------------------------------------------
//  A taken A surpresses B, because B is then the wrong path. Two consequences fall:
//    - a call or return is unconditional, so a slot holding one is always taken
//      on a hit, so B can never also want the stack.
//    - the stack pointer is therefore the same for both words of a pair.
//
//  ---- straddles ----------------------------------------------------------------
//  A straddling branch owns the high half of its word and the low half of the
//  next. In the A slot the tail is B, which is in the same bundle, so B stays live
//  and the redirect simply lands on the following pair. In the B slot the tail is
//  the next pair's A word, which needs the one-pair hand-off.
//
//  ---- history ------------------------------------------------------------------
//  Both slots index the PHT with the same history. B's index does not include A's
//  direction, which is not known when the pair is armed. That costs B one branch
//  of freshness and saves a third candidate read plus a three-way late mux
//  in the P2 cone.
//  The history is speculative also. The backend keeps the true one and hands
//  it back with every redirect, along with the stack pointer.
//
//  Solo Fmax (ring-of-regs, nextpnr --85k, tw=100, 20 seeds): see fmax.md
// ================================================================================
module bpredict #(
  parameter int          BTB_INDEX_W = 9,
  parameter int          PHT_INDEX_W = 13,
  parameter int          BHR_W       = 24,
  parameter int          TAG_W       = 11,
  parameter int          RAS_DEPTH   = 8,
  parameter int          RAS_PTR_W   = 3,
  parameter int          FTQ_DEPTH   = 32,
  parameter int          FTQ_MARGIN  = 12,
  parameter logic [31:0] RESET_PC    = 32'h0000_0000
) (
  input  logic                    clk,
  input  logic                    resetn,

  // ---- backend redirect --------------------------------------------------------
  input  logic                    redirectValid,
  input  logic [31:0]             redirectPC,
  input  logic [BHR_W-1:0]        redirectBHR,
  input  logic [RAS_PTR_W-1:0]    redirectRasPtr,

  // ---- predictor update --------------------------------------------------------
  input  logic                    btbWrEnable,
  input  logic                    btbWrBank,
  input  logic [BTB_INDEX_W-1:0]  btbWrIndex,
  input  logic [53:0]             btbWrEntry,
  input  logic                    phtWrEnable,
  input  logic [PHT_INDEX_W-1:0]  phtWrIndex,
  input  logic [1:0]              phtWrCounter,

  // ---- fetch engine: take an address -------------------------------------------
  output logic                    issueValid,
  output logic [31:2]             issuePC,
  input  logic                    issue,

  // ---- fetch engine: report on the oldest word ---------------------------------
  output logic [31:2]             headPC,
  output logic [1:0]              headHwValid,
  output logic [PHT_INDEX_W-1:0]  headGshare,
  output logic [RAS_PTR_W-1:0]    headRasPtr,
  input  logic                    retire,
  input  logic                    replay
);

  logic boot;   assign boot   = ~resetn;
  logic squash; assign squash = boot || redirectValid;

  // ---- throttle ----------------------------------------------------------------
  logic canPush, canIssue, redirectNow, issuePair;
  always_ff @(posedge clk) canIssue <= canPush;
  assign issuePair = redirectNow || canIssue;

  // ==============================================================================
  // P0 -- issue the pair, arm both memories
  // ==============================================================================
    logic [31:0]            nextPC;
    logic [31:0]            pcA, pcB;
    logic [BHR_W-1:0]       branchHistory;
    logic [PHT_INDEX_W-1:0] gshareA, gshareB;
    logic [RAS_PTR_W-1:0]   rasPtr;

    assign pcA = {nextPC[31:2], 2'b00};
    assign pcB = pcA + 32'd4;

    // ---- group history ---------------------------------------------------------
    logic pcHash; assign pcHash = pcA[3] ^ pcA[6] ^ pcA[10] ^ pcA[14];

    logic [BHR_W-1:0] bhrNotTaken; assign bhrNotTaken = {branchHistory[BHR_W-2:0],  pcHash};
    logic [BHR_W-1:0] bhrTaken;    assign bhrTaken    = {branchHistory[BHR_W-2:0], ~pcHash};

    logic [PHT_INDEX_W-1:0] foldedHistory; assign foldedHistory =
      branchHistory[PHT_INDEX_W-1:0] ^ PHT_INDEX_W'(branchHistory[BHR_W-1:PHT_INDEX_W]);
    assign gshareA = pcA[PHT_INDEX_W+1:2] ^ foldedHistory;
    assign gshareB = pcB[PHT_INDEX_W+1:2] ^ foldedHistory;
  // ==============================================================================
  // P0
  // ==============================================================================


  // ==============================================================================
  // P0 -> P2 -- reads in flight, the pair's own metadata riding alongside
  // ==============================================================================
    logic                   valid_P0,   valid_P1,   valid_P2, valid_P2b;
    logic [31:2]            pcA_P1,     pcA_P2,     pcA_P2b;
    logic                   startHi_P1, startHi_P2, startHi_P2b;
    logic [PHT_INDEX_W-1:0] gsA_P1,     gsA_P2,     gsA_P2b;
    logic [PHT_INDEX_W-1:0] gsB_P1,     gsB_P2,     gsB_P2b;
    logic [RAS_PTR_W-1:0]   ras_P1,     ras_P2,     ras_P2b;
    logic [BHR_W-1:0]       bhrT_P1,    bhrT_P2,    bhrT_P2b, bhrT_P3;

    always_ff @(posedge clk) begin
      valid_P0 <= issuePair;
      if (redirectNow) begin
        valid_P1   <= 1'b0;     valid_P2    <= 1'b0;       valid_P2b   <= 1'b0;
      end else begin
        valid_P1   <= valid_P0; valid_P2    <= valid_P1;   valid_P2b   <= valid_P2;
      end
      begin
        pcA_P1     <= pcA[31:2]; pcA_P2     <= pcA_P1;     pcA_P2b     <= pcA_P2;
        startHi_P1 <= nextPC[1]; startHi_P2 <= startHi_P1; startHi_P2b <= startHi_P2;
        gsA_P1     <= gshareA;   gsA_P2     <= gsA_P1;     gsA_P2b     <= gsA_P2;
        gsB_P1     <= gshareB;   gsB_P2     <= gsB_P1;     gsB_P2b     <= gsB_P2;
        ras_P1     <= rasPtr;    ras_P2     <= ras_P1;     ras_P2b     <= ras_P2;
        bhrT_P1    <= bhrTaken;  bhrT_P2    <= bhrT_P1;    bhrT_P2b    <= bhrT_P2;
      end
    end

    // ---- BTB: one lookup per bank, back in program order -----------------------
    logic        tagMatchA, takenOnHitA, condOnHitA, straddleA, exitLowA, callA, returnA;
    logic        tagMatchB, takenOnHitB, condOnHitB, straddleB, exitLowB, callB, returnB;
    logic [31:0] btbTargetA, btbTargetB;

    btb #(.INDEX_W(BTB_INDEX_W), .TAG_W(TAG_W)) u_btb (
      .clk, .readEnable(1'b1),
      .lookupPcA(pcA), .lookupPcB(pcB),
      .wrEnable(btbWrEnable), .wrBank(btbWrBank),
      .wrIndex(btbWrIndex), .wrEntry(btbWrEntry),
      .tagMatchA, .takenOnHitA, .condOnHitA,
      .isStraddleA(straddleA), .exitAfterLowA(exitLowA),
      .isCallA(callA), .isReturnA(returnA), .targetA(btbTargetA),
      .tagMatchB, .takenOnHitB, .condOnHitB,
      .isStraddleB(straddleB), .exitAfterLowB(exitLowB),
      .isCallB(callB), .isReturnB(returnB), .targetB(btbTargetB)
    );

    // ---- PHT: both slots share the history, so neither resolve bit is pending ----
    logic phtTakenA, phtTakenB;
    pht #(.INDEX_W(PHT_INDEX_W)) u_pht (
      .clk, .readEnable(1'b1),
      .indexA(gshareA), .indexB(gshareB),
      .resolveA(1'b0),  .resolveB(1'b0),
      .wrEnable(phtWrEnable), .wrIndex(phtWrIndex), .wrCounter(phtWrCounter),
      .takenA(phtTakenA), .takenB(phtTakenB)
    );
  // ==============================================================================
  // P0 -> P2
  // ==============================================================================


  // ==============================================================================
  // P2 -- form both verdicts, then register them
  // ==============================================================================
    // P2a: land the memory outputs, form nothing ---------------------------------
    logic        tagQA,      tagQB,      firesQA, firesQB, condQA,   condQB;
    logic        straddleQA, straddleQB, callQA,  callQB,  returnQA, returnQB;
    logic        exitLowQA,  exitLowQB,  dirQA,   dirQB;
    logic [31:0] targetQA,   targetQB;

    logic firesA; assign firesA = takenOnHitA || (condOnHitA && phtTakenA);
    logic firesB; assign firesB = takenOnHitB || (condOnHitB && phtTakenB);

    logic [31:0] rasTop;
    logic [31:0] targetSelA; assign targetSelA = returnA ? rasTop : btbTargetA;
    logic [31:0] targetSelB; assign targetSelB = returnB ? rasTop : btbTargetB;

    always_ff @(posedge clk) begin
      tagQA      <= tagMatchA;   tagQB      <= tagMatchB;
      firesQA    <= firesA;      firesQB    <= firesB;
      condQA     <= condOnHitA;  condQB     <= condOnHitB;
      straddleQA <= straddleA;   straddleQB <= straddleB;
      callQA     <= callA;       callQB     <= callB;
      returnQA   <= returnA;     returnQB   <= returnB;
      exitLowQA  <= exitLowA;    exitLowQB  <= exitLowB;
      dirQA      <= phtTakenA;   dirQB      <= phtTakenB;
      targetQA   <= targetSelA;  targetQB   <= targetSelB;
    end

    // ---- P2b: the verdict, entirely from registers (fmax-directed) -------------
    logic verdictValid; assign verdictValid = valid_P2b && !redirectNow;
    logic predTakenA;   assign predTakenA   = verdictValid && tagQA && firesQA;
    logic slotBLive;    assign slotBLive    = !predTakenA || straddleQA;
    logic predTakenB;   assign predTakenB   =
      slotBLive && verdictValid && tagQB && firesQB && !straddleQB;

    logic        taken_P3,   push_P3,   pop_P3,    write_P3;
    logic        exitLow_P3, validB_P3, aTaken_P3;
    logic [31:0] targetA_P3, targetB_P3;
    logic [31:2] pcA_P3,     pcA_P3Plus1, pcA_P3Plus2;
    logic        startHi_P3;
    logic [PHT_INDEX_W-1:0] gsA_P3, gsB_P3;
    logic [RAS_PTR_W-1:0]   ras_P3;

    always_ff @(posedge clk) begin
      if (squash) begin
        taken_P3 <= 1'b0; push_P3 <= 1'b0; pop_P3 <= 1'b0; write_P3 <= 1'b0;
      end else begin
        taken_P3 <= predTakenA || predTakenB;
        push_P3  <= (predTakenA && callQA)   || (predTakenB && callQB);
        pop_P3   <= (predTakenA && returnQA) || (predTakenB && returnQB);
        write_P3 <= verdictValid;
      end
      begin
        targetA_P3    <= targetQA;
        targetB_P3    <= targetQB;
        aTaken_P3     <= predTakenA;
        validB_P3     <= slotBLive;
        exitLow_P3    <= predTakenA ? exitLowQA : exitLowQB;
        pcA_P3        <= pcA_P2b;
        pcA_P3Plus1   <= pcA_P2b + 30'd1;
        pcA_P3Plus2   <= pcA_P2b + 30'd2;
        startHi_P3    <= startHi_P2b;
        gsA_P3        <= gsA_P2b;
        gsB_P3        <= gsB_P2b;
        ras_P3        <= ras_P2b;
        bhrT_P3       <= bhrT_P2b;
      end
    end
  // ==============================================================================
  // P2
  // ==============================================================================


  // ==============================================================================
  // P3 -- apply the verdict, finish the FTQ entries for the pair issued at P0
  // ==============================================================================
    // ---- NextPC mux: four ways, every input a flop/plain adder -----------------
    logic [31:0] externalPC;    assign externalPC  = boot ? RESET_PC : redirectPC;
    logic        selExternal;   assign selExternal = boot || redirectValid;
    logic [31:0] seqNextPC;     assign seqNextPC   = pcA + 32'd8;
    logic [31:0] appliedTarget; assign appliedTarget = aTaken_P3 ? targetA_P3 : targetB_P3;
    assign redirectNow = boot || redirectValid || taken_P3;

    logic [31:0] combNextPC; assign combNextPC =
      selExternal ? externalPC    :
      taken_P3    ? appliedTarget :
    seqNextPC;

    // ---- branch history: one bit per issued pair, repaired on a taken redirect
    always_ff @(posedge clk) if (issuePair) nextPC <= combNextPC;
    always_ff @(posedge clk) begin
      if (boot)           branchHistory <= '0;
      else if (redirectValid) branchHistory <= redirectBHR;
      else if (taken_P3)      branchHistory <= bhrT_P3;
      else if (issuePair)     branchHistory <= bhrNotTaken;
    end

    // ---- return address stack --------------------------------------------------
    logic [31:2] retWord; assign retWord = aTaken_P3
      ? (exitLow_P3 ? pcA_P3      : pcA_P3Plus1)
      : (exitLow_P3 ? pcA_P3Plus1 : pcA_P3Plus2);
    logic [31:0] callReturnPC; assign callReturnPC = {retWord, exitLow_P3, 1'b0};

    ras #(.DEPTH(RAS_DEPTH), .PTR_W(RAS_PTR_W)) u_ras (
      .clk, .boot,
      .restore(redirectValid), .restorePtr(redirectRasPtr),
      .enable(1'b1), .push(push_P3), .pop(pop_P3), .pushAddr(callReturnPC),
      .top(rasTop), .ptr(rasPtr)
    );

    // ---- fetch target queue ----------------------------------------------------
    logic [1:0] hwValidA, hwValidB;
    assign hwValidA = { ~(aTaken_P3  && taken_P3 && exitLow_P3), ~startHi_P3 };
    assign hwValidB = { ~(!aTaken_P3 && taken_P3 && exitLow_P3), 1'b1         };

    ftq #(.DEPTH(FTQ_DEPTH), .MARGIN(FTQ_MARGIN),
          .PHT_INDEX_W(PHT_INDEX_W), .RAS_PTR_W(RAS_PTR_W)) u_ftq (
      .clk, .resetn, .flush(redirectValid),
      .push(write_P3),
      .push_pcA(pcA_P3), .push_pcB(pcA_P3 + 30'd1),
      .push_hwValidA(hwValidA), .push_hwValidB(hwValidB),
      .push_gshareA(gsA_P3), .push_gshareB(gsB_P3),
      .push_rasPtr(ras_P3), .push_validB(validB_P3),
      .canPush(canPush),
      .issueValid, .issuePC, .issue,
      .headPC, .headHwValid, .headGshare, .headRasPtr, .retire, .replay
    );

  // ==============================================================================
  // P3
  // ==============================================================================

endmodule

