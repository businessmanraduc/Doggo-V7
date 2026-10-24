# issue_queue solo Fmax

ring-of-regs, nextpnr --85k CABGA381, tw=100, 20 seeds
tools: Yosys 0.62, nextpnr-35f1433

| floor | median | mean | ceil |
|---|---|---|---|
| 144.84 | 154.92 | 155.06 | 163.00 |

## census (worst path per seed)

| seed | fmax | start -> end |
|---|---|---|
| 1 | 150.63 | u_dut.iq_branchMask  -> u_dut.g_dup |
| 2 | 157.36 | u_dut.g_dup          -> u_dut.g_dup |
| 3 | 154.42 | u_dut.g_dup          -> u_dut.g_dup |
| 4 | 158.15 | u_dut.g_dup          -> u_dut.g_dup |
| 5 | 154.80 | u_dut.g_dup          -> u_dut.g_dup |
| 6 | 156.15 | u_dut.iq_branchMask  -> u_dut.iq_delayL3 |
| 7 | 155.11 | u_dut.iq_branchMask  -> u_dut.iq_delayL3 |
| 8 | 153.49 | u_s1.r               -> u_dut.g_dup |
| 9 | 153.70 | u_dut.iq_delayL4b    -> u_dut.iq_rowLate2 |
| 10 | 155.04 | u_s1.r               -> u_dut.g_dup |
| 11 | 157.58 | u_s1.r               -> u_dut.iq_wakeNow |
| 12 | 144.84 | u_dut.iq_branchMask  -> u_dut.g_dup |
| 13 | 148.17 | u_s1.perturb         -> u_dut.g_dup |
| 14 | 153.85 | u_s1.r               -> u_dut.iq_wakeNow |
| 15 | 159.72 | u_s1.r               -> u_dut.g_dup |
| 16 | 163.00 | u_dut.g_dup          -> u_dut.g_dup |
| 17 | 152.14 | u_dut.g_dup          -> u_dut.g_dup |
| 18 | 159.67 | u_s1.r               -> u_dut.g_dup |
| 19 | 159.67 | u_s1.r               -> u_dut.iq_delayL4a |
| 20 | 153.63 | u_dut.g_dup          -> u_dut.g_dup |
