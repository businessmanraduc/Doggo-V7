# fetch_queue solo Fmax

ring-of-regs, nextpnr --85k CABGA381, tw=100, 20 seeds

| floor | mean | ceil |
|---|---|---|
| 168.18 | 187.99 | 204.42 |

## census (worst path per seed)

| seed | fmax | start -> end |
|---|---|---|
| 1 | 187.48 | u_srcC.r             -> u_dut.count |
| 2 | 204.42 | u_dut.count          -> u_dut.count |
| 3 | 191.06 | u_dut.count          -> u_dut.count |
| 4 | 192.20 | u_dut.count          -> u_dut.count |
| 5 | 187.90 | u_dut.count          -> u_dut.count |
| 6 | 186.74 | u_dut.flushShadow    -> u_dut.count |
| 7 | 191.53 | u_dut.flushShadow    -> u_dut.count |
| 8 | 168.18 | u_srcC.r             -> u_dut.count |
| 9 | 181.62 | u_srcC.r             -> u_dut.count |
| 10 | 196.50 | u_srcC.r             -> u_dut.count |
| 11 | 189.21 | u_dut.count          -> u_dut.count |
| 12 | 192.42 | u_dut.count          -> u_dut.count |
| 13 | 184.03 | u_dut.count          -> u_dut.count |
| 14 | 182.68 | u_dut.count          -> u_dut.count |
| 15 | 187.34 | u_dut.flushShadow    -> u_dut.count |
| 16 | 185.53 | u_dut.count          -> u_dut.count |
| 17 | 188.93 | u_dut.count          -> u_dut.count |
| 18 | 186.05 | u_dut.count          -> u_dut.count |
| 19 | 185.91 | u_dut.flushShadow    -> u_dut.count |
| 20 | 190.04 | u_dut.count          -> u_dut.count |
