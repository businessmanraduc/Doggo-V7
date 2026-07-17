# dispatch_fifo solo Fmax

ring-of-regs, nextpnr --85k CABGA381, tw=100, 20 seeds

| floor | mean | ceil |
|---|---|---|
| 196.23 | 215.92 | 232.40 |

## census (worst path per seed)

| seed | fmax | start -> end |
|---|---|---|
| 1 | 220.56 | u_dut.count          -> u_dut.count |
| 2 | 227.89 | u_dut.count          -> u_dut.count |
| 3 | 220.26 | u_dut.count          -> u_dut.count |
| 4 | 204.71 | u_dut.count          -> u_dut.count |
| 5 | 208.77 | u_dut.count          -> u_dut.count |
| 6 | 208.68 | u_dut.count          -> u_dut.count |
| 7 | 209.16 | u_dut.count          -> u_dut.count |
| 8 | 221.88 | u_dut.count          -> u_dut.count |
| 9 | 209.07 | u_dut.count          -> u_dut.count |
| 10 | 232.40 | u_dut.count          -> u_dut.count |
| 11 | 209.29 | u_dut.count          -> u_dut.count |
| 12 | 196.23 | u_dut.count          -> u_dut.count |
| 13 | 228.00 | u_dut.count          -> u_dut.count |
| 14 | 207.38 | u_dut.count          -> u_dut.count |
| 15 | 216.73 | u_dut.count          -> u_dut.count |
| 16 | 207.81 | u_dut.count          -> u_dut.count |
| 17 | 228.89 | u_dut.count          -> u_dut.count |
| 18 | 222.87 | u_dut.count          -> u_dut.count |
| 19 | 219.35 | u_dut.count          -> u_dut.count |
| 20 | 218.39 | u_dut.count          -> u_dut.count |
