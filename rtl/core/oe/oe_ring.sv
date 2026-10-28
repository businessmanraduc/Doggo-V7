// ================================================================================
//  oe_ring -- ring wrapper: every top port register-bounded
//  ports are the ring convention: clk, perturb (in), q (out)
// ================================================================================
`include "uop_defs.svh"

module oe_ring (
  input  logic clk,
  input  logic perturb,
  output logic q
);

  logic [127:0] s;
  lfsr_src #(.W(32)) u_s0 (.clk, .perturb(perturb), .q(s[31:0]));
  lfsr_src #(.W(32)) u_s1 (.clk, .perturb(s[0]), .q(s[63:32]));
  lfsr_src #(.W(32)) u_s2 (.clk, .perturb(s[32]), .q(s[95:64]));
  lfsr_src #(.W(32)) u_s3 (.clk, .perturb(s[64]), .q(s[127:96]));

  logic stall_d_r1;
  logic [7:0] is_pr_grant;
  logic [3:0] iq_grantBranchMask;
  logic [3:0] pr_rf_robIndex;
  logic [5:0] pr_rf_rs1Tag;
  logic [5:0] pr_rf_rs2Tag;
  logic [5:0] pr_rf_rdTag;
  logic pr_rf_rdWriteEnable;
  logic [1:0] pr_rf_snapshot;
  logic [30:0] pr_rf_pc;
  logic [0:0] pr_rf_meta;
  logic pr_rf_isCall;
  logic pr_rf_isRet;
  logic [30:0] pr_rf_branchTarget;
  logic [30:0] pr_rf_seq;
  logic [CLASS_W-1:0] pr_rf_class;
  logic pr_rf_sub;
  logic pr_rf_selArith;
  logic pr_rf_selAnd;
  logic pr_rf_selOr;
  logic pr_rf_selXor;
  logic pr_rf_selSlt;
  logic pr_rf_sltUnsigned;
  logic pr_rf_shiftRight;
  logic pr_rf_shiftArith;
  logic pr_rf_xIsPC;
  logic pr_rf_xIsZero;
  logic pr_rf_zIsImm;
  logic pr_rf_zIsZero;
  logic pr_rf_branchUseLt;
  logic pr_rf_branchInvert;
  logic pr_rf_mulSignedA;
  logic pr_rf_mulSignedB;
  logic pr_rf_mulHigh;
  logic pr_rf_divSigned;
  logic pr_rf_divRemainder;
  logic [2:0] pr_rf_func3;
  logic [31:0] pr_rf_immediate;
  logic cm_valid;
  logic cm_exception;
  logic cm_refetch;
  logic cm_flush;
  logic [4:0] cm_rdIndex;
  logic [5:0] cm_rdTag;
  logic [5:0] cm_rdOldTag;
  logic cm_rdWriteEnable;
  logic [30:0] cm_pc;
  logic cm_rvc;
  logic [SYSTEM_W-1:0] cm_system;
  logic cm_illegal;
  logic cm_serialising;
  logic cm_isLoad;
  logic cm_isStore;
  logic [31:0] cm_badAddress;

  oe #(.MW(1)) u_dut (
    .clk,
    .resetn                (s[0]),
    .f5_d_valid            (s[1]),
    .f5_d_instr            (s[33:2]),
    .f5_d_rvc              (s[34]),
    .f5_d_pc               (s[65:35]),
    .f5_d_meta             (s[66]),
    .ex_resolveValid       (s[67]),
    .ex_resolveSnapshot    (s[69:68]),
    .ex_resolveMispredict  (s[70]),
    .ex_resolveRobIndex    (s[74:71]),
    .wb_valid              (s[75]),
    .wb_robIndex           (s[79:76]),
    .wb_exception          (s[80]),
    .wb_refetch            (s[81]),
    .wb_badAddress         (s[113:82]),
    .stall_d_r1,
    .is_pr_grant,
    .iq_grantBranchMask,
    .pr_rf_robIndex,
    .pr_rf_rs1Tag,
    .pr_rf_rs2Tag,
    .pr_rf_rdTag,
    .pr_rf_rdWriteEnable,
    .pr_rf_snapshot,
    .pr_rf_pc,
    .pr_rf_meta,
    .pr_rf_isCall,
    .pr_rf_isRet,
    .pr_rf_branchTarget,
    .pr_rf_seq,
    .pr_rf_class,
    .pr_rf_sub,
    .pr_rf_selArith,
    .pr_rf_selAnd,
    .pr_rf_selOr,
    .pr_rf_selXor,
    .pr_rf_selSlt,
    .pr_rf_sltUnsigned,
    .pr_rf_shiftRight,
    .pr_rf_shiftArith,
    .pr_rf_xIsPC,
    .pr_rf_xIsZero,
    .pr_rf_zIsImm,
    .pr_rf_zIsZero,
    .pr_rf_branchUseLt,
    .pr_rf_branchInvert,
    .pr_rf_mulSignedA,
    .pr_rf_mulSignedB,
    .pr_rf_mulHigh,
    .pr_rf_divSigned,
    .pr_rf_divRemainder,
    .pr_rf_func3,
    .pr_rf_immediate,
    .cm_valid,
    .cm_exception,
    .cm_refetch,
    .cm_flush,
    .cm_rdIndex,
    .cm_rdTag,
    .cm_rdOldTag,
    .cm_rdWriteEnable,
    .cm_pc,
    .cm_rvc,
    .cm_system,
    .cm_illegal,
    .cm_serialising,
    .cm_isLoad,
    .cm_isStore,
    .cm_badAddress
  );

  xor_sink #(.W(297)) u_snk (.clk, .q, .d({
    stall_d_r1, is_pr_grant, iq_grantBranchMask, pr_rf_robIndex, pr_rf_rs1Tag,
    pr_rf_rs2Tag, pr_rf_rdTag, pr_rf_rdWriteEnable, pr_rf_snapshot, pr_rf_pc,
    pr_rf_meta, pr_rf_isCall, pr_rf_isRet, pr_rf_branchTarget, pr_rf_seq,
    pr_rf_class, pr_rf_sub, pr_rf_selArith, pr_rf_selAnd, pr_rf_selOr, pr_rf_selXor,
    pr_rf_selSlt, pr_rf_sltUnsigned, pr_rf_shiftRight, pr_rf_shiftArith,
    pr_rf_xIsPC, pr_rf_xIsZero, pr_rf_zIsImm, pr_rf_zIsZero, pr_rf_branchUseLt,
    pr_rf_branchInvert, pr_rf_mulSignedA, pr_rf_mulSignedB, pr_rf_mulHigh,
    pr_rf_divSigned, pr_rf_divRemainder, pr_rf_func3, pr_rf_immediate, cm_valid,
    cm_exception, cm_refetch, cm_flush, cm_rdIndex, cm_rdTag, cm_rdOldTag,
    cm_rdWriteEnable, cm_pc, cm_rvc, cm_system, cm_illegal, cm_serialising,
    cm_isLoad, cm_isStore, cm_badAddress}));

endmodule
