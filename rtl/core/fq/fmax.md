# fetch_queue solo Fmax

ring-of-regs, nextpnr --85k CABGA381, tw=100, 20 seeds

| floor | mean | ceil |
|---|---|---|
| 171.82 | 186.35 | 215.01 |

## census (worst path per seed)

| seed | fmax | start -> end |
|---|---|---|
| 1 | 189.32 | u_dut.count          -> u_dut.count |
| 2 | 189.75 | u_dut.count          -> u_dut.count |
| 3 | 215.01 | u_srcC.r             -> u_dut.count |
| 4 | 179.15 | u_dut.count          -> u_dut.count |
| 5 | 186.81 | u_dut.count          -> u_dut.count |
| 6 | 173.67 | u_srcC.r             -> u_dut.count |
| 7 | 186.57 | u_dut.count          -> u_dut.count |
| 8 | 173.43 | u_dut.count          -> u_dut.count |
| 9 | 196.08 | u_srcC.r             -> u_dut.count |
| 10 | 204.29 | u_dut.count          -> u_dut.count |
| 11 | 173.76 | u_dut.count          -> u_dut.count |
| 12 | 171.82 | u_dut.count          -> u_dut.count |
| 13 | 195.47 | u_dut.count          -> u_dut.count |
| 14 | 181.62 | u_dut.count          -> u_dut.count |
| 15 | 181.29 | u_dut.count          -> u_dut.count |
| 16 | 188.22 | u_dut.count          -> u_dut.count |
| 17 | 171.91 | u_srcC.r             -> u_dut.count |
| 18 | 191.83 | u_dut.count          -> u_dut.count |
| 19 | 174.09 | u_dut.flushShadow    -> u_dut.count |
| 20 | 203.00 | u_dut.flushShadow    -> u_dut.count |
