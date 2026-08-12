# bpredict solo Fmax

ring-of-regs, nextpnr --85k CABGA381, tw=100, 20 seeds

| floor | mean | ceil |
|---|---|---|
| 151.45 | 167.05 | 177.56 |

## census (worst path per seed)

| seed | fmax | start -> end |
|---|---|---|
| 1 | 174.79 | u_dut.taken_P3       -> u_dut.push_P3 |
| 2 | 170.62 | u_dut.valid_P2b      -> u_dut.push_P3 |
| 3 | 162.63 | u_dut.u_ftq.readPtr  -> u_dut.u_ftq.memIssue.0.2_DO |
| 4 | 169.00 | u_dut.u_btb.slotAIsOdd -> u_dut.u_pht.u_primaryB.u_ebr.ADB9 |
| 5 | 152.70 | u_dut.u_ftq.readPtr  -> u_dut.u_ftq.memIssue.0.2_DO |
| 6 | 167.14 | u_dut.validB_P3      -> u_dut.u_ftq.unissued |
| 7 | 161.71 | u_dut.u_ftq.readPtr  -> u_dut.u_ftq.readPtr |
| 8 | 165.70 | u_dut.u_ftq.readPtr  -> u_dut.u_ftq.readPtr |
| 9 | 168.18 | u_dut.u_ftq.readPtr  -> u_dut.u_ftq.readPtr |
| 10 | 168.63 | u_dut.write_P3       -> u_dut.u_ftq.unissued |
| 11 | 170.01 | u_dut.u_ftq.readPtr  -> u_dut.u_ftq.readPtr |
| 12 | 155.35 | u_dut.u_ftq.readPtr  -> u_dut.u_ftq.memIssue.0.2_DO |
| 13 | 176.49 | u_dut.redirectValid  -> u_dut.nextPC |
| 14 | 171.73 | u_dut.nextPC         -> u_dut.u_pht.u_primaryB.u_ebr.ADB11 |
| 15 | 177.56 | u_dut.redirectValid  -> u_dut.nextPC |
| 16 | 174.58 | u_dut.redirectValid  -> u_dut.nextPC |
| 17 | 151.45 | u_dut.u_ftq.readPtr  -> u_dut.u_ftq.memIssue.0.2_DO |
| 18 | 171.38 | u_dut.write_P3       -> u_dut.u_ftq.unissued |
| 19 | 156.74 | u_dut.taken_P3       -> u_dut.push_P3 |
| 20 | 174.64 | u_dut.write_P3       -> u_dut.u_ftq.unissued |
