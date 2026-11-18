# phantooom_core solo Fmax

ring-of-regs, nextpnr --85k CABGA381, tw=100, 20 seeds
tools: Yosys 0.62, nextpnr-35f1433

| floor | median | mean | ceil |
|---|---|---|---|
| 129.23 | 140.70 | 139.96 | 147.69 |

## census (worst path per seed)

| seed | fmax | start -> end |
|---|---|---|
| 1 | 130.96 | u_dut.u_oe.u_reorderBuffer.rb_count -> u_dut.u_oe.u_issueQueue.iq_dispatchReadyQ |
| 2 | 141.38 | u_dut.u_oe.u_reorderBuffer.rb_count -> u_dut.u_oe.u_reorderBuffer.rb_exception |
| 3 | 145.33 | u_dut.u_oe.u_rename.r2_pds_rs2Tag -> u_dut.u_oe.u_predisp.pds_ds_rs2Wait |
| 4 | 136.52 | u_dut.u_oe.u_rename.rd2_skidValid -> u_dut.u_oe.u_rename.fl_headTag |
| 5 | 139.61 | u_dut.u_oe.u_reorderBuffer.cm_exception -> u_dut.u_oe.u_rename.rn_retireMap |
| 6 | 145.56 | u_dut.u_oe.u_rename.r2_pds_rs2Use -> u_dut.u_oe.u_predisp.pds_ds_rs2Wait |
| 7 | 147.69 | u_dut.u_oe.u_reorderBuffer.rb_count -> u_dut.u_oe.u_issueQueue.iq_dispatchReadyQ |
| 8 | 145.41 | u_dut.u_oe.u_reorderBuffer.cm_exception -> u_dut.u_oe.u_rename.rn_retireMap |
| 9 | 130.16 | u_dut.u_oe.u_reorderBuffer.rb_count -> u_dut.u_oe.u_issueQueue.iq_dispatchReadyQ |
| 10 | 140.02 | u_dut.u_oe.u_reorderBuffer.rb_done -> u_dut.u_oe.u_reorderBuffer.rb_headReady |
| 11 | 134.39 | u_dut.u_oe.u_reorderBuffer.rb_count -> u_dut.u_oe.u_issueQueue.iq_dispatchReadyQ |
| 12 | 143.58 | u_dut.u_oe.u_reorderBuffer.cm_valid -> u_dut.u_oe.u_rename.rn_retireMap |
| 13 | 142.31 | u_dut.u_oe.u_issueQueue.iq_count -> u_dut.u_oe.u_predisp.pds_ds_rs1Wait |
| 14 | 136.65 | u_dut.u_oe.u_rename.r2_pds_rs2Tag -> u_dut.u_oe.u_predisp.pds_ds_rs2Wait |
| 15 | 146.69 | u_dut.u_ex.u_alu.g_copy -> u_dut.u_ex.u_alu.ex0_ex1_result |
| 16 | 129.23 | u_dut.u_oe.u_rename.r1_r2_valid -> u_dut.u_oe.u_rename.fl_ram.0.3_DO_2 |
| 17 | 138.83 | u_dut.u_oe.u_reorderBuffer.rb_count -> u_dut.u_oe.u_reorderBuffer.rb_done |
| 18 | 138.62 | u_dut.u_oe.u_predisp.pds_ds_valid -> u_dut.u_oe.u_issueQueue.iq_dispatchReadyQ |
| 19 | 142.19 | u_dut.u_oe.u_predisp.pds_ds_valid -> u_dut.u_oe.u_issueQueue.iq_dispatchReadyQ |
| 20 | 144.01 | u_dut.u_oe.u_rename.r2_pds_rs2Tag -> u_dut.u_oe.u_predisp.pds_ds_depL3 |
