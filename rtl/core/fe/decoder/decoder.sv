// ================================================================================
//  Fetch Engine Decoder: rename-critical decode of RV32IMC + Zicsr + Zifencei
// ================================================================================
//  The 32-bit and 16-bit encodings are to be decoded in parallel from the
//  aligned instruction incoming, while the rvc flag decides the winner out of
//  the two decoded pairs.
//
//  Purpose:
//   - Only what rename needs at R1 and what the L2 predictor needs at P7 is made
//     here. Everything else is passed on as the job for the R1 and R2 stages to
//     figure out in order to meet ns timing constraints.
//   - Illegal encodings are not treated here.
//   - x0 is folded per path in rdWriteEnable, rs1Use, rs2Use.
//   - makes pc, branchTarget and seq halfword addresses.
// ================================================================================
module decoder #(
  parameter int MW = 1                      // prediction metadata to F1
) (
  input  logic          clk,
  input  logic          resetn,
  // ---- Fetch-5/Decode inter-stage pipeline register ----------------------------
  input  logic          f5_d_valid,
  input  logic [31:0]   f5_d_instr,
  input  logic          f5_d_rvc,
  input  logic [30:0]   f5_d_pc,
  input  logic [MW-1:0] f5_d_meta,
  // ---- Decode/Rename-1 inter-stage pipeline register controls ------------------
  input  logic          stall_d_r1,         // R1 cannot take the register -> hold
  input  logic          flush_d_r1,         // kill the register's instruction
  // ---- Decode/Rename-1 inter-stage pipeline register ---------------------------
  output logic          d_r1_valid,
  output logic [31:0]   d_r1_instr,
  output logic          d_r1_rvc,
  output logic [30:0]   d_r1_pc,
  output logic [MW-1:0] d_r1_meta,
  output logic [4:0]    d_r1_rs1Index,
  output logic [4:0]    d_r1_rs2Index,
  output logic [4:0]    d_r1_rdIndex,
  output logic          d_r1_rs1Use,
  output logic          d_r1_rs2Use,
  output logic          d_r1_rdWriteEnable,
  output logic          d_r1_isBranch,
  output logic          d_r1_isJal,
  output logic          d_r1_isJalr,
  output logic          d_r1_isCall,
  output logic          d_r1_isRet,
  output logic [30:0]   d_r1_branchTarget,  // pc + offset, valid for isBranch and isJal
  output logic [30:0]   d_r1_seq            // pc + instruction length
);

  // ---- 32-bit opcodes (instr[6:2]) ---------------------------------------------
  localparam logic [4:0] OP_LOAD    = 5'b00000;
  localparam logic [4:0] OP_IMM     = 5'b00100;
  localparam logic [4:0] OP_AUIPC   = 5'b00101;
  localparam logic [4:0] OP_STORE   = 5'b01000;
  localparam logic [4:0] OP_OP      = 5'b01100;
  localparam logic [4:0] OP_LUI     = 5'b01101;
  localparam logic [4:0] OP_BRANCH  = 5'b11000;
  localparam logic [4:0] OP_JALR    = 5'b11001;
  localparam logic [4:0] OP_JAL     = 5'b11011;
  localparam logic [4:0] OP_SYSTEM  = 5'b11100;

  logic [31:0] d_instr; assign d_instr = f5_d_instr;

  // ---- 32-bit path -------------------------------------------------------------
  logic [4:0] w_op, w_rdIndex, w_rs1Index,   w_rs2Index;
  logic       w_rdWriteEnable, w_rs1Use,     w_rs2Use;
  logic       w_rdNonZero,     w_rs1NonZero, w_rs2NonZero;
  logic       w_isBranch, w_isJal, w_isJalr, w_rdLink, w_rs1Link, w_isRet;

  assign w_op       = d_instr[6:2];
  assign w_rdIndex  = d_instr[11:7];
  assign w_rs1Index = d_instr[19:15];
  assign w_rs2Index = d_instr[24:20];

  always_comb begin
    w_rdWriteEnable = 1'b0;
    w_rs1Use        = 1'b0;
    w_rs2Use        = 1'b0;
    case (w_op)
      OP_LUI, OP_AUIPC, OP_JAL: {w_rdWriteEnable}                     = 1'b1;
      OP_JALR, OP_LOAD, OP_IMM: {w_rdWriteEnable, w_rs1Use}           = 2'b11;
      OP_OP:                    {w_rdWriteEnable, w_rs1Use, w_rs2Use} = 3'b111;
      OP_BRANCH, OP_STORE:      {w_rs1Use, w_rs2Use}                  = 2'b11;
      OP_SYSTEM: begin
        w_rdWriteEnable = d_instr[13:12] != 2'b00;
        w_rs1Use        = d_instr[13:12] != 2'b00 && !d_instr[14];
      end
      default: ;
    endcase
  end

  assign w_rdNonZero  = w_rdIndex  != 5'd0;
  assign w_rs1NonZero = w_rs1Index != 5'd0;
  assign w_rs2NonZero = w_rs2Index != 5'd0;
  assign w_isBranch   = w_op       == OP_BRANCH;
  assign w_isJal      = w_op       == OP_JAL;
  assign w_isJalr     = w_op       == OP_JALR;
  assign w_rdLink     = w_rdIndex  == 5'd1 || w_rdIndex  == 5'd5;
  assign w_rs1Link    = w_rs1Index == 5'd1 || w_rs1Index == 5'd5;
  assign w_isRet = w_isJalr && w_rs1Link && !(w_rdLink && d_instr[9] == d_instr[17]);

  // ---- 16-bit path -------------------------------------------------------------
  logic [15:0] c_instr;
  logic [4:0]  c_rdIndexFull, c_rs2IndexFull, c_rdIndexPart, c_rs2IndexPart;
  logic [4:0]  c_rdIndex, c_rs1Index, c_rs2Index;
  logic        c_rdNonZero, c_rs2NonZero;
  logic        c_rdWriteEnable, c_rs1Use, c_rs2Use;
  logic        c_isBranch, c_isJal, c_isJalr, c_isCall, c_isRet;

  assign c_instr        = f5_d_instr[15:0];
  assign c_rdIndexFull  = c_instr[11:7];
  assign c_rs2IndexFull = c_instr[6:2];
  assign c_rdIndexPart  = {2'b01, c_instr[9:7]};
  assign c_rs2IndexPart = {2'b01, c_instr[4:2]};
  assign c_rdNonZero    = c_rdIndexFull  != 5'd0;
  assign c_rs2NonZero   = c_rs2IndexFull != 5'd0;

  always_comb begin
    c_rdIndex       = c_rdIndexFull;
    c_rs1Index      = c_rdIndexFull;
    c_rs2Index      = c_rs2IndexFull;
    c_rdWriteEnable = 1'b0;
    c_rs1Use        = 1'b0;
    c_rs2Use        = 1'b0;
    case ({c_instr[15:13], c_instr[1:0]})
      5'b000_00: begin                            // c.addi4spn
        c_rdIndex       = c_rs2IndexPart; c_rs1Index = 5'd2;
        c_rdWriteEnable = 1'b1;           c_rs1Use   = 1'b1;
      end
      5'b010_00: begin                            // c.lw
        c_rdIndex       = c_rs2IndexPart; c_rs1Index = c_rdIndexPart;
        c_rdWriteEnable = 1'b1;           c_rs1Use   = 1'b1;
      end
      5'b110_00: begin                            // c.sw
        c_rs1Index      = c_rdIndexPart;  c_rs2Index = c_rs2IndexPart;
        c_rs1Use        = 1'b1;           c_rs2Use   = 1'b1;
      end
      5'b000_01, 5'b000_10: begin                 // c.addi, c.slli
        c_rdWriteEnable = c_rdNonZero;    c_rs1Use   = c_rdNonZero;
      end
      5'b001_01: begin                            // c.jal
        c_rdWriteEnable = 1'b1;           c_rdIndex  = 5'd1;
      end
      5'b010_01: begin                            // c.li
        c_rdWriteEnable = c_rdNonZero;
      end
      5'b011_01: begin                            // c.addi16sp / c.lui
        c_rdWriteEnable = c_rdNonZero;    c_rs1Use   = c_rdIndexFull == 5'd2;
      end
      5'b100_01: begin                            // c.srli .. c.and
        c_rdIndex       = c_rdIndexPart;  c_rs1Index = c_rdIndexPart;
        c_rdWriteEnable = 1'b1;           c_rs2Index = c_rs2IndexPart;
        c_rs1Use        = 1'b1;           c_rs2Use   = c_instr[11:10] == 2'b11;
      end
      5'b110_01, 5'b111_01: begin                 // c.beqz, c.bnez
        c_rs1Index      = c_rdIndexPart;  c_rs1Use   = 1'b1;
      end
      5'b010_10: begin                            // c.lwsp
        c_rs1Index      = 5'd2;           c_rs1Use   = 1'b1;
        c_rdWriteEnable = c_rdNonZero;
      end
      5'b100_10: begin
        if (!c_rs2NonZero) begin                  // c.jr, c.jalr, c.ebreak
          c_rdIndex       = 5'd1;         c_rs1Use   = c_rdNonZero;
          c_rdWriteEnable = c_instr[12] && c_rdNonZero;
        end else begin                            // c.mv, c.add
          c_rdWriteEnable = c_rdNonZero;  c_rs2Use   = 1'b1;
          c_rs1Use        = c_instr[12] && c_rdNonZero;
        end
      end
      5'b110_10: begin                            // c.swsp
        c_rs1Index        = 5'd2;         c_rs1Use   = 1'b1;
        c_rs2Use          = c_rs2NonZero;
      end
      default: ;                                  // c.j, FP, reserved
    endcase
  end

  assign c_isBranch = c_instr[1:0] == 2'b01 && c_instr[15:14] == 2'b11;
  assign c_isJal    = c_instr[1:0] == 2'b01 && c_instr[14:13] == 2'b01;
  assign c_isJalr   = c_instr[1:0] == 2'b10 && c_instr[15:13] == 3'b100 && !c_rs2NonZero && c_rdNonZero;
  assign c_isCall   = (c_isJal && !c_instr[15]) || (c_isJalr && c_instr[12]);
  assign c_isRet    = c_isJalr &&  (c_rdIndexFull == 5'd1 || c_rdIndexFull == 5'd5)
                               && !(c_instr[12]           && c_rdIndexFull == 5'd1);

  // ---- direct target + sequential pc -------------------------------------------
  logic [31:0] w_immB, w_immJ, c_immB, c_immJ, d_imm;
  logic [30:0] d_branchTarget, d_seq;

  assign w_immB = {{20{d_instr[31]}}, d_instr[7],     d_instr[30:25], d_instr[11:8],  1'b0};
  assign w_immJ = {{12{d_instr[31]}}, d_instr[19:12], d_instr[20],    d_instr[30:21], 1'b0};
  assign c_immB = {{24{c_instr[12]}}, c_instr[6:5],   c_instr[2],     c_instr[11:10], c_instr[4:3],  1'b0};
  assign c_immJ = {{21{c_instr[12]}}, c_instr[8],     c_instr[10:9],  c_instr[6],     c_instr[7],
                       c_instr[2],    c_instr[11],    c_instr[5:3],   1'b0};
  assign d_imm  = f5_d_rvc ? (c_instr[14] ? c_immB : c_immJ) : (d_instr[3] ? w_immJ : w_immB);

  assign d_branchTarget = f5_d_pc + d_imm[31:1];
  assign d_seq          = f5_d_pc + (f5_d_rvc ? 31'd1 : 31'd2);

  // ---- merge -------------------------------------------------------------------
  logic [4:0] d_rdIndex, d_rs1Index, d_rs2Index;
  logic       d_rdWriteEnable, d_rs1Use, d_rs2Use, d_isBranch;
  logic       d_isJal,         d_isJalr, d_isCall, d_isRet;

  assign d_rdIndex       = f5_d_rvc ? c_rdIndex       : w_rdIndex;
  assign d_rs1Index      = f5_d_rvc ? c_rs1Index      : w_rs1Index;
  assign d_rs2Index      = f5_d_rvc ? c_rs2Index      : w_rs2Index;
  assign d_rdWriteEnable = f5_d_rvc ? c_rdWriteEnable : w_rdWriteEnable && w_rdNonZero;
  assign d_rs1Use        = f5_d_rvc ? c_rs1Use        : w_rs1Use && w_rs1NonZero;
  assign d_rs2Use        = f5_d_rvc ? c_rs2Use        : w_rs2Use && w_rs2NonZero;
  assign d_isBranch      = f5_d_rvc ? c_isBranch      : w_isBranch;
  assign d_isJal         = f5_d_rvc ? c_isJal         : w_isJal;
  assign d_isJalr        = f5_d_rvc ? c_isJalr        : w_isJalr;
  assign d_isCall        = f5_d_rvc ? c_isCall        : (w_isJal || w_isJalr) && w_rdLink;
  assign d_isRet         = f5_d_rvc ? c_isRet         : w_isRet;

  // ---- Decode/Rename-1 inter-stage pipeline register ---------------------------
  always_ff @(posedge clk) begin
    if (!resetn || flush_d_r1) d_r1_valid <= 1'b0;
    else if (!stall_d_r1)      d_r1_valid <= f5_d_valid;
    if (!stall_d_r1) begin
      d_r1_instr         <= f5_d_instr;
      d_r1_rvc           <= f5_d_rvc;
      d_r1_pc            <= f5_d_pc;
      d_r1_meta          <= f5_d_meta;
      d_r1_rs1Index      <= d_rs1Index;
      d_r1_rs2Index      <= d_rs2Index;
      d_r1_rdIndex       <= d_rdIndex;
      d_r1_rs1Use        <= d_rs1Use;
      d_r1_rs2Use        <= d_rs2Use;
      d_r1_rdWriteEnable <= d_rdWriteEnable;
      d_r1_isBranch      <= d_isBranch;
      d_r1_isJal         <= d_isJal;
      d_r1_isJalr        <= d_isJalr;
      d_r1_isCall        <= d_isCall;
      d_r1_isRet         <= d_isRet;
      d_r1_branchTarget  <= d_branchTarget;
      d_r1_seq           <= d_seq;
    end
  end

endmodule

