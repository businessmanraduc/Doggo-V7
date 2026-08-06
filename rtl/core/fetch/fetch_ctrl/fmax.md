# fetch_ctrl solo Fmax

ring-of-regs, nextpnr --85k CABGA381, tw=100, 20 seeds

| floor | mean | ceil |
|---|---|---|
| 226.30 | 259.43 | 287.94 |

## census (worst path per seed)

| seed | fmax | start -> end |
|---|---|---|
| 1 | 226.71 | u_dut.hwF4           -> u_dut.validF1 |
| 2 | 277.09 | u_dut.hwF4           -> u_dut.validF1 |
| 3 | 245.40 | u_dut.backendRedirect -> u_dut.validF1 |
| 4 | 287.94 | u_dut.resetn         -> u_dut.validF1 |
| 5 | 283.69 | u_dut.backendRedirect -> u_dut.validF1 |
| 6 | 261.10 | u_dut.resetn         -> u_dut.validF1 |
| 7 | 253.68 | u_dut.hwF4           -> u_dut.rState |
| 8 | 271.81 | u_dut.hwF4           -> u_dut.rState |
| 9 | 277.85 | u_dut.hwF4           -> u_dut.validF1 |
| 10 | 256.15 | u_dut.resetn         -> u_dut.validF1 |
| 11 | 226.30 | u_dut.backendRedirect -> u_dut.validF1 |
| 12 | 257.33 | u_dut.backendRedirect -> u_dut.validF1 |
| 13 | 279.96 | u_dut.backendRedirect -> u_dut.missPC |
| 14 | 256.74 | u_dut.resetn         -> u_dut.validF1 |
| 15 | 256.21 | u_dut.backendRedirect -> u_dut.rState |
| 16 | 250.50 | u_dut.hwF4           -> u_dut.missPC |
| 17 | 264.97 | u_dut.resetn         -> u_dut.validF1 |
| 18 | 239.29 | u_dut.hwF4           -> u_dut.missPC |
| 19 | 257.86 | u_dut.hwF4           -> u_dut.missPC |
| 20 | 258.06 | u_dut.hwF4           -> u_dut.missPC |
