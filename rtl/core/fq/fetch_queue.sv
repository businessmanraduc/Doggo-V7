// ================================================================================
//  PHANTOoOM-32 -- Fetch Queue
// ================================================================================
//  Decouples the fetch pipeline from decode. One entry per 32-bit cache word,
//  carrying its own PC so nothing downstream has to reconstruct it.
//
//    entry = { pc[31:1], word[31:0] }
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
  parameter int FETCH_LATENCY = 3,
  parameter int IDX_W         = $clog2(DEPTH)
) (
  input  logic        clk,
  input  logic        resetn,
  input  logic        flush,      // redirect: drop the queue and the shadow

  // ---- push: from the cache's F3, one word per hit -----------------------------
  input  logic        push_valid,
  input  logic [30:0] push_pc,
  input  logic [31:0] push_word,

  // ---- credit: back to F0 ------------------------------------------------------
  output logic        canFetch,

  // ---- pop: two entries visible to align, at most one taken --------------------
  output logic        pop_validA,
  output logic [30:0] pop_pcA,
  output logic [31:0] pop_wordA,
  output logic        pop_validB,
  output logic [30:0] pop_pcB,
  output logic [31:0] pop_wordB,
  input  logic        pop_taken
);

  localparam int PC_W    = 31;
  localparam int ENTRY_W = PC_W + 32;

  logic [IDX_W-1:0] head, tail, aheadIdx;
  logic [IDX_W:0]   count;
  logic             doPush, doPop, dropPush;

  // ---- flush shadow: swallow lookups that were already in-flight ---------------
  logic [FETCH_LATENCY-1:0] flushShadow;
  always_ff @(posedge clk) begin
    if (!resetn)    flushShadow <= '0;
    else if (flush) flushShadow <= '1;
    else            flushShadow <= flushShadow >> 1;
  end
  assign dropPush = |flushShadow;

  // ---- handshakes --------------------------------------------------------------
  assign doPush     = push_valid && !dropPush && !count[IDX_W];
  assign doPop      = pop_validA && pop_taken;
  assign pop_validA = (count != '0);
  assign pop_validB = |count[IDX_W:1];
  assign canFetch   = (count <= (IDX_W+1)'(DEPTH - FETCH_LATENCY - 1));

  // ---- payload: one copy per read port -----------------------------------------
  (* ram_style = "distributed" *) logic [ENTRY_W-1:0] memA [DEPTH];
  (* ram_style = "distributed" *) logic [ENTRY_W-1:0] memB [DEPTH];

  always_ff @(posedge clk) begin
    if (doPush) begin
      memA[tail] <= {push_pc, push_word};
      memB[tail] <= {push_pc, push_word};
    end
  end

  assign aheadIdx = head + IDX_W'(1);
  assign {pop_pcA, pop_wordA} = memA[head];
  assign {pop_pcB, pop_wordB} = memB[aheadIdx];

  // ---- pointers ----------------------------------------------------------------
  always_ff @(posedge clk) begin
    if (!resetn || flush) begin
      head  <= '0;
      tail  <= '0;
      count <= '0;
    end else begin
      head  <= head  + IDX_W'(doPop);
      tail  <= tail  + IDX_W'(doPush);
      count <= count + (IDX_W+1)'(doPush) - (IDX_W+1)'(doPop);
    end
  end

endmodule

