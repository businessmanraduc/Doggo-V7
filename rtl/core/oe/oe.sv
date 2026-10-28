// ================================================================================
//  Out-of-order Engine: D to IQ and ROB, between Fetch Engine and Execute
// ================================================================================
//  D               RD1/RD2            PreDS                DS            IS/PR
//  predecoder ─┬─► rename  ───────┬─► predisp ─────────┬─► dispatch ─┬─► issue_queue
//              └─► decoder ───────┴─► predisp_payload ─┘             ├─► payload
//                                                                    └─► rob
// ================================================================================
`include "uop_defs.svh"

module oe #(
  parameter int MW = 1
) (
  input  logic                clk,
  input  logic                resetn,
  // ---- Fetch-5/Decode inter-stage pipeline register ----------------------------
  input  logic                f5_d_valid,
  input  logic [31:0]         f5_d_instr,
  input  logic                f5_d_rvc,
  input  logic [30:0]         f5_d_pc,
  input  logic [MW-1:0]       f5_d_meta,
  output logic                stall_d_r1,
  // ---- branch resolve (EX) -----------------------------------------------------
  input  logic                ex_resolveValid,
  input  logic [1:0]          ex_resolveSnapshot,
  input  logic                ex_resolveMispredict,
  input  logic [3:0]          ex_resolveRobIndex,
  // ---- completion (s+8) --------------------------------------------------------
  input  logic                wb_valid,
  input  logic [3:0]          wb_robIndex,
  input  logic                wb_exception,
  input  logic                wb_refetch,
  input  logic [31:0]         wb_badAddress,
  // ---- Issue/Payload-Read inter-stage pipeline register ------------------------
  output logic [7:0]          is_pr_grant,
  output logic [3:0]          iq_grantBranchMask,
  // ---- Payload-Read/Register-File inter-stage pipeline register ----------------
  output logic [3:0]          pr_rf_robIndex,
  output logic [5:0]          pr_rf_rs1Tag,
  output logic [5:0]          pr_rf_rs2Tag,
  output logic [5:0]          pr_rf_rdTag,
  output logic                pr_rf_rdWriteEnable,
  output logic [1:0]          pr_rf_snapshot,
  output logic [30:0]         pr_rf_pc,
  output logic [MW-1:0]       pr_rf_meta,
  output logic                pr_rf_isCall,
  output logic                pr_rf_isRet,
  output logic [30:0]         pr_rf_branchTarget,
  output logic [30:0]         pr_rf_seq,
  output logic [CLASS_W-1:0]  pr_rf_class,
  output logic                pr_rf_sub,
  output logic                pr_rf_selArith,
  output logic                pr_rf_selAnd,
  output logic                pr_rf_selOr,
  output logic                pr_rf_selXor,
  output logic                pr_rf_selSlt,
  output logic                pr_rf_sltUnsigned,
  output logic                pr_rf_shiftRight,
  output logic                pr_rf_shiftArith,
  output logic                pr_rf_xIsPC,
  output logic                pr_rf_xIsZero,
  output logic                pr_rf_zIsImm,
  output logic                pr_rf_zIsZero,
  output logic                pr_rf_branchUseLt,
  output logic                pr_rf_branchInvert,
  output logic                pr_rf_mulSignedA,
  output logic                pr_rf_mulSignedB,
  output logic                pr_rf_mulHigh,
  output logic                pr_rf_divSigned,
  output logic                pr_rf_divRemainder,
  output logic [2:0]          pr_rf_func3,
  output logic [31:0]         pr_rf_immediate,
  // ---- commit (registered) -----------------------------------------------------
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

  // ---- kill and commit ---------------------------------------------------------
  logic flush_d_r1;  assign flush_d_r1  = cm_flush | (ex_resolveValid & ex_resolveMispredict);
  logic cm_commitRd; assign cm_commitRd = cm_valid & cm_rdWriteEnable & !cm_exception;

  // ---- D: predecoder -----------------------------------------------------------
  logic           d_r1_valid;
  logic [31:0]    d_r1_instr;
  logic           d_r1_rvc;
  logic [30:0]    d_r1_pc;
  logic [MW-1:0]  d_r1_meta;
  logic [4:0]     d_r1_rs1Index, d_r1_rs2Index, d_r1_rdIndex;
  logic           d_r1_rs1Use,   d_r1_rs2Use,   d_r1_rdWriteEnable;
  logic           d_r1_isBranch, d_r1_isJal,    d_r1_isJalr, d_r1_isCall, d_r1_isRet;
  logic [30:0]    d_r1_branchTarget, d_r1_seq;

  predecoder #(.MW(MW)) u_predecoder (
    .clk, .resetn,
    .f5_d_valid,    .f5_d_instr,    .f5_d_rvc,     .f5_d_pc,     .f5_d_meta,
    .stall_d_r1,    .flush_d_r1,
    .d_r1_valid,    .d_r1_instr,    .d_r1_rvc,     .d_r1_pc,     .d_r1_meta,
    .d_r1_rs1Index, .d_r1_rs2Index, .d_r1_rdIndex,
    .d_r1_rs1Use,   .d_r1_rs2Use,   .d_r1_rdWriteEnable,
    .d_r1_isBranch, .d_r1_isJal,    .d_r1_isJalr,  .d_r1_isCall, .d_r1_isRet,
    .d_r1_branchTarget, .d_r1_seq
  );

  // ---- RD1/RD2: rename ---------------------------------------------------------
  logic       stall_r1_r2,   stall_r2_pds,  rd2_skidValid, r2_pds_valid;
  logic [5:0] r2_pds_rs1Tag, r2_pds_rs2Tag, r2_pds_rdTag,  r2_pds_rdOldTag;
  logic       r2_pds_rs1Use, r2_pds_rs2Use, r2_pds_rdWriteEnable;
  logic [4:0] r2_pds_rdIndex;
  logic [3:0] r2_pds_branchMask;
  logic [1:0] r2_pds_snapshot;

  rename u_rename (
    .clk, .resetn,
    .d_r1_valid,      .d_r1_rs1Index, .d_r1_rs2Index,  .d_r1_rdIndex,
    .d_r1_rs1Use,     .d_r1_rs2Use,   .d_r1_rdWriteEnable,
    .d_r1_isBranch,   .d_r1_isJalr,
    .stall_r2_pds,    .stall_r1_r2,   .stall_d_r1,     .rd2_skidValid,
    .ex_resolveValid, .ex_resolveSnapshot, .ex_resolveMispredict,
    .cm_commitRd,     .cm_rdIndex,    .cm_rdTag,       .cm_rdOldTag,   .cm_flush,
    .r2_pds_valid,    .r2_pds_rs1Tag, .r2_pds_rs2Tag,  .r2_pds_rdTag,  .r2_pds_rdOldTag,
    .r2_pds_rs1Use,   .r2_pds_rs2Use, .r2_pds_rdIndex, .r2_pds_rdWriteEnable,
    .r2_pds_branchMask, .r2_pds_snapshot
  );

  // ---- RD1/RD2: decoder --------------------------------------------------------
  logic [30:0]    d2_pds_pc,          d2_pds_branchTarget, d2_pds_seq;
  logic [MW-1:0]  d2_pds_meta;
  logic           d2_pds_isCall,      d2_pds_isRet,        d2_pds_rvc;
  logic           d2_pds_sub,         d2_pds_selArith,     d2_pds_selAnd, d2_pds_selOr, d2_pds_selXor;
  logic           d2_pds_selSlt,      d2_pds_sltUnsigned,  d2_pds_shiftRight, d2_pds_shiftArith;
  logic           d2_pds_xIsPC,       d2_pds_xIsZero,      d2_pds_zIsImm, d2_pds_zIsZero;
  logic           d2_pds_branchUseLt, d2_pds_branchInvert;
  logic           d2_pds_mulSignedA,  d2_pds_mulSignedB,   d2_pds_mulHigh;
  logic           d2_pds_divSigned,   d2_pds_divRemainder;
  logic [2:0]     d2_pds_func3;
  logic           d2_pds_serialising, d2_pds_illegal;
  logic [31:0]    d2_pds_immediate;
  logic [CLASS_W-1:0]   d2_pds_class;
  logic [LATENCY_W-1:0] d2_pds_latency;
  logic [SYSTEM_W-1:0]  d2_pds_system;

  decoder #(.MW(MW)) u_decoder (
    .clk,
    .d_d1_instr        (d_r1_instr),
    .d_d1_rvc          (d_r1_rvc),
    .d_d1_pc           (d_r1_pc),
    .d_d1_meta         (d_r1_meta),
    .d_d1_rs1Use       (d_r1_rs1Use),
    .d_d1_rs2Use       (d_r1_rs2Use),
    .d_d1_isCall       (d_r1_isCall),
    .d_d1_isRet        (d_r1_isRet),
    .d_d1_branchTarget (d_r1_branchTarget),
    .d_d1_seq          (d_r1_seq),
    .stall_d1_d2       (stall_r1_r2),
    .stall_d2_pds      (stall_r2_pds),
    .rd2_skidValid,
    .d2_pds_pc,  .d2_pds_meta,     .d2_pds_isCall, .d2_pds_isRet, .d2_pds_branchTarget,
    .d2_pds_seq, .d2_pds_rvc,      .d2_pds_class,  .d2_pds_latency,
    .d2_pds_sub, .d2_pds_selArith, .d2_pds_selAnd, .d2_pds_selOr, .d2_pds_selXor,
    .d2_pds_selSlt, .d2_pds_sltUnsigned, .d2_pds_shiftRight, .d2_pds_shiftArith,
    .d2_pds_xIsPC,  .d2_pds_xIsZero,     .d2_pds_zIsImm,     .d2_pds_zIsZero,
    .d2_pds_branchUseLt, .d2_pds_branchInvert,
    .d2_pds_mulSignedA,  .d2_pds_mulSignedB,   .d2_pds_mulHigh,
    .d2_pds_divSigned,   .d2_pds_divRemainder, .d2_pds_func3, .d2_pds_system,
    .d2_pds_serialising, .d2_pds_immediate,    .d2_pds_illegal
  );

  // ---- PreDS: predisp ----------------------------------------------------------
  logic       stall_pds_ds,   ds_fire,       ds_iqGo,      ds_iqFire;
  logic       pds_ds_valid;
  logic [5:0] pds_ds_rs1Tag,  pds_ds_rs2Tag, pds_ds_rdTag, pds_ds_rdOldTag;
  logic       pds_ds_rdWriteEnable;
  logic [4:0] pds_ds_rdIndex;
  logic [3:0] pds_ds_branchMask;
  logic [1:0] pds_ds_snapshot;
  logic [7:0] pds_ds_depL1,   pds_ds_depL3,  pds_ds_depL4, pds_ds_depL5;
  logic       pds_ds_rs1Wait, pds_ds_rs2Wait;
  logic [7:0] pds_ds_rs1Slot, pds_ds_rs2Slot;
  logic [7:0] iq_tailSlot,    iq_visible,    iq_grantPrevious;
  logic [7:0] iq_wakeL3,      iq_wakeL4,     iq_wakeL5;
  logic [LATENCY_W-1:0] pds_ds_latency;

  predisp u_predisp (
    .clk, .resetn,
    .r2_pds_valid,      .r2_pds_rs1Tag, .r2_pds_rs2Tag,    .r2_pds_rdTag, .r2_pds_rdOldTag,
    .r2_pds_rs1Use,     .r2_pds_rs2Use, .r2_pds_rdIndex,   .r2_pds_rdWriteEnable,
    .r2_pds_branchMask, .r2_pds_snapshot,
    .d2_pds_latency,
    .stall_pds_ds,      .stall_r2_pds, .ds_iqFire,
    .ex_resolveValid,   .ex_resolveSnapshot, .ex_resolveMispredict, .cm_flush,
    .iq_tailSlot,       .iq_visible,    .iq_grantPrevious, .iq_wakeL3,    .iq_wakeL4, .iq_wakeL5,
    .pds_ds_valid,      .pds_ds_rs1Tag, .pds_ds_rs2Tag,    .pds_ds_rdTag, .pds_ds_rdOldTag,
    .pds_ds_rdIndex,    .pds_ds_rdWriteEnable,
    .pds_ds_branchMask, .pds_ds_snapshot, .pds_ds_latency,
    .pds_ds_depL1,      .pds_ds_depL3,    .pds_ds_depL4,   .pds_ds_depL5,
    .pds_ds_rs1Wait,    .pds_ds_rs2Wait,  .pds_ds_rs1Slot, .pds_ds_rs2Slot
  );

  // ---- PreDS: predisp_payload --------------------------------------------------
  logic [30:0]    pds_ds_pc,     pds_ds_branchTarget, pds_ds_seq;
  logic [MW-1:0]  pds_ds_meta;
  logic           pds_ds_isCall, pds_ds_isRet,        pds_ds_rvc;
  logic           pds_ds_sub,    pds_ds_selArith,     pds_ds_selAnd, pds_ds_selOr, pds_ds_selXor;
  logic           pds_ds_selSlt, pds_ds_sltUnsigned,  pds_ds_shiftRight, pds_ds_shiftArith;
  logic           pds_ds_xIsPC,  pds_ds_xIsZero,      pds_ds_zIsImm, pds_ds_zIsZero;
  logic           pds_ds_branchUseLt, pds_ds_branchInvert;
  logic           pds_ds_mulSignedA,  pds_ds_mulSignedB, pds_ds_mulHigh;
  logic           pds_ds_divSigned,   pds_ds_divRemainder;
  logic [2:0]     pds_ds_func3;
  logic           pds_ds_serialising, pds_ds_illegal;
  logic [31:0]    pds_ds_immediate;
  logic [CLASS_W-1:0]  pds_ds_class;
  logic [SYSTEM_W-1:0] pds_ds_system;

  predisp_payload #(.MW(MW)) u_predispPayload (
    .clk,
    .d2_pds_pc,  .d2_pds_meta,     .d2_pds_isCall, .d2_pds_isRet, .d2_pds_branchTarget,
    .d2_pds_seq, .d2_pds_rvc,      .d2_pds_class,
    .d2_pds_sub, .d2_pds_selArith, .d2_pds_selAnd, .d2_pds_selOr, .d2_pds_selXor,
    .d2_pds_selSlt, .d2_pds_sltUnsigned, .d2_pds_shiftRight, .d2_pds_shiftArith,
    .d2_pds_xIsPC,  .d2_pds_xIsZero,     .d2_pds_zIsImm,     .d2_pds_zIsZero,
    .d2_pds_branchUseLt, .d2_pds_branchInvert,
    .d2_pds_mulSignedA,  .d2_pds_mulSignedB,   .d2_pds_mulHigh,
    .d2_pds_divSigned,   .d2_pds_divRemainder, .d2_pds_func3, .d2_pds_system,
    .d2_pds_serialising, .d2_pds_immediate,    .d2_pds_illegal,
    .stall_pds_ds,
    .pds_ds_pc,  .pds_ds_meta,     .pds_ds_isCall, .pds_ds_isRet, .pds_ds_branchTarget,
    .pds_ds_seq, .pds_ds_rvc,      .pds_ds_class,
    .pds_ds_sub, .pds_ds_selArith, .pds_ds_selAnd, .pds_ds_selOr, .pds_ds_selXor,
    .pds_ds_selSlt, .pds_ds_sltUnsigned, .pds_ds_shiftRight, .pds_ds_shiftArith,
    .pds_ds_xIsPC,  .pds_ds_xIsZero,     .pds_ds_zIsImm,     .pds_ds_zIsZero,
    .pds_ds_branchUseLt, .pds_ds_branchInvert,
    .pds_ds_mulSignedA,  .pds_ds_mulSignedB,   .pds_ds_mulHigh,
    .pds_ds_divSigned,   .pds_ds_divRemainder, .pds_ds_func3, .pds_ds_system,
    .pds_ds_serialising, .pds_ds_immediate,    .pds_ds_illegal
  );

  // ---- DS: dispatch ------------------------------------------------------------
  logic iq_dispatchReady, rob_dispatchReady, rob_empty;

  dispatch u_dispatch (
    .clk, .resetn,
    .d2_pds_class,     .d2_pds_illegal,     .d2_pds_serialising,
    .pds_ds_valid,     .pds_ds_serialising,
    .iq_dispatchReady, .rob_dispatchReady,  .rob_empty,
    .stall_pds_ds,     .ds_fire, .ds_iqGo, .ds_iqFire
  );

  // ---- IS: issue_queue ---------------------------------------------------------
  issue_queue #(.N(8)) u_issueQueue (
    .clk, .resetn,
    .ds_iqGo,
    .pds_ds_depL1,     .pds_ds_depL3,   .pds_ds_depL4,   .pds_ds_depL5,
    .pds_ds_rs1Wait,   .pds_ds_rs2Wait, .pds_ds_rs1Slot, .pds_ds_rs2Slot,
    .pds_ds_rs1FromDiv  (1'b0),
    .pds_ds_rs1FromMiss (1'b0),
    .pds_ds_rs2FromDiv  (1'b0),
    .pds_ds_rs2FromMiss (1'b0),
    .pds_ds_latency,   .pds_ds_rdWriteEnable, .pds_ds_branchMask,
    .iq_dispatchReady,
    .sd_steal           (1'b0),
    .sd_divWake         (1'b0),
    .sd_missWake        (1'b0),
    .ex_resolveValid,  .ex_resolveSnapshot,  .ex_resolveMispredict, .cm_flush,
    .iq_tailSlot,      .iq_visible,
    .iq_grantPrevious, .iq_wakeL3,           .iq_wakeL4,            .iq_wakeL5,
    .is_pr_grant,      .iq_grantBranchMask
  );

  // ---- IS/PR: payload ----------------------------------------------------------
  logic [3:0] ds_robIndex;

  payload #(.MW(MW)) u_payload (
    .clk,
    .ds_iqFire,      .iq_tailSlot,    .ds_robIndex,
    .pds_ds_rs1Tag,  .pds_ds_rs2Tag,  .pds_ds_rdTag,  .pds_ds_rdWriteEnable, .pds_ds_snapshot,
    .pds_ds_pc,      .pds_ds_meta,    .pds_ds_isCall, .pds_ds_isRet,     .pds_ds_branchTarget,
    .pds_ds_seq,     .pds_ds_class,
    .pds_ds_sub,     .pds_ds_selArith,    .pds_ds_selAnd,      .pds_ds_selOr, .pds_ds_selXor,
    .pds_ds_selSlt,  .pds_ds_sltUnsigned, .pds_ds_shiftRight,  .pds_ds_shiftArith,
    .pds_ds_xIsPC,   .pds_ds_xIsZero,     .pds_ds_zIsImm,      .pds_ds_zIsZero,
    .pds_ds_branchUseLt, .pds_ds_branchInvert,
    .pds_ds_mulSignedA,  .pds_ds_mulSignedB,   .pds_ds_mulHigh,
    .pds_ds_divSigned,   .pds_ds_divRemainder, .pds_ds_func3,  .pds_ds_immediate,
    .is_pr_grant,
    .pr_rf_robIndex, .pr_rf_rs1Tag,   .pr_rf_rs2Tag,  .pr_rf_rdTag,      .pr_rf_rdWriteEnable,
    .pr_rf_snapshot, .pr_rf_pc,       .pr_rf_meta,    .pr_rf_isCall,     .pr_rf_isRet,
    .pr_rf_branchTarget, .pr_rf_seq,  .pr_rf_class,
    .pr_rf_sub,      .pr_rf_selArith, .pr_rf_selAnd,  .pr_rf_selOr,      .pr_rf_selXor,
    .pr_rf_selSlt,   .pr_rf_sltUnsigned, .pr_rf_shiftRight, .pr_rf_shiftArith,
    .pr_rf_xIsPC,    .pr_rf_xIsZero,  .pr_rf_zIsImm,  .pr_rf_zIsZero,
    .pr_rf_branchUseLt, .pr_rf_branchInvert,
    .pr_rf_mulSignedA,  .pr_rf_mulSignedB,     .pr_rf_mulHigh,
    .pr_rf_divSigned,   .pr_rf_divRemainder,   .pr_rf_func3,   .pr_rf_immediate
  );

  // ---- DS/CM: rob --------------------------------------------------------------
  rob u_rob (
    .clk, .resetn,
    .ds_fire,
    .pds_ds_rdIndex,    .pds_ds_rdTag, .pds_ds_rdOldTag, .pds_ds_rdWriteEnable,
    .pds_ds_pc,         .pds_ds_rvc,   .pds_ds_class,    .pds_ds_system, .pds_ds_illegal,
    .pds_ds_serialising,
    .rob_dispatchReady, .rob_empty,    .ds_robIndex,
    .wb_valid,          .wb_robIndex,  .wb_exception,    .wb_refetch,    .wb_badAddress,
    .lq_violationValid    (1'b0),
    .lq_violationRobIndex (4'd0),
    .ex_resolveValid,   .ex_resolveMispredict,           .ex_resolveRobIndex,
    .cm_valid,          .cm_exception, .cm_refetch,      .cm_flush,
    .cm_rdIndex,        .cm_rdTag,     .cm_rdOldTag,     .cm_rdWriteEnable,
    .cm_pc,             .cm_rvc,       .cm_system,       .cm_illegal,    .cm_serialising,
    .cm_isLoad,         .cm_isStore,   .cm_badAddress
  );

endmodule

