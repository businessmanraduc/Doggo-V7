# alu solo Fmax

ring-of-regs, nextpnr --85k CABGA381, tw=100, 20 seeds

| floor | mean | ceil |
|---|---|---|
| 175.07 | 183.99 | 192.83 |

## census (worst path per seed)

| seed | fmax | start -> end |
|---|---|---|
| 1 | 186.25 | u_srcOp.perturb      -> u_sink.dq |
| 2 | 189.90 | u_srcOp.perturb      -> u_sink.dq |
| 3 | 187.44 | u_srcR.perturb       -> u_sink.dq |
| 4 | 192.83 | u_srcR.perturb       -> u_sink.dq |
| 5 | 183.28 | u_srcR.perturb       -> u_sink.dq |
| 6 | 177.94 | u_srcOp.perturb      -> u_sink.dq |
| 7 | 189.21 | u_srcOp.perturb      -> u_sink.dq |
| 8 | 181.29 | u_srcR.perturb       -> u_sink.dq |
| 9 | 180.96 | u_srcR.perturb       -> u_sink.dq |
| 10 | 181.79 | u_srcR.perturb       -> u_sink.dq |
| 11 | 177.87 | u_srcOp.perturb      -> u_sink.dq |
| 12 | 183.99 | u_srcR.perturb       -> u_sink.dq |
| 13 | 175.07 | u_srcR.perturb       -> u_sink.dq |
| 14 | 186.36 | u_srcR.perturb       -> u_sink.dq |
| 15 | 180.96 | u_srcOp.perturb      -> u_sink.dq |
| 16 | 187.90 | u_srcOp.perturb      -> u_sink.dq |
| 17 | 188.96 | u_srcR.perturb       -> u_sink.dq |
| 18 | 184.54 | u_srcR.perturb       -> u_sink.dq |
| 19 | 177.43 | u_srcOp.perturb      -> u_sink.dq |
| 20 | 185.77 | u_srcOp.perturb      -> u_sink.dq |
