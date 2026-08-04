# fetch_queue solo Fmax

ring-of-regs, nextpnr --85k CABGA381, tw=100, 20 seeds

| floor | mean | ceil |
|---|---|---|
| 170.30 | 188.94 | 202.14 |

## census (worst path per seed)

| seed | fmax | start -> end |
|---|---|---|
| 1 | 194.67 | u_dut.flushShadow    -> u_dut.count |
| 2 | 190.91 | u_dut.count          -> u_dut.head |
| 3 | 202.14 | u_srcC.r             -> u_dut.count |
| 4 | 189.43 | u_dut.count          -> u_dut.count |
| 5 | 170.30 | u_dut.count          -> u_dut.count |
| 6 | 192.46 | u_srcC.r             -> u_dut.count |
| 7 | 195.31 | u_srcC.r             -> u_dut.count |
| 8 | 192.98 | u_dut.count          -> u_dut.count |
| 9 | 189.65 | u_srcC.r             -> u_dut.count |
| 10 | 188.68 | u_dut.count          -> u_dut.count |
| 11 | 196.19 | u_dut.count          -> u_dut.count |
| 12 | 185.29 | u_dut.flushShadow    -> u_dut.count |
| 13 | 185.43 | u_dut.count          -> u_dut.count |
| 14 | 187.62 | u_dut.count          -> u_dut.count |
| 15 | 193.69 | u_dut.flushShadow    -> u_dut.count |
| 16 | 181.06 | u_dut.count          -> u_dut.count |
| 17 | 174.13 | u_srcC.r             -> u_dut.count |
| 18 | 190.80 | u_dut.count          -> u_dut.count |
| 19 | 186.36 | u_srcC.r             -> u_dut.count |
| 20 | 191.75 | u_dut.count          -> u_dut.count |
