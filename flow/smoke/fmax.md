# add_smoke solo Fmax

ring-of-regs, nextpnr --85k CABGA381, tw=90, 20 seeds

| floor | mean | ceil |
|---|---|---|
| 268.31 | 273.71 | 287.94 |

## census (worst path per seed)

| seed | fmax | start -> end |
|---|---|---|
| 1 | 273.75 | u_srcB.r             -> u_dut.out |
| 2 | 272.55 | u_srcB.r             -> u_dut.out |
| 3 | 276.78 | u_srcB.r             -> u_dut.out |
| 4 | 272.93 | u_srcB.r             -> u_dut.out |
| 5 | 273.45 | u_srcB.r             -> u_dut.out |
| 6 | 273.82 | u_srcA.r             -> u_dut.out |
| 7 | 271.30 | u_srcB.r             -> u_dut.out |
| 8 | 268.31 | u_srcB.r             -> u_dut.out |
| 9 | 287.94 | u_srcA.r             -> u_dut.out |
| 10 | 272.70 | u_srcB.r             -> u_dut.out |
| 11 | 272.70 | u_srcB.r             -> u_dut.out |
| 12 | 270.34 | u_srcB.r             -> u_dut.out |
| 13 | 282.01 | u_srcB.perturb       -> u_dut.out |
| 14 | 273.75 | u_srcB.r             -> u_dut.out |
| 15 | 272.93 | u_srcA.r             -> u_dut.out |
| 16 | 273.45 | u_srcB.r             -> u_dut.out |
| 17 | 273.75 | u_srcB.r             -> u_dut.out |
| 18 | 272.55 | u_srcB.r             -> u_dut.out |
| 19 | 270.20 | u_srcB.perturb       -> u_dut.out |
| 20 | 268.89 | u_srcB.r             -> u_dut.out |
