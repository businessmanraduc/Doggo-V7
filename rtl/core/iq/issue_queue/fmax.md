# issue_queue solo Fmax

ring-of-regs, nextpnr --85k CABGA381, tw=100, 20 seeds
tools: Yosys 0.62, nextpnr-35f1433

| floor | median | mean | ceil |
|---|---|---|---|
| 151.47 | 156.97 | 156.19 | 165.10 |

## census (worst path per seed)

| seed | fmax | start -> end |
|---|---|---|
| 1 | 153.89 | u_dut.iq_depL1       -> u_dut.g_dup |
| 2 | 162.05 | u_dut.iq_delayL5c    -> u_dut.iq_dispatchLate2 |
| 3 | 153.33 | u_dut.g_dup          -> u_dut.g_dup |
| 4 | 151.47 | u_s3.r               -> u_dut.iq_dispatchLate2 |
| 5 | 151.54 | u_s3.r               -> u_dut.g_dup |
| 6 | 165.10 | u_dut.iq_depDiv      -> u_dut.iq_rowLate2 |
| 7 | 158.13 | u_dut.g_dup          -> u_dut.g_dup |
| 8 | 152.53 | u_s1.r               -> u_dut.iq_delayL3 |
| 9 | 156.91 | u_s1.r               -> u_dut.iq_wakeNow |
| 10 | 153.47 | u_dut.pds_ds_rs1Wait -> u_dut.g_dup |
| 11 | 158.35 | u_dut.g_dup          -> u_dut.g_dup |
| 12 | 158.63 | u_dut.g_dup          -> u_dut.g_dup |
| 13 | 157.63 | u_s1.r               -> u_dut.g_dup |
| 14 | 160.98 | u_dut.g_dup          -> u_dut.g_dup |
| 15 | 158.58 | u_dut.g_dup          -> u_dut.g_dup |
| 16 | 157.04 | u_dut.g_dup          -> u_dut.g_dup |
| 17 | 152.88 | u_dut.iq_branchMask  -> u_dut.iq_wakeNow |
| 18 | 151.75 | u_s1.r               -> u_dut.iq_ready |
| 19 | 151.63 | u_dut.g_dup          -> u_dut.g_dup |
| 20 | 157.90 | u_s1.r               -> u_dut.g_dup |
