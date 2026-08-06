# fetch_queue solo Fmax

ring-of-regs, nextpnr --85k CABGA381, tw=100, 20 seeds

| floor | mean | ceil |
|---|---|---|
| 172.27 | 191.17 | 208.64 |

## census (worst path per seed)

| seed | fmax | start -> end |
|---|---|---|
| 1 | 189.14 | u_dut.flushShadow    -> u_dut.count |
| 2 | 182.78 | u_dut.count          -> u_dut.count |
| 3 | 195.77 | u_dut.count          -> u_dut.count |
| 4 | 185.70 | u_dut.count          -> u_dut.count |
| 5 | 194.55 | u_srcC.r             -> u_dut.count |
| 6 | 187.20 | u_dut.flushShadow    -> u_dut.count |
| 7 | 191.72 | u_dut.count          -> u_dut.count |
| 8 | 208.64 | u_dut.count          -> u_dut.count |
| 9 | 182.32 | u_dut.count          -> u_dut.count |
| 10 | 203.96 | u_srcC.r             -> u_dut.count |
| 11 | 190.59 | u_dut.count          -> u_dut.count |
| 12 | 199.20 | u_dut.flushShadow    -> u_dut.count |
| 13 | 205.34 | u_dut.count          -> u_dut.count |
| 14 | 187.62 | u_srcC.r             -> u_dut.count |
| 15 | 184.40 | u_dut.flushShadow    -> u_dut.count |
| 16 | 190.15 | u_dut.count          -> u_dut.count |
| 17 | 189.97 | u_dut.count          -> u_dut.count |
| 18 | 186.46 | u_srcC.r             -> u_dut.count |
| 19 | 195.69 | u_dut.count          -> u_dut.count |
| 20 | 172.27 | u_dut.count          -> u_dut.count |
