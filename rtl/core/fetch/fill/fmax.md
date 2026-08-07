# linefill solo Fmax

ring-of-regs, nextpnr --85k CABGA381, tw=100, 20 seeds

| floor | mean | ceil |
|---|---|---|
| 192.75 | 216.58 | 228.41 |

## census (worst path per seed)

| seed | fmax | start -> end |
|---|---|---|
| 1 | 228.36 | u_dut.state          -> u_dut.state |
| 2 | 218.05 | u_dut.state          -> u_dut.settleCount |
| 3 | 216.22 | u_dut.state          -> u_dut.settleCount |
| 4 | 215.56 | u_dut.state          -> u_dut.settleCount |
| 5 | 222.07 | u_dut.state          -> u_dut.state |
| 6 | 221.98 | u_dut.state          -> u_dut.state |
| 7 | 228.41 | u_dut.state          -> u_dut.state |
| 8 | 211.82 | u_dut.state          -> u_dut.state |
| 9 | 228.10 | u_dut.state          -> u_dut.tagWrTag |
| 10 | 217.30 | u_dut.state          -> u_dut.state |
| 11 | 225.99 | u_dut.state          -> u_dut.state |
| 12 | 221.34 | u_dut.state          -> u_dut.tagWrTag |
| 13 | 206.06 | u_dut.state          -> u_dut.settleCount |
| 14 | 217.68 | u_dut.state          -> u_dut.state |
| 15 | 210.88 | u_dut.state          -> u_dut.settleCount |
| 16 | 192.75 | u_dut.state          -> u_dut.tagWrTag |
| 17 | 199.44 | u_dut.state          -> u_dut.settleCount |
| 18 | 210.84 | u_dut.state          -> u_dut.settleCount |
| 19 | 226.55 | u_dut.state          -> u_dut.settleCount |
| 20 | 212.13 | u_dut.state          -> u_dut.settleCount |
