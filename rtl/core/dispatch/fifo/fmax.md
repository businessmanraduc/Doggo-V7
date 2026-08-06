# dispatch_fifo solo Fmax

ring-of-regs, nextpnr --85k CABGA381, tw=100, 20 seeds

| floor | mean | ceil |
|---|---|---|
| 186.29 | 219.19 | 256.87 |

## census (worst path per seed)

| seed | fmax | start -> end |
|---|---|---|
| 1 | 228.62 | u_dut.count          -> u_dut.count |
| 2 | 227.32 | u_dut.count          -> u_dut.count |
| 3 | 215.33 | u_dut.count          -> u_dut.count |
| 4 | 188.93 | u_dut.count          -> u_dut.count |
| 5 | 249.13 | u_dut.count          -> u_dut.count |
| 6 | 256.87 | u_dut.count          -> u_dut.count |
| 7 | 234.25 | u_dut.count          -> u_dut.count |
| 8 | 229.20 | u_dut.count          -> u_dut.count |
| 9 | 214.27 | u_dut.count          -> u_dut.count |
| 10 | 214.27 | u_dut.count          -> u_dut.count |
| 11 | 224.92 | u_dut.count          -> u_dut.count |
| 12 | 202.96 | u_dut.count          -> u_dut.count |
| 13 | 228.89 | u_dut.count          -> u_dut.count |
| 14 | 236.85 | u_dut.enq_valid      -> u_dut.count |
| 15 | 198.10 | u_dut.count          -> u_dut.count |
| 16 | 219.15 | u_dut.count          -> u_dut.count |
| 17 | 186.29 | u_dut.count          -> u_dut.count |
| 18 | 231.21 | u_dut.count          -> u_dut.count |
| 19 | 210.57 | u_dut.count          -> u_dut.count |
| 20 | 186.71 | u_dut.count          -> u_dut.count |
