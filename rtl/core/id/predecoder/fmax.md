# predecoder solo Fmax

ring-of-regs, nextpnr --85k CABGA381, tw=100, 20 seeds

| floor | mean | ceil |
|---|---|---|
| 167.36 | 178.31 | 192.86 |

## census (worst path per seed)

| seed | fmax | start -> end |
|---|---|---|
| 1 | 176.74 | u_dut.f5_d_rvc       -> u_dut.d_r1_branchTarget |
| 2 | 182.65 | u_s0.r               -> u_dut.d_r1_branchTarget |
| 3 | 179.21 | u_dut.f5_d_rvc       -> u_dut.d_r1_branchTarget |
| 4 | 180.90 | u_s0.r               -> u_dut.d_r1_rs1Use |
| 5 | 167.36 | u_s0.r               -> u_dut.d_r1_rs1Use |
| 6 | 181.55 | u_s0.r               -> u_dut.d_r1_branchTarget |
| 7 | 177.12 | u_s0.r               -> u_dut.d_r1_branchTarget |
| 8 | 176.77 | u_dut.f5_d_rvc       -> u_dut.d_r1_branchTarget |
| 9 | 175.99 | u_dut.f5_d_rvc       -> u_dut.d_r1_branchTarget |
| 10 | 167.90 | u_dut.f5_d_rvc       -> u_dut.d_r1_branchTarget |
| 11 | 189.25 | u_s0.r               -> u_dut.d_r1_branchTarget |
| 12 | 192.86 | u_s0.r               -> u_dut.d_r1_branchTarget |
| 13 | 177.30 | u_s0.r               -> u_dut.d_r1_branchTarget |
| 14 | 174.25 | u_dut.f5_d_rvc       -> u_dut.d_r1_branchTarget |
| 15 | 187.62 | u_s0.r               -> u_dut.d_r1_branchTarget |
| 16 | 171.29 | u_s0.r               -> u_dut.d_r1_branchTarget |
| 17 | 171.67 | u_s0.r               -> u_dut.d_r1_branchTarget |
| 18 | 181.29 | u_s0.r               -> u_dut.d_r1_rdWriteEnable |
| 19 | 180.25 | u_s0.r               -> u_dut.d_r1_rs1Use |
| 20 | 174.13 | u_s0.r               -> u_dut.d_r1_rdWriteEnable |
