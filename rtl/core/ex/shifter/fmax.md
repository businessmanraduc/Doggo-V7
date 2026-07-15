# shifter solo Fmax

ring-of-regs, nextpnr --85k CABGA381, tw=100, 20 seeds

| floor | mean | ceil |
|---|---|---|
| 187.48 | 195.69 | 203.87 |

## census (worst path per seed)

| seed | fmax | start -> end |
|---|---|---|
| 1 | 197.51 | u_dut.s1_amount      -> u_sink.dq |
| 2 | 195.81 | u_dut.s1_amount      -> u_sink.dq |
| 3 | 192.68 | u_dut.s1_amount      -> u_sink.dq |
| 4 | 198.26 | u_dut.s1_amount      -> u_sink.dq |
| 5 | 193.76 | u_dut.s1_amount      -> u_sink.dq |
| 6 | 195.47 | u_dut.s1_data        -> u_sink.dq |
| 7 | 188.04 | u_dut.s1_data        -> u_sink.dq |
| 8 | 198.45 | u_dut.s1_op          -> u_sink.dq |
| 9 | 193.31 | u_dut.s1_data        -> u_sink.dq |
| 10 | 190.11 | u_srcOp.r            -> u_dut.s1_data |
| 11 | 199.40 | u_dut.s1_data        -> u_sink.dq |
| 12 | 196.12 | u_dut.s1_amount      -> u_sink.dq |
| 13 | 191.79 | u_dut.s1_amount      -> u_sink.dq |
| 14 | 201.90 | u_dut.s1_data        -> u_sink.dq |
| 15 | 198.49 | u_dut.s1_amount      -> u_sink.dq |
| 16 | 193.05 | u_dut.s1_amount      -> u_sink.dq |
| 17 | 187.48 | u_dut.s1_data        -> u_sink.dq |
| 18 | 199.36 | u_dut.s1_data        -> u_sink.dq |
| 19 | 203.87 | u_dut.s1_amount      -> u_sink.dq |
| 20 | 198.89 | u_dut.s1_amount      -> u_sink.dq |
