# rob solo Fmax

ring-of-regs, nextpnr --85k CABGA381, tw=100, 20 seeds

| floor | mean | ceil |
|---|---|---|
| 168.21 | 185.99 | 203.79 |

## census (worst path per seed)

| seed | fmax | start -> end |
|---|---|---|
| 1 | 196.00 | u_dut.head           -> u_dut.count |
| 2 | 189.72 | u_dut.done           -> u_dut.count |
| 3 | 199.56 | u_dut.done           -> u_dut.full |
| 4 | 176.90 | u_dut.done           -> u_dut.count |
| 5 | 186.08 | u_dut.done           -> u_dut.full |
| 6 | 185.46 | u_dut.done           -> u_dut.full |
| 7 | 190.19 | u_dut.done           -> u_dut.full |
| 8 | 190.22 | u_dut.head           -> u_dut.full |
| 9 | 187.90 | u_dut.head           -> u_dut.full |
| 10 | 183.69 | u_dut.done           -> u_dut.full |
| 11 | 190.15 | u_dut.head           -> u_dut.count |
| 12 | 171.82 | u_dut.head           -> u_dut.count |
| 13 | 168.21 | u_dut.head           -> u_dut.full |
| 14 | 191.35 | u_dut.head           -> u_dut.full |
| 15 | 178.03 | u_dut.head           -> u_dut.count |
| 16 | 192.20 | u_dut.head           -> u_dut.count |
| 17 | 187.72 | u_dut.done           -> u_dut.full |
| 18 | 171.97 | u_dut.head           -> u_dut.count |
| 19 | 178.86 | u_dut.done           -> u_dut.full |
| 20 | 203.79 | u_dut.head           -> u_dut.count |
