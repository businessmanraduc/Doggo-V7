# shifter solo Fmax

ring-of-regs, nextpnr --85k CABGA381, tw=100, 20 seeds

| floor | mean | ceil |
|---|---|---|
| 187.48 | 200.88 | 209.07 |

## census (worst path per seed)

| seed | fmax | start -> end |
|---|---|---|
| 1 | 197.01 | u_dut.s1_data        -> u_sink.dq |
| 2 | 203.96 | u_dut.s1_amount      -> u_sink.dq |
| 3 | 197.39 | u_dut.s1_amount      -> u_sink.dq |
| 4 | 209.07 | u_dut.s1_amount      -> u_sink.dq |
| 5 | 193.76 | u_dut.s1_amount      -> u_sink.dq |
| 6 | 197.90 | u_srcOp.r            -> u_dut.s1_data |
| 7 | 205.51 | u_dut.s1_op          -> u_sink.dq |
| 8 | 201.61 | u_dut.s1_data        -> u_sink.dq |
| 9 | 199.84 | u_dut.s1_data        -> u_sink.dq |
| 10 | 195.89 | u_dut.s1_amount      -> u_sink.dq |
| 11 | 202.43 | u_dut.s1_data        -> u_sink.dq |
| 12 | 197.43 | u_dut.s1_amount      -> u_sink.dq |
| 13 | 207.60 | u_dut.s1_data        -> u_sink.dq |
| 14 | 206.53 | u_dut.s1_data        -> u_sink.dq |
| 15 | 198.37 | u_dut.s1_data        -> u_sink.dq |
| 16 | 199.40 | u_dut.s1_amount      -> u_sink.dq |
| 17 | 187.48 | u_dut.s1_data        -> u_sink.dq |
| 18 | 201.73 | u_dut.s1_data        -> u_sink.dq |
| 19 | 206.36 | u_dut.s1_data        -> u_sink.dq |
| 20 | 208.42 | u_dut.s1_data        -> u_sink.dq |
