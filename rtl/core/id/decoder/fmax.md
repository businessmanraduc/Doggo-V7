# decoder solo Fmax

ring-of-regs, nextpnr --85k CABGA381, tw=100, 20 seeds
tools: Yosys 0.62, nextpnr-35f1433

| floor | median | mean | ceil |
|---|---|---|---|
| 145.60 | 148.91 | 150.42 | 157.53 |

## census (worst path per seed)

| seed | fmax | start -> end |
|---|---|---|
| 1 | 150.20 | u_s0.r               -> u_dut.d1_d2_illegalW |
| 2 | 146.82 | u_s0.r               -> u_dut.d1_d2_illegalW |
| 3 | 149.03 | u_s0.r               -> u_dut.d1_d2_illegalW |
| 4 | 147.73 | u_s0.r               -> u_dut.d1_d2_selSlt |
| 5 | 148.30 | u_s0.r               -> u_dut.d1_d2_illegalW |
| 6 | 157.53 | u_s0.r               -> u_dut.d1_d2_illegalW |
| 7 | 147.78 | u_s0.r               -> u_dut.d1_d2_illegalW |
| 8 | 148.41 | u_s0.r               -> u_dut.d1_d2_illegalW |
| 9 | 147.45 | u_s0.r               -> u_dut.d1_d2_illegalW |
| 10 | 146.56 | u_s0.r               -> u_dut.d1_d2_illegalW |
| 11 | 151.72 | u_s0.r               -> u_dut.d1_d2_illegalW |
| 12 | 153.40 | u_s0.r               -> u_dut.d1_d2_illegalW |
| 13 | 148.79 | u_s0.r               -> u_dut.d1_d2_illegalW |
| 14 | 152.28 | u_s0.r               -> u_dut.d1_d2_sltUnsigned |
| 15 | 153.68 | u_s0.r               -> u_dut.d1_d2_illegalW |
| 16 | 157.04 | u_s0.r               -> u_dut.d1_d2_illegalW |
| 17 | 156.62 | u_s0.r               -> u_dut.d1_d2_illegalW |
| 18 | 148.79 | u_s0.r               -> u_dut.d1_d2_illegalW |
| 19 | 145.60 | u_s0.r               -> u_dut.d1_d2_illegalW |
| 20 | 150.72 | u_s0.r               -> u_dut.d1_d2_illegalW |
