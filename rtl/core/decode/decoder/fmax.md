# decoder solo Fmax

ring-of-regs, nextpnr --85k CABGA381, tw=100, 20 seeds

| floor | mean | ceil |
|---|---|---|
| 172.95 | 185.91 | 199.24 |

## census (worst path per seed)

| seed | fmax | start -> end |
|---|---|---|
| 1 | 183.39 | u_srcI.r             -> u_sink.dq |
| 2 | 191.72 | u_srcI.r             -> u_sink.dq |
| 3 | 172.95 | u_srcI.r             -> u_sink.dq |
| 4 | 179.95 | u_srcI.r             -> u_sink.dq |
| 5 | 190.22 | u_srcI.r             -> u_sink.dq |
| 6 | 195.16 | u_srcI.r             -> u_sink.dq |
| 7 | 191.39 | u_srcI.r             -> u_sink.dq |
| 8 | 177.68 | u_srcI.r             -> u_sink.dq |
| 9 | 177.43 | u_srcI.r             -> u_sink.dq |
| 10 | 190.44 | u_srcI.r             -> u_sink.dq |
| 11 | 179.31 | u_srcI.r             -> u_sink.dq |
| 12 | 187.48 | u_srcI.r             -> u_sink.dq |
| 13 | 189.93 | u_srcI.r             -> u_sink.dq |
| 14 | 188.64 | u_srcI.r             -> u_sink.dq |
| 15 | 190.01 | u_srcP.perturb       -> u_sink.dq |
| 16 | 189.72 | u_srcI.r             -> u_sink.dq |
| 17 | 177.46 | u_srcP.perturb       -> u_sink.dq |
| 18 | 181.49 | u_srcI.r             -> u_sink.dq |
| 19 | 199.24 | u_srcI.r             -> u_sink.dq |
| 20 | 184.60 | u_srcI.r             -> u_sink.dq |
