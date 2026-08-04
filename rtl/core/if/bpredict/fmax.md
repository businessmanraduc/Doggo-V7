# bpredict solo Fmax

ring-of-regs, nextpnr --85k CABGA381, tw=100, 20 seeds

| floor | mean | ceil |
|---|---|---|
| 135.63 | 142.51 | 145.50 |

## census (worst path per seed)

| seed | fmax | start -> end |
|---|---|---|
| 1 | 141.22 | u_dut.u_btb.g_block  -> u_dut.u_btb.g_fabricReg.entryQ |
| 2 | 138.12 | u_dut.u_btb.g_block  -> u_dut.u_btb.g_fabricReg.entryQ |
| 3 | 140.75 | u_dut.u_btb.g_block  -> u_dut.u_btb.g_fabricReg.entryQ |
| 4 | 142.43 | u_dut.u_btb.g_block  -> u_dut.u_btb.g_fabricReg.entryQ |
| 5 | 139.90 | u_dut.u_btb.g_block  -> u_dut.u_btb.g_fabricReg.entryQ |
| 6 | 143.62 | u_dut.u_btb.g_block  -> u_dut.u_btb.g_fabricReg.entryQ |
| 7 | 143.53 | u_dut.u_btb.g_block  -> u_dut.u_btb.g_fabricReg.entryQ |
| 8 | 141.78 | u_dut.u_btb.g_block  -> u_dut.u_btb.g_fabricReg.entryQ |
| 9 | 145.26 | u_dut.u_btb.g_block  -> u_dut.u_btb.g_fabricReg.entryQ |
| 10 | 145.03 | u_dut.u_btb.g_block  -> u_dut.u_btb.g_fabricReg.entryQ |
| 11 | 141.26 | u_dut.u_btb.g_block  -> u_dut.u_btb.g_fabricReg.entryQ |
| 12 | 142.61 | u_dut.u_btb.g_block  -> u_dut.u_btb.g_fabricReg.entryQ |
| 13 | 144.70 | u_dut.u_btb.g_block  -> u_dut.u_btb.g_fabricReg.entryQ |
| 14 | 145.50 | u_dut.u_btb.g_block  -> u_dut.btbExitLow |
| 15 | 135.63 | u_dut.u_btb.g_block  -> u_dut.u_btb.g_fabricReg.entryQ |
| 16 | 144.82 | u_dut.u_btb.g_block  -> u_dut.u_btb.g_fabricReg.entryQ |
| 17 | 143.55 | u_dut.u_btb.g_block  -> u_dut.u_btb.g_fabricReg.entryQ |
| 18 | 143.06 | u_dut.u_btb.g_block  -> u_dut.u_btb.g_fabricReg.entryQ |
| 19 | 143.76 | u_dut.u_btb.g_block  -> u_dut.u_btb.g_fabricReg.entryQ |
| 20 | 143.66 | u_dut.u_btb.g_block  -> u_dut.u_btb.g_fabricReg.entryQ |
