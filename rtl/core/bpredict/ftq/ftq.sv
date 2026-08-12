// ================================================================================
//  PHANTOoOM-32 -- Fetch Target Queue
// ================================================================================
//  Decouples the predictor from the fetch engine. The predictor writes finished
//  fetch targets in here and runs ahead; the fetch engine takes them one word per
//  cycle.
//
//  --- one entry is a word pair --------------------------------------------------
//  The predictor resolves two words per cycle, and two writes to different
//  addresses need two LUTRAM write ports, which DPR16X4 does not have.
//  Because of this, a pair shares one entry and one write port:
//
//    { pcA, pcB, hwValidA, hwValidB, gshareA, gshareB, rasPtr, validB }
//
//  ---- three pointers architecture ----------------------------------------------
//    tail      where the predictor writes
//    readPtr   the word the fetch engine issues next
//    headPtr   the word the cache is currently reporting on
//
//  A cleared validB leaves a hole in the word stream. Issue and retire both
//  step over it in the same cycle they use the A word, so a hole costs no cycle.
//
//  Solo Fmax (ring-of-regs, nextpnr --85k, tw=100, 20 seeds): see fmax.md
// ================================================================================
module ftq #(
  parameter int DEPTH       = 16,
  parameter int MARGIN      = 2,
  parameter int PHT_INDEX_W = 13,
  parameter int RAS_PTR_W   = 3,
  parameter int PTR_W       = $clog2(DEPTH)
) (
  input  logic                    clk,
  input  logic                    resetn,
  input  logic                    flush,

  // ---- predictor: one finished pair per cycle ----------------------------------
  input  logic                    push,
  input  logic [31:2]             push_pcA,
  input  logic [31:2]             push_pcB,
  input  logic [1:0]              push_hwValidA,
  input  logic [1:0]              push_hwValidB,
  input  logic [PHT_INDEX_W-1:0]  push_gshareA,
  input  logic [PHT_INDEX_W-1:0]  push_gshareB,
  input  logic [RAS_PTR_W-1:0]    push_rasPtr,
  input  logic                    push_validB,
  output logic                    canPush,

  // ---- fetch engine: take an address -------------------------------------------
  output logic                    issueValid,
  output logic [31:2]             issuePC,
  input  logic                    issue,

  // ---- fetch engine: report on oldest word -------------------------------------
  output logic [31:2]             headPC,
  output logic [1:0]              headHwValid,
  output logic [PHT_INDEX_W-1:0]  headGshare,
  output logic [RAS_PTR_W-1:0]    headRasPtr,
  input  logic                    retire,
  input  logic                    replay
);

  localparam int ISSUE_W  = 30 + 30;
  localparam int RETIRE_W = 30 + 30 + 2 + 2 + PHT_INDEX_W + PHT_INDEX_W + RAS_PTR_W;

  // ---- payload: one copy per read port -----------------------------------------
  (* ram_style = "distributed" *) logic [ISSUE_W-1:0]  memIssue  [DEPTH];
  (* ram_style = "distributed" *) logic [RETIRE_W-1:0] memRetire [DEPTH];

  logic [PTR_W-1:0] tail, readPtr, headPtr;
  logic                   readSub, headSub;
  logic [PTR_W+1:0] count;                    // words not yet retired
  logic [PTR_W+1:0] unissued;                 // words not yet issued
  logic [PTR_W+1:0] pushWords;
  assign pushWords = push
    ? (push_validB ? (PTR_W+2)'(2) : (PTR_W+2)'(1))
    : (PTR_W+2)'(0);

  always_ff @(posedge clk) begin
    if (push) begin
      memIssue[tail]  <= {push_pcA, push_pcB};
      memRetire[tail] <= {
        push_pcA, push_pcB, push_hwValidA, push_hwValidB,
        push_gshareA, push_gshareB, push_rasPtr
      };
    end
  end

  // ---- issue side --------------------------------------------------------------
  (* ram_style = "distributed" *) logic memValidBIssue  [DEPTH];
  (* ram_style = "distributed" *) logic memValidBRetire [DEPTH];
  always_ff @(posedge clk) begin
    if (push) begin
      memValidBIssue[tail]  <= push_validB;
      memValidBRetire[tail] <= push_validB;
    end
  end

  logic [31:2] issuePcA, issuePcB;
  logic        issueValidB;
  assign {issuePcA, issuePcB} = memIssue[readPtr];
  assign issueValidB = memValidBIssue[readPtr];
  assign issueValid  = (unissued != '0);
  assign issuePC     = readSub ? issuePcB : issuePcA;

  logic issueLastWord; assign issueLastWord = readSub || !issueValidB;

  // ---- retire side -------------------------------------------------------------
  logic [31:2]            retirePcA, retirePcB;
  logic [1:0]             retireHwA, retireHwB;
  logic [PHT_INDEX_W-1:0] retireGsA, retireGsB;
  logic [RAS_PTR_W-1:0]   retireRas;
  logic                   retireValidB;
  assign {retirePcA, retirePcB, retireHwA, retireHwB,
          retireGsA, retireGsB, retireRas} = memRetire[headPtr];
  assign retireValidB = memValidBRetire[headPtr];

  assign headPC       = headSub ? retirePcB : retirePcA;
  assign headHwValid  = headSub ? retireHwB : retireHwA;
  assign headGshare   = headSub ? retireGsB : retireGsA;
  assign headRasPtr   = retireRas;

  logic retireLastWord; assign retireLastWord = headSub || !retireValidB;

  // ---- pointers ----------------------------------------------------------------
  always_ff @(posedge clk) begin
    if (!resetn || flush) begin
      tail    <= '0;   readPtr <= '0;   headPtr <= '0;
      readSub <= 1'b0; headSub <= 1'b0; count   <= '0; unissued <= '0;
    end else begin
      if (push) tail <= tail + PTR_W'(1);

      if (replay) begin
        readPtr  <= headPtr; readSub <= headSub;
        unissued <= count + pushWords;
      end else begin
        if (issue) begin
          if (issueLastWord) begin
            readPtr <= readPtr + PTR_W'(1);
            readSub <= 1'b0;
          end else begin
            readSub <= 1'b1;
          end
        end
        unissued <= unissued - (PTR_W+2)'(issue) + pushWords;
      end

      if (retire) begin
        if (retireLastWord) begin
          headPtr <= headPtr + PTR_W'(1);
          headSub <= 1'b0;
        end else begin
          headSub <= 1'b1;
        end
      end
      count <= count - (PTR_W+2)'(retire) + pushWords;
    end
  end

  logic [PTR_W-1:0] entriesUsed; assign entriesUsed = tail - headPtr;
  always_ff @(posedge clk) begin
    if (!resetn) canPush <= 1'b1;
    else         canPush <= (entriesUsed < PTR_W'(DEPTH - MARGIN));
  end

endmodule

