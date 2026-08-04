# align solo Fmax

ring-of-regs, nextpnr --85k CABGA381, tw=100, 20 seeds

| floor | mean | ceil |
|---|---|---|
| 173.19 | 189.53 | 207.60 |

## census (worst path per seed)

| seed | fmax | start -> end |
|---|---|---|
| 1 | 188.36 | u_dut.half           -> u_sink.dq |
| 2 | 194.82 | u_srcC.r             -> u_sink.dq |
| 3 | 173.43 | u_dut.half           -> u_sink.dq |
| 4 | 203.00 | u_dut.half           -> u_sink.dq |
| 5 | 173.19 | u_srcC.r             -> u_sink.dq |
| 6 | 190.69 | u_dut.half           -> u_sink.dq |
| 7 | 204.16 | u_srcC.r             -> u_dut.half |
| 8 | 196.73 | u_srcC.r             -> u_sink.dq |
| 9 | 186.81 | u_dut.half           -> u_sink.dq |
| 10 | 175.69 | u_srcC.r             -> u_sink.dq |
| 11 | 193.39 | u_dut.half           -> u_sink.dq |
| 12 | 193.20 | u_srcC.r             -> u_sink.dq |
| 13 | 185.05 | u_dut.half           -> u_sink.dq |
| 14 | 191.94 | u_srcC.r             -> u_sink.dq |
| 15 | 175.93 | u_srcC.r             -> u_sink.dq |
| 16 | 207.60 | u_srcC.r             -> u_sink.dq |
| 17 | 190.04 | u_dut.half           -> u_sink.dq |
| 18 | 178.48 | u_srcC.r             -> u_sink.dq |
| 19 | 194.70 | u_dut.half           -> u_sink.dq |
| 20 | 193.42 | u_dut.half           -> u_sink.dq |
