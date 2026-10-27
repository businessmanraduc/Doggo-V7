# rename solo Fmax

ring-of-regs, nextpnr --85k CABGA381, tw=100, 20 seeds
tools: Yosys 0.62, nextpnr-35f1433

| floor | median | mean | ceil |
|---|---|---|---|
| 143.43 | 153.89 | 153.84 | 166.75 |

## census (worst path per seed)

| seed | fmax | start -> end |
|---|---|---|
| 1 | 164.04 | u_dut.stall_r2_pds   -> u_dut.rn_map |
| 2 | 145.88 | u_dut.sn_full        -> u_dut.fl_headTag |
| 3 | 156.64 | u_dut.r1_r2_valid    -> u_dut.fl_headTag |
| 4 | 144.11 | u_dut.stall_r2_pds   -> u_dut.fl_headTag |
| 5 | 161.76 | u_dut.stall_r2_pds   -> u_dut.fl_headTag |
| 6 | 144.55 | u_dut.sn_full        -> u_dut.fl_headTag |
| 7 | 162.28 | u_dut.d_r1_isJalr    -> u_dut.fl_headTag |
| 8 | 166.75 | u_dut.stall_r2_pds   -> u_dut.fl_headTag |
| 9 | 153.82 | u_dut.r1_r2_valid    -> u_dut.rn_map |
| 10 | 152.30 | u_dut.r1_r2_valid    -> u_dut.fl_headTag |
| 11 | 152.28 | u_dut.sn_full        -> u_dut.fl_headTag |
| 12 | 143.43 | u_dut.sn_full        -> u_dut.fl_headTag |
| 13 | 155.26 | u_dut.d_r1_isJalr    -> u_dut.fl_headTag |
| 14 | 155.11 | u_dut.d_r1_isJalr    -> u_dut.fl_headTag |
| 15 | 156.62 | u_dut.sn_full        -> u_dut.fl_headTag |
| 16 | 151.75 | u_dut.r1_r2_valid    -> u_dut.fl_headTag |
| 17 | 147.41 | u_dut.sn_full        -> u_dut.fl_headTag |
| 18 | 158.50 | u_dut.sn_full        -> u_dut.fl_headTag |
| 19 | 153.96 | u_dut.stall_r2_pds   -> u_dut.fl_headTag |
| 20 | 150.26 | u_dut.d_r1_isJalr    -> u_dut.fl_headTag |
