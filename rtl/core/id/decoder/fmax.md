# decoder solo Fmax

ring-of-regs, nextpnr --85k CABGA381, tw=100, 20 seeds

| floor | mean | ceil |
|---|---|---|
| 146.97 | 156.33 | 166.22 |

## census (worst path per seed)

| seed | fmax | start -> end |
|---|---|---|
| 1 | 154.63 | u_s0.r               -> u_dut.r1_r2_illegal |
| 2 | 156.23 | u_s0.r               -> u_dut.r1_r2_illegal |
| 3 | 157.93 | u_s0.r               -> u_dut.r1_r2_selSlt |
| 4 | 155.91 | u_s0.r               -> u_dut.r1_r2_illegal |
| 5 | 159.87 | u_s0.r               -> u_dut.r1_r2_illegal |
| 6 | 160.62 | u_s0.r               -> u_dut.r1_r2_selSlt |
| 7 | 157.58 | u_s0.r               -> u_dut.r1_r2_illegal |
| 8 | 166.22 | u_s0.r               -> u_dut.r1_r2_illegal |
| 9 | 153.78 | u_s0.r               -> u_dut.r1_r2_sub |
| 10 | 152.88 | u_s0.r               -> u_dut.r1_r2_illegal |
| 11 | 148.21 | u_s0.r               -> u_dut.r1_r2_sub |
| 12 | 150.38 | u_s0.r               -> u_dut.r1_r2_illegal |
| 13 | 148.68 | u_s0.r               -> u_dut.r1_r2_illegal |
| 14 | 157.41 | u_s0.r               -> u_dut.r1_r2_illegal |
| 15 | 146.97 | u_s0.r               -> u_dut.r1_r2_illegal |
| 16 | 165.15 | u_s0.r               -> u_dut.r1_r2_illegal |
| 17 | 158.58 | u_s0.r               -> u_dut.r1_r2_illegal |
| 18 | 161.60 | u_s0.r               -> u_dut.r1_r2_illegal |
| 19 | 158.86 | u_s0.r               -> u_dut.r1_r2_illegal |
| 20 | 155.13 | u_s0.r               -> u_dut.r1_r2_illegal |
