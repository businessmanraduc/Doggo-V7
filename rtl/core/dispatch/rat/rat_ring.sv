// ================================================================================
//  rat_ring -- ring wrapper: every DUT port register-bounded
//  ports are the ring convention: clk, perturb (in), q (out)
// ================================================================================
//  Two LFSRs so the lookup indices never share bits with the alloc/commit
//  streams, which would let yosys fold ports together.
// ================================================================================

module rat_ring (
  input  logic clk,
  input  logic perturb,
  output logic q
);

  logic [31:0] rndA, rndB;
  logic        rs1Pending, rs2Pending;
  logic [3:0]  rs1Producer, rs2Producer;

  lfsr_src #(.W(32)) u_srcA (.clk, .perturb(perturb), .q(rndA));
  lfsr_src #(.W(32)) u_srcB (.clk, .perturb(rndA[0]), .q(rndB));

  rat u_dut (
    .clk,
    .resetn        (rndA[31]),
    .flush         (rndA[30]),

    .rs1Index      (rndA[4:0]),
    .rs2Index      (rndA[9:5]),
    .rs1Pending,
    .rs2Pending,
    .rs1Producer,
    .rs2Producer,

    .alloc_valid   (rndB[31]),
    .alloc_rdIndex (rndB[4:0]),
    .alloc_robIdx  (rndB[8:5]),

    .cmt_valid     (rndB[30]),
    .cmt_rdIndex   (rndB[13:9]),
    .cmt_robIdx    (rndB[17:14])
  );

  xor_sink #(.W(10)) u_sink (
    .clk,
    .d({rs1Pending, rs2Pending, rs1Producer, rs2Producer}),
    .q(q)
  );

endmodule
