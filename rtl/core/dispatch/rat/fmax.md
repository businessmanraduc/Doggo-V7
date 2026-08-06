# rat solo Fmax

ring-of-regs, nextpnr --85k CABGA381, tw=100, 20 seeds

| floor | mean | ceil |
|---|---|---|
| 167.08 | 175.18 | 190.01 |

## census (worst path per seed)

| seed | fmax | start -> end |
|---|---|---|
| 1 | 175.75 | u_srcB.r             -> u_dut.pending |
| 2 | 173.34 | u_srcB.r             -> u_dut.pending |
| 3 | 183.08 | u_srcB.r             -> u_dut.pending |
| 4 | 190.01 | u_srcB.r             -> u_dut.pending |
| 5 | 168.58 | u_srcB.r             -> u_dut.pending |
| 6 | 175.84 | u_srcB.r             -> u_dut.pending |
| 7 | 168.44 | u_srcB.r             -> u_dut.pending |
| 8 | 167.81 | u_srcB.r             -> u_dut.pending |
| 9 | 167.08 | u_srcB.r             -> u_dut.pending |
| 10 | 186.95 | u_srcB.r             -> u_dut.pending |
| 11 | 178.22 | u_srcB.r             -> u_dut.pending |
| 12 | 180.21 | u_srcB.r             -> u_dut.pending |
| 13 | 179.92 | u_srcB.r             -> u_dut.pending |
| 14 | 173.40 | u_srcB.r             -> u_dut.pending |
| 15 | 175.01 | u_srcB.r             -> u_dut.pending |
| 16 | 168.95 | u_srcB.r             -> u_dut.pending |
| 17 | 173.52 | u_srcB.r             -> u_dut.pending |
| 18 | 175.04 | u_srcB.r             -> u_dut.pending |
| 19 | 172.29 | u_srcB.r             -> u_dut.pending |
| 20 | 170.10 | u_srcB.r             -> u_dut.pending |
