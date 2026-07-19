// ================================================================================
//  regfile_ring -- ring wrapper: every DUT port register-bounded
//  ports are the ring convention: clk, perturb (in), q (out)
// ================================================================================

module regfile_ring (
  input  logic clk,
  input  logic perturb,
  output logic q
);

  logic [31:0] wrData, rs1Data, rs2Data;
  logic [15:0] ctl;

  lfsr_src #(.W(32)) u_srcD (.clk, .perturb(perturb),   .q(wrData));
  lfsr_src #(.W(16)) u_srcC (.clk, .perturb(wrData[0]), .q(ctl));

  regfile u_dut (
    .clk,
    .rs1Index (ctl[4:0]),
    .rs2Index (ctl[9:5]),
    .rs1Data,
    .rs2Data,
    .wrEnable (ctl[15]),
    .wrIndex  (ctl[14:10]),
    .wrData
  );

  xor_sink #(.W(64)) u_sink (.clk, .d({rs1Data, rs2Data}), .q(q));

endmodule

