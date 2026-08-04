// ================================================================================
//  align_ring -- ring-of-regs timing top for the instruction aligner
//  ports are the ring convention: clk, perturb (in), q (out)
// ================================================================================
module align_ring (
  input  logic clk,
  input  logic perturb,
  output logic q
);

  logic [31:0] wA, wB, pc;
  logic [7:0]  ctl;

  lfsr_src #(.W(32)) u_srcA (.clk, .perturb(perturb), .q(wA));
  lfsr_src #(.W(32)) u_srcB (.clk, .perturb(wA[0]),   .q(wB));
  lfsr_src #(.W(32)) u_srcP (.clk, .perturb(wB[0]),   .q(pc));
  lfsr_src #(.W(8))  u_srcC (.clk, .perturb(pc[0]),   .q(ctl));

  logic [1:0]  fq_take;
  logic        out_valid, out_isCompressed;
  logic [31:1] out_pc;
  logic [31:0] out_instr;
  logic [12:0] out_gshare;

  align u_dut (
    .clk,
    .resetn      (ctl[7]),
    .flush       (ctl[6]),

    .fq_validA   (ctl[5]),
    .fq_pcA      (pc[31:2]),
    .fq_hwValidA (ctl[3:2]),
    .fq_gshareA  (pc[14:2]),
    .fq_wordA    (wA),
    .fq_validB   (ctl[4]),
    .fq_hwValidB (ctl[1:0]),
    .fq_wordB    (wB),
    .fq_take     (fq_take),

    .out_valid, .out_pc, .out_instr, .out_isCompressed, .out_gshare,
    .out_ready   (pc[1])
  );

  xor_sink #(.W(80)) u_sink (
    .clk, .d({out_instr, out_pc, out_gshare, out_valid, out_isCompressed, fq_take}),
    .q(q)
  );

endmodule

