# fetch_queue solo Fmax

ring-of-regs, nextpnr --85k CABGA381, tw=100, 20 seeds

| floor | mean | ceil |
|---|---|---|
| 180.41 | 196.22 | 220.46 |

## census (worst path per seed)

| seed | fmax | start -> end |
|---|---|---|
| 1 | 192.57 | u_dut.count          -> u_dut.count |
| 2 | 198.65 | u_dut.count          -> u_dut.count |
| 3 | 191.39 | u_dut.count          -> u_dut.count |
| 4 | 190.69 | u_dut.count          -> u_dut.count |
| 5 | 196.70 | u_dut.count          -> u_dut.count |
| 6 | 182.45 | u_dut.count          -> u_dut.count |
| 7 | 217.20 | u_dut.count          -> u_dut.count |
| 8 | 190.44 | u_dut.count          -> u_dut.count |
| 9 | 188.96 | u_dut.count          -> u_dut.count |
| 10 | 190.51 | u_dut.count          -> u_dut.count |
| 11 | 196.39 | u_dut.count          -> u_dut.count |
| 12 | 198.65 | u_dut.count          -> u_dut.count |
| 13 | 182.58 | u_dut.count          -> u_dut.count |
| 14 | 208.25 | u_dut.count          -> u_dut.count |
| 15 | 180.41 | u_dut.count          -> u_dut.count |
| 16 | 191.20 | u_dut.count          -> u_dut.count |
| 17 | 190.69 | u_dut.count          -> u_dut.count |
| 18 | 197.47 | u_dut.count          -> u_dut.count |
| 19 | 218.77 | u_dut.count          -> u_dut.count |
| 20 | 220.46 | u_dut.flushShadow    -> u_dut.count |
