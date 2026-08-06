# linefill solo Fmax

ring-of-regs, nextpnr --85k CABGA381, tw=100, 20 seeds

| floor | mean | ceil |
|---|---|---|
| 191.09 | 213.29 | 232.40 |

## census (worst path per seed)

| seed | fmax | start -> end |
|---|---|---|
| 1 | 216.17 | u_dut.state          -> u_dut.tagWrTag |
| 2 | 205.80 | u_dut.state          -> u_dut.state |
| 3 | 203.46 | u_dut.state          -> u_dut.state |
| 4 | 208.20 | u_dut.state          -> u_dut.state |
| 5 | 213.27 | u_dut.state          -> u_dut.state |
| 6 | 224.42 | u_dut.sweepCount     -> u_dut.settleCount |
| 7 | 213.68 | u_dut.state          -> u_dut.state |
| 8 | 219.20 | u_dut.state          -> u_dut.state |
| 9 | 232.40 | u_dut.state          -> u_dut.state |
| 10 | 202.68 | u_dut.state          -> u_dut.state |
| 11 | 191.09 | u_dut.state          -> u_dut.state |
| 12 | 226.81 | u_dut.state          -> u_dut.tagWrTag |
| 13 | 220.46 | u_dut.state          -> u_dut.state |
| 14 | 221.58 | u_dut.state          -> u_dut.tagWrTag |
| 15 | 211.55 | u_dut.state          -> u_dut.state |
| 16 | 219.78 | u_dut.sweepCount     -> u_dut.state |
| 17 | 194.48 | u_dut.state          -> u_dut.state |
| 18 | 199.96 | u_dut.state          -> u_dut.state |
| 19 | 224.22 | u_dut.sweepCount     -> u_dut.settleCount |
| 20 | 216.59 | u_dut.state          -> u_dut.state |
