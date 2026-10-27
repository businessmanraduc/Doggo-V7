# rename solo Fmax

ring-of-regs, nextpnr --85k CABGA381, tw=100, 20 seeds
tools: Yosys 0.62, nextpnr-35f1433

| floor | median | mean | ceil |
|---|---|---|---|
| 138.81 | 156.20 | 156.48 | 177.84 |

## census (worst path per seed)

| seed | fmax | start -> end |
|---|---|---|
| 1 | 149.16 | u_dut.rn_hold        -> u_dut.rn_map |
| 2 | 156.40 | u_dut.rn_hold        -> u_dut.rn_map |
| 3 | 161.32 | u_dut.r1_r2_valid    -> u_dut.rn_map |
| 4 | 168.35 | u_dut.r1_r2_valid    -> u_dut.rn_map |
| 5 | 163.67 | u_dut.rd2_skidValid  -> u_dut.rn_map |
| 6 | 152.07 | u_dut.d_r1_isBranch  -> u_dut.rn_map |
| 7 | 155.62 | u_dut.d_r1_isBranch  -> u_dut.fl_headTag |
| 8 | 156.01 | u_dut.rn_hold        -> u_dut.rn_map |
| 9 | 162.07 | u_dut.r1_r2_valid    -> u_dut.rn_map |
| 10 | 146.31 | u_dut.d_r1_isJalr    -> u_dut.rn_map |
| 11 | 162.36 | u_dut.d_r1_isJalr    -> u_dut.rn_map |
| 12 | 176.62 | u_s0.r               -> u_dut.r1_r2_rs1Part |
| 13 | 156.94 | u_dut.d_r1_isBranch  -> u_dut.fl_headTag |
| 14 | 140.77 | u_dut.rn_hold        -> u_dut.rn_map |
| 15 | 177.84 | u_dut.r1_r2_valid    -> u_dut.rn_map |
| 16 | 142.17 | u_dut.rd2_skidValid  -> u_dut.rn_map |
| 17 | 157.78 | u_dut.rn_hold        -> u_dut.rn_map |
| 18 | 138.81 | u_dut.r1_r2_valid    -> u_dut.rn_map |
| 19 | 155.47 | u_dut.rd2_skidValid  -> u_dut.rn_map |
| 20 | 149.88 | u_dut.d_r1_isBranch  -> u_dut.rn_map |
