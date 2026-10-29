// ================================================================================
//  Register file: 64 x 32 physical registers, 2 read ports, 1 write port
// ================================================================================
//  PR/RF tags ──► rf read (async) ──► rr (RF/RR register)
//  respipe WB ──► rf write (s+8)
// ================================================================================
//  Mechanisms:
//   - LUTRAM in two banks to supply two reads per cycle.
//   - ALL 64 entries start at 0 using the cells' INITVAL.
//   - A write in WB is handled for a read on the same register by the next stage.
// ================================================================================
module rf (
  input  logic        clk,
  // ---- WB: write port ----------------------------------------------------------
  input  logic        ex7_wb_producer,
  input  logic [5:0]  ex7_wb_rdTag,
  input  logic [31:0] ex7_wb_result,
  // ---- RF: read ports ----------------------------------------------------------
  input  logic [5:0]  pr_rf_rs1Tag,
  input  logic [5:0]  pr_rf_rs2Tag,
  output logic [31:0] rf_rs1Data,
  output logic [31:0] rf_rs2Data
);

  (* ram_style = "distributed" *) logic [31:0] rf_regs [64];
  initial for (int k = 0; k < 64; k++) rf_regs[k] = '0;

  always_ff @(posedge clk) begin
    if (ex7_wb_producer) rf_regs[ex7_wb_rdTag] <= ex7_wb_result;
  end

  assign rf_rs1Data = rf_regs[pr_rf_rs1Tag];
  assign rf_rs2Data = rf_regs[pr_rf_rs2Tag];

endmodule

