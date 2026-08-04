// ================================================================================
//  fetch_queue_ring -- ring wrapper: every DUT port register-bounded
//  ports are the ring convention: clk, perturb (in), q (out)
// ================================================================================

module fetch_queue_ring (
  input  logic clk,
  input  logic perturb,
  output logic q
);

  logic [31:0] word;
  logic [31:0] pc;
  logic [7:0]  ctl;

  lfsr_src #(.W(32)) u_srcW (.clk, .perturb(perturb), .q(word));
  lfsr_src #(.W(32)) u_srcP (.clk, .perturb(word[0]), .q(pc));
  lfsr_src #(.W(8))  u_srcC (.clk, .perturb(pc[0]),   .q(ctl));

  logic        canFetch;
  logic        popValidA, popValidB;
  logic [31:2] popPcA, popPcB;
  logic [1:0]  popHwA, popHwB;
  logic [31:0] popWordA, popWordB;

  fetch_queue u_dut (
    .clk,
    .resetn       (ctl[7]),
    .flush        (ctl[6]),

    .push_valid   (ctl[5]),
    .push_pc      (pc[31:2]),
    .push_hwValid (ctl[3:2]),
    .push_word    (word),

    .canFetch     (canFetch),

    .pop_validA   (popValidA),
    .pop_pcA      (popPcA),
    .pop_hwValidA (popHwA),
    .pop_wordA    (popWordA),
    .pop_validB   (popValidB),
    .pop_pcB      (popPcB),
    .pop_hwValidB (popHwB),
    .pop_wordB    (popWordB),
    .pop_taken    (ctl[4])
  );

  xor_sink #(.W(131)) u_sink (
    .clk,
    .d({canFetch, popValidA, popPcA, popHwA, popWordA,
                  popValidB, popPcB, popHwB, popWordB}),
    .q(q)
  );

endmodule

