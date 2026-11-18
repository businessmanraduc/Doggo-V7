# rename solo Fmax

ring-of-regs, nextpnr --85k CABGA381, tw=100, 20 seeds
tools: Yosys 0.62, nextpnr-35f1433

| floor | median | mean | ceil |
|---|---|---|---|
| 160.62 | 172.86 | 174.21 | 192.49 |

## census (worst path per seed)

| seed | fmax | start -> end |
|---|---|---|
| 1 | 175.65 | u_dut.sn_mask        -> u_dut.sn_full |
| 2 | 185.74 | u_dut.sn_full        -> u_dut.fl_head |
| 3 | 172.44 | u_dut.d_r1_needSnapshot -> u_dut.fl_headTag |
| 4 | 179.53 | u_dut.sn_live        -> u_dut.sn_full |
| 5 | 175.75 | u_dut.sn_mask        -> u_dut.sn_full |
| 6 | 192.49 | u_dut.sn_mask        -> u_dut.sn_full |
| 7 | 160.62 | u_dut.rd2_skidValid  -> u_dut.fl_headTag |
| 8 | 168.24 | u_dut.rn_hold        -> u_dut.fl_head |
| 9 | 171.94 | u_dut.sn_mask        -> u_dut.sn_full |
| 10 | 169.55 | u_dut.sn_full        -> u_dut.fl_head |
| 11 | 173.28 | u_dut.sn_live        -> u_dut.sn_full |
| 12 | 167.25 | u_dut.sn_mask        -> u_dut.sn_full |
| 13 | 175.13 | u_dut.sn_mask        -> u_dut.sn_full |
| 14 | 171.12 | u_dut.sn_mask        -> u_dut.sn_full |
| 15 | 167.11 | u_dut.sn_mask        -> u_dut.sn_full |
| 16 | 166.69 | u_dut.d_r1_needSnapshot -> u_dut.sn_full |
| 17 | 173.61 | u_dut.sn_mask        -> u_dut.sn_full |
| 18 | 183.12 | u_dut.sn_mask        -> u_dut.sn_full |
| 19 | 182.55 | u_dut.sn_live        -> u_dut.sn_full |
| 20 | 172.38 | u_dut.d_r1_needSnapshot -> u_dut.sn_full |
