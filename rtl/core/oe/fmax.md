# oe solo Fmax

ring-of-regs, nextpnr --85k CABGA381, tw=100, 20 seeds
tools: Yosys 0.62, nextpnr-35f1433

| floor | median | mean | ceil |
|---|---|---|---|
| 121.68 | 136.77 | 135.06 | 144.53 |

## census (worst path per seed)

| seed | fmax | start -> end |
|---|---|---|
| 1 | 136.63 | u_dut.u_predisp.pds_dsProducer -> u_dut.u_predisp.pds_ds_depL4 |
| 2 | 125.23 | u_dut.u_dispatch.dp_skipIq -> u_dut.u_issueQueue.iq_dispatchReadyQ |
| 3 | 144.53 | u_dut.u_rename.rd2_skidValid -> u_dut.u_rename.fl_headTag |
| 4 | 136.91 | u_dut.u_dispatch.dp_skipIq -> u_dut.u_issueQueue.iq_dispatchReadyQ |
| 5 | 133.85 | u_s2.r               -> u_dut.u_issueQueue.iq_reuseHold1 |
| 6 | 126.79 | u_dut.u_rename.rd2_skidValid -> u_dut.u_rename.fl_headTag |
| 7 | 137.68 | u_dut.u_predecoder.d_r1_instr -> u_dut.u_decoder.d1_d2_zIsZero |
| 8 | 137.16 | u_dut.u_rename.rd2_skidValid -> u_dut.u_rename.fl_headTag |
| 9 | 137.84 | u_dut.u_predecoder.d_r1_instr -> u_dut.u_decoder.d1_d2_illegalAlu |
| 10 | 139.12 | u_dut.u_rename.rd2_skidValid -> u_dut.u_rename.sn_full |
| 11 | 121.68 | u_dut.u_rename.rd2_skidValid -> u_dut.u_rename.fl_headTag |
| 12 | 143.16 | u_dut.u_predecoder.d_r1_instr -> u_dut.u_decoder.d1_d2_selArith |
| 13 | 138.95 | u_dut.u_rename.rd2_skidValid -> u_dut.u_rename.sn_full |
| 14 | 139.28 | u_dut.u_predecoder.d_r1_instr -> u_dut.u_decoder.d1_d2_illegalAlu |
| 15 | 126.01 | u_dut.u_reorderBuffer.rb_count -> u_dut.u_issueQueue.iq_dispatchReadyQ |
| 16 | 134.34 | u_dut.u_rename.rd2_skidValid -> u_dut.u_rename.sn_full |
| 17 | 134.14 | u_dut.u_dispatch.dp_serialBlock -> u_dut.u_issueQueue.iq_dispatchReadyQ |
| 18 | 130.48 | u_dut.u_rename.rd2_skidValid -> u_dut.u_rename.fl_headTag |
| 19 | 143.88 | u_s2.r               -> u_dut.u_issueQueue.iq_reuseHold1 |
| 20 | 133.44 | u_dut.u_predisp.pds_ds_valid -> u_dut.u_issueQueue.iq_dispatchReadyQ |
