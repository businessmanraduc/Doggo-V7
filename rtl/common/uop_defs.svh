// ================================================================================
//  uop_defs -- bit indices of the one-hot uop vectors made by dec_r
// ================================================================================
//  Included at file scope, before the module itself.
// ================================================================================

`ifndef UOP_DEFS_SVH
`define UOP_DEFS_SVH

// ---- class: which unit executes the uop ----------------------------------------
localparam int CLASS_ALU    = 0;
localparam int CLASS_SHIFT  = 1;
localparam int CLASS_SLT    = 2;
localparam int CLASS_LOAD   = 3;
localparam int CLASS_STORE  = 4;
localparam int CLASS_BRANCH = 5;
localparam int CLASS_JAL    = 6;
localparam int CLASS_JALR   = 7;
localparam int CLASS_MUL    = 8;
localparam int CLASS_DIV    = 9;
localparam int CLASS_CSR    = 10;
localparam int CLASS_SYSTEM = 11;
localparam int CLASS_W      = 12;

// ---- latency group of a result (issue to issue); none for no result ------------
localparam int LATENCY_1    = 0;
localparam int LATENCY_3    = 1;
localparam int LATENCY_4    = 2;
localparam int LATENCY_5    = 3;
localparam int LATENCY_DIV  = 4;
localparam int LATENCY_W    = 5;

// ---- system op, executed at the ROB head ---------------------------------------
localparam int SYSTEM_ECALL  = 0;
localparam int SYSTEM_EBREAK = 1;
localparam int SYSTEM_MRET   = 2;
localparam int SYSTEM_WFI    = 3;
localparam int SYSTEM_FENCE  = 4;
localparam int SYSTEM_FENCEI = 5;
localparam int SYSTEM_W      = 6;

`endif
