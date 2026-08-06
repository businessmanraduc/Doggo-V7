# bpredict solo Fmax

ring-of-regs, nextpnr --85k CABGA381, tw=100, 20 seeds

| floor | mean | ceil |
|---|---|---|
| 135.78 | 142.75 | 145.41 |

## census (worst path per seed)

| seed | fmax | start -> end |
|---|---|---|
| 1 | 141.22 | u_dut.u_btb.g_block  -> u_dut.u_btb.g_fabricReg.entryQ |
| 2 | 141.68 | u_dut.u_btb.g_block  -> u_dut.u_btb.g_fabricReg.entryQ |
| 3 | 140.75 | u_dut.u_btb.g_block  -> u_dut.u_btb.g_fabricReg.entryQ |
| 4 | 142.43 | u_dut.u_btb.g_block  -> u_dut.u_btb.g_fabricReg.entryQ |
| 5 | 138.26 | u_dut.u_btb.g_block  -> u_dut.u_btb.g_fabricReg.entryQ |
| 6 | 143.62 | u_dut.u_btb.g_block  -> u_dut.u_btb.g_fabricReg.entryQ |
| 7 | 143.53 | u_dut.u_btb.g_block  -> u_dut.u_btb.g_fabricReg.entryQ |
| 8 | 144.70 | u_dut.u_btb.g_block  -> u_dut.u_btb.g_fabricReg.entryQ |
| 9 | 144.70 | u_dut.u_btb.g_block  -> u_dut.u_btb.g_fabricReg.entryQ |
| 10 | 145.03 | u_dut.u_btb.g_block  -> u_dut.u_btb.g_fabricReg.entryQ |
| 11 | 141.10 | u_dut.u_btb.g_block  -> u_dut.u_btb.g_fabricReg.entryQ |
| 12 | 142.61 | u_dut.u_btb.g_block  -> u_dut.u_btb.g_fabricReg.entryQ |
| 13 | 144.70 | u_dut.u_btb.g_block  -> u_dut.u_btb.g_fabricReg.entryQ |
| 14 | 145.41 | u_dut.u_btb.g_block  -> u_dut.u_btb.g_fabricReg.entryQ |
| 15 | 135.78 | u_dut.u_btb.g_block  -> u_dut.u_btb.g_fabricReg.entryQ |
| 16 | 144.82 | u_dut.u_btb.g_block  -> u_dut.u_btb.g_fabricReg.entryQ |
| 17 | 143.39 | u_dut.u_btb.g_block  -> u_dut.u_btb.g_fabricReg.entryQ |
| 18 | 143.86 | u_dut.u_btb.g_block  -> u_dut.u_btb.g_fabricReg.entryQ |
| 19 | 143.76 | u_dut.u_btb.g_block  -> u_dut.u_btb.g_fabricReg.entryQ |
| 20 | 143.66 | u_dut.u_btb.g_block  -> u_dut.u_btb.g_fabricReg.entryQ |
