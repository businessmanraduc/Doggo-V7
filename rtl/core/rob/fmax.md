# rob solo Fmax

ring-of-regs, nextpnr --85k CABGA381, tw=100, 20 seeds
tools: Yosys 0.62, nextpnr-35f1433

| floor | median | mean | ceil |
|---|---|---|---|
| 140.37 | 162.26 | 161.17 | 178.00 |

## census (worst path per seed)

| seed | fmax | start -> end |
|---|---|---|
| 1 | 148.72 | u_dut.cm_flush       -> u_dut.rb_refetch |
| 2 | 157.95 | u_s1.r               -> u_dut.rb_count |
| 3 | 163.13 | u_dut.ex_resolveMispredict -> u_dut.rb_done |
| 4 | 166.81 | u_dut.cm_flush       -> u_dut.rb_refetch |
| 5 | 178.00 | u_dut.ex_resolveValid -> u_dut.rb_count |
| 6 | 172.53 | u_dut.ex_resolveValid -> u_dut.rb_refetch |
| 7 | 172.65 | u_dut.cm_flush       -> u_dut.rb_refetch |
| 8 | 162.84 | u_dut.cm_flush       -> u_dut.rb_count |
| 9 | 166.53 | u_dut.cm_flush       -> u_dut.rb_refetch |
| 10 | 157.90 | u_dut.cm_flush       -> u_dut.rb_refetch |
| 11 | 153.40 | u_dut.rb_count       -> u_dut.rb_refetch |
| 12 | 157.63 | u_dut.rb_count       -> u_dut.rb_refetch |
| 13 | 157.04 | u_dut.rb_count       -> u_dut.rb_done |
| 14 | 161.68 | u_dut.cm_flush       -> u_dut.rb_refetch |
| 15 | 165.48 | u_s1.r               -> u_dut.rb_refetch |
| 16 | 140.37 | u_dut.cm_flush       -> u_dut.rb_refetch |
| 17 | 157.16 | u_dut.cm_flush       -> u_dut.rb_refetch |
| 18 | 165.78 | u_s1.r               -> u_dut.rb_done |
| 19 | 166.83 | u_dut.ex_resolveValid -> u_dut.rb_refetch |
| 20 | 150.99 | u_dut.ex_resolveValid -> u_dut.rb_done |
