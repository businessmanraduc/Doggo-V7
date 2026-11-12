# alu solo Fmax

ring-of-regs, nextpnr --85k CABGA381, tw=100, 20 seeds
tools: Yosys 0.62, nextpnr-35f1433

| floor | median | mean | ceil |
|---|---|---|---|
| 155.93 | 165.45 | 165.09 | 176.46 |

## census (worst path per seed)

| seed | fmax | start -> end |
|---|---|---|
| 1 | 171.00 | u_dut.g_copy         -> u_dut.ex0_ex1_result |
| 2 | 160.88 | u_dut.g_copy         -> u_dut.ex0_ex1_taken |
| 3 | 165.40 | u_dut.g_copy         -> u_dut.ex0_ex1_taken |
| 4 | 165.59 | u_dut.g_copy         -> u_dut.ex0_ex1_taken |
| 5 | 166.94 | u_dut.g_copy         -> u_dut.ex0_ex1_result |
| 6 | 157.04 | u_dut.g_copy         -> u_dut.ex0_ex1_taken |
| 7 | 168.38 | u_dut.g_copy         -> u_dut.ex0_ex1_result |
| 8 | 160.54 | u_dut.ex0_ex1_result -> u_dut.ex0_ex1_result |
| 9 | 166.94 | u_dut.g_copy         -> u_dut.ex0_ex1_taken |
| 10 | 169.32 | u_dut.g_copy         -> u_dut.ex0_ex1_taken |
| 11 | 163.67 | u_s1.r               -> u_dut.ex0_ex1_taken |
| 12 | 171.12 | u_dut.g_copy         -> u_dut.ex0_ex1_result |
| 13 | 172.29 | u_dut.g_copy         -> u_dut.ex0_ex1_result |
| 14 | 176.46 | u_dut.ex0_ex1_result -> u_dut.ex0_ex1_result |
| 15 | 163.99 | u_dut.g_copy         -> u_dut.ex0_ex1_taken |
| 16 | 157.95 | u_dut.g_copy         -> u_dut.ex0_ex1_taken |
| 17 | 160.80 | u_dut.g_copy         -> u_dut.ex0_ex1_taken |
| 18 | 162.07 | u_dut.g_copy         -> u_dut.ex0_ex1_result |
| 19 | 165.51 | u_dut.g_copy         -> u_dut.ex0_ex1_taken |
| 20 | 155.93 | u_dut.ex0_ex1_result -> u_dut.ex0_ex1_result |
