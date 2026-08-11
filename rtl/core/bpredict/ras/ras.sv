// ================================================================================
//  PHANTOoOM-32 -- Return Address Stack
// ================================================================================
//  Predicts returns. A call pushes the address of the instruction after it, a
//  return pops that address back.
//
//  The top of stack lives in a flop, the entries below it in LUTRAM read one pop
//  ahead.
//  A push stores the new address at mem[ptr] and mirrors it into the top, so
//  mem[p-1] is always the top for pointer p and every live entry exists in
//  memory.
//  ptr is published per fetch word and handed back on a redirect, exactly
//  like the branch history. A restore reloads the top as well as the pointer,
//  so the stack resumes whole rather than one deep.
//
//  Solo Fmax (ring-of-regs, nextpnr --85k, tw=100, 20 seeds): see fmax.md
// ================================================================================
module ras #(
  parameter int DEPTH = 8,
  parameter int PTR_W = $clog2(DEPTH)
) (
  input  logic              clk,
  input  logic              boot,

  // ---- checkpoint restore, from the backend or replay --------------------------
  input  logic              restore,
  input  logic [PTR_W-1:0]  restorePtr,

  // ---- one applied verdict, at most one push/pop -------------------------------
  input  logic              enable,
  input  logic              push,
  input  logic              pop,
  input  logic [31:0]       pushAddr,

  output logic [31:0]       top,
  output logic [PTR_W-1:0]  ptr
);

  (* ram_style = "distributed" *) logic [31:0] mem [DEPTH];

  always_ff @(posedge clk) begin
    if (boot) begin
      ptr <= '0; top <= '0;
    end else if (restore) begin
      ptr <= restorePtr;
      top <= mem[restorePtr - PTR_W'(1)];
    end else if (enable) begin
      if (push) begin
        mem[ptr] <= pushAddr;
        top      <= pushAddr;
        ptr      <= ptr + PTR_W'(1);
      end else if (pop) begin
        top      <= mem[ptr - PTR_W'(2)];
        ptr      <= ptr - PTR_W'(1);
      end
    end
  end

endmodule

