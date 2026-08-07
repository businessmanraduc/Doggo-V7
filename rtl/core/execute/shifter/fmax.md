# shifter solo Fmax

ring-of-regs, nextpnr --85k CABGA381, tw=100, 20 seeds

| floor | mean | ceil |
|---|---|---|
| 185.67 | 204.72 | 213.77 |

## census (worst path per seed)

| seed | fmax | start -> end |
|---|---|---|
| 1 | 209.64 | u_dut.s1_data        -> u_sink.dq |
| 2 | 189.50 | u_dut.s1_amount      -> u_sink.dq |
| 3 | 206.61 | u_dut.s1_data        -> u_sink.dq |
| 4 | 204.08 | u_dut.s1_data        -> u_sink.dq |
| 5 | 185.67 | u_dut.s1_amount      -> u_sink.dq |
| 6 | 213.77 | u_dut.s1_data        -> u_sink.dq |
| 7 | 205.93 | u_dut.s1_data        -> u_sink.dq |
| 8 | 208.51 | u_dut.s1_data        -> u_sink.dq |
| 9 | 208.64 | u_dut.s1_data        -> u_sink.dq |
| 10 | 204.71 | u_dut.s1_data        -> u_sink.dq |
| 11 | 205.68 | u_dut.s1_data        -> u_sink.dq |
| 12 | 211.95 | u_dut.s1_amount      -> u_sink.dq |
| 13 | 207.13 | u_dut.s1_data        -> u_sink.dq |
| 14 | 202.59 | u_dut.s1_data        -> u_sink.dq |
| 15 | 206.23 | u_dut.s1_data        -> u_sink.dq |
| 16 | 206.36 | u_dut.s1_data        -> u_sink.dq |
| 17 | 196.58 | u_dut.s1_amount      -> u_sink.dq |
| 18 | 207.17 | u_dut.s1_data        -> u_sink.dq |
| 19 | 207.99 | u_dut.s1_data        -> u_sink.dq |
| 20 | 205.59 | u_dut.s1_data        -> u_sink.dq |
