# rename solo Fmax

ring-of-regs, nextpnr --85k CABGA381, tw=100, 20 seeds
tools: Yosys 0.62, nextpnr-35f1433

| floor | median | mean | ceil |
|---|---|---|---|
| 147.10 | 155.05 | 154.82 | 166.17 |

## census (worst path per seed)

| seed | fmax | start -> end |
|---|---|---|
| 1 | 152.32 | u_dut.rn_hold        -> u_dut.fl_headTag |
| 2 | 156.84 | u_dut.rn_hold        -> u_dut.fl_headTag |
| 3 | 149.79 | u_dut.fl_head        -> u_dut.rn_hold |
| 4 | 161.79 | u_dut.r1_r2_valid    -> u_dut.fl_headTag |
| 5 | 157.80 | u_dut.fl_tail        -> u_dut.rn_hold |
| 6 | 149.23 | u_dut.fl_tail        -> u_dut.rn_hold |
| 7 | 156.35 | u_dut.d_r1_isJalr    -> u_dut.fl_headTag |
| 8 | 154.46 | u_dut.stall_r2_pds   -> u_dut.fl_headTag |
| 9 | 152.44 | u_dut.fl_head        -> u_dut.rn_hold |
| 10 | 148.24 | u_dut.fl_tail        -> u_dut.rn_hold |
| 11 | 155.64 | u_dut.fl_tail        -> u_dut.rn_hold |
| 12 | 162.55 | u_dut.fl_head        -> u_dut.rn_hold |
| 13 | 148.24 | u_dut.stall_r2_pds   -> u_dut.fl_headTag |
| 14 | 156.99 | u_dut.fl_tail        -> u_dut.rn_hold |
| 15 | 147.10 | u_dut.fl_tail        -> u_dut.rn_hold |
| 16 | 160.05 | u_dut.fl_head        -> u_dut.fl_headTag |
| 17 | 151.40 | u_dut.rn_hold        -> u_dut.fl_headTag |
| 18 | 166.17 | u_dut.d_r1_isBranch  -> u_dut.fl_headTag |
| 19 | 159.41 | u_dut.d_r1_isBranch  -> u_dut.fl_headTag |
| 20 | 149.57 | u_dut.fl_tail        -> u_dut.rn_hold |
