# ex solo Fmax

ring-of-regs, nextpnr --85k CABGA381, tw=100, 20 seeds
tools: Yosys 0.62, nextpnr-35f1433

| floor | median | mean | ceil |
|---|---|---|---|
| 143.60 | 153.16 | 152.32 | 157.73 |

## census (worst path per seed)

| seed | fmax | start -> end |
|---|---|---|
| 1 | 150.13 | u_dut.u_alu.ex0_ex1_result -> u_dut.u_alu.ex0_ex1_result |
| 2 | 151.08 | u_dut.u_alu.g_copy   -> u_dut.u_alu.ex0_ex1_result |
| 3 | 157.43 | u_dut.u_rr.rr_ex0_z  -> u_dut.u_alu.ex0_ex1_result |
| 4 | 154.34 | u_dut.u_alu.g_copy   -> u_dut.u_alu.ex0_ex1_result |
| 5 | 152.98 | u_dut.u_rr.rr_ex0_z  -> u_dut.u_alu.ex0_ex1_result |
| 6 | 157.73 | u_dut.u_alu.g_copy   -> u_dut.u_alu.ex0_ex1_result |
| 7 | 155.42 | u_dut.u_alu.ex0_ex1_result -> u_dut.u_alu.ex0_ex1_result |
| 8 | 156.18 | u_dut.u_alu.ex0_ex1_result -> u_dut.u_alu.ex0_ex1_result |
| 9 | 151.03 | u_dut.u_alu.g_copy   -> u_dut.u_alu.ex0_ex1_result |
| 10 | 153.52 | u_dut.u_alu.g_copy   -> u_dut.u_alu.ex0_ex1_result |
| 11 | 143.60 | u_dut.u_alu.g_copy   -> u_dut.u_alu.ex0_ex1_result |
| 12 | 152.60 | u_dut.u_alu.ex0_ex1_result -> u_dut.u_alu.ex0_ex1_result |
| 13 | 147.51 | u_dut.u_alu.ex0_ex1_result -> u_dut.u_alu.ex0_ex1_result |
| 14 | 153.33 | u_dut.u_alu.g_copy   -> u_dut.u_alu.ex0_ex1_result |
| 15 | 155.11 | u_dut.u_rr.rr_ex0_z  -> u_dut.u_alu.ex0_ex1_result |
| 16 | 155.69 | u_dut.u_rr.rr_ex0_z  -> u_dut.u_alu.ex0_ex1_result |
| 17 | 149.05 | u_dut.u_rr.rr_ex0_z  -> u_dut.u_alu.ex0_ex1_result |
| 18 | 153.68 | u_dut.u_alu.g_copy   -> u_dut.u_alu.ex0_ex1_result |
| 19 | 149.66 | u_dut.u_alu.g_copy   -> u_dut.u_alu.ex0_ex1_result |
| 20 | 146.35 | u_dut.u_rr.rr_ex0_z  -> u_dut.u_alu.ex0_ex1_result |
