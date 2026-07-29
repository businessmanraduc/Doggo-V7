# icache solo Fmax

ring-of-regs, nextpnr --85k CABGA381, tw=100, 20 seeds

| floor | mean | ceil |
|---|---|---|
| 158.68 | 169.47 | 178.00 |

## census (worst path per seed)

| seed | fmax | start -> end |
|---|---|---|
| 1 | 175.41 | u_dut.lookupSetQ1    -> u_dut.g_tagWay |
| 2 | 167.64 | u_dut.lookupSetQ1    -> u_dut.g_tagWay |
| 3 | 164.64 | u_dut.lookupSetQ1    -> u_dut.g_tagWay |
| 4 | 175.81 | u_dut.lookupSetQ1    -> u_dut.g_tagWay |
| 5 | 170.68 | u_dut.lookupSetQ1    -> u_dut.g_tagWay |
| 6 | 162.28 | u_dut.lookupSetQ1    -> u_dut.g_tagWay |
| 7 | 167.50 | u_dut.lookupSetQ1    -> u_dut.lookupState |
| 8 | 163.72 | u_dut.lookupSetQ1    -> u_dut.g_tagWay |
| 9 | 168.29 | u_dut.hitVecQ        -> u_dut.plruMem.0.6 |
| 10 | 172.35 | u_dut.lookupSetQ1    -> u_dut.g_tagWay |
| 11 | 164.34 | u_dut.lookupSetQ1    -> u_dut.g_tagWay |
| 12 | 165.40 | u_dut.lookupSetQ1    -> u_dut.g_tagWay |
| 13 | 172.77 | u_dut.lookupSetQ1    -> u_dut.g_tagWay |
| 14 | 175.84 | u_dut.lookupSetQ1    -> u_dut.g_tagWay |
| 15 | 175.44 | u_dut.hitVecQ        -> u_dut.plruMem.0.0 |
| 16 | 174.34 | u_dut.lookupSetQ1    -> u_dut.g_tagWay |
| 17 | 169.20 | u_dut.lookupSetQ1    -> u_dut.g_tagWay |
| 18 | 167.00 | u_dut.lookupSetQ1    -> u_dut.g_tagWay |
| 19 | 158.68 | u_dut.hitVecQ        -> u_dut.plruMem.0.7 |
| 20 | 178.00 | u_dut.lookupSetQ1    -> u_dut.lookupState |
