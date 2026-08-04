# decoder solo Fmax

ring-of-regs, nextpnr --85k CABGA381, tw=100, 20 seeds

| floor | mean | ceil |
|---|---|---|
| 164.77 | 176.62 | 190.33 |

## census (worst path per seed)

| seed | fmax | start -> end |
|---|---|---|
| 1 | 171.59 | u_srcP.perturb       -> u_sink.dq |
| 2 | 176.87 | u_srcI.r             -> u_sink.dq |
| 3 | 173.43 | u_srcI.r             -> u_sink.dq |
| 4 | 178.48 | u_srcI.r             -> u_sink.dq |
| 5 | 187.20 | u_srcI.r             -> u_sink.dq |
| 6 | 188.32 | u_srcI.r             -> u_sink.dq |
| 7 | 167.25 | u_srcI.r             -> u_sink.dq |
| 8 | 174.70 | u_srcI.r             -> u_sink.dq |
| 9 | 186.39 | u_srcI.r             -> u_sink.dq |
| 10 | 185.91 | u_srcI.r             -> u_sink.dq |
| 11 | 171.26 | u_srcI.r             -> u_sink.dq |
| 12 | 173.37 | u_srcI.r             -> u_sink.dq |
| 13 | 164.77 | u_srcP.perturb       -> u_sink.dq |
| 14 | 169.89 | u_srcI.r             -> u_sink.dq |
| 15 | 169.41 | u_srcI.r             -> u_sink.dq |
| 16 | 166.97 | u_srcI.r             -> u_sink.dq |
| 17 | 176.12 | u_srcI.r             -> u_sink.dq |
| 18 | 170.71 | u_srcI.r             -> u_sink.dq |
| 19 | 189.39 | u_srcI.r             -> u_sink.dq |
| 20 | 190.33 | u_srcI.r             -> u_sink.dq |
