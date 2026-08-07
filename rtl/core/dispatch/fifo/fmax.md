# dispatch_fifo solo Fmax

ring-of-regs, nextpnr --85k CABGA381, tw=100, 20 seeds

| floor | mean | ceil |
|---|---|---|
| 180.31 | 229.51 | 262.74 |

## census (worst path per seed)

| seed | fmax | start -> end |
|---|---|---|
| 1 | 180.31 | u_dut.enq_valid      -> u_dut.count |
| 2 | 250.13 | u_dut.count          -> u_dut.count |
| 3 | 207.00 | u_dut.count          -> u_dut.count |
| 4 | 253.68 | u_dut.count          -> u_dut.count |
| 5 | 227.53 | u_dut.count          -> u_dut.count |
| 6 | 234.30 | u_dut.count          -> u_dut.count |
| 7 | 221.68 | u_dut.count          -> u_dut.count |
| 8 | 224.16 | u_dut.count          -> u_dut.count |
| 9 | 262.74 | u_dut.count          -> u_dut.count |
| 10 | 238.38 | u_dut.enq_valid      -> u_dut.count |
| 11 | 201.65 | u_dut.count          -> u_dut.count |
| 12 | 246.67 | u_dut.count          -> u_dut.count |
| 13 | 206.53 | u_dut.count          -> u_dut.count |
| 14 | 237.08 | u_dut.enq_valid      -> u_dut.count |
| 15 | 251.89 | u_dut.count          -> u_dut.count |
| 16 | 238.72 | u_dut.count          -> u_dut.count |
| 17 | 233.59 | u_dut.count          -> u_dut.count |
| 18 | 240.21 | u_dut.count          -> u_dut.count |
| 19 | 224.22 | u_dut.count          -> u_dut.count |
| 20 | 209.64 | u_dut.count          -> u_dut.count |
