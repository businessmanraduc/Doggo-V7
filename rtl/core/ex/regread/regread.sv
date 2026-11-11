// ================================================================================
//  Register read: forward selects in RF, six-source operand forward in RR
// ================================================================================
//  RF (s+2)                  RR (s+3)                         EX0 (s+4)
//  rf data, pc, imm, seq ──► rf_rr_x/z ──┐
//  tags vs 6 producers   ──► selects   ──┼─► 2 LUT levels ──► rr_ex0_x/z ──► alu
//  EX1..CM results (respipe, alu) ───────┘
// ================================================================================
//  Mechanisms:
//   - Each source tag compared with producers that will hold the needed value
//   in the next cycle; no match -> the RF value.
// ================================================================================
`include "uop_defs.svh"

module regread (
  input  logic               clk,
  // ---- Payload-Read/Register-File inter-stage pipeline register ----------------
  input  logic [5:0]         pr_rf_rs1Tag,
  input  logic [5:0]         pr_rf_rs2Tag,
  input  logic [30:0]        pr_rf_pc,
  input  logic [30:0]        pr_rf_seq,
  input  logic [CLASS_W-1:0] pr_rf_class,
  input  logic               pr_rf_sub,
  input  logic               pr_rf_selArith,
  input  logic               pr_rf_selAnd,
  input  logic               pr_rf_selOr,
  input  logic               pr_rf_selXor,
  input  logic               pr_rf_sltUnsigned,
  input  logic               pr_rf_xIsPC,
  input  logic               pr_rf_xIsZero,
  input  logic               pr_rf_zIsImm,
  input  logic               pr_rf_zIsZero,
  input  logic               pr_rf_branchUseLt,
  input  logic               pr_rf_branchInvert,
  input  logic [31:0]        pr_rf_immediate,
  // ---- RF read -----------------------------------------------------------------
  input  logic [31:0]        rf_rs1Data,
  input  logic [31:0]        rf_rs2Data,
  // ---- producers (respipe) -----------------------------------------------------
  input  logic               rf_rr_producer,
  input  logic [5:0]         rf_rr_rdTag,
  input  logic               rr_ex0_producer,
  input  logic [5:0]         rr_ex0_rdTag,
  input  logic               ex0_ex1_producer,
  input  logic [5:0]         ex0_ex1_rdTag,
  input  logic               ex1_ex2_producer,
  input  logic [5:0]         ex1_ex2_rdTag,
  input  logic               ex2_ex3_producer,
  input  logic [5:0]         ex2_ex3_rdTag,
  input  logic               ex3_wb_producer,
  input  logic [5:0]         ex3_wb_rdTag,
  // ---- results -----------------------------------------------------------------
  input  logic [31:0]        ex0_ex1_result,
  input  logic [31:0]        ex1_ex2_result,
  input  logic [31:0]        ex2_ex3_result,
  input  logic [31:0]        ex3_wb_result,
  input  logic [31:0]        wb_cm_result,
  // ---- Register-File/Register-Read inter-stage pipeline register ---------------
  output logic               rf_rr_selfX,
  output logic               rf_rr_selfZ,
  output logic               rf_rr_sub,
  output logic               rf_rr_selArith,
  output logic               rf_rr_selAnd,
  output logic               rf_rr_selOr,
  output logic               rf_rr_selXor,
  output logic               rf_rr_sltUnsigned,
  output logic               rf_rr_branchUseLt,
  output logic               rf_rr_branchInvert,
  // ---- Register-Read/Execute0 inter-stage pipeline register --------------------
  output logic [31:0]        rr_ex0_x,
  output logic [31:0]        rr_ex0_z
);

  // ---- RF: tag compares --------------------------------------------------------
  logic [5:0] rr_producer; assign rr_producer = {
    ex3_wb_producer,  ex2_ex3_producer, ex1_ex2_producer,
    ex0_ex1_producer, rr_ex0_producer,  rf_rr_producer
  };
  logic [5:0] rr_tag [6];
  assign rr_tag[0] = rf_rr_rdTag;
  assign rr_tag[1] = rr_ex0_rdTag;
  assign rr_tag[2] = ex0_ex1_rdTag;
  assign rr_tag[3] = ex1_ex2_rdTag;
  assign rr_tag[4] = ex2_ex3_rdTag;
  assign rr_tag[5] = ex3_wb_rdTag;

  logic [5:0] rr_matchX, rr_matchZ;
  for (genvar k = 0; k < 6; k++) begin : g_match
    assign rr_matchX[k] = rr_producer[k] & (rr_tag[k] == pr_rf_rs1Tag);
    assign rr_matchZ[k] = rr_producer[k] & (rr_tag[k] == pr_rf_rs2Tag);
  end

  logic rr_isLink; assign rr_isLink = pr_rf_class[CLASS_JAL] | pr_rf_class[CLASS_JALR];
  logic rr_useX;   assign rr_useX   = !pr_rf_xIsPC  & !pr_rf_xIsZero & !rr_isLink;
  logic rr_useZ;   assign rr_useZ   = !pr_rf_zIsImm & !pr_rf_zIsZero & !rr_isLink;

  // ---- RF/RR: operands & selects -----------------------------------------------
  logic [31:0] rf_rr_x,    rf_rr_z;
  logic [5:0]  rf_rr_selX, rf_rr_selZ;
  logic        rf_rr_subZ;
  always_ff @(posedge clk) begin
    rf_rr_x <= pr_rf_xIsPC ? {pr_rf_pc,  1'b0} : rf_rs1Data;
    rf_rr_z <= rr_isLink   ? {pr_rf_seq, 1'b0} : pr_rf_zIsImm ? pr_rf_immediate : rf_rs2Data;

    rf_rr_selfX <= rr_useX & rr_matchX[0];
    rf_rr_selfZ <= rr_useZ & rr_matchZ[0];
    rf_rr_selX  <= {{5{rr_useX}} & rr_matchX[5:1], pr_rf_xIsPC  | (rr_useX & !(|rr_matchX))};
    rf_rr_selZ  <= {{5{rr_useZ}} & rr_matchZ[5:1], pr_rf_zIsImm | (rr_useZ & !(|rr_matchZ)) | rr_isLink};
    rf_rr_subZ  <= pr_rf_sub & !(rr_useZ & rr_matchZ[0]);

    rf_rr_sub           <= pr_rf_sub;
    rf_rr_selArith      <= pr_rf_selArith | rr_isLink;
    rf_rr_selAnd        <= pr_rf_selAnd;
    rf_rr_selOr         <= pr_rf_selOr;
    rf_rr_selXor        <= pr_rf_selXor;
    rf_rr_sltUnsigned   <= pr_rf_sltUnsigned;
    rf_rr_branchUseLt   <= pr_rf_branchUseLt;
    rf_rr_branchInvert  <= pr_rf_branchInvert;
  end

  // ---- RR: two-level one-hot forward per bit -----------------------------------
  (* keep *) logic [31:0] rr_xa, rr_xb, rr_xc, rr_za, rr_zb, rr_zc;
  assign rr_xa = (rf_rr_x        & {32{rf_rr_selX[0]}}) | (ex0_ex1_result & {32{rf_rr_selX[1]}});
  assign rr_xb = (ex1_ex2_result & {32{rf_rr_selX[2]}}) | (ex2_ex3_result & {32{rf_rr_selX[3]}});
  assign rr_xc = (ex3_wb_result  & {32{rf_rr_selX[4]}}) | (wb_cm_result   & {32{rf_rr_selX[5]}});
  assign rr_za = (rf_rr_z        & {32{rf_rr_selZ[0]}}) | (ex0_ex1_result & {32{rf_rr_selZ[1]}});
  assign rr_zb = (ex1_ex2_result & {32{rf_rr_selZ[2]}}) | (ex2_ex3_result & {32{rf_rr_selZ[3]}});
  assign rr_zc = (ex3_wb_result  & {32{rf_rr_selZ[4]}}) | (wb_cm_result   & {32{rf_rr_selZ[5]}});

  always_ff @(posedge clk) begin
    rr_ex0_x <= (rr_xa | rr_xb | rr_xc);
    rr_ex0_z <= (rr_za | rr_zb | rr_zc) ^ {32{rf_rr_subZ}};
  end

endmodule

