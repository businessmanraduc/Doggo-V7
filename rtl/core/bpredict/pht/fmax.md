# pht solo Fmax

ring-of-regs, nextpnr --85k CABGA381, tw=100, 20 seeds

| floor | mean | ceil |
|---|---|---|
| 362.98 | 400.61 | 447.43 |

## census (worst path per seed)

| seed | fmax | start -> end |
|---|---|---|
| 1 | 422.83 | u_dut.u_primaryA.u_ebr.DOB1 -> u_sink.dq |
| 2 | 374.95 | u2.perturb           -> u_dut.u_alternateA.u_ebr.ADB1 |
| 3 | 415.45 | u1.r                 -> u_dut.u_alternateB.u_ebr.ADB1 |
| 4 | 381.53 | u2.perturb           -> u_dut.u_primaryA.u_ebr.ADB1 |
| 5 | 377.50 | u1.r                 -> u_dut.u_alternateB.u_ebr.ADB1 |
| 6 | 362.98 | u1.r                 -> u_dut.u_alternateB.u_ebr.ADB1 |
| 7 | 395.10 | u_dut.u_alternateB.u_ebr.DOB1 -> u_sink.dq |
| 8 | 417.36 | u_dut.u_alternateA.u_ebr.DOB1 -> u_sink.dq |
| 9 | 390.32 | u_dut.u_alternateA.u_ebr.DOB1 -> u_sink.dq |
| 10 | 417.36 | u_dut.u_primaryB.u_ebr.DOB1 -> u_sink.dq |
| 11 | 390.32 | u_dut.u_primaryB.u_ebr.DOB1 -> u_sink.dq |
| 12 | 438.98 | u2.perturb           -> u_dut.u_alternateA.u_ebr.ADB1 |
| 13 | 419.46 | u_dut.u_alternateA.u_ebr.DOB1 -> u_sink.dq |
| 14 | 371.61 | u2.perturb           -> u_dut.u_alternateA.u_ebr.ADB1 |
| 15 | 394.32 | u2.perturb           -> u_dut.u_alternateA.u_ebr.ADB1 |
| 16 | 383.14 | u1.r                 -> u_dut.u_alternateB.u_ebr.ADB1 |
| 17 | 447.43 | u_dut.u_alternateB.u_ebr.DOB1 -> u_sink.dq |
| 18 | 417.36 | u_dut.u_alternateB.u_ebr.DOB1 -> u_sink.dq |
| 19 | 376.93 | u2.perturb           -> u_dut.u_alternateA.u_ebr.ADB1 |
| 20 | 417.36 | u_dut.u_primaryA.u_ebr.DOB1 -> u_sink.dq |
