# regfile solo Fmax

ring-of-regs, nextpnr --85k CABGA381, tw=100, 20 seeds

| floor | mean | ceil |
|---|---|---|
| 253.94 | 276.98 | 287.44 |

## census (worst path per seed)

| seed | fmax | start -> end |
|---|---|---|
| 1 | 279.96 | u_srcC.r             -> u_sink.dq |
| 2 | 286.86 | u_srcC.r             -> u_dut.mem.0.15 |
| 3 | 276.70 | u_srcC.r             -> u_sink.dq |
| 4 | 267.38 | u_srcC.r             -> u_sink.dq |
| 5 | 264.69 | u_srcC.r             -> u_sink.dq |
| 6 | 277.93 | u_srcC.r             -> u_sink.dq |
| 7 | 279.56 | u_srcC.r             -> u_sink.dq |
| 8 | 274.42 | u_srcC.r             -> u_sink.dq |
| 9 | 253.94 | u_srcC.r             -> u_sink.dq |
| 10 | 284.98 | u_srcC.r             -> u_sink.dq |
| 11 | 282.09 | u_srcC.r             -> u_sink.dq |
| 12 | 279.96 | u_srcC.r             -> u_sink.dq |
| 13 | 276.78 | u_srcC.r             -> u_sink.dq |
| 14 | 279.96 | u_srcC.r             -> u_sink.dq |
| 15 | 270.78 | u_srcC.r             -> u_sink.dq |
| 16 | 277.16 | u_srcC.r             -> u_sink.dq |
| 17 | 282.65 | u_srcC.r             -> u_sink.dq |
| 18 | 283.93 | u_srcC.r             -> u_sink.dq |
| 19 | 272.41 | u_srcC.r             -> u_sink.dq |
| 20 | 287.44 | u_srcC.r             -> u_sink.dq |
