# btb solo Fmax

ring-of-regs, nextpnr --85k CABGA381, tw=100, 20 seeds

| floor | mean | ceil |
|---|---|---|
| 187.83 | 201.45 | 213.54 |

## census (worst path per seed)

| seed | fmax | start -> end |
|---|---|---|
| 1 | 200.64 | u_dut.g_odd          -> u_sink.dq |
| 2 | 199.64 | u_dut.g_even         -> u_sink.dq |
| 3 | 207.56 | u_dut.g_odd          -> u_sink.dq |
| 4 | 201.82 | u_dut.g_odd          -> u_sink.dq |
| 5 | 195.66 | u_dut.g_odd          -> u_sink.dq |
| 6 | 193.76 | u_dut.g_even         -> u_sink.dq |
| 7 | 208.12 | u_dut.g_even         -> u_sink.dq |
| 8 | 195.12 | u_dut.g_odd          -> u_sink.dq |
| 9 | 193.65 | u_dut.g_even         -> u_sink.dq |
| 10 | 213.54 | u_dut.g_even         -> u_sink.dq |
| 11 | 203.92 | u_dut.g_even         -> u_sink.dq |
| 12 | 209.95 | u_dut.g_odd          -> u_sink.dq |
| 13 | 207.13 | u_dut.g_odd          -> u_sink.dq |
| 14 | 205.34 | u_dut.g_even         -> u_sink.dq |
| 15 | 200.36 | u_dut.g_odd          -> u_sink.dq |
| 16 | 198.85 | u_dut.g_odd          -> u_sink.dq |
| 17 | 200.60 | u_dut.g_odd          -> u_sink.dq |
| 18 | 209.60 | u_dut.g_even         -> u_sink.dq |
| 19 | 187.83 | u_dut.g_odd          -> u_sink.dq |
| 20 | 195.96 | u_dut.g_odd          -> u_sink.dq |
