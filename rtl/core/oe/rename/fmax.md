# rename solo Fmax

ring-of-regs, nextpnr --85k CABGA381, tw=100, 20 seeds
tools: Yosys 0.62, nextpnr-35f1433

| floor | median | mean | ceil |
|---|---|---|---|
| 145.01 | 165.70 | 165.55 | 188.36 |

## census (worst path per seed)

| seed | fmax | start -> end |
|---|---|---|
| 1 | 164.47 | u_dut.d_r1_isBranch  -> u_dut.rn_map |
| 2 | 188.36 | u_dut.d_r1_isBranch  -> u_dut.rn_map |
| 3 | 175.22 | u_dut.rd2_skidValid  -> u_dut.rn_map |
| 4 | 164.18 | u_dut.rn_hold        -> u_dut.rn_map |
| 5 | 166.22 | u_dut.rn_hold        -> u_dut.rn_map |
| 6 | 175.75 | u_s0.r               -> u_dut.sn_full |
| 7 | 165.65 | u_dut.r1_r2_valid    -> u_dut.rn_map |
| 8 | 145.01 | u_dut.d_r1_isJalr    -> u_dut.rn_map |
| 9 | 169.78 | u_dut.d_r1_isJalr    -> u_dut.rn_map |
| 10 | 169.75 | u_dut.rn_hold        -> u_dut.rn_map |
| 11 | 177.34 | u_dut.d_r1_isBranch  -> u_dut.rn_map |
| 12 | 177.18 | u_dut.rd2_skidValid  -> u_dut.rn_map |
| 13 | 147.97 | u_dut.r1_r2_valid    -> u_dut.rn_map |
| 14 | 146.05 | u_dut.r1_r2_valid    -> u_dut.rn_map |
| 15 | 160.90 | u_dut.rn_hold        -> u_dut.rn_map |
| 16 | 165.76 | u_dut.d_r1_isJalr    -> u_dut.rn_map |
| 17 | 165.54 | u_dut.r1_r2_valid    -> u_dut.rn_map |
| 18 | 163.64 | u_dut.r1_r2_valid    -> u_dut.rn_map |
| 19 | 173.79 | u_dut.rn_hold        -> u_dut.rn_map |
| 20 | 148.35 | u_dut.d_r1_isJalr    -> u_dut.rn_map |
