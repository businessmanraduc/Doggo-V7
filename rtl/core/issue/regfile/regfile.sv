// ================================================================================
//  PHANTOoOM-32 -- Register File
// ================================================================================
//  32 x 32, two combinational read ports (issue), one write port (commit).
//
//  Same-edge write and read of one register returns old value: that reader is
//  covered by ROB forwarding.
//
//  Solo Fmax (ring-of-regs, nextpnr --85k, tw=100, 20 seeds): 252.91 / 269.23 / 284.98
// ================================================================================
module regfile (
  input  logic          clk,

  // ---- issue: two combinational reads ------------------------------------------
  input  logic [4:0]  rs1Index,
  input  logic [4:0]  rs2Index,
  output logic [31:0] rs1Data,
  output logic [31:0] rs2Data,

  // ---- commit: one write -------------------------------------------------------
  input  logic        wrEnable,
  input  logic [4:0]  wrIndex,
  input  logic [31:0] wrData
);

  (* ram_style = "distributed" *) logic [31:0] mem [32];

  always_ff @(posedge clk) begin
    if (wrEnable) mem[wrIndex] <= wrData;
  end

  assign rs1Data = (rs1Index == '0) ? 32'b0 : mem[rs1Index];
  assign rs2Data = (rs2Index == '0) ? 32'b0 : mem[rs2Index];

endmodule

