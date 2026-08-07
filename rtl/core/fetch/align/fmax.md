# align solo Fmax

ring-of-regs, nextpnr --85k CABGA381, tw=100, 20 seeds

| floor | mean | ceil |
|---|---|---|
| 193.50 | 210.39 | 232.45 |

## census (worst path per seed)

| seed | fmax | start -> end |
|---|---|---|
| 1 | 208.51 | u_dut.half           -> u_sink.dq |
| 2 | 196.19 | u_srcC.r             -> u_sink.dq |
| 3 | 193.50 | u_dut.half           -> u_sink.dq |
| 4 | 232.45 | u_srcC.r             -> u_dut.half |
| 5 | 208.77 | u_dut.half           -> u_sink.dq |
| 6 | 226.30 | u_dut.half           -> u_sink.dq |
| 7 | 231.48 | u_srcC.r             -> u_sink.dq |
| 8 | 198.73 | u_dut.half           -> u_sink.dq |
| 9 | 217.16 | u_srcC.r             -> u_sink.dq |
| 10 | 230.36 | u_dut.half           -> u_sink.dq |
| 11 | 209.47 | u_dut.half           -> u_sink.dq |
| 12 | 210.97 | u_srcC.r             -> u_sink.dq |
| 13 | 203.25 | u_dut.half           -> u_sink.dq |
| 14 | 217.20 | u_dut.half           -> u_sink.dq |
| 15 | 199.84 | u_srcC.r             -> u_sink.dq |
| 16 | 207.43 | u_dut.half           -> u_sink.dq |
| 17 | 194.55 | u_dut.half           -> u_sink.dq |
| 18 | 214.13 | u_srcC.r             -> u_sink.dq |
| 19 | 209.91 | u_srcC.r             -> u_sink.dq |
| 20 | 197.63 | u_srcC.r             -> u_sink.dq |
