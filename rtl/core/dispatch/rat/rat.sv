// ================================================================================
//  PHANTOoOM-32 -- Register Alias Table
// ================================================================================
//  pending[r]  - register r has an in-flight writer
//  producer[r] - ROB ticket of the newest in-flight writer of r
//
//  Issue reads both to pick regfile vs ROB forward.
//  Allocation records the newest writer.
//  Commit clears pending only when the retiring ticket is still the newest writer.
//
//  Solo Fmax (ring-of-regs, nextpnr --85k, tw=100, 20 seeds): 159.46 / 170.88 / 184.54
// ================================================================================
module rat #(
  parameter int ROB_IDX_W = 4
) (
  input  logic                 clk,
  input  logic                 resetn,
  input  logic                 flush,

  // ---- issue: operand lookup, combinational ------------------------------------
  input  logic [4:0]           rs1Index,
  input  logic [4:0]           rs2Index,
  output logic                 rs1Pending,
  output logic                 rs2Pending,
  output logic [ROB_IDX_W-1:0] rs1Producer,
  output logic [ROB_IDX_W-1:0] rs2Producer,

  // ---- issue: allocate the next writer -----------------------------------------
  input  logic                 alloc_valid,
  input  logic [4:0]           alloc_rdIndex,
  input  logic [ROB_IDX_W-1:0] alloc_robIdx,

  // ---- commit: retire a writer -------------------------------------------------
  input  logic                 cmt_valid,
  input  logic [4:0]           cmt_rdIndex,
  input  logic [ROB_IDX_W-1:0] cmt_robIdx
);

  logic [31:0] pending;
  (* ram_style = "distributed" *) logic [ROB_IDX_W-1:0] producer [32];

  assign rs1Pending  = pending[rs1Index];
  assign rs2Pending  = pending[rs2Index];
  assign rs1Producer = producer[rs1Index];
  assign rs2Producer = producer[rs2Index];

  logic commitIsNewest;
  assign commitIsNewest = cmt_valid && (producer[cmt_rdIndex] == cmt_robIdx);

  logic [31:0] setMask, clrMask;
  always_comb begin
    setMask = alloc_valid    ? (32'(1) << alloc_rdIndex) : '0;
    clrMask = commitIsNewest ? (32'(1) << cmt_rdIndex)   : '0;
  end

  always_ff @(posedge clk) begin
    if (!resetn || flush) pending <= '0;
    else                  pending <= (pending & ~clrMask) | setMask;
  end

  always_ff @(posedge clk) begin
    if (alloc_valid) producer[alloc_rdIndex] <= alloc_robIdx;
  end

endmodule

