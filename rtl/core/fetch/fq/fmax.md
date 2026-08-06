# fetch_queue solo Fmax

ring-of-regs, nextpnr --85k CABGA381, tw=100, 20 seeds

| floor | mean | ceil |
|---|---|---|
| 172.86 | 187.08 | 203.33 |

## census (worst path per seed)

| seed | fmax | start -> end |
|---|---|---|
| 1 | 182.42 | u_dut.count          -> u_dut.count |
| 2 | 180.80 | u_dut.count          -> u_dut.count |
| 3 | 183.25 | u_dut.count          -> u_dut.count |
| 4 | 191.17 | u_dut.count          -> u_dut.count |
| 5 | 192.79 | u_srcC.r             -> u_dut.count |
| 6 | 189.07 | u_dut.flushShadow    -> u_dut.count |
| 7 | 183.96 | u_dut.count          -> u_dut.count |
| 8 | 194.29 | u_dut.count          -> u_dut.head |
| 9 | 182.32 | u_dut.count          -> u_dut.count |
| 10 | 203.33 | u_srcC.r             -> u_dut.count |
| 11 | 190.88 | u_dut.count          -> u_dut.count |
| 12 | 191.17 | u_dut.flushShadow    -> u_dut.count |
| 13 | 190.95 | u_dut.count          -> u_dut.count |
| 14 | 185.87 | u_dut.count          -> u_dut.count |
| 15 | 182.28 | u_dut.count          -> u_dut.count |
| 16 | 189.50 | u_dut.count          -> u_dut.count |
| 17 | 183.49 | u_dut.count          -> u_dut.count |
| 18 | 185.36 | u_dut.flushShadow    -> u_dut.count |
| 19 | 185.77 | u_dut.count          -> u_dut.count |
| 20 | 172.86 | u_dut.count          -> u_dut.count |
