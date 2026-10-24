// ================================================================================
//  dispatch_ring -- ring wrapper: every DUT port register-bounded
//  ports are the ring convention: clk, perturb (in), q (out)
// ================================================================================
//  Solo figure only: every output is one LUT on flops. The DS cluster ring
//  (predisp, predisp_payload, IQ, payload, ROB) sets the real figure.
// ================================================================================

`include "uop_defs.svh"

module dispatch_ring (
  input  logic clk,
  input  logic perturb,
  output logic q
);

  logic [31:0] s0;
  logic [3:0]  out;

  lfsr_src #(.W(32)) u_s0 (.clk, .perturb(perturb), .q(s0));

  dispatch u_dut (
    .clk,
    .resetn             (s0[31] | s0[30]),
    .r2_pds_class       (s0[CLASS_W-1:0]),
    .r2_pds_illegal     (s0[12]),
    .r2_pds_serialising (s0[13]),
    .pds_ds_valid       (s0[14]),
    .pds_ds_serialising (s0[15]),
    .iq_dispatchReady   (s0[16]),
    .rob_dispatchReady  (s0[17]),
    .rob_empty          (s0[18]),
    .stall_pds_ds       (out[0]),
    .ds_fire            (out[1]),
    .ds_iqGo            (out[2]),
    .ds_iqFire          (out[3])
  );

  xor_sink #(.W(4)) u_sink (.clk, .d(out), .q);

endmodule
