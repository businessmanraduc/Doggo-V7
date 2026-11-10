# respipe solo Fmax

ring-of-regs, nextpnr --85k CABGA381, tw=100, 20 seeds
tools: Yosys 0.62, nextpnr-35f1433

| floor | median | mean | ceil |
|---|---|---|---|
| 216.64 | 232.21 | 231.87 | 248.82 |

## census (worst path per seed)

| seed | fmax | start -> end |
|---|---|---|
| 1 | 243.31 | u_dut.rf_rr_branchMask -> u_dut.rr_ex0_producer |
| 2 | 239.41 | u_dut.ex2_ex3_branchMask -> u_dut.ex3_wb_producer |
| 3 | 227.12 | u_s1.r               -> u_dut.ex0_ex1_producer |
| 4 | 231.80 | u_s1.r               -> u_dut.rr_ex0_producer |
| 5 | 228.52 | u_s1.r               -> u_dut.ex1_ex2_producer |
| 6 | 226.86 | u_s1.r               -> u_dut.rf_rr_producer |
| 7 | 233.86 | u_s1.r               -> u_dut.rf_rr_producer |
| 8 | 229.52 | u_s1.r               -> u_dut.ex3_wb_producer |
| 9 | 242.01 | u_s1.r               -> u_dut.ex3_wb_producer |
| 10 | 235.24 | u_s1.r               -> u_dut.ex0_ex1_producer |
| 11 | 225.17 | u_s1.r               -> u_dut.ex0_ex1_producer |
| 12 | 234.03 | u_s1.r               -> u_dut.ex3_wb_producer |
| 13 | 248.82 | u_dut.rf_rr_branchMask -> u_dut.rr_ex0_producer |
| 14 | 218.96 | u_dut.ex1_ex2_branchMask -> u_dut.ex2_ex3_producer |
| 15 | 232.61 | u_dut.rf_rr_branchMask -> u_dut.rr_ex0_producer |
| 16 | 216.64 | u_s1.r               -> u_dut.rr_ex0_producer |
| 17 | 234.36 | u_s1.r               -> u_dut.ex0_ex1_producer |
| 18 | 222.87 | u_s1.r               -> u_dut.rf_rr_producer |
| 19 | 237.53 | u_s1.r               -> u_dut.rf_rr_producer |
| 20 | 228.78 | u_s1.r               -> u_dut.ex2_ex3_producer |
