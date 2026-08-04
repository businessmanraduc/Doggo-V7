# bpredict solo Fmax

ring-of-regs, nextpnr --85k CABGA381, tw=100, 20 seeds

| floor | mean | ceil |
|---|---|---|
| 138.43 | 143.02 | 145.56 |

## census (worst path per seed)

| seed | fmax | start -> end |
|---|---|---|
| 1 | 144.82 | u_dut.u_btb.g_block  -> u_dut.u_btb.g_fabricReg.entryQ |
| 2 | 145.56 | u_dut.u_btb.g_block  -> u_dut.u_btb.g_fabricReg.entryQ |
| 3 | 143.33 | u_dut.u_btb.g_block  -> u_dut.u_btb.g_fabricReg.entryQ |
| 4 | 143.06 | u_dut.u_btb.g_block  -> u_dut.u_btb.g_fabricReg.entryQ |
| 5 | 141.56 | u_dut.u_btb.g_block  -> u_dut.u_btb.g_fabricReg.entryQ |
| 6 | 141.14 | u_dut.u_btb.g_block  -> u_dut.u_btb.g_fabricReg.entryQ |
| 7 | 144.70 | u_dut.u_btb.g_block  -> u_dut.u_btb.g_fabricReg.entryQ |
| 8 | 144.70 | u_dut.u_btb.g_block  -> u_dut.btbIsConditional |
| 9 | 142.01 | u_dut.u_btb.g_block  -> u_dut.u_btb.g_fabricReg.entryQ |
| 10 | 143.06 | u_dut.u_btb.g_block  -> u_dut.u_btb.g_fabricReg.entryQ |
| 11 | 143.33 | u_dut.u_btb.g_block  -> u_dut.u_btb.g_fabricReg.entryQ |
| 12 | 142.84 | u_dut.u_btb.g_block  -> u_dut.u_btb.g_fabricReg.entryQ |
| 13 | 138.43 | u_dut.u_pht.u_alternate.u_ebr.DOB1 -> u_dut.u_pht.alternateCounter |
| 14 | 142.01 | u_dut.u_btb.g_block  -> u_dut.btbIsBranch |
| 15 | 144.70 | u_dut.u_btb.g_block  -> u_dut.u_btb.g_fabricReg.entryQ |
| 16 | 141.00 | u_dut.u_btb.g_block  -> u_dut.u_btb.g_fabricReg.entryQ |
| 17 | 141.82 | u_dut.u_btb.g_block  -> u_dut.u_btb.g_fabricReg.entryQ |
| 18 | 143.43 | u_dut.u_btb.g_block  -> u_dut.u_btb.g_fabricReg.entryQ |
| 19 | 143.37 | u_dut.u_btb.g_block  -> u_dut.u_btb.g_fabricReg.entryQ |
| 20 | 145.50 | u_dut.u_btb.g_block  -> u_dut.u_btb.g_fabricReg.entryQ |
