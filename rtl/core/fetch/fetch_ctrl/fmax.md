# fetch_ctrl solo Fmax

ring-of-regs, nextpnr --85k CABGA381, tw=100, 20 seeds

| floor | mean | ceil |
|---|---|---|
| 244.56 | 265.39 | 287.11 |

## census (worst path per seed)

| seed | fmax | start -> end |
|---|---|---|
| 1 | 270.56 | u_dut.backendRedirect -> u_dut.validF1 |
| 2 | 247.95 | u_dut.backendRedirect -> u_dut.validF1 |
| 3 | 284.82 | u_dut.hwF4           -> u_dut.validF1 |
| 4 | 251.70 | u_dut.hwF4           -> u_dut.validF1 |
| 5 | 273.75 | u_dut.hwF4           -> u_dut.validF1 |
| 6 | 244.56 | u_dut.hwF4           -> u_dut.validF1 |
| 7 | 283.29 | u_dut.backendRedirect -> u_dut.validF1 |
| 8 | 273.67 | u_dut.validF4        -> u_dut.validF1 |
| 9 | 268.96 | u_dut.hwF4           -> u_dut.rState |
| 10 | 251.83 | u_dut.hwF4           -> u_dut.validF1 |
| 11 | 287.11 | u_dut.backendRedirect -> u_dut.validF1 |
| 12 | 252.53 | u_dut.resetn         -> u_dut.validF1 |
| 13 | 252.33 | u_dut.backendRedirect -> u_dut.validF1 |
| 14 | 271.74 | u_dut.hwF4           -> u_dut.validF1 |
| 15 | 268.46 | u_dut.backendRedirect -> u_dut.validF1 |
| 16 | 260.28 | u_dut.resetn         -> u_dut.rState |
| 17 | 256.61 | u_dut.validF4        -> u_dut.validF1 |
| 18 | 258.73 | u_dut.hwF4           -> u_dut.rState |
| 19 | 278.09 | u_dut.hwF4           -> u_dut.validF1 |
| 20 | 270.93 | u_dut.hwF4           -> u_dut.validF1 |
