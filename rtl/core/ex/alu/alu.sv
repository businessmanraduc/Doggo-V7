// ================================================================================
//  ALU: one-cycle loop with its own bypass, branch compare beside the chain
// ================================================================================
//  RF/RR controls ──► rr_ex0 copies (G) ─┐
//  rr_ex0_x/z (rr) ──────────────────────┼─► add / logic  ──► ex0_ex1_result ──┐
//                     ▲                  └─► eq chain, lt ──► ex0_ex1_taken    │
//                     └───────────────────── own result (self select) ─────────┘
// ================================================================================
//  Mechanisms:
//   - Two bypass sources: own result and operand register.
//   - x = r         & selfX | x enters CCU2C cell with no LUT before it.
//   - w = (r ^ sub) & selfZ | z is one LUT per bit.
//   - Logic ops read x and w beside the chain, z inverted helps with Zbb.
//   - Branch: eq on second chain, lt from the adder's cout.
// ================================================================================
module alu #(
  parameter int G = 4
) (
  input  logic        clk,
  // ---- Register-File/Register-Read inter-stage pipeline register ---------------
  input  logic        rf_rr_selfX,
  input  logic        rf_rr_selfZ,
  input  logic        rf_rr_sub,
  input  logic        rf_rr_selArith,
  input  logic        rf_rr_selAnd,
  input  logic        rf_rr_selOr,
  input  logic        rf_rr_selXor,
  input  logic        rf_rr_sltUnsigned,
  input  logic        rf_rr_branchUseLt,
  input  logic        rf_rr_branchInvert,
  // ---- Register-Read/Execute0 inter-stage pipeline register --------------------
  input  logic [31:0] rr_ex0_x,
  input  logic [31:0] rr_ex0_z,
  // ---- Execute0/Execute1 inter-stage pipeline register -------------------------
  output logic [31:0] ex0_ex1_result,
  output logic        ex0_ex1_taken
);

  localparam int B = 32 / G;

  // ---- RR/EX0: control copies --------------------------------------------------
  logic [G-1:0] rr_ex0_selfX,    rr_ex0_selfZ,  rr_ex0_sub;
  logic [G-1:0] rr_ex0_selArith, rr_ex0_selAnd, rr_ex0_selOr, rr_ex0_selXor;
  logic         rr_ex0_sltUnsigned, rr_ex0_branchUseLt, rr_ex0_branchInvert;

  for (genvar k = 0; k < G; k++) begin : g_copy
    dup_reg #(.W(7)) u_control (
      .clk, .resetn(1'b1),
      .d({
        rf_rr_selfX,        rf_rr_selfZ,      rf_rr_sub,
        rf_rr_selArith,     rf_rr_selAnd,     rf_rr_selOr,     rf_rr_selXor
      }),
      .q({
        rr_ex0_selfX[k],    rr_ex0_selfZ[k],  rr_ex0_sub[k],
        rr_ex0_selArith[k], rr_ex0_selAnd[k], rr_ex0_selOr[k], rr_ex0_selXor[k]
      })
    );
  end

  always_ff @(posedge clk) begin
    rr_ex0_sltUnsigned  <= rf_rr_sltUnsigned;
    rr_ex0_branchUseLt  <= rf_rr_branchUseLt;
    rr_ex0_branchInvert <= rf_rr_branchInvert;
  end

  // ---- EX0: bypass + logic -----------------------------------------------------
  logic [31:0] alu_x, alu_w, alu_sum, alu_logic, alu_result;
  for (genvar i = 0; i < 32; i++) begin : g_bit
    localparam int K = i / B;
    assign alu_x[i]     = ((ex0_ex1_result[i])                 & rr_ex0_selfX[K]) | rr_ex0_x[i];
    assign alu_w[i]     = ((ex0_ex1_result[i] ^ rr_ex0_sub[K]) & rr_ex0_selfZ[K]) | rr_ex0_z[i];
    assign alu_logic[i] = (
        (rr_ex0_selAnd[K] & (alu_x[i] & alu_w[i]))
      | (rr_ex0_selOr[K]  & (alu_x[i] | alu_w[i]))
      | (rr_ex0_selXor[K] & (alu_x[i] ^ alu_w[i]))
    );
    assign alu_result[i] = (alu_sum[i] & rr_ex0_selArith[K]) | alu_logic[i];
  end

  // ---- EX0: adder + branch compare ---------------------------------------------
  logic alu_lt, alu_eq;
  logic alu_ltPre; assign alu_ltPre = rr_ex0_sltUnsigned | (alu_x[31] ^ alu_w[31]);

  cc_add3x #(.G(G)) u_add (
    .a(alu_w),           .b(ex0_ex1_result), .c(rr_ex0_selfX), .d(rr_ex0_x),
    .cin(rr_ex0_sub[0]), .sltSel(1'b1),      .sltP(alu_ltPre), .s(alu_sum),  .slt(alu_lt)
  );
  cc_eq3x  #(.G(G)) u_eq  (
    .a(alu_w),           .b(ex0_ex1_result), .c(rr_ex0_selfX), .d(rr_ex0_x), .eq(alu_eq)
  );

  // ---- EX0/EX1 -----------------------------------------------------------------
  always_ff @(posedge clk) begin
    ex0_ex1_result <= alu_result;
    ex0_ex1_taken  <= (rr_ex0_branchUseLt ? alu_lt : alu_eq) ^ rr_ex0_branchInvert;
  end

endmodule

