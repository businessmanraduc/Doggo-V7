// ================================================================================
//  PHANTOoOM-32 -- Dispatch FIFO
// ================================================================================
//  Elastic in-order buffer between decode and issue.
//
//  First-word-fall-through: deq_data is live whenever deq_valid.
//  Flush empties the queue at next edge; same-cycle handshakes are dropped.
//
//  Solo Fmax (ring-of-regs, nextpnr --85k, tw=100, 20 seeds): 196.23 / 215.92 / 232.40
// ================================================================================
module dispatch_fifo #(
  parameter int W     = 96,
  parameter int DEPTH = 8,
  parameter int IDX_W = $clog2(DEPTH)
) (
  input  logic         clk,
  input  logic         resetn,
  input  logic         flush,       // trap/branch mispredict

  // ---- enqueue: from decode, in program order ----------------------------------
  input  logic         enq_valid,
  input  logic [W-1:0] enq_data,
  output logic         enq_ready,   // queue not full

  // ---- dequeue: to issue, in program order -------------------------------------
  output logic         deq_valid,   // queue not empty
  output logic [W-1:0] deq_data,
  input  logic         deq_ready
);

  logic [IDX_W-1:0] head, tail;
  logic [IDX_W:0]   count;
  logic             doEnq, doDeq;

  assign enq_ready = !count[IDX_W];
  assign deq_valid = (count != '0);
  assign doEnq     = enq_valid && enq_ready;
  assign doDeq     = deq_valid && deq_ready;

  // ---- payload: LUTRAM, written at tail, read combinationally at head ----------
  (* ram_style = "distributed" *) logic [W-1:0] mem [DEPTH];

  always_ff @(posedge clk) begin
    if (doEnq) mem[tail] <= enq_data;
  end
  assign deq_data = mem[head];

  // ---- pointers ----------------------------------------------------------------
  always_ff @(posedge clk) begin
    if (!resetn || flush) begin
      head  <= '0;
      tail  <= '0;
      count <= '0;
    end else begin
      head  <= head  + IDX_W'(doDeq);
      tail  <= tail  + IDX_W'(doEnq);
      count <= count + (IDX_W+1)'(doEnq) - (IDX_W+1)'(doDeq);
    end
  end

endmodule

