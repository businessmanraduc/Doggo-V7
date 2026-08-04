# align solo Fmax

ring-of-regs, nextpnr --85k CABGA381, tw=100, 20 seeds

| floor | mean | ceil |
|---|---|---|
| 156.32 | 189.79 | 208.20 |

## census (worst path per seed)

| seed | fmax | start -> end |
|---|---|---|
| 1 | 199.84 | u_srcC.r             -> u_sink.dq |
| 2 | 195.43 | u_dut.half           -> u_sink.dq |
| 3 | 178.51 | u_dut.half           -> u_sink.dq |
| 4 | 178.22 | u_srcC.r             -> u_sink.dq |
| 5 | 207.68 | u_dut.half           -> u_sink.dq |
| 6 | 191.17 | u_srcC.r             -> u_sink.dq |
| 7 | 156.32 | u_dut.half           -> u_sink.dq |
| 8 | 208.20 | u_srcC.r             -> u_sink.dq |
| 9 | 202.14 | u_srcC.r             -> u_sink.dq |
| 10 | 184.37 | u_dut.half           -> u_sink.dq |
| 11 | 189.68 | u_dut.half           -> u_sink.dq |
| 12 | 181.79 | u_dut.half           -> u_sink.dq |
| 13 | 195.50 | u_srcC.r             -> u_sink.dq |
| 14 | 192.46 | u_srcC.r             -> u_dut.half |
| 15 | 186.39 | u_srcC.r             -> u_sink.dq |
| 16 | 206.61 | u_srcC.r             -> u_dut.half |
| 17 | 174.95 | u_dut.half           -> u_sink.dq |
| 18 | 196.08 | u_dut.half           -> u_sink.dq |
| 19 | 174.67 | u_dut.half           -> u_sink.dq |
| 20 | 195.73 | u_srcC.r             -> u_sink.dq |
