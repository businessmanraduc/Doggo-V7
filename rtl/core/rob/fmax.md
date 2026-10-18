# rob solo Fmax

ring-of-regs, nextpnr --85k CABGA381, tw=100, 20 seeds
tools: Yosys 0.62, nextpnr-35f1433

| floor | median | mean | ceil |
|---|---|---|---|
| 159.62 | 169.25 | 168.76 | 179.53 |

## census (worst path per seed)

| seed | fmax | start -> end |
|---|---|---|
| 1 | 167.28 | u_dut.rb_done        -> u_dut.rb_headReady |
| 2 | 178.19 | u_dut.ex_resolveValid -> u_dut.rb_count |
| 3 | 159.62 | u_dut.ex_resolveMispredict -> u_dut.rb_count |
| 4 | 179.53 | u_dut.rb_done        -> u_dut.rb_headReady |
| 5 | 172.21 | u_dut.ex_resolveValid -> u_dut.rb_done |
| 6 | 173.64 | u_dut.rb_refetch     -> u_dut.cm_flush |
| 7 | 168.75 | u_s2.r               -> u_dut.rb_count |
| 8 | 168.89 | u_dut.ex_resolveMispredict -> u_dut.rb_count |
| 9 | 163.35 | u_dut.rb_done        -> u_dut.rb_headReady |
| 10 | 171.00 | u_dut.ex_resolveMispredict -> u_dut.rb_count |
| 11 | 165.54 | u_dut.ex_resolveValid -> u_dut.rb_done |
| 12 | 165.10 | u_dut.ex_resolveValid -> u_dut.rb_done |
| 13 | 171.59 | u_dut.ex_resolveValid -> u_dut.rb_count |
| 14 | 164.47 | u_dut.ex_resolveMispredict -> u_dut.rb_count |
| 15 | 169.61 | u_dut.ex_resolveValid -> u_dut.rb_done |
| 16 | 171.20 | u_dut.rb_refetch     -> u_dut.cm_flush |
| 17 | 160.77 | u_dut.ex_resolveValid -> u_dut.rb_count |
| 18 | 160.21 | u_dut.rb_headOneHot  -> u_dut.rb_headReady |
| 19 | 169.89 | u_dut.ex_resolveMispredict -> u_dut.rb_done |
| 20 | 174.40 | u_dut.rb_headOneHot  -> u_dut.rb_headReady |
