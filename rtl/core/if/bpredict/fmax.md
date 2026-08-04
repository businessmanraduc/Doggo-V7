# bpredict solo Fmax

ring-of-regs, nextpnr --85k CABGA381, tw=100, 20 seeds

| floor | mean | ceil |
|---|---|---|
| 135.39 | 141.74 | 144.78 |

## census (worst path per seed)

| seed | fmax | start -> end |
|---|---|---|
| 1 | 144.70 | u_dut.u_btb.g_block  -> u_dut.u_btb.g_fabricReg.entryQ |
| 2 | 142.69 | u_dut.u_btb.g_block  -> u_dut.u_btb.g_fabricReg.entryQ |
| 3 | 143.88 | u_dut.u_btb.g_block  -> u_dut.u_btb.g_fabricReg.entryQ |
| 4 | 138.27 | u_dut.u_btb.g_block  -> u_dut.u_btb.g_fabricReg.entryQ |
| 5 | 141.82 | u_dut.u_btb.g_block  -> u_dut.u_btb.g_fabricReg.entryQ |
| 6 | 135.39 | u_dut.u_btb.g_fabricReg.entryQ -> u_dut.nextPC |
| 7 | 144.78 | u_dut.u_btb.g_block  -> u_dut.u_btb.g_fabricReg.entryQ |
| 8 | 138.26 | u_dut.u_btb.g_block  -> u_dut.u_btb.g_fabricReg.entryQ |
| 9 | 143.72 | u_dut.u_btb.g_block  -> u_dut.u_btb.g_fabricReg.entryQ |
| 10 | 144.70 | u_dut.u_btb.g_block  -> u_dut.btbExitLow |
| 11 | 141.04 | u_dut.u_btb.g_block  -> u_dut.u_btb.g_fabricReg.entryQ |
| 12 | 143.53 | u_dut.u_btb.g_block  -> u_dut.u_btb.g_fabricReg.entryQ |
| 13 | 142.86 | u_dut.u_btb.g_block  -> u_dut.u_btb.g_fabricReg.entryQ |
| 14 | 141.24 | u_dut.u_btb.g_block  -> u_dut.btbIsBranch |
| 15 | 144.70 | u_dut.u_btb.g_block  -> u_dut.u_btb.g_fabricReg.entryQ |
| 16 | 141.00 | u_dut.u_btb.g_block  -> u_dut.u_btb.g_fabricReg.entryQ |
| 17 | 137.80 | u_dut.u_btb.g_block  -> u_dut.u_btb.g_fabricReg.entryQ |
| 18 | 142.43 | u_dut.u_btb.g_block  -> u_dut.u_btb.g_fabricReg.entryQ |
| 19 | 141.90 | u_dut.u_btb.g_block  -> u_dut.u_btb.g_fabricReg.entryQ |
| 20 | 140.10 | u_dut.u_btb.g_block  -> u_dut.u_btb.g_fabricReg.entryQ |
