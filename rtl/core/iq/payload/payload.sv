// ================================================================================
//  Payload RAM: per-slot uop fields, written at dispatch, read by the grant
// ================================================================================
//  PreDS               DS                   IS             PR
//  predisp ─────────┬► dispatch ──fire──┬─► iq ──grant─┬─► payload read
//  predisp_payload ─┘                   └─► payload ───┘
// ================================================================================
//  Holds what execute needs after grant is acquired. IQ rows keep only what
//  the wake/select loop changes each cycle.
//
//  Mechanisms:
//   - One packed word per slot in one LUTRAM array (separate arrays per field
//   round each field up to 4 bits).
//   - Write at the IQ tail slot on ds_iqFire/read by registered grant, both
//   one-hot slots encoded for LUTRAM accessing.
// ================================================================================
`include "uop_defs.svh"

module payload #(
  parameter int MW = 1
) (
  input  logic                clk,
  // ---- dispatch ----------------------------------------------------------------
  input  logic                ds_iqFire,
  input  logic [7:0]          iq_tailSlot,
  input  logic [3:0]          ds_robIndex,
  // ---- Dispatch-1/Dispatch inter-stage pipeline register (rename side) ---------
  input  logic [5:0]          pds_ds_rs1Tag,
  input  logic [5:0]          pds_ds_rs2Tag,
  input  logic [5:0]          pds_ds_rdTag,
  input  logic                pds_ds_rdWriteEnable,
  input  logic [1:0]          pds_ds_snapshot,
  // ---- Dispatch-1/Dispatch inter-stage pipeline register (decoder side) --------
  input  logic [30:0]         pds_ds_pc,
  input  logic [MW-1:0]       pds_ds_meta,
  input  logic                pds_ds_isCall,
  input  logic                pds_ds_isRet,
  input  logic [30:0]         pds_ds_branchTarget,
  input  logic [30:0]         pds_ds_seq,
  input  logic [CLASS_W-1:0]  pds_ds_class,
  input  logic                pds_ds_sub,
  input  logic                pds_ds_selArith,
  input  logic                pds_ds_selAnd,
  input  logic                pds_ds_selOr,
  input  logic                pds_ds_selXor,
  input  logic                pds_ds_selSlt,
  input  logic                pds_ds_sltUnsigned,
  input  logic                pds_ds_shiftRight,
  input  logic                pds_ds_shiftArith,
  input  logic                pds_ds_xIsPC,
  input  logic                pds_ds_xIsZero,
  input  logic                pds_ds_zIsImm,
  input  logic                pds_ds_zIsZero,
  input  logic                pds_ds_branchUseLt,
  input  logic                pds_ds_branchInvert,
  input  logic                pds_ds_mulSignedA,
  input  logic                pds_ds_mulSignedB,
  input  logic                pds_ds_mulHigh,
  input  logic                pds_ds_divSigned,
  input  logic                pds_ds_divRemainder,
  input  logic [2:0]          pds_ds_func3,
  input  logic [31:0]         pds_ds_immediate,
  // ---- Issue/Payload-Read inter-stage pipeline register ------------------------
  input  logic [7:0]          is_pr_grant,         // one-hot
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
  output logic [31:0]         pr_rf_immediate
);

  // ---- one-hot slot to RAM address ---------------------------------------------
  function automatic logic [2:0] encode8(input logic [7:0] val);
    encode8 = {
      val[4] | val[5] | val[6] | val[7],
      val[2] | val[3] | val[6] | val[7],
      val[1] | val[3] | val[5] | val[7]
    };
  endfunction

  // ---- packed word -------------------------------------------------------------
  typedef struct packed {
    logic [3:0]         robIndex;
    logic [5:0]         rs1Tag;
    logic [5:0]         rs2Tag;
    logic [5:0]         rdTag;
    logic               rdWriteEnable;
    logic [1:0]         snapshot;
    logic [30:0]        pc;
    logic [MW-1:0]      meta;
    logic               isCall;
    logic               isRet;
    logic [30:0]        branchTarget;
    logic [30:0]        seq;
    logic [CLASS_W-1:0] class_;
    logic               sub;
    logic               selArith;
    logic               selAnd;
    logic               selOr;
    logic               selXor;
    logic               selSlt;
    logic               sltUnsigned;
    logic               shiftRight;
    logic               shiftArith;
    logic               xIsPC;
    logic               xIsZero;
    logic               zIsImm;
    logic               zIsZero;
    logic               branchUseLt;
    logic               branchInvert;
    logic               mulSignedA;
    logic               mulSignedB;
    logic               mulHigh;
    logic               divSigned;
    logic               divRemainder;
    logic [2:0]         func3;
    logic [31:0]        immediate;
  } word_t;

  word_t pl_writeWord, pl_readWord;
  assign pl_writeWord.robIndex      = ds_robIndex;
  assign pl_writeWord.rs1Tag        = pds_ds_rs1Tag;
  assign pl_writeWord.rs2Tag        = pds_ds_rs2Tag;
  assign pl_writeWord.rdTag         = pds_ds_rdTag;
  assign pl_writeWord.rdWriteEnable = pds_ds_rdWriteEnable;
  assign pl_writeWord.snapshot      = pds_ds_snapshot;
  assign pl_writeWord.pc            = pds_ds_pc;
  assign pl_writeWord.meta          = pds_ds_meta;
  assign pl_writeWord.isCall        = pds_ds_isCall;
  assign pl_writeWord.isRet         = pds_ds_isRet;
  assign pl_writeWord.branchTarget  = pds_ds_branchTarget;
  assign pl_writeWord.seq           = pds_ds_seq;
  assign pl_writeWord.class_        = pds_ds_class;
  assign pl_writeWord.sub           = pds_ds_sub;
  assign pl_writeWord.selArith      = pds_ds_selArith;
  assign pl_writeWord.selAnd        = pds_ds_selAnd;
  assign pl_writeWord.selOr         = pds_ds_selOr;
  assign pl_writeWord.selXor        = pds_ds_selXor;
  assign pl_writeWord.selSlt        = pds_ds_selSlt;
  assign pl_writeWord.sltUnsigned   = pds_ds_sltUnsigned;
  assign pl_writeWord.shiftRight    = pds_ds_shiftRight;
  assign pl_writeWord.shiftArith    = pds_ds_shiftArith;
  assign pl_writeWord.xIsPC         = pds_ds_xIsPC;
  assign pl_writeWord.xIsZero       = pds_ds_xIsZero;
  assign pl_writeWord.zIsImm        = pds_ds_zIsImm;
  assign pl_writeWord.zIsZero       = pds_ds_zIsZero;
  assign pl_writeWord.branchUseLt   = pds_ds_branchUseLt;
  assign pl_writeWord.branchInvert  = pds_ds_branchInvert;
  assign pl_writeWord.mulSignedA    = pds_ds_mulSignedA;
  assign pl_writeWord.mulSignedB    = pds_ds_mulSignedB;
  assign pl_writeWord.mulHigh       = pds_ds_mulHigh;
  assign pl_writeWord.divSigned     = pds_ds_divSigned;
  assign pl_writeWord.divRemainder  = pds_ds_divRemainder;
  assign pl_writeWord.func3         = pds_ds_func3;
  assign pl_writeWord.immediate     = pds_ds_immediate;


  // ---- Payload RAM -------------------------------------------------------------
  // -- plain vector array bcuz yosys 0.62 drops an unpacked array of word_t ------
  logic [$bits(pl_writeWord)-1:0] pl_ram [8];
  always_ff @(posedge clk)
    if (ds_iqFire) pl_ram[encode8(iq_tailSlot)] <= pl_writeWord;

  // ---- Payload-Read/Register-File inter-stage pipeline register ----------------
  always_ff @(posedge clk)
    pl_readWord <= pl_ram[encode8(is_pr_grant)];

  assign pr_rf_robIndex      = pl_readWord.robIndex;
  assign pr_rf_rs1Tag        = pl_readWord.rs1Tag;
  assign pr_rf_rs2Tag        = pl_readWord.rs2Tag;
  assign pr_rf_rdTag         = pl_readWord.rdTag;
  assign pr_rf_rdWriteEnable = pl_readWord.rdWriteEnable;
  assign pr_rf_snapshot      = pl_readWord.snapshot;
  assign pr_rf_pc            = pl_readWord.pc;
  assign pr_rf_meta          = pl_readWord.meta;
  assign pr_rf_isCall        = pl_readWord.isCall;
  assign pr_rf_isRet         = pl_readWord.isRet;
  assign pr_rf_branchTarget  = pl_readWord.branchTarget;
  assign pr_rf_seq           = pl_readWord.seq;
  assign pr_rf_class         = pl_readWord.class_;
  assign pr_rf_sub           = pl_readWord.sub;
  assign pr_rf_selArith      = pl_readWord.selArith;
  assign pr_rf_selAnd        = pl_readWord.selAnd;
  assign pr_rf_selOr         = pl_readWord.selOr;
  assign pr_rf_selXor        = pl_readWord.selXor;
  assign pr_rf_selSlt        = pl_readWord.selSlt;
  assign pr_rf_sltUnsigned   = pl_readWord.sltUnsigned;
  assign pr_rf_shiftRight    = pl_readWord.shiftRight;
  assign pr_rf_shiftArith    = pl_readWord.shiftArith;
  assign pr_rf_xIsPC         = pl_readWord.xIsPC;
  assign pr_rf_xIsZero       = pl_readWord.xIsZero;
  assign pr_rf_zIsImm        = pl_readWord.zIsImm;
  assign pr_rf_zIsZero       = pl_readWord.zIsZero;
  assign pr_rf_branchUseLt   = pl_readWord.branchUseLt;
  assign pr_rf_branchInvert  = pl_readWord.branchInvert;
  assign pr_rf_mulSignedA    = pl_readWord.mulSignedA;
  assign pr_rf_mulSignedB    = pl_readWord.mulSignedB;
  assign pr_rf_mulHigh       = pl_readWord.mulHigh;
  assign pr_rf_divSigned     = pl_readWord.divSigned;
  assign pr_rf_divRemainder  = pl_readWord.divRemainder;
  assign pr_rf_func3         = pl_readWord.func3;
  assign pr_rf_immediate     = pl_readWord.immediate;

endmodule

