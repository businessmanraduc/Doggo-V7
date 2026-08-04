// ================================================================================
//  PHANTOoOM-32 -- Instruction Aligner
// ================================================================================
//  Walks the live halfwords of the fetch queue and hands one instruction per
//  cycle to decode. Output is fall-through: valid whenever an instruction can
//  be formed, and the D0 boundary registers it.
//
//  Position within the head word is 'half'. hwValid says which halfwords of
//  a word the fetch stream actually executes:
//
//    11  both halves live          01  stream exits after low half
//    10  entered at the high half  00  never queued
//
//  Four shapes, chosen by position and by two opcode bits in that position:
//
//    half 0, 16-bit  A[15:0]             stay on A unless high half is dead
//    half 0, 32-bit  A[31:0]             pop A
//    half 1, 16-bit  A[31:16]            pop A
//    half 1, 32-bit {B[15:0], A[31:16]}  pop A/pop A+B when B has nothing left
//
//  Solo Fmax (ring-of-regs, nextpnr --85k, tw=100, 20 seeds): see fmax.md
// ================================================================================
module align (
  input  logic        clk,
  input  logic        resetn,
  input  logic        flush,

  // ---- fetch queue: two entries visible, up to two retired ---------------------
  input  logic        fq_validA,
  input  logic [31:2] fq_pcA,
  input  logic [1:0]  fq_hwValidA,
  input  logic [31:0] fq_wordA,
  input  logic        fq_validB,
  input  logic [1:0]  fq_hwValidB,
  input  logic [31:0] fq_wordB,
  output logic [1:0]  fq_take,

  // ---- to D0 -------------------------------------------------------------------
  output logic        out_valid,
  output logic [31:1] out_pc,
  output logic [31:0] out_instr,
  output logic        out_isCompressed,
  input  logic        out_ready
);

  // ---- position: skip low half when stream never entered it --------------------
  logic half, effHalf;
  assign effHalf = (!half && !fq_hwValidA[0]) ? 1'b1 : half;

  // ---- the 32 bits starting at current position --------------------------------
  assign out_instr = effHalf ? {fq_wordB[15:0], fq_wordA[31:16]} : fq_wordA;
  assign out_pc    = {fq_pcA, effHalf};

  logic isWide, isStraddle;
  assign isWide     = (out_instr[1:0] == 2'b11);
  assign isStraddle = isWide && effHalf;

  assign out_isCompressed = !isWide;
  assign out_valid        = fq_validA && (!isStraddle || fq_validB);

  // ---- retire: how much of the queue this instruction consumes -----------------
  logic       stayOnA;
  logic [1:0] takeCount;
  assign stayOnA   = !effHalf && !isWide && fq_hwValidA[1];
  assign takeCount =
    (isStraddle && !fq_hwValidB[1]) ? 2'd2 :
    stayOnA                         ? 2'd0 :
  2'd1;
  assign fq_take = (out_valid && out_ready) ? takeCount : 2'd0;

  // ---- next position -----------------------------------------------------------
  logic nextHalf; assign nextHalf = stayOnA || (isStraddle && fq_hwValidB[1]);
  always_ff @(posedge clk) begin
    if (!resetn || flush)            half <= 1'b0;
    else if (out_valid && out_ready) half <= nextHalf;
  end

endmodule

