# icache solo Fmax

ring-of-regs, nextpnr --85k CABGA381, tw=100, 20 seeds

| floor | mean | ceil |
|---|---|---|
| 181.23 | 193.28 | 203.29 |

## census (worst path per seed)

| seed | fmax | start -> end |
|---|---|---|
| 1 | 195.89 | u_dut.hitVecF4       -> u_sink.dq |
| 2 | 186.74 | u_dut.u_fill.state   -> u_dut.u_fill.state |
| 3 | 191.94 | u_dut.u_fill.state   -> u_dut.u_fill.state |
| 4 | 196.16 | u_dut.hitVecF4       -> u_sink.dq |
| 5 | 181.23 | u_dut.lookupWordIndexF1 -> u_dut.lookupState |
| 6 | 197.24 | u_dut.hitVecF4       -> u_dut.u_fill.fillTag |
| 7 | 203.29 | u_dut.hitVecF4       -> u_dut.plruMem.0.7 |
| 8 | 191.06 | u_dut.lookupWordIndexF1 -> u_dut.lookupState |
| 9 | 191.28 | u_dut.hitVecF4       -> u_sink.dq |
| 10 | 193.31 | u_dut.u_fill.state   -> u_dut.u_fill.state |
| 11 | 197.82 | u_dut.lookupTagF3    -> u_dut.hitVecF4 |
| 12 | 196.89 | u_dut.hitVecF4       -> u_sink.dq |
| 13 | 198.65 | u_dut.lookupWordIndexF1 -> u_dut.lookupState |
| 14 | 199.28 | u_dut.u_fill.sweepCount -> u_dut.u_fill.settleCount |
| 15 | 187.90 | u_dut.hitVecF4       -> u_sink.dq |
| 16 | 193.20 | u_dut.lookupWordIndexF1 -> u_dut.lookupState |
| 17 | 191.72 | u_dut.lookupWordIndexF1 -> u_dut.lookupState |
| 18 | 196.00 | u_dut.lookupWordIndexF1 -> u_dut.lookupState |
| 19 | 191.17 | u_dut.lookupWordIndexF1 -> u_dut.lookupState |
| 20 | 184.74 | u_dut.hitVecF4       -> u_sink.dq |
