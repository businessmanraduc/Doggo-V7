# align solo Fmax

ring-of-regs, nextpnr --85k CABGA381, tw=100, 20 seeds

| floor | mean | ceil |
|---|---|---|
| 193.80 | 214.02 | 236.91 |

## census (worst path per seed)

| seed | fmax | start -> end |
|---|---|---|
| 1 | 206.06 | u_srcC.r             -> u_sink.dq |
| 2 | 217.96 | u_dut.half           -> u_sink.dq |
| 3 | 218.53 | u_srcC.r             -> u_sink.dq |
| 4 | 203.09 | u_srcC.r             -> u_sink.dq |
| 5 | 222.17 | u_srcC.r             -> u_sink.dq |
| 6 | 213.45 | u_srcC.r             -> u_dut.half |
| 7 | 193.80 | u_dut.half           -> u_sink.dq |
| 8 | 220.07 | u_srcC.r             -> u_sink.dq |
| 9 | 201.61 | u_dut.half           -> u_sink.dq |
| 10 | 216.03 | u_srcC.r             -> u_sink.dq |
| 11 | 198.18 | u_dut.half           -> u_sink.dq |
| 12 | 236.91 | u_srcC.r             -> u_dut.half |
| 13 | 229.99 | u_dut.half           -> u_sink.dq |
| 14 | 224.42 | u_dut.half           -> u_dut.half |
| 15 | 220.31 | u_srcC.r             -> u_sink.dq |
| 16 | 206.74 | u_dut.half           -> u_sink.dq |
| 17 | 215.24 | u_srcC.r             -> u_dut.half |
| 18 | 210.61 | u_srcC.r             -> u_sink.dq |
| 19 | 209.95 | u_dut.half           -> u_sink.dq |
| 20 | 215.19 | u_dut.half           -> u_sink.dq |
