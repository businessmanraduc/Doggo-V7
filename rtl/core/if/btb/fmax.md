# btb solo Fmax

ring-of-regs, nextpnr --85k CABGA381, tw=100, 20 seeds

| floor | mean | ceil |
|---|---|---|
| 143.29 | 144.71 | 145.94 |

## census (worst path per seed)

| seed | fmax | start -> end |
|---|---|---|
| 1 | 144.70 | u_dut.g_block        -> u_dut.g_fabricReg.entryQ |
| 2 | 144.70 | u_dut.g_block        -> u_dut.g_fabricReg.entryQ |
| 3 | 143.39 | u_dut.g_block        -> u_dut.g_fabricReg.entryQ |
| 4 | 144.70 | u_dut.g_block        -> u_dut.g_fabricReg.entryQ |
| 5 | 144.70 | u_dut.g_block        -> u_dut.g_fabricReg.entryQ |
| 6 | 145.26 | u_dut.g_block        -> u_dut.g_fabricReg.entryQ |
| 7 | 143.29 | u_dut.g_block        -> isStraddle |
| 8 | 144.70 | u_dut.g_block        -> u_dut.g_fabricReg.entryQ |
| 9 | 144.70 | u_dut.g_block        -> isBranch |
| 10 | 145.24 | u_dut.g_block        -> u_dut.g_fabricReg.entryQ |
| 11 | 144.24 | u_dut.g_block        -> u_dut.g_fabricReg.entryQ |
| 12 | 145.52 | u_dut.g_block        -> u_dut.g_fabricReg.entryQ |
| 13 | 143.88 | u_dut.g_block        -> u_dut.g_fabricReg.entryQ |
| 14 | 144.70 | u_dut.g_block        -> u_dut.g_fabricReg.entryQ |
| 15 | 145.94 | u_dut.g_block        -> isBranch |
| 16 | 144.70 | u_dut.g_block        -> u_dut.g_fabricReg.entryQ |
| 17 | 145.26 | u_dut.g_block        -> u_dut.g_fabricReg.entryQ |
| 18 | 145.50 | u_dut.g_block        -> u_dut.g_fabricReg.entryQ |
| 19 | 145.24 | u_dut.g_block        -> u_dut.g_fabricReg.entryQ |
| 20 | 143.76 | u_dut.g_block        -> u_dut.g_fabricReg.entryQ |
