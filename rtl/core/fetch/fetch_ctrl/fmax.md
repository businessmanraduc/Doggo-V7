# fetch_ctrl solo Fmax

ring-of-regs, nextpnr --85k CABGA381, tw=100, 20 seeds

| floor | mean | ceil |
|---|---|---|
| 228.73 | 257.85 | 281.37 |

## census (worst path per seed)

| seed | fmax | start -> end |
|---|---|---|
| 1 | 256.61 | u_dut.resetn         -> u_dut.validF1 |
| 2 | 281.37 | u_dut.validF3        -> u_dut.validF3 |
| 3 | 261.71 | u_dut.hwF3           -> u_dut.validF1 |
| 4 | 253.68 | u_dut.backendRedirect -> u_dut.validF1 |
| 5 | 280.98 | u_dut.hwF3           -> u_dut.missPC |
| 6 | 259.34 | u_dut.validF3        -> u_dut.validF1 |
| 7 | 273.45 | u_dut.validF3        -> u_dut.validF1 |
| 8 | 260.21 | u_dut.backendRedirect -> u_dut.validF1 |
| 9 | 274.12 | u_dut.resetn         -> u_dut.validF1 |
| 10 | 251.26 | u_dut.backendRedirect -> u_dut.validF1 |
| 11 | 257.27 | u_dut.validF3        -> u_dut.missPC |
| 12 | 250.44 | u_dut.validF3        -> u_dut.validF1 |
| 13 | 235.63 | u_dut.validF3        -> u_dut.validF1 |
| 14 | 257.20 | u_dut.hwF3           -> u_dut.validF1 |
| 15 | 252.91 | u_dut.hwF3           -> u_dut.missPC |
| 16 | 252.59 | u_dut.backendRedirect -> u_dut.rState |
| 17 | 254.97 | u_dut.hwF3           -> u_dut.validF1 |
| 18 | 258.06 | u_dut.resetn         -> u_dut.validF1 |
| 19 | 228.73 | u_dut.resetn         -> u_dut.rState |
| 20 | 256.54 | u_dut.resetn         -> u_dut.validF1 |
