// ================================================================================
//  dispatch_fifo_ring -- ring wrapper: every DUT port register-bounded
//  ports are the ring convention: clk, perturb (in), q (out)
// ================================================================================

module dispatch_fifo_ring (
  input  logic clk,
  input  logic perturb,
  output logic q
);

  logic [95:0] enqData, deqData;
  logic [7:0]  ctl;
  logic        enqReady, deqValid;

  lfsr_src #(.W(96)) u_srcD (.clk, .perturb(perturb),    .q(enqData));
  lfsr_src #(.W(8))  u_srcC (.clk, .perturb(enqData[0]), .q(ctl));

  dispatch_fifo u_dut (
    .clk,
    .resetn    (ctl[7]),
    .flush     (ctl[6]),

    .enq_valid (ctl[5]),
    .enq_data  (enqData),
    .enq_ready (enqReady),

    .deq_valid (deqValid),
    .deq_data  (deqData),
    .deq_ready (ctl[4])
  );

  xor_sink #(.W(98)) u_sink (.clk, .d({enqReady, deqValid, deqData}), .q(q));

endmodule

