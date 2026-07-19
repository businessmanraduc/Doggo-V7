# rat solo Fmax

ring-of-regs, nextpnr --85k CABGA381, tw=100, 20 seeds

| floor | mean | ceil |
|---|---|---|
| 159.46 | 170.88 | 184.54 |

## census (worst path per seed)

| seed | fmax | start -> end |
|---|---|---|
| 1 | 167.79 | u_srcB.r             -> u_dut.pending |
| 2 | 173.37 | u_srcB.r             -> u_dut.pending |
| 3 | 178.79 | u_srcB.r             -> u_dut.pending |
| 4 | 184.54 | u_srcB.r             -> u_dut.pending |
| 5 | 168.01 | u_srcB.r             -> u_dut.pending |
| 6 | 174.25 | u_srcB.r             -> u_dut.pending |
| 7 | 168.95 | u_srcB.r             -> u_dut.pending |
| 8 | 165.07 | u_srcB.r             -> u_dut.pending |
| 9 | 167.45 | u_srcB.r             -> u_dut.pending |
| 10 | 177.09 | u_srcB.r             -> u_dut.pending |
| 11 | 170.24 | u_srcB.r             -> u_dut.pending |
| 12 | 171.41 | u_srcB.r             -> u_dut.pending |
| 13 | 172.65 | u_srcB.r             -> u_dut.pending |
| 14 | 173.01 | u_srcB.r             -> u_dut.pending |
| 15 | 173.76 | u_srcB.r             -> u_dut.pending |
| 16 | 159.46 | u_srcB.r             -> u_dut.pending |
| 17 | 167.87 | u_srcB.r             -> u_dut.pending |
| 18 | 169.87 | u_srcB.r             -> u_dut.pending |
| 19 | 166.67 | u_srcB.r             -> u_dut.pending |
| 20 | 167.31 | u_srcB.r             -> u_dut.pending |
