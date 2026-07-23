# bpredict solo Fmax

ring-of-regs, nextpnr --85k CABGA381, tw=100, 20 seeds

| floor | mean | ceil |
|---|---|---|
| 135.45 | 141.10 | 145.43 |

## census (worst path per seed)

| seed | fmax | start -> end |
|---|---|---|
| 1 | 141.14 | u_dut.u_btb.g_block  -> u_dut.u_btb.g_fabricReg.entryQ |
| 2 | 141.00 | u_dut.u_btb.g_block  -> u_dut.u_btb.g_fabricReg.entryQ |
| 3 | 142.86 | u_dut.u_btb.g_block  -> u_dut.u_btb.g_fabricReg.entryQ |
| 4 | 143.51 | u_dut.u_btb.g_block  -> u_dut.u_btb.g_fabricReg.entryQ |
| 5 | 136.28 | u_dut.u_btb.g_block  -> u_dut.u_btb.g_fabricReg.entryQ |
| 6 | 143.39 | u_dut.u_btb.g_block  -> u_dut.u_btb.g_fabricReg.entryQ |
| 7 | 139.92 | u_dut.u_btb.g_block  -> u_dut.u_btb.g_fabricReg.entryQ |
| 8 | 141.90 | u_dut.u_btb.g_block  -> u_dut.u_btb.g_fabricReg.entryQ |
| 9 | 142.01 | u_dut.u_btb.g_block  -> u_dut.u_btb.g_fabricReg.entryQ |
| 10 | 135.74 | u_dut.u_btb.g_block  -> u_dut.u_btb.g_fabricReg.entryQ |
| 11 | 141.96 | u_dut.u_btb.g_block  -> u_dut.u_btb.g_fabricReg.entryQ |
| 12 | 141.36 | u_dut.u_btb.g_block  -> u_dut.u_btb.g_fabricReg.entryQ |
| 13 | 145.43 | u_dut.u_btb.g_block  -> u_dut.u_btb.g_fabricReg.entryQ |
| 14 | 136.35 | u_dut.u_btb.g_block  -> u_dut.btbIsBranch |
| 15 | 140.71 | u_dut.u_btb.g_block  -> u_dut.u_btb.g_fabricReg.entryQ |
| 16 | 140.79 | u_dut.u_btb.g_block  -> u_dut.u_btb.g_fabricReg.entryQ |
| 17 | 145.41 | u_dut.u_btb.g_block  -> u_dut.u_btb.g_fabricReg.entryQ |
| 18 | 144.63 | u_dut.u_btb.g_block  -> u_dut.u_btb.g_fabricReg.entryQ |
| 19 | 135.45 | u_dut.u_btb.g_block  -> u_dut.u_btb.g_fabricReg.entryQ |
| 20 | 142.09 | u_dut.u_btb.g_block  -> u_dut.u_btb.g_fabricReg.entryQ |
