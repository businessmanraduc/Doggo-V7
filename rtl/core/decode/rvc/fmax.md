# rvc_expand solo Fmax

ring-of-regs, nextpnr --85k CABGA381, tw=100, 20 seeds

| floor | mean | ceil |
|---|---|---|
| 176.09 | 192.45 | 204.16 |

## census (worst path per seed)

| seed | fmax | start -> end |
|---|---|---|
| 1 | 186.32 | u_src.r              -> u_sink.dq |
| 2 | 176.09 | u_src.r              -> u_sink.dq |
| 3 | 193.35 | u_src.r              -> u_sink.dq |
| 4 | 196.58 | u_src.r              -> u_sink.dq |
| 5 | 198.37 | u_src.r              -> u_sink.dq |
| 6 | 185.08 | u_src.r              -> u_sink.dq |
| 7 | 200.64 | u_src.r              -> u_sink.dq |
| 8 | 195.27 | u_src.r              -> u_sink.dq |
| 9 | 204.16 | u_src.r              -> u_sink.dq |
| 10 | 194.14 | u_src.r              -> u_sink.dq |
| 11 | 194.82 | u_src.r              -> u_sink.dq |
| 12 | 191.35 | u_src.r              -> u_sink.dq |
| 13 | 183.55 | u_src.r              -> u_sink.dq |
| 14 | 190.01 | u_src.r              -> u_sink.dq |
| 15 | 189.14 | u_src.r              -> u_sink.dq |
| 16 | 191.57 | u_src.r              -> u_sink.dq |
| 17 | 192.98 | u_src.r              -> u_sink.dq |
| 18 | 192.12 | u_src.r              -> u_sink.dq |
| 19 | 199.48 | u_src.r              -> u_sink.dq |
| 20 | 194.06 | u_src.r              -> u_sink.dq |
