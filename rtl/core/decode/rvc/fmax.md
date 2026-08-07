# rvc_expand solo Fmax

ring-of-regs, nextpnr --85k CABGA381, tw=100, 20 seeds

| floor | mean | ceil |
|---|---|---|
| 188.86 | 194.15 | 199.68 |

## census (worst path per seed)

| seed | fmax | start -> end |
|---|---|---|
| 1 | 193.09 | u_src.r              -> u_sink.dq |
| 2 | 199.68 | u_src.r              -> u_sink.dq |
| 3 | 198.85 | u_src.r              -> u_sink.dq |
| 4 | 195.27 | u_src.r              -> u_sink.dq |
| 5 | 189.57 | u_src.r              -> u_sink.dq |
| 6 | 197.20 | u_src.r              -> u_sink.dq |
| 7 | 194.67 | u_src.r              -> u_sink.dq |
| 8 | 190.26 | u_src.r              -> u_sink.dq |
| 9 | 192.23 | u_src.r              -> u_sink.dq |
| 10 | 193.16 | u_src.r              -> u_sink.dq |
| 11 | 192.72 | u_src.r              -> u_sink.dq |
| 12 | 199.20 | u_src.r              -> u_sink.dq |
| 13 | 191.64 | u_src.r              -> u_sink.dq |
| 14 | 190.37 | u_src.r              -> u_sink.dq |
| 15 | 198.33 | u_src.r              -> u_sink.dq |
| 16 | 195.58 | u_src.r              -> u_sink.dq |
| 17 | 190.11 | u_src.r              -> u_sink.dq |
| 18 | 196.16 | u_src.r              -> u_sink.dq |
| 19 | 188.86 | u_src.r              -> u_sink.dq |
| 20 | 196.04 | u_src.r              -> u_sink.dq |
