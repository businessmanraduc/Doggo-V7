// ================================================================================
//  fetch_ctrl_ring -- ring wrapper: every DUT port register-bounded
//  ports are the ring convention: clk, perturb (in), q (out)
// ================================================================================

module fetch_ctrl_ring (
  input  logic clk,
  input  logic perturb,
  output logic q
);

  localparam int PHT_W = 13;

  logic [31:0] pc;
  logic [31:0] gs;
  logic [7:0]  ctl;

  lfsr_src #(.W(32)) u_srcP (.clk, .perturb(perturb), .q(pc));
  lfsr_src #(.W(32)) u_srcG (.clk, .perturb(pc[0]),   .q(gs));
  lfsr_src #(.W(8))  u_srcC (.clk, .perturb(gs[0]),   .q(ctl));

  logic             boot, stall, lookupValid, lookupKill, replayValid;
  logic [31:0]      replayPC;
  logic [PHT_W-1:0] replayBHR;
  logic             pushValid;
  logic [31:2]      pushPC;
  logic [1:0]       pushHwValid;
  logic [PHT_W-1:0] pushGshare;

  fetch_ctrl #(.PHT_INDEX_W(PHT_W)) u_dut (
    .clk,
    .resetn          (ctl[7]),

    .fetchPC         (pc[31:2]),
    .fetchHwValid    (ctl[1:0]),
    .fetchGshare     (gs[PHT_W-1:0]),

    .hit             (ctl[6]),
    .fillBusy        (ctl[5]),
    .canFetch        (ctl[4]),
    .backendRedirect (ctl[3]),

    .boot, .stall, .lookupValid, .lookupKill,
    .replayValid, .replayPC, .replayBHR,
    .pushValid, .pushPC, .pushHwValid, .pushGshare
  );

  xor_sink #(.W(96)) u_sink (
    .clk,
    .d({replayPC, replayBHR, pushPC, pushGshare, pushHwValid,
        boot, stall, lookupValid, lookupKill, replayValid, pushValid}),
    .q(q)
  );

endmodule
