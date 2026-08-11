# bpredict solo Fmax

ring-of-regs, nextpnr --85k CABGA381, tw=100, 20 seeds

| floor | mean | ceil |
|---|---|---|
| 154.25 | 169.88 | 179.92 |

## census (worst path per seed)

| seed | fmax | start -> end |
|---|---|---|
| 1 | 179.92 | u_dut.u_ftq.readPtr  -> u_dut.u_ftq.readPtr |
| 2 | 168.78 | u_dut.u_ftq.readPtr  -> u_dut.u_ftq.readPtr |
| 3 | 165.45 | u_dut.resetn         -> u_dut.nextPC |
| 4 | 167.93 | u_dut.u_ftq.readPtr  -> u_dut.u_ftq.readPtr |
| 5 | 169.32 | u_dut.u_ftq.memRetire.0.0_DO_3 -> u_dut.u_ftq.memRetire.0.0_DO_3 |
| 6 | 154.25 | u_dut.resetn         -> u_dut.nextPC |
| 7 | 173.25 | u_dut.u_ftq.memRetire.0.0_DO_3 -> u_dut.u_ftq.memRetire.0.0_DO_3 |
| 8 | 171.14 | u_dut.redirectValid  -> u_dut.nextPC |
| 9 | 171.76 | u_dut.write_P3       -> u_dut.u_ftq.unissued |
| 10 | 174.98 | u_dut.u_ftq.readPtr  -> u_dut.u_ftq.readPtr |
| 11 | 168.58 | u_dut.redirectValid  -> u_dut.nextPC |
| 12 | 162.44 | u_dut.redirectValid  -> u_dut.nextPC |
| 13 | 169.38 | u_dut.nextPC         -> u_dut.u_pht.u_primaryB.u_ebr.ADB7 |
| 14 | 173.52 | u_dut.u_btb.g_odd    -> u_dut.tagQB |
| 15 | 167.08 | u_dut.resetn         -> u_dut.nextPC |
| 16 | 164.15 | u_dut.write_P3       -> u_dut.u_ftq.unissued |
| 17 | 175.47 | u_dut.u_btb.g_odd    -> u_dut.tagQA |
| 18 | 171.35 | u_dut.valid_P2b      -> u_dut.pop_P3 |
| 19 | 172.47 | u_dut.redirectValid  -> u_dut.nextPC |
| 20 | 176.46 | u_dut.redirectValid  -> u_dut.nextPC |
