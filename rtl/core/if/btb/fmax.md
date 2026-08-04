# btb solo Fmax

ring-of-regs, nextpnr --85k CABGA381, tw=100, 20 seeds

| floor | mean | ceil |
|---|---|---|
| 143.39 | 144.75 | 145.50 |

## census (worst path per seed)

| seed | fmax | start -> end |
|---|---|---|
| 1 | 143.76 | u_dut.g_block        -> u_dut.g_fabricReg.entryQ |
| 2 | 144.70 | u_dut.g_block        -> u_dut.g_fabricReg.entryQ |
| 3 | 145.24 | u_dut.g_block        -> u_dut.g_fabricReg.entryQ |
| 4 | 145.26 | u_dut.g_block        -> u_dut.g_fabricReg.entryQ |
| 5 | 144.70 | u_dut.g_block        -> u_dut.g_fabricReg.entryQ |
| 6 | 145.26 | u_dut.g_block        -> u_dut.g_fabricReg.entryQ |
| 7 | 143.39 | u_dut.g_block        -> isBranch |
| 8 | 144.70 | u_dut.g_block        -> u_dut.g_fabricReg.entryQ |
| 9 | 144.70 | u_dut.g_block        -> u_dut.g_fabricReg.entryQ |
| 10 | 145.50 | u_dut.g_block        -> u_dut.g_fabricReg.entryQ |
| 11 | 144.70 | u_dut.g_block        -> u_dut.g_fabricReg.entryQ |
| 12 | 144.70 | u_dut.g_block        -> u_dut.g_fabricReg.entryQ |
| 13 | 144.70 | u_dut.g_block        -> u_dut.g_fabricReg.entryQ |
| 14 | 143.39 | u_dut.g_block        -> u_dut.g_fabricReg.entryQ |
| 15 | 144.70 | u_dut.g_block        -> isConditional |
| 16 | 144.70 | u_dut.g_block        -> u_dut.g_fabricReg.entryQ |
| 17 | 145.33 | u_dut.g_block        -> u_dut.g_fabricReg.entryQ |
| 18 | 145.43 | u_dut.g_block        -> u_dut.g_fabricReg.entryQ |
| 19 | 145.43 | u_dut.g_block        -> u_dut.g_fabricReg.entryQ |
| 20 | 144.70 | u_dut.g_block        -> u_dut.g_fabricReg.entryQ |
