# icache solo Fmax

ring-of-regs, nextpnr --85k CABGA381, tw=100, 20 seeds

| floor | mean | ceil |
|---|---|---|
| 187.79 | 197.50 | 207.94 |

## census (worst path per seed)

| seed | fmax | start -> end |
|---|---|---|
| 1 | 201.98 | u_dut.hitVecF4       -> u_sink.dq |
| 2 | 192.01 | u_dut.u_fill.state   -> u_dut.u_fill.state |
| 3 | 193.42 | u_dut.lookupWordIndexF1 -> u_dut.lookupState |
| 4 | 203.29 | u_dut.hitVecF4       -> u_sink.dq |
| 5 | 187.79 | u_dut.lookupWordIndexF1 -> u_dut.lookupState |
| 6 | 197.28 | u_dut.hitVecF4       -> u_dut.u_fill.fillTag |
| 7 | 207.94 | u_dut.lookupTagF3    -> u_dut.hitVecF4 |
| 8 | 197.24 | u_dut.lookupTagF3    -> u_dut.hitVecF4 |
| 9 | 198.02 | u_dut.hitVecF4       -> u_dut.u_fill.fillTag |
| 10 | 194.44 | u_dut.u_fill.state   -> u_dut.u_fill.state |
| 11 | 203.67 | u_dut.hitVecF4       -> u_dut.u_fill.state |
| 12 | 194.29 | u_dut.hitVecF4       -> u_dut.plruMem.0.6 |
| 13 | 198.65 | u_dut.lookupWordIndexF1 -> u_dut.lookupState |
| 14 | 204.12 | u_dut.hitVecF4       -> u_sink.dq |
| 15 | 191.50 | u_dut.hitVecF4       -> u_sink.dq |
| 16 | 198.14 | u_dut.lookupWordIndexF1 -> u_dut.lookupState |
| 17 | 193.99 | u_dut.lookupTagF3    -> u_dut.hitVecF4 |
| 18 | 202.59 | u_dut.u_fill.state   -> u_dut.u_fill.state |
| 19 | 191.90 | u_dut.lookupWordIndexF1 -> u_dut.lookupState |
| 20 | 197.71 | u_dut.hitVecF4       -> u_sink.dq |
