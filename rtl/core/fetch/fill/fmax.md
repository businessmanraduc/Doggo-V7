# linefill solo Fmax

ring-of-regs, nextpnr --85k CABGA381, tw=100, 20 seeds

| floor | mean | ceil |
|---|---|---|
| 192.57 | 220.75 | 241.08 |

## census (worst path per seed)

| seed | fmax | start -> end |
|---|---|---|
| 1 | 230.41 | u_dut.state          -> u_dut.tagWrTag |
| 2 | 207.99 | u_dut.state          -> u_dut.state |
| 3 | 211.95 | u_dut.state          -> u_dut.tagWrTag |
| 4 | 224.16 | u_dut.state          -> u_dut.state |
| 5 | 215.66 | u_dut.sweepCount     -> u_dut.state |
| 6 | 231.80 | u_dut.state          -> u_dut.state |
| 7 | 209.73 | u_dut.sweepCount     -> u_dut.state |
| 8 | 229.89 | u_dut.state          -> u_dut.state |
| 9 | 231.96 | u_dut.sweepCount     -> u_dut.state |
| 10 | 203.13 | u_dut.state          -> u_dut.state |
| 11 | 192.57 | u_dut.state          -> u_dut.state |
| 12 | 241.08 | u_dut.state          -> u_dut.tagWrTag |
| 13 | 220.99 | u_dut.state          -> u_dut.state |
| 14 | 237.19 | u_dut.state          -> u_dut.state |
| 15 | 211.55 | u_dut.state          -> u_dut.state |
| 16 | 219.78 | u_dut.sweepCount     -> u_dut.state |
| 17 | 231.32 | u_dut.state          -> u_dut.state |
| 18 | 220.95 | u_dut.state          -> u_dut.state |
| 19 | 223.41 | u_dut.sweepCount     -> u_dut.settleCount |
| 20 | 219.49 | u_dut.state          -> u_dut.state |
