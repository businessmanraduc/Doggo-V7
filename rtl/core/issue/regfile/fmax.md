# regfile solo Fmax

ring-of-regs, nextpnr --85k CABGA381, tw=100, 20 seeds

| floor | mean | ceil |
|---|---|---|
| 252.91 | 269.23 | 284.98 |

## census (worst path per seed)

| seed | fmax | start -> end |
|---|---|---|
| 1 | 279.64 | u_srcC.r             -> u_sink.dq |
| 2 | 284.98 | u_srcC.r             -> u_dut.mem.0.15 |
| 3 | 269.98 | u_srcC.r             -> u_sink.dq |
| 4 | 266.03 | u_srcC.r             -> u_sink.dq |
| 5 | 257.20 | u_srcC.r             -> u_sink.dq |
| 6 | 265.96 | u_srcC.r             -> u_sink.dq |
| 7 | 271.74 | u_srcC.r             -> u_sink.dq |
| 8 | 271.37 | u_srcC.r             -> u_sink.dq |
| 9 | 254.71 | u_srcC.r             -> u_sink.dq |
| 10 | 272.85 | u_srcC.r             -> u_sink.dq |
| 11 | 252.91 | u_srcC.r             -> u_sink.dq |
| 12 | 279.41 | u_srcC.r             -> u_sink.dq |
| 13 | 255.95 | u_srcC.r             -> u_sink.dq |
| 14 | 279.96 | u_srcC.r             -> u_sink.dq |
| 15 | 269.32 | u_srcC.r             -> u_sink.dq |
| 16 | 277.16 | u_srcC.r             -> u_sink.dq |
| 17 | 263.92 | u_srcC.r             -> u_sink.dq |
| 18 | 275.79 | u_srcC.r             -> u_sink.dq |
| 19 | 264.06 | u_srcC.r             -> u_sink.dq |
| 20 | 271.67 | u_srcC.r             -> u_sink.dq |
