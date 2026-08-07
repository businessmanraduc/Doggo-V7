# fetch_ctrl solo Fmax

ring-of-regs, nextpnr --85k CABGA381, tw=100, 20 seeds

| floor | mean | ceil |
|---|---|---|
| 244.74 | 262.29 | 296.21 |

## census (worst path per seed)

| seed | fmax | start -> end |
|---|---|---|
| 1 | 258.87 | u_dut.resetn         -> u_dut.validF1 |
| 2 | 269.32 | u_dut.resetn         -> u_dut.validF1 |
| 3 | 245.82 | u_dut.resetn         -> u_dut.validF1 |
| 4 | 279.49 | u_dut.validF4        -> u_dut.rState |
| 5 | 244.74 | u_dut.backendRedirect -> u_dut.validF1 |
| 6 | 267.31 | u_dut.validF4        -> u_dut.validF1 |
| 7 | 251.19 | u_dut.hwF4           -> u_dut.rState |
| 8 | 269.25 | u_dut.resetn         -> u_dut.validF1 |
| 9 | 261.57 | u_dut.hwF4           -> u_dut.missPC |
| 10 | 270.34 | u_dut.backendRedirect -> u_dut.validF1 |
| 11 | 277.62 | u_dut.hwF4           -> u_dut.validF1 |
| 12 | 250.69 | u_dut.validF4        -> u_dut.validF1 |
| 13 | 249.56 | u_dut.hwF4           -> u_dut.rState |
| 14 | 256.81 | u_dut.validF4        -> u_dut.validF1 |
| 15 | 296.21 | u_dut.hwF4           -> u_dut.rState |
| 16 | 260.01 | u_dut.validF4        -> u_dut.missPC |
| 17 | 262.67 | u_dut.validF4        -> u_dut.validF1 |
| 18 | 254.78 | u_dut.backendRedirect -> u_dut.validF1 |
| 19 | 274.20 | u_dut.validF4        -> u_dut.validF1 |
| 20 | 245.40 | u_dut.resetn         -> u_dut.validF1 |
