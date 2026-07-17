`include "uop.svh"
// ================================================================================
//  decoder_ring -- ring wrapper: every DUT port register-bounded
//  ports are the ring convention: clk, perturb (in), q (out)
// ================================================================================

module decoder_ring (
  input  logic clk,
  input  logic perturb,
  output logic q
);

  logic [31:0] rndI, rndP;
  logic [1:0]  ctl;
  uop_t        uop;

  lfsr_src #(.W(32)) u_srcI (.clk, .perturb(perturb), .q(rndI));
  lfsr_src #(.W(32)) u_srcP (.clk, .perturb(rndI[0]), .q(rndP));
  lfsr_src #(.W(2))  u_srcC (.clk, .perturb(rndP[0]), .q(ctl));

  decoder u_dut (
    .instr        (rndI),
    .pc           (rndP),
    .isCompressed (ctl[1]),
    .illegal      (ctl[0]),
    .uop
  );

  xor_sink #(.W($bits(uop))) u_sink (.clk, .d(uop), .q(q));

endmodule

