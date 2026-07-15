# alu solo Fmax

ring-of-regs, nextpnr --85k CABGA381, tw=100, 20 seeds

| floor | mean | ceil |
|---|---|---|
| 175.07 | 183.17 | 192.83 |

## census (worst path per seed)

| seed | fmax | start -> end |
|---|---|---|
| 1 | 185.80 | u_srcL.r             -> u_sink.dq |
| 2 | 181.79 | u_srcOp.perturb      -> u_sink.dq |
| 3 | 187.44 | u_srcR.perturb       -> u_sink.dq |
| 4 | 192.83 | u_srcR.perturb       -> u_sink.dq |
| 5 | 183.28 | u_srcR.perturb       -> u_sink.dq |
| 6 | 177.94 | u_srcOp.perturb      -> u_sink.dq |
| 7 | 188.50 | u_srcOp.perturb      -> u_sink.dq |
| 8 | 177.65 | u_srcR.perturb       -> u_sink.dq |
| 9 | 179.99 | u_srcR.perturb       -> u_sink.dq |
| 10 | 181.79 | u_srcR.perturb       -> u_sink.dq |
| 11 | 177.90 | u_srcOp.perturb      -> u_sink.dq |
| 12 | 182.75 | u_srcR.perturb       -> u_sink.dq |
| 13 | 175.07 | u_srcR.perturb       -> u_sink.dq |
| 14 | 185.63 | u_srcR.perturb       -> u_sink.dq |
| 15 | 180.70 | u_srcOp.perturb      -> u_sink.dq |
| 16 | 187.90 | u_srcOp.perturb      -> u_sink.dq |
| 17 | 187.41 | u_srcR.r             -> u_sink.dq |
| 18 | 184.54 | u_srcR.perturb       -> u_sink.dq |
| 19 | 177.43 | u_srcOp.perturb      -> u_sink.dq |
| 20 | 187.02 | u_srcR.perturb       -> u_sink.dq |
