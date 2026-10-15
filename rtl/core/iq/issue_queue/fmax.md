# issue_queue solo Fmax

ring-of-regs, nextpnr --85k CABGA381, tw=100, 20 seeds
tools: Yosys 0.62, nextpnr-35f1433

| floor | median | mean | ceil |
|---|---|---|---|
| 148.06 | 158.69 | 158.79 | 164.88 |

## census (worst path per seed)

| seed | fmax | start -> end |
|---|---|---|
| 1 | 157.98 | u_dut.sd_divWake     -> u_dut.iq_dispatchLate2 |
| 2 | 154.80 | u_s2.r               -> u_dut.g_dup |
| 3 | 157.28 | u_dut.iq_branchMask  -> u_dut.g_dup |
| 4 | 160.26 | u_dut.g_dup          -> u_dut.g_dup |
| 5 | 161.50 | u_dut.g_dup          -> u_dut.g_dup |
| 6 | 158.23 | u_s1.r               -> u_dut.g_dup |
| 7 | 155.81 | u_dut.iq_dispatchReadyQ -> u_dut.g_dup |
| 8 | 159.57 | u_dut.g_dup          -> u_dut.g_dup |
| 9 | 159.16 | u_dut.iq_delayL4b    -> u_dut.iq_rowLate2 |
| 10 | 164.37 | u_dut.g_dup          -> u_dut.g_dup |
| 11 | 156.25 | u_dut.iq_depL1       -> u_dut.g_dup |
| 12 | 162.71 | u_s1.r               -> u_dut.g_dup |
| 13 | 148.06 | u_dut.iq_delayL3     -> u_dut.iq_rowLate2 |
| 14 | 163.53 | u_dut.g_dup          -> u_dut.g_dup |
| 15 | 164.15 | u_dut.g_dup          -> u_dut.g_dup |
| 16 | 159.16 | u_s1.r               -> u_dut.g_dup |
| 17 | 164.88 | u_dut.g_dup          -> u_dut.g_dup |
| 18 | 157.78 | u_dut.g_dup          -> u_dut.g_dup |
| 19 | 155.81 | u_s1.r               -> u_dut.g_dup |
| 20 | 154.54 | u_s1.perturb         -> u_dut.g_dup |
