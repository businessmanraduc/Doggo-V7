# linefill solo Fmax

ring-of-regs, nextpnr --85k CABGA381, tw=100, 20 seeds

| floor | mean | ceil |
|---|---|---|
| 200.08 | 214.66 | 225.63 |

## census (worst path per seed)

| seed | fmax | start -> end |
|---|---|---|
| 1 | 224.67 | u_dut.state          -> u_dut.state |
| 2 | 216.31 | u_dut.state          -> u_dut.tagWrTag |
| 3 | 225.63 | u_dut.state          -> u_dut.beatCount |
| 4 | 207.60 | u_dut.state          -> u_dut.state |
| 5 | 223.61 | u_dut.sweepCount     -> u_dut.state |
| 6 | 209.38 | u_dut.state          -> u_dut.state |
| 7 | 224.77 | u_dut.state          -> u_dut.state |
| 8 | 202.14 | u_dut.state          -> u_dut.state |
| 9 | 204.29 | u_dut.state          -> u_dut.state |
| 10 | 217.39 | u_dut.state          -> u_dut.state |
| 11 | 216.40 | u_dut.state          -> u_dut.state |
| 12 | 224.11 | u_dut.state          -> u_dut.state |
| 13 | 210.66 | u_dut.state          -> u_dut.beatCount |
| 14 | 216.40 | u_dut.state          -> u_dut.state |
| 15 | 200.08 | u_dut.state          -> u_dut.tagWrTag |
| 16 | 203.38 | u_dut.state          -> u_dut.state |
| 17 | 211.24 | u_dut.state          -> u_dut.state |
| 18 | 221.04 | u_dut.state          -> u_dut.state |
| 19 | 213.36 | u_dut.state          -> u_dut.state |
| 20 | 220.80 | u_dut.state          -> u_dut.state |
