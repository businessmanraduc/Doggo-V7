// ================================================================================
//  PHANTOoOM-32 -- Fetch Queue
// ================================================================================
//  Decouples the fetch pipeline from decode. One entry per 32-bit cache word,
//  carrying its own PC so nothing downstream has to reconstruct it.
//
//    entry A = { pc[31:2], hwValid[1:0], gshare[12:0], word[31:0] }
//    entry B = { pc[31:2], hwValid[1:0], word[31:0] }
//
//  gshare is the PHT index the predictor used for this word.
//  hwValid is the halfword-valid mask the predictor published for this word:
//    11  both halves live          01  stream exits after the low half
//    10  entered at the high half  00  dead word
//
//  A dead word is dropped at the push port rather than stored, so align only
//  ever sees entries with at least one live halfword.
//
//  Up to two entries retire per cycle: a straddling instruction consumes the
//  low half of the second entry, and when that was its only live half, both
//  entries are finished together.
//
//  Two entries are visible at once (head and head+1) because of the possibility
//  that a 32-bit instruction might straddle a word boundary. The second read
//  port is a replicated LUTRAM copy, without a second write port needed.
//
//  canFetch throttles F0 directly, effectively telling the fetch pipeline
//  that it can only continue presenting new data while more than FETCH_LATENCY
//  slots are free. After a flush the in-flight lookups still land, so their
//  pushes are dropped for FETCH_LATENCY cycles.
//
//  Solo Fmax (ring-of-regs, nextpnr --85k, tw=100, 20 seeds): see fmax.md
// ================================================================================
module fetch_queue #(
  parameter int DEPTH         = 16,
  parameter int FETCH_LATENCY = 4,
  parameter int IDX_W         = $clog2(DEPTH)
) (
  input  logic        clk,
  input  logic        resetn,
  input  logic        flush,      // redirect: drop the queue and the shadow

  // ---- push: from the cache's F3, one word per hit -----------------------------
  input  logic        push_valid,
  input  logic [31:2] push_pc,
  input  logic [1:0]  push_hwValid,
  input  logic [12:0] push_gshare,
  input  logic [31:0] push_word,

  // ---- credit: back to F0 ------------------------------------------------------
  output logic        canFetch,

  // ---- pop: two entries visible to align, at most one taken --------------------
  output logic        pop_validA,
  output logic [31:2] pop_pcA,
  output logic [1:0]  pop_hwValidA,
  output logic [12:0] pop_gshareA,
  output logic [31:0] pop_wordA,
  output logic        pop_validB,
  output logic [31:2] pop_pcB,
  output logic [1:0]  pop_hwValidB,
  output logic [31:0] pop_wordB,
  input  logic [1:0]  pop_take
);

  localparam int PC_W      = 30;
  localparam int GSHARE_W  = 13;
  localparam int ENTRY_A_W = PC_W + 2 + GSHARE_W + 32;
  localparam int ENTRY_B_W = PC_W + 2 + 32;

  logic [IDX_W-1:0] head, tail, aheadIdx;
  logic [IDX_W:0]   count;
  logic             doPush, dropPush;
  logic [1:0]       popCount;

  // ---- flush shadow: swallow lookups that were already in-flight ---------------
  logic [FETCH_LATENCY-1:0] flushShadow;
  always_ff @(posedge clk) begin
    if (!resetn)    flushShadow <= '0;
    else if (flush) flushShadow <= '1;
    else            flushShadow <= flushShadow >> 1;
  end
  assign dropPush = |flushShadow;

  // ---- handshakes --------------------------------------------------------------
  assign doPush     = push_valid && !dropPush && !count[IDX_W] && (push_hwValid != 2'b00);
  assign pop_validA = (count != '0);
  assign pop_validB = |count[IDX_W:1];
  assign popCount   =
    (pop_take[1] && pop_validB) ? 2'd2 :
    (|pop_take   && pop_validA) ? 2'd1 :
  2'd0;
  assign canFetch   = (count <= (IDX_W+1)'(DEPTH - FETCH_LATENCY - 1));

  // ---- payload: one copy per read port -----------------------------------------
  (* ram_style = "distributed" *) logic [ENTRY_A_W-1:0] memA [DEPTH];
  (* ram_style = "distributed" *) logic [ENTRY_B_W-1:0] memB [DEPTH];

  always_ff @(posedge clk) begin
    if (doPush) begin
      memA[tail] <= {push_pc, push_hwValid, push_gshare, push_word};
      memB[tail] <= {push_pc, push_hwValid, push_word};
    end
  end

  assign aheadIdx = head + IDX_W'(1);
  assign {pop_pcA, pop_hwValidA, pop_gshareA, pop_wordA} = memA[head];
  assign {pop_pcB, pop_hwValidB,              pop_wordB} = memB[aheadIdx];

  // ---- pointers ----------------------------------------------------------------
  always_ff @(posedge clk) begin
    if (!resetn || flush) begin
      head  <= '0;
      tail  <= '0;
      count <= '0;
    end else begin
      head  <= head  + IDX_W'(popCount);
      tail  <= tail  + IDX_W'(doPush);
      count <= count + (IDX_W+1)'(doPush) - (IDX_W+1)'(popCount);
    end
  end

endmodule

