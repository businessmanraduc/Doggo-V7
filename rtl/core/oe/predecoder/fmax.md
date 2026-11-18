# predecoder solo Fmax

ring-of-regs, nextpnr --85k CABGA381, tw=100, 20 seeds
tools: Yosys 0.62, nextpnr-35f1433

| floor | median | mean | ceil |
|---|---|---|---|
| 144.40 | 152.83 | 152.20 | 162.00 |

## census (worst path per seed)

| seed | fmax | start -> end |
|---|---|---|
| 1 | 144.40 | u_s0.r               -> u_dut.d_r1_rdLo |
| 2 | 150.97 | u_s0.r               -> u_dut.d_r1_rdLo |
| 3 | 155.69 | u_s0.r               -> u_dut.d_r1_rdLo |
| 4 | 155.84 | u_s0.r               -> u_dut.d_r1_rdLo |
| 5 | 147.80 | u_s0.r               -> u_dut.d_r1_rdLo |
| 6 | 145.01 | u_s0.r               -> u_dut.d_r1_rdLo |
| 7 | 147.82 | u_s0.r               -> u_dut.d_r1_rdHi |
| 8 | 156.27 | u_s0.r               -> u_dut.d_r1_rdHi |
| 9 | 152.07 | u_s0.r               -> u_dut.d_r1_rdLo |
| 10 | 151.49 | u_s1.perturb         -> u_dut.d_r1_rdLo |
| 11 | 148.59 | u_s0.r               -> u_dut.d_r1_rdLo |
| 12 | 162.00 | u_s1.perturb         -> u_dut.d_r1_rdLo |
| 13 | 147.38 | u_s0.r               -> u_dut.d_r1_rdLo |
| 14 | 154.89 | u_s0.r               -> u_dut.d_r1_rdLo |
| 15 | 144.61 | u_s1.perturb         -> u_dut.d_r1_rdLo |
| 16 | 160.44 | u_s0.r               -> u_dut.d_r1_rdLo |
| 17 | 153.59 | u_s0.r               -> u_dut.d_r1_rdLo |
| 18 | 155.45 | u_s0.r               -> u_dut.d_r1_rdHi |
| 19 | 154.01 | u_s0.r               -> u_dut.d_r1_rdLo |
| 20 | 155.67 | u_s0.r               -> u_dut.d_r1_rdLo |
