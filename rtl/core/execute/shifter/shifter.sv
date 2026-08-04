`include "isa.svh"
// ================================================================================
//  PHANTOoOM-32 -- Shifter FU
// ================================================================================
//  Barrel shifter split across one register stage: coarse by {amount[4:3], 3'b0},
//  then fine by amount[2:0], so the pair equals one shift by amount[4:0].
//
//  Fully pipelined, accepts a new op every cycle, result one cycle late behind
//  the ALU's result.
//
//  Solo Fmax (ring-of-regs, nextpnr --85k, tw=100, 20 seeds): 187.48 / 195.69 / 203.87
// ================================================================================
module shifter (
  input  logic        clk,
  input  logic [31:0] operand,    // value to shift (rs1)
  input  logic [4:0]  amount,     // shift amount   (rs2[4:0] or imm)
  input  shiftOp_t    op,         // direction and fill
  output logic [31:0] result
);

  logic [31:0] coarse;
  logic [31:0] s1_data;
  logic [2:0]  s1_amount;
  shiftOp_t    s1_op;

  always_comb begin
    case (op)
      SHIFT_SLL: coarse = operand << {amount[4:3], 3'b000};
      SHIFT_SRA: coarse = 32'($signed(operand) >>> {amount[4:3], 3'b000});
      default:   coarse = operand >> {amount[4:3], 3'b000};
    endcase
  end

  always_ff @(posedge clk) begin
    s1_data   <= coarse;
    s1_amount <= amount[2:0];
    s1_op     <= op;
  end

  always_comb begin
    case (s1_op)
      SHIFT_SLL: result = s1_data << s1_amount;
      SHIFT_SRA: result = 32'($signed(s1_data) >>> s1_amount);
      default:   result = s1_data >> s1_amount;
    endcase
  end

endmodule

