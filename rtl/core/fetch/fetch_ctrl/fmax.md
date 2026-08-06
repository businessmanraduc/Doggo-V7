# fetch_ctrl solo Fmax

ring-of-regs, nextpnr --85k CABGA381, tw=100, 20 seeds

| floor | mean | ceil |
|---|---|---|
| 224.01 | 254.46 | 287.94 |

## census (worst path per seed)

| seed | fmax | start -> end |
|---|---|---|
| 1 | 230.04 | u_dut.resetn         -> u_dut.validF1 |
| 2 | 277.09 | u_dut.hwF4           -> u_dut.validF1 |
| 3 | 224.01 | u_dut.hwF4           -> u_dut.validF1 |
| 4 | 287.94 | u_dut.resetn         -> u_dut.validF1 |
| 5 | 269.03 | u_dut.backendRedirect -> u_dut.validF1 |
| 6 | 256.28 | u_dut.resetn         -> u_dut.validF1 |
| 7 | 254.39 | u_dut.hwF4           -> u_dut.rState |
| 8 | 271.81 | u_dut.hwF4           -> u_dut.rState |
| 9 | 268.31 | u_dut.hwF4           -> u_dut.missPC |
| 10 | 261.51 | u_dut.resetn         -> u_dut.validF1 |
| 11 | 226.30 | u_dut.backendRedirect -> u_dut.validF1 |
| 12 | 257.33 | u_dut.backendRedirect -> u_dut.validF1 |
| 13 | 269.69 | u_dut.hwF4           -> u_dut.rState |
| 14 | 256.74 | u_dut.resetn         -> u_dut.validF1 |
| 15 | 242.25 | u_dut.resetn         -> u_dut.rState |
| 16 | 227.32 | u_dut.hwF4           -> u_dut.rState |
| 17 | 245.58 | u_dut.backendRedirect -> u_dut.validF1 |
| 18 | 239.29 | u_dut.hwF4           -> u_dut.missPC |
| 19 | 266.31 | u_dut.hwF4           -> u_dut.missPC |
| 20 | 258.06 | u_dut.hwF4           -> u_dut.missPC |
