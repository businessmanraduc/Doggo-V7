# ras solo Fmax

ring-of-regs, nextpnr --85k CABGA381, tw=100, 20 seeds

| floor | mean | ceil |
|---|---|---|
| 191.17 | 209.62 | 235.40 |

## census (worst path per seed)

| seed | fmax | start -> end |
|---|---|---|
| 1 | 211.86 | u2.r                 -> u_dut.top |
| 2 | 205.97 | u2.r                 -> u_dut.top |
| 3 | 209.47 | u2.r                 -> u_dut.top |
| 4 | 218.15 | u_dut.ptr            -> u_dut.top |
| 5 | 202.76 | u2.r                 -> u_dut.top |
| 6 | 219.01 | u2.r                 -> u_dut.top |
| 7 | 214.82 | u2.r                 -> u_dut.top |
| 8 | 196.73 | u2.r                 -> u_dut.top |
| 9 | 229.04 | u2.r                 -> u_dut.top |
| 10 | 204.71 | u2.r                 -> u_dut.top |
| 11 | 217.34 | u2.r                 -> u_dut.top |
| 12 | 203.83 | u2.r                 -> u_dut.top |
| 13 | 202.63 | u2.r                 -> u_dut.top |
| 14 | 235.40 | u2.r                 -> u_dut.top |
| 15 | 207.08 | u2.r                 -> u_dut.top |
| 16 | 191.17 | u2.r                 -> u_dut.top |
| 17 | 194.59 | u2.r                 -> u_dut.top |
| 18 | 200.96 | u2.r                 -> u_dut.top |
| 19 | 208.94 | u2.r                 -> u_dut.top |
| 20 | 217.86 | u2.r                 -> u_dut.top |
