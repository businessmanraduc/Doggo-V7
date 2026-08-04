# dispatch_fifo solo Fmax

ring-of-regs, nextpnr --85k CABGA381, tw=100, 20 seeds

| floor | mean | ceil |
|---|---|---|
| 188.93 | 216.27 | 261.10 |

## census (worst path per seed)

| seed | fmax | start -> end |
|---|---|---|
| 1 | 228.62 | u_dut.count          -> u_dut.count |
| 2 | 227.32 | u_dut.count          -> u_dut.count |
| 3 | 190.26 | u_dut.count          -> u_dut.count |
| 4 | 188.93 | u_dut.count          -> u_dut.count |
| 5 | 261.10 | u_dut.count          -> u_dut.count |
| 6 | 238.27 | u_dut.count          -> u_dut.count |
| 7 | 222.52 | u_dut.count          -> u_dut.count |
| 8 | 229.20 | u_dut.count          -> u_dut.count |
| 9 | 212.95 | u_dut.count          -> u_dut.count |
| 10 | 214.27 | u_dut.count          -> u_dut.count |
| 11 | 217.68 | u_dut.count          -> u_dut.count |
| 12 | 206.27 | u_dut.count          -> u_dut.count |
| 13 | 222.72 | u_dut.count          -> u_dut.count |
| 14 | 236.85 | u_dut.enq_valid      -> u_dut.count |
| 15 | 198.10 | u_dut.count          -> u_dut.count |
| 16 | 202.63 | u_dut.count          -> u_dut.count |
| 17 | 189.86 | u_dut.count          -> u_dut.count |
| 18 | 226.91 | u_dut.count          -> u_dut.count |
| 19 | 211.24 | u_dut.count          -> u_dut.count |
| 20 | 199.72 | u_dut.count          -> u_dut.count |
