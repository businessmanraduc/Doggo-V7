// ================================================================================
//  dispatch: DS fire and stall, every output one LUT on flops
// ================================================================================
//  As simple and quick as it can get, because it directs four big modules:
//  issue_queue, reorder_buffer, predispatch and payload.
// ================================================================================
`include "uop_defs.svh"

module dispatch (
  input  logic               clk,
  input  logic               resetn,
  input  logic [CLASS_W-1:0] d2_pds_class,
  input  logic               d2_pds_illegal,
  input  logic               d2_pds_serialising,
  input  logic               pds_ds_valid,
  input  logic               pds_ds_serialising,
  input  logic               iq_dispatchReady,
  input  logic               rob_dispatchReady,
  input  logic               rob_empty,
  output logic               stall_pds_ds,
  output logic               ds_fire,
  output logic               ds_iqGo,
  output logic               ds_iqFire
);

  logic dp_skipIq, dp_serialBlock;
  always_ff @(posedge clk) begin
    if (!resetn) begin
      dp_skipIq      <= 1'b0;
      dp_serialBlock <= 1'b0;
    end else begin
      if (!stall_pds_ds)
        dp_skipIq    <= d2_pds_class[CLASS_SYSTEM] | d2_pds_illegal;
      dp_serialBlock <= (stall_pds_ds ? pds_ds_serialising : d2_pds_serialising)
        & !(rob_empty & !ds_fire);
    end
  end

  assign ds_iqGo      = pds_ds_valid &   rob_dispatchReady & !dp_serialBlock & !dp_skipIq;
  assign ds_iqFire    = pds_ds_valid &   rob_dispatchReady & !dp_serialBlock & !dp_skipIq & iq_dispatchReady;
  assign ds_fire      = pds_ds_valid &   rob_dispatchReady & !dp_serialBlock & (dp_skipIq | iq_dispatchReady);
  assign stall_pds_ds = pds_ds_valid & !(rob_dispatchReady & !dp_serialBlock & (dp_skipIq | iq_dispatchReady));

endmodule

