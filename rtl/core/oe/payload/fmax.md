# payload solo Fmax

ring-of-regs, nextpnr --85k CABGA381, tw=100, 20 seeds
tools: Yosys 0.62, nextpnr-35f1433

| floor | median | mean | ceil |
|---|---|---|---|
| 230.04 | 263.12 | 259.67 | 286.37 |

## census (worst path per seed)

| seed | fmax | start -> end |
|---|---|---|
| 1 | 261.03 | u_s6.r               -> u_dut.pl_readWord |
| 2 | 267.88 | u_s6.r               -> u_dut.pl_readWord |
| 3 | 278.63 | u_s6.r               -> u_dut.pl_readWord |
| 4 | 263.99 | u_s6.r               -> u_dut.pl_readWord |
| 5 | 266.24 | u_s6.r               -> u_dut.pl_readWord |
| 6 | 262.26 | u_s6.r               -> u_dut.pl_readWord |
| 7 | 241.72 | u_s6.r               -> u_dut.pr_rf_xIsZero |
| 8 | 266.81 | u_s6.r               -> u_dut.pl_readWord |
| 9 | 230.04 | u_s6.r               -> u_dut.pr_rf_sltUnsigned |
| 10 | 264.62 | u_s6.r               -> u_dut.pl_readWord |
| 11 | 244.08 | u_s6.r               -> u_dut.pl_readWord |
| 12 | 255.89 | u_s6.r               -> u_dut.pl_readWord |
| 13 | 264.83 | u_s6.r               -> u_dut.pl_readWord |
| 14 | 266.60 | u_s6.r               -> u_dut.pl_readWord |
| 15 | 250.50 | u_s0.r               -> u_dut.pl_ram.0.36 |
| 16 | 286.37 | u_s6.r               -> u_dut.pl_readWord |
| 17 | 262.26 | u_s6.r               -> u_dut.pl_readWord |
| 18 | 266.03 | u_s6.r               -> u_dut.pl_readWord |
| 19 | 236.29 | u_s6.r               -> u_dut.pl_readWord |
| 20 | 257.27 | u_s6.r               -> u_dut.pl_readWord |
