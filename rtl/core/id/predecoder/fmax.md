# predecoder solo Fmax

ring-of-regs, nextpnr --85k CABGA381, tw=100, 20 seeds
tools: Yosys 0.62, nextpnr-35f1433

| floor | median | mean | ceil |
|---|---|---|---|
| 154.99 | 177.04 | 177.51 | 187.23 |

## census (worst path per seed)

| seed | fmax | start -> end |
|---|---|---|
| 1 | 175.53 | u_dut.f5_d_rvc       -> u_dut.d_r1_branchTarget |
| 2 | 176.80 | u_dut.f5_d_rvc       -> u_dut.d_r1_branchTarget |
| 3 | 176.09 | u_dut.f5_d_rvc       -> u_dut.d_r1_branchTarget |
| 4 | 175.07 | u_dut.f5_d_rvc       -> u_dut.d_r1_branchTarget |
| 5 | 178.57 | u_dut.f5_d_rvc       -> u_dut.d_r1_branchTarget |
| 6 | 186.67 | u_dut.f5_d_rvc       -> u_dut.d_r1_branchTarget |
| 7 | 179.34 | u_s0.r               -> u_dut.d_r1_branchTarget |
| 8 | 167.56 | u_s1.perturb         -> u_dut.d_r1_rdIndex |
| 9 | 171.03 | u_s0.r               -> u_dut.d_r1_rdIndex |
| 10 | 182.15 | u_s0.r               -> u_dut.d_r1_branchTarget |
| 11 | 187.23 | u_s0.r               -> u_dut.d_r1_branchTarget |
| 12 | 184.06 | u_s0.r               -> u_dut.d_r1_branchTarget |
| 13 | 185.43 | u_dut.f5_d_rvc       -> u_dut.d_r1_branchTarget |
| 14 | 180.96 | u_s0.r               -> u_dut.d_r1_branchTarget |
| 15 | 154.99 | u_s0.r               -> u_dut.d_r1_rs2Use |
| 16 | 176.71 | u_s0.r               -> u_dut.d_r1_rs1Use |
| 17 | 176.77 | u_dut.f5_d_rvc       -> u_dut.d_r1_branchTarget |
| 18 | 177.27 | u_s0.r               -> u_dut.d_r1_branchTarget |
| 19 | 176.03 | u_s0.r               -> u_dut.d_r1_rs1Use |
| 20 | 182.02 | u_s0.r               -> u_dut.d_r1_rs1Use |
