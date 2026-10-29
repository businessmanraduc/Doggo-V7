# rf solo Fmax

ring-of-regs, nextpnr --85k CABGA381, tw=100, 20 seeds
tools: Yosys 0.62, nextpnr-35f1433

| floor | median | mean | ceil |
|---|---|---|---|
| 179.99 | 200.16 | 200.33 | 213.08 |

## census (worst path per seed)

| seed | fmax | start -> end |
|---|---|---|
| 1 | 201.45 | u_s1.r               -> u_snk.dq |
| 2 | 204.37 | u_s1.r               -> u_snk.dq |
| 3 | 199.32 | u_s1.r               -> u_snk.dq |
| 4 | 192.20 | u_s1.r               -> u_snk.dq |
| 5 | 199.92 | u_s1.r               -> u_snk.dq |
| 6 | 200.96 | u_s1.r               -> u_snk.dq |
| 7 | 208.90 | u_s1.r               -> u_snk.dq |
| 8 | 200.64 | u_s1.r               -> u_snk.dq |
| 9 | 192.38 | u_s1.r               -> u_snk.dq |
| 10 | 199.28 | u_s1.r               -> u_snk.dq |
| 11 | 200.40 | u_s1.r               -> u_snk.dq |
| 12 | 203.29 | u_s1.r               -> u_snk.dq |
| 13 | 205.09 | u_s1.r               -> u_snk.dq |
| 14 | 199.92 | u_s1.r               -> u_snk.dq |
| 15 | 198.37 | u_s1.r               -> u_snk.dq |
| 16 | 213.08 | u_s1.r               -> u_snk.dq |
| 17 | 199.16 | u_s1.r               -> u_snk.dq |
| 18 | 179.99 | u_s1.r               -> u_snk.dq |
| 19 | 211.46 | u_s1.r               -> u_snk.dq |
| 20 | 196.50 | u_s1.r               -> u_snk.dq |
