# decoder solo Fmax

ring-of-regs, nextpnr --85k CABGA381, tw=100, 20 seeds

| floor | mean | ceil |
|---|---|---|
| 166.72 | 182.16 | 197.28 |

## census (worst path per seed)

| seed | fmax | start -> end |
|---|---|---|
| 1 | 175.99 | u_srcI.r             -> u_sink.dq |
| 2 | 176.18 | u_srcI.r             -> u_sink.dq |
| 3 | 166.72 | u_srcI.r             -> u_sink.dq |
| 4 | 184.74 | u_srcI.r             -> u_sink.dq |
| 5 | 185.80 | u_srcI.r             -> u_sink.dq |
| 6 | 195.39 | u_srcI.r             -> u_sink.dq |
| 7 | 167.25 | u_srcI.r             -> u_sink.dq |
| 8 | 176.87 | u_srcI.r             -> u_sink.dq |
| 9 | 190.44 | u_srcI.r             -> u_sink.dq |
| 10 | 189.65 | u_srcI.r             -> u_sink.dq |
| 11 | 185.22 | u_srcI.r             -> u_sink.dq |
| 12 | 179.50 | u_srcI.r             -> u_sink.dq |
| 13 | 174.13 | u_srcI.r             -> u_sink.dq |
| 14 | 192.98 | u_srcP.perturb       -> u_sink.dq |
| 15 | 186.12 | u_srcI.r             -> u_sink.dq |
| 16 | 180.12 | u_srcI.r             -> u_sink.dq |
| 17 | 182.88 | u_srcI.r             -> u_sink.dq |
| 18 | 175.65 | u_srcP.perturb       -> u_sink.dq |
| 19 | 180.21 | u_srcP.perturb       -> u_sink.dq |
| 20 | 197.28 | u_srcP.perturb       -> u_sink.dq |
