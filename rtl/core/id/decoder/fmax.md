# decoder solo Fmax

ring-of-regs, nextpnr --85k CABGA381, tw=100, 20 seeds
tools: Yosys 0.62, nextpnr-35f1433

| floor | median | mean | ceil |
|---|---|---|---|
| 147.08 | 155.86 | 155.99 | 163.64 |

## census (worst path per seed)

| seed | fmax | start -> end |
|---|---|---|
| 1 | 149.45 | u_s0.r               -> u_dut.d1_d2_selArith |
| 2 | 163.64 | u_s0.r               -> u_dut.d1_d2_sltUnsigned |
| 3 | 160.95 | u_s0.r               -> u_dut.d1_d2_selSlt |
| 4 | 158.45 | u_s0.r               -> u_dut.d1_d2_selArith |
| 5 | 155.93 | u_s0.r               -> u_dut.d1_d2_sltUnsigned |
| 6 | 147.08 | u_s0.r               -> u_dut.d1_d2_illegalAlu |
| 7 | 155.79 | u_s0.r               -> u_dut.d1_d2_sltUnsigned |
| 8 | 150.26 | u_s0.r               -> u_dut.d1_d2_sltUnsigned |
| 9 | 153.68 | u_s0.r               -> u_dut.d1_d2_sltUnsigned |
| 10 | 151.63 | u_s0.r               -> u_dut.d1_d2_selXor |
| 11 | 155.01 | u_s0.r               -> u_dut.d1_d2_selSlt |
| 12 | 158.76 | u_s0.r               -> u_dut.d1_d2_sub |
| 13 | 161.42 | u_s0.r               -> u_dut.d1_d2_illegalSys |
| 14 | 157.04 | u_s0.r               -> u_dut.d1_d2_system |
| 15 | 163.61 | u_s0.r               -> u_dut.d1_d2_sub |
| 16 | 156.20 | u_s0.r               -> u_dut.d1_d2_selArith |
| 17 | 152.77 | u_s0.r               -> u_dut.d1_d2_illegalAlu |
| 18 | 150.35 | u_s0.r               -> u_dut.d1_d2_sltUnsigned |
| 19 | 154.58 | u_s0.r               -> u_dut.d1_d2_class |
| 20 | 163.21 | u_s0.r               -> u_dut.d1_d2_sltUnsigned |
