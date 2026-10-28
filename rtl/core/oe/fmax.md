# oe solo Fmax

ring-of-regs, nextpnr --85k CABGA381, tw=100, 20 seeds
tools: Yosys 0.62, nextpnr-35f1433

| floor | median | mean | ceil |
|---|---|---|---|
| 123.06 | 135.51 | 133.66 | 143.12 |

## census (worst path per seed)

| seed | fmax | start -> end |
|---|---|---|
| 1 | 124.89 | u_dut.u_predisp.pds_ds_valid -> u_dut.u_issueQueue.iq_dispatchReadyQ |
| 2 | 138.33 | u_dut.u_predisp.pds_ds_valid -> u_dut.u_issueQueue.iq_dispatchReadyQ |
| 3 | 139.68 | u_dut.u_predecoder.d_r1_instr -> u_dut.u_decoder.d1_d2_selSlt |
| 4 | 137.70 | u_dut.u_predisp.pds_ds_depL3 -> u_dut.u_predisp.pds_ds_rs2Wait |
| 5 | 133.78 | u_dut.u_rename.r2_pds_rs2Tag -> u_dut.u_predisp.pds_ds_rs2Wait |
| 6 | 126.21 | u_dut.u_predecoder.d_r1_isJalr -> u_dut.u_rename.rn_map |
| 7 | 137.32 | u_dut.u_predecoder.d_r1_isJalr -> u_dut.u_rename.rn_map |
| 8 | 136.04 | u_dut.u_predecoder.d_r1_isJalr -> u_dut.u_rename.rn_map |
| 9 | 136.84 | u_dut.u_predecoder.d_r1_isBranch -> u_dut.u_rename.rn_map |
| 10 | 135.41 | u_s2.r               -> u_dut.u_rename.sn_full |
| 11 | 138.03 | u_dut.u_rob.cm_exception -> u_dut.u_rename.rn_retireMap |
| 12 | 135.61 | u_dut.u_predecoder.d_r1_isBranch -> u_dut.u_rename.rn_map |
| 13 | 143.12 | u_dut.u_rename.r2_pds_rs2Use -> u_dut.u_predisp.pds_ds_rs2Wait |
| 14 | 127.32 | u_dut.u_predecoder.d_r1_isBranch -> u_dut.u_rename.rn_map |
| 15 | 139.14 | u_dut.u_issueQueue.g_dup -> u_dut.u_issueQueue.g_dup |
| 16 | 129.77 | u_dut.u_rename.rn_hold -> u_dut.u_rename.rn_map |
| 17 | 134.03 | u_dut.u_predecoder.d_r1_instr -> u_dut.u_decoder.d1_d2_illegalAlu |
| 18 | 133.28 | u_dut.u_predecoder.d_r1_isJalr -> u_dut.u_rename.rn_map |
| 19 | 123.06 | u_dut.u_predecoder.d_r1_isBranch -> u_dut.u_rename.rn_map |
| 20 | 123.66 | u_dut.u_predecoder.d_r1_isBranch -> u_dut.u_rename.rn_map |
