# align solo Fmax

ring-of-regs, nextpnr --85k CABGA381, tw=100, 20 seeds

| floor | mean | ceil |
|---|---|---|
| 156.32 | 191.66 | 213.04 |

## census (worst path per seed)

| seed | fmax | start -> end |
|---|---|---|
| 1 | 190.91 | u_srcC.r             -> u_sink.dq |
| 2 | 198.02 | u_dut.half           -> u_sink.dq |
| 3 | 178.54 | u_dut.half           -> u_sink.dq |
| 4 | 178.22 | u_srcC.r             -> u_sink.dq |
| 5 | 207.68 | u_dut.half           -> u_sink.dq |
| 6 | 191.17 | u_srcC.r             -> u_sink.dq |
| 7 | 156.32 | u_dut.half           -> u_sink.dq |
| 8 | 208.20 | u_srcC.r             -> u_sink.dq |
| 9 | 202.39 | u_srcC.r             -> u_sink.dq |
| 10 | 198.29 | u_dut.half           -> u_sink.dq |
| 11 | 189.68 | u_dut.half           -> u_sink.dq |
| 12 | 181.79 | u_dut.half           -> u_sink.dq |
| 13 | 207.25 | u_srcC.r             -> u_dut.half |
| 14 | 192.98 | u_srcC.r             -> u_dut.half |
| 15 | 190.66 | u_srcC.r             -> u_sink.dq |
| 16 | 213.04 | u_srcC.r             -> u_sink.dq |
| 17 | 176.12 | u_dut.half           -> u_sink.dq |
| 18 | 203.33 | u_dut.half           -> u_dut.half |
| 19 | 172.80 | u_dut.half           -> u_sink.dq |
| 20 | 195.73 | u_srcC.r             -> u_sink.dq |
