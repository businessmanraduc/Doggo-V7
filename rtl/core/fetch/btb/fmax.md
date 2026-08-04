# btb solo Fmax

ring-of-regs, nextpnr --85k CABGA381, tw=100, 20 seeds

| floor | mean | ceil |
|---|---|---|
| 143.04 | 144.54 | 145.50 |

## census (worst path per seed)

| seed | fmax | start -> end |
|---|---|---|
| 1 | 145.31 | u_dut.g_block        -> u_dut.g_fabricReg.entryQ |
| 2 | 145.50 | u_dut.g_block        -> u_dut.g_fabricReg.entryQ |
| 3 | 145.37 | u_dut.g_block        -> isBranch |
| 4 | 143.88 | u_dut.g_block        -> u_dut.g_fabricReg.entryQ |
| 5 | 145.33 | u_dut.g_block        -> u_dut.g_fabricReg.entryQ |
| 6 | 143.39 | u_dut.g_block        -> u_dut.g_fabricReg.entryQ |
| 7 | 143.76 | u_dut.g_block        -> u_dut.g_fabricReg.entryQ |
| 8 | 145.33 | u_dut.g_block        -> u_dut.g_fabricReg.entryQ |
| 9 | 145.50 | u_dut.g_block        -> isConditional |
| 10 | 145.43 | u_dut.g_block        -> u_dut.g_fabricReg.entryQ |
| 11 | 145.29 | u_dut.g_block        -> u_dut.g_fabricReg.entryQ |
| 12 | 143.04 | u_dut.g_block        -> u_dut.g_fabricReg.entryQ |
| 13 | 144.70 | u_dut.g_block        -> u_dut.g_fabricReg.entryQ |
| 14 | 144.70 | u_dut.g_block        -> u_dut.g_fabricReg.entryQ |
| 15 | 144.70 | u_dut.g_block        -> u_dut.g_fabricReg.entryQ |
| 16 | 143.76 | u_dut.g_block        -> u_dut.g_fabricReg.entryQ |
| 17 | 143.43 | u_dut.g_block        -> u_dut.g_fabricReg.entryQ |
| 18 | 143.43 | u_dut.g_block        -> u_dut.g_fabricReg.entryQ |
| 19 | 145.33 | u_dut.g_block        -> u_dut.g_fabricReg.entryQ |
| 20 | 143.64 | u_dut.g_block        -> u_dut.g_fabricReg.entryQ |
