// ================================================================================
//  PHANTOoOM Core: The main core of the PHANTOoOM-CPU (Doggo-V7) - M2 version
// ================================================================================
//  Core Diagram: To-Be-Drawn
// ================================================================================
//  Top module including the Fetch Engine (coming soon), Out-of-Order Engine
//  and Execution Engine all in one.
// ================================================================================
`include "uop_defs.svh"

module phantooom_core #(parameter int MW = 1) (
  input  logic                clk,
  input  logic                resetn,
  // ---- Fetch Engine lines (temporarily controlled by testbench) ----------------
  input  logic                f5_d_valid,
  input  logic [31:0]         f5_d_instr,
  input  logic                f5_d_rvc,
  input  logic [30:0]         f5_d_pc,
  input  logic [MW-1:0]       f5_d_meta,
  output logic                stall_d_r1,
  // ---- Commit Stage information (for lockstep verification) --------------------
  output logic                cm_valid,
  output logic                cm_exception,
  output logic                cm_refetch,
  output logic                cm_flush,
  output logic [4:0]          cm_rdIndex,
  output logic [5:0]          cm_rdTag,
  output logic [5:0]          cm_rdOldTag,
  output logic                cm_rdWriteEnable,
  output logic [30:0]         cm_pc,
  output logic                cm_rvc,
  output logic [SYSTEM_W-1:0] cm_system,
  output logic                cm_illegal,
  output logic                cm_serialising,
  output logic                cm_isLoad,
  output logic                cm_isStore,
  output logic [31:0]         cm_badAddress
);

  // ---- WB connections ----------------------------------------------------------
  logic        wb_valid,      wb_exception, wb_refetch;
  logic [3:0]  wb_robIndex;
  logic [31:0] wb_badAddress;

  // ---- IS/PR inter-stage pipeline connections ----------------------------------
  logic [7:0]  is_pr_grant;

  // ---- IQ connections ----------------------------------------------------------
  logic [3:0]  iq_grantBranchMask;

  // ---- PR/RF inter-stage pipeline connections ----------------------------------
  logic [3:0]  pr_rf_robIndex;
  logic [5:0]  pr_rf_rs1Tag,      pr_rf_rs2Tag,  pr_rf_rdTag;
  logic        pr_rf_rdWriteEnable;
  logic [30:0] pr_rf_pc,          pr_rf_seq;
  logic [CLASS_W-1:0] pr_rf_class;
  logic        pr_rf_sub;
  logic        pr_rf_selArith,    pr_rf_selAnd,  pr_rf_selOr,  pr_rf_selXor;
  logic        pr_rf_sltUnsigned;
  logic        pr_rf_xIsPC,       pr_rf_xIsZero, pr_rf_zIsImm, pr_rf_zIsZero;
  logic        pr_rf_branchUseLt, pr_rf_branchInvert;
  logic [31:0] pr_rf_immediate;

  // ---- PR/RF inter-stage pipeline connections (M3+) ----------------------------
  logic [1:0]    pr_rf_snapshot;
  logic [MW-1:0] pr_rf_meta;
  logic          pr_rf_isCall,     pr_rf_isRet;
  logic [30:0]   pr_rf_branchTarget;
  logic          pr_rf_selSlt,     pr_rf_shiftRight, pr_rf_shiftArith;
  logic          pr_rf_mulSignedA, pr_rf_mulSignedB, pr_rf_mulHigh;
  logic          pr_rf_divSigned,  pr_rf_divRemainder;
  logic [2:0]    pr_rf_func3;

  // ---- Out-of-Order Engine -----------------------------------------------------
  oe #(.MW(MW)) u_oe (
    .clk, .resetn,
    .f5_d_valid,     .f5_d_instr,     .f5_d_rvc,     .f5_d_pc,        .f5_d_meta, .stall_d_r1,
    .ex0_resolveValid('0),            .ex0_resolveSnapshot('0),
    .ex0_resolveMispredict('0),       .ex0_resolveRobIndex('0),
    .wb_valid,       .wb_robIndex,    .wb_exception, .wb_refetch,     .wb_badAddress,
    .is_pr_grant,    .iq_grantBranchMask,
    .pr_rf_robIndex, .pr_rf_rs1Tag,   .pr_rf_rs2Tag, .pr_rf_rdTag,    .pr_rf_rdWriteEnable,
    .pr_rf_snapshot, .pr_rf_pc,       .pr_rf_meta,   .pr_rf_isCall,   .pr_rf_isRet,
    .pr_rf_branchTarget,
    .pr_rf_seq,      .pr_rf_class,    .pr_rf_sub,
    .pr_rf_selArith, .pr_rf_selAnd,   .pr_rf_selOr,  .pr_rf_selXor,
    .pr_rf_selSlt,   .pr_rf_sltUnsigned,
    .pr_rf_shiftRight,  .pr_rf_shiftArith,
    .pr_rf_xIsPC,    .pr_rf_xIsZero,  .pr_rf_zIsImm, .pr_rf_zIsZero,
    .pr_rf_branchUseLt, .pr_rf_branchInvert,
    .pr_rf_mulSignedA,  .pr_rf_mulSignedB,           .pr_rf_mulHigh,
    .pr_rf_divSigned,   .pr_rf_divRemainder,         .pr_rf_func3,
    .pr_rf_immediate,
    .cm_valid,
    .cm_exception,       .cm_refetch, .cm_flush,
    .cm_rdIndex,         .cm_rdTag,   .cm_rdOldTag,
    .cm_rdWriteEnable,   .cm_pc,      .cm_rvc,       .cm_system,      .cm_illegal,
    .cm_serialising,     .cm_isLoad,  .cm_isStore,   .cm_badAddress
  );

  // ---- Execution Engine --------------------------------------------------------
  ex u_ex (
    .clk,               .resetn,
    .is_pr_grant,       .iq_grantBranchMask,
    .pr_rf_robIndex,    .pr_rf_rs1Tag,   .pr_rf_rs2Tag, .pr_rf_rdTag, .pr_rf_rdWriteEnable,
    .pr_rf_pc,          .pr_rf_seq,      .pr_rf_class,
    .pr_rf_sub,         .pr_rf_selArith, .pr_rf_selAnd, .pr_rf_selOr, .pr_rf_selXor,
    .pr_rf_sltUnsigned,
    .pr_rf_xIsPC,       .pr_rf_xIsZero,  .pr_rf_zIsImm, .pr_rf_zIsZero,
    .pr_rf_branchUseLt, .pr_rf_branchInvert,
    .pr_rf_immediate,
    .ex0_resolveValid('0), .ex0_resolveSnapshot('0), .ex0_resolveMispredict('0),
    .cm_flush,          .ex0_ex1_taken(),
    .wb_valid,          .wb_robIndex,    .wb_exception, .wb_refetch,  .wb_badAddress
  );

endmodule

