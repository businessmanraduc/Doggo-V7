// ================================================================================
//  linefill_ring -- ring-of-regs timing top for the line-fill engine
// ================================================================================
module linefill_ring (input logic clk, input logic perturb, output logic q);
  localparam int SET_IDX_W = 7;
  localparam int TAG_W     = 13;
  localparam int WORDIDX_W = 10;

  logic [31:0] s0, s1, s2, s3;
  lfsr_src #(.W(32)) u0 (.clk, .perturb(perturb), .q(s0));
  lfsr_src #(.W(32)) u1 (.clk, .perturb(s0[0]),   .q(s1));
  lfsr_src #(.W(32)) u2 (.clk, .perturb(s1[0]),   .q(s2));
  lfsr_src #(.W(32)) u3 (.clk, .perturb(s2[0]),   .q(s3));

  logic [31:0]          fillAddr;
  logic                 fillReq;
  logic [3:0]           dataWrEnable;
  logic [WORDIDX_W-1:0] dataWrIndex;
  logic [31:0]          dataWrWord;
  logic [3:0]           tagWrEnable;
  logic [SET_IDX_W-1:0] tagWrSet;
  logic [TAG_W-1:0]     tagWrTag;
  logic                 tagWrValid;
  logic                 initDone;
  logic                 fillBusy;

  linefill u_dut (
    .clk, .resetn(s0[31]),
    .missValid(s1[0]), .missTag(s1[TAG_W:1]), .missSet(s2[SET_IDX_W-1:0]),
    .missVictim(s2[9:8]),
    .fillAddr, .fillReq, .fillRData(s3), .fillRValid(s1[31]),
    .dataWrEnable, .dataWrIndex, .dataWrWord,
    .tagWrEnable, .tagWrSet, .tagWrTag, .tagWrValid,
    .initDone, .fillBusy
  );

  xor_sink #(.W(106)) u_sink (
    .clk,
    .d({fillAddr, fillReq, dataWrEnable, dataWrIndex, dataWrWord,
        tagWrEnable, tagWrSet, tagWrTag, tagWrValid, initDone, fillBusy}),
    .q(q)
  );
endmodule

