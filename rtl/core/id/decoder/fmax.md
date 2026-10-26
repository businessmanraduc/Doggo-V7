# decoder solo Fmax

ring-of-regs, nextpnr --85k CABGA381, tw=100, 20 seeds
tools: Yosys 0.62, nextpnr-35f1433

| floor | median | mean | ceil |
|---|---|---|---|
| 138.10 | 154.75 | 154.14 | 161.97 |

## census (worst path per seed)

| seed | fmax | start -> end |
|---|---|---|
| 1 | 160.88 | u_s0.r               -> u_dut.r1_r2_illegal |
| 2 | 155.88 | u_s0.r               -> u_dut.r1_r2_illegal |
| 3 | 138.10 | u_s0.r               -> u_dut.r1_r2_illegal |
| 4 | 154.54 | u_s0.r               -> u_dut.r1_r2_illegal |
| 5 | 156.67 | u_s0.r               -> u_dut.r1_r2_illegal |
| 6 | 141.32 | u_s0.r               -> u_dut.r1_r2_illegal |
| 7 | 161.97 | u_s0.r               -> u_dut.r1_r2_sltUnsigned |
| 8 | 160.23 | u_s0.r               -> u_dut.r1_r2_illegal |
| 9 | 150.04 | u_s0.r               -> u_dut.r1_r2_illegal |
| 10 | 159.01 | u_s0.r               -> u_dut.r1_r2_illegal |
| 11 | 154.30 | u_s0.r               -> u_dut.r1_r2_sub |
| 12 | 154.46 | u_s0.r               -> u_dut.r1_r2_illegal |
| 13 | 155.64 | u_s0.r               -> u_dut.r1_r2_illegal |
| 14 | 150.40 | u_s0.r               -> u_dut.r1_r2_selArith |
| 15 | 154.06 | u_s0.r               -> u_dut.r1_r2_sub |
| 16 | 156.86 | u_s0.r               -> u_dut.r1_r2_illegal |
| 17 | 154.97 | u_s1.perturb         -> u_dut.r1_r2_illegal |
| 18 | 152.84 | u_s0.r               -> u_dut.r1_r2_illegal |
| 19 | 157.73 | u_s0.r               -> u_dut.r1_r2_illegal |
| 20 | 152.98 | u_s0.r               -> u_dut.r1_r2_sltUnsigned |
