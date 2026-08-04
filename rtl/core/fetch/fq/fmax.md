# fetch_queue solo Fmax

ring-of-regs, nextpnr --85k CABGA381, tw=100, 20 seeds

| floor | mean | ceil |
|---|---|---|
| 177.24 | 190.63 | 205.34 |

## census (worst path per seed)

| seed | fmax | start -> end |
|---|---|---|
| 1 | 204.04 | u_dut.flushShadow    -> u_dut.count |
| 2 | 192.09 | u_dut.count          -> u_dut.head |
| 3 | 189.32 | u_dut.count          -> u_dut.count |
| 4 | 205.34 | u_dut.count          -> u_dut.count |
| 5 | 177.24 | u_dut.count          -> u_dut.count |
| 6 | 200.64 | u_dut.count          -> u_dut.count |
| 7 | 187.55 | u_dut.count          -> u_dut.count |
| 8 | 190.77 | u_dut.count          -> u_dut.count |
| 9 | 201.29 | u_dut.count          -> u_dut.count |
| 10 | 185.74 | u_dut.flushShadow    -> u_dut.count |
| 11 | 183.35 | u_dut.count          -> u_dut.count |
| 12 | 189.00 | u_srcC.r             -> u_dut.count |
| 13 | 192.68 | u_dut.count          -> u_dut.count |
| 14 | 186.29 | u_srcC.r             -> u_dut.count |
| 15 | 197.78 | u_dut.count          -> u_dut.count |
| 16 | 197.78 | u_dut.count          -> u_dut.count |
| 17 | 181.92 | u_dut.count          -> u_dut.count |
| 18 | 182.92 | u_srcC.r             -> u_dut.count |
| 19 | 182.45 | u_dut.count          -> u_dut.count |
| 20 | 184.50 | u_dut.count          -> u_dut.head |
