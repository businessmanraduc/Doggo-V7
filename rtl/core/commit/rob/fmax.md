# rob solo Fmax

ring-of-regs, nextpnr --85k CABGA381, tw=100, 20 seeds

| floor | mean | ceil |
|---|---|---|
| 160.15 | 183.73 | 199.56 |

## census (worst path per seed)

| seed | fmax | start -> end |
|---|---|---|
| 1 | 189.43 | u_dut.head           -> u_dut.count |
| 2 | 189.72 | u_dut.done           -> u_dut.count |
| 3 | 199.56 | u_dut.done           -> u_dut.full |
| 4 | 164.23 | u_dut.done           -> u_dut.count |
| 5 | 186.08 | u_dut.done           -> u_dut.full |
| 6 | 185.19 | u_dut.done           -> u_dut.full |
| 7 | 187.62 | u_dut.done           -> u_dut.full |
| 8 | 184.03 | u_dut.done           -> u_dut.full |
| 9 | 184.30 | u_dut.head           -> u_dut.full |
| 10 | 183.39 | u_dut.head           -> u_dut.full |
| 11 | 189.97 | u_dut.head           -> u_dut.count |
| 12 | 172.00 | u_dut.head           -> u_dut.count |
| 13 | 160.15 | u_dut.head           -> u_dut.full |
| 14 | 189.86 | u_dut.done           -> u_dut.full |
| 15 | 180.96 | u_dut.head           -> u_dut.count |
| 16 | 190.22 | u_dut.head           -> u_dut.count |
| 17 | 192.20 | u_dut.head           -> u_dut.full |
| 18 | 174.16 | u_dut.head           -> u_dut.count |
| 19 | 176.40 | u_dut.done           -> u_dut.full |
| 20 | 195.05 | u_dut.head           -> u_dut.count |
