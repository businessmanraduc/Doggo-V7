// ================================================================================
//  Execution Engine: RF read to WB, ALU only (M2)
// ================================================================================
//  RF             RR            EX0            EX1..CM
//  rf ──────────► rr ─────────► alu ─────────► respipe ──► rf write, wb_*
//                  ▲                             │
//                  └─── results (valid, tags) ───┘
// ================================================================================
//  Grant and payload in (from OE), completion out (wb_* to ROB).
//  M2: ALU, lui, auipc, jal/jalr rd.
// ================================================================================
`include "uop_defs.svh"

module ex (
  input  logic                clk,
  input  logic                resetn,
  // ---- Issue/Payload-Read inter-stage pipeline register ------------------------
  input  logic [7:0]          is_pr_grant,
  input  logic [3:0]          iq_grantBranchMask,
  // ---- Payload-Read/Register-File inter-stage pipeline register ----------------
  input  logic [3:0]          pr_rf_robIndex,
  input  logic [5:0]          pr_rf_rs1Tag,
  input  logic [5:0]          pr_rf_rs2Tag,
  input  logic [5:0]          pr_rf_rdTag,
  input  logic                pr_rf_rdWriteEnable,
  input  logic [30:0]         pr_rf_pc,
  input  logic [30:0]         pr_rf_seq,
  input  logic [CLASS_W-1:0]  pr_rf_class,
  input  logic                pr_rf_sub,
  input  logic                pr_rf_selArith,
  input  logic                pr_rf_selAnd,
  input  logic                pr_rf_selOr,
  input  logic                pr_rf_selXor,
  input  logic                pr_rf_sltUnsigned,
  input  logic                pr_rf_xIsPC,
  input  logic                pr_rf_xIsZero,
  input  logic                pr_rf_zIsImm,
  input  logic                pr_rf_zIsZero,
  input  logic                pr_rf_branchUseLt,
  input  logic                pr_rf_branchInvert,
  input  logic [31:0]         pr_rf_immediate,
  // ---- kill --------------------------------------------------------------------
  input  logic                ex0_resolveValid,
  input  logic [1:0]          ex0_resolveSnapshot,
  input  logic                ex0_resolveMispredict,
  input  logic                cm_flush,
  // ---- branch (M3) -------------------------------------------------------------
  output logic                ex0_ex1_taken,
  // ---- completion (s+8) --------------------------------------------------------
  output logic                wb_valid,
  output logic [3:0]          wb_robIndex,
  output logic                wb_exception,
  output logic                wb_refetch,
  output logic [31:0]         wb_badAddress
);

  assign wb_exception  = 1'b0;
  assign wb_refetch    = 1'b0;
  assign wb_badAddress = '0;

  // ---- respipe -----------------------------------------------------------------
  logic        rf_rr_producer,   rr_ex0_producer,  ex0_ex1_producer;
  logic        ex1_ex2_producer, ex2_ex3_producer, ex3_wb_producer;
  logic [5:0]  rf_rr_rdTag,      rr_ex0_rdTag,     ex0_ex1_rdTag;
  logic [5:0]  ex1_ex2_rdTag,    ex2_ex3_rdTag,    ex3_wb_rdTag;
  logic [31:0] ex0_ex1_result,   ex1_ex2_result,   ex2_ex3_result, ex3_wb_result, wb_cm_result;

  respipe u_respipe (
    .clk,              .resetn,
    .is_pr_grant,      .iq_grantBranchMask,
    .pr_rf_rdTag,      .pr_rf_rdWriteEnable, .pr_rf_robIndex,
    .ex0_resolveValid, .ex0_resolveSnapshot, .ex0_resolveMispredict, .cm_flush,
    .rf_rr_producer,   .rf_rr_rdTag,         .rr_ex0_producer,       .rr_ex0_rdTag,
    .ex0_ex1_producer, .ex0_ex1_rdTag,       .ex1_ex2_producer,      .ex1_ex2_rdTag,
    .ex2_ex3_producer, .ex2_ex3_rdTag,       .ex3_wb_producer,       .ex3_wb_rdTag,
    .ex0_ex1_result,   .ex1_ex2_result,      .ex2_ex3_result,        .ex3_wb_result, .wb_cm_result,
    .wb_valid,         .wb_robIndex
  );

  // ---- rf ----------------------------------------------------------------------
  logic [31:0] rf_rs1Data, rf_rs2Data;

  regfile u_regfile (
    .clk,
    .ex3_wb_producer, .ex3_wb_rdTag, .ex3_wb_result,
    .pr_rf_rs1Tag,    .pr_rf_rs2Tag,
    .rf_rs1Data,      .rf_rs2Data
  );

  // ---- rr ----------------------------------------------------------------------
  logic        rf_rr_selfX,    rf_rr_selfZ,  rf_rr_sub;
  logic        rf_rr_selArith, rf_rr_selAnd, rf_rr_selOr, rf_rr_selXor;
  logic        rf_rr_sltUnsigned, rf_rr_branchUseLt, rf_rr_branchInvert;
  logic [31:0] rr_ex0_x, rr_ex0_z;

  regread u_rr (
    .clk,
    .pr_rf_rs1Tag,      .pr_rf_rs2Tag,       .pr_rf_pc,         .pr_rf_seq,     .pr_rf_class,
    .pr_rf_sub,         .pr_rf_selArith,     .pr_rf_selAnd,     .pr_rf_selOr,   .pr_rf_selXor,
    .pr_rf_sltUnsigned, .pr_rf_xIsPC,        .pr_rf_xIsZero,    .pr_rf_zIsImm,  .pr_rf_zIsZero,
    .pr_rf_branchUseLt, .pr_rf_branchInvert, .pr_rf_immediate,
    .rf_rs1Data,        .rf_rs2Data,
    .rf_rr_producer,    .rf_rr_rdTag,        .rr_ex0_producer,  .rr_ex0_rdTag,
    .ex0_ex1_producer,  .ex0_ex1_rdTag,      .ex1_ex2_producer, .ex1_ex2_rdTag,
    .ex2_ex3_producer,  .ex2_ex3_rdTag,      .ex3_wb_producer,  .ex3_wb_rdTag,
    .ex0_ex1_result,    .ex1_ex2_result,     .ex2_ex3_result,   .ex3_wb_result, .wb_cm_result,
    .rf_rr_selfX,       .rf_rr_selfZ,        .rf_rr_sub,
    .rf_rr_selArith,    .rf_rr_selAnd,       .rf_rr_selOr,      .rf_rr_selXor,
    .rf_rr_sltUnsigned, .rf_rr_branchUseLt,  .rf_rr_branchInvert,
    .rr_ex0_x,          .rr_ex0_z
  );

  // ---- alu ---------------------------------------------------------------------
  alu #(.G(4)) u_alu (
    .clk,
    .rf_rr_selfX,       .rf_rr_selfZ,       .rf_rr_sub,
    .rf_rr_selArith,    .rf_rr_selAnd,      .rf_rr_selOr, .rf_rr_selXor,
    .rf_rr_sltUnsigned, .rf_rr_branchUseLt, .rf_rr_branchInvert,
    .rr_ex0_x,          .rr_ex0_z,
    .ex0_ex1_result,    .ex0_ex1_taken
  );

endmodule

