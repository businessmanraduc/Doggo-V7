# rvc_expand solo Fmax

ring-of-regs, nextpnr --85k CABGA381, tw=100, 20 seeds

| floor | mean | ceil |
|---|---|---|
| 181.82 | 187.93 | 196.66 |

## census (worst path per seed)

| seed | fmax | start -> end |
|---|---|---|
| 1 | 183.92 | u_src.r              -> u_sink.dq |
| 2 | 182.02 | u_src.r              -> u_sink.dq |
| 3 | 191.42 | u_src.r              -> u_sink.dq |
| 4 | 186.25 | u_src.r              -> u_sink.dq |
| 5 | 194.10 | u_src.r              -> u_sink.dq |
| 6 | 185.08 | u_src.r              -> u_sink.dq |
| 7 | 185.80 | u_src.r              -> u_sink.dq |
| 8 | 193.24 | u_src.r              -> u_sink.dq |
| 9 | 194.93 | u_src.r              -> u_sink.dq |
| 10 | 193.39 | u_src.r              -> u_sink.dq |
| 11 | 186.64 | u_src.r              -> u_sink.dq |
| 12 | 184.74 | u_src.r              -> u_sink.dq |
| 13 | 183.45 | u_src.r              -> u_sink.dq |
| 14 | 181.82 | u_src.r              -> u_sink.dq |
| 15 | 189.14 | u_src.r              -> u_sink.dq |
| 16 | 187.51 | u_src.r              -> u_sink.dq |
| 17 | 190.01 | u_src.r              -> u_sink.dq |
| 18 | 183.59 | u_src.r              -> u_sink.dq |
| 19 | 196.66 | u_src.r              -> u_sink.dq |
| 20 | 184.98 | u_src.r              -> u_sink.dq |
