# regread solo Fmax

ring-of-regs, nextpnr --85k CABGA381, tw=100, 20 seeds
tools: Yosys 0.62, nextpnr-35f1433

| floor | median | mean | ceil |
|---|---|---|---|
| 174.16 | 183.57 | 184.38 | 201.29 |

## census (worst path per seed)

| seed | fmax | start -> end |
|---|---|---|
| 1 | 175.07 | g_src                -> u_dut.rf_rr_selZ |
| 2 | 184.26 | u_s0.r               -> u_dut.rf_rr_selZ |
| 3 | 189.90 | u_s0.r               -> u_dut.rf_rr_selX |
| 4 | 175.62 | u_s0.r               -> u_dut.rf_rr_selZ |
| 5 | 182.88 | u_s0.r               -> u_dut.rf_rr_selX |
| 6 | 186.39 | u_s0.r               -> u_dut.rf_rr_selZ |
| 7 | 182.78 | g_src                -> u_dut.rf_rr_selX |
| 8 | 201.29 | g_src                -> u_dut.rf_rr_selZ |
| 9 | 174.16 | g_src                -> u_dut.rf_rr_selX |
| 10 | 193.24 | u_s0.r               -> u_dut.rf_rr_selX |
| 11 | 188.36 | u_s0.r               -> u_dut.rf_rr_selX |
| 12 | 194.67 | u_s0.r               -> u_dut.rf_rr_selX |
| 13 | 181.19 | u_s0.r               -> u_dut.rf_rr_selZ |
| 14 | 184.64 | u_s0.r               -> u_dut.rf_rr_selZ |
| 15 | 180.86 | g_src                -> u_dut.rf_rr_selX |
| 16 | 187.97 | u_s0.r               -> u_dut.rf_rr_selX |
| 17 | 185.25 | u_s0.r               -> u_dut.rf_rr_selX |
| 18 | 182.68 | g_src                -> u_dut.rf_rr_selX |
| 19 | 178.60 | u_s0.r               -> u_dut.rf_rr_selX |
| 20 | 177.84 | u_s0.r               -> u_dut.rf_rr_selZ |
