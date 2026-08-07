# icache solo Fmax

ring-of-regs, nextpnr --85k CABGA381, tw=100, 20 seeds

| floor | mean | ceil |
|---|---|---|
| 195.08 | 206.12 | 217.01 |

## census (worst path per seed)

| seed | fmax | start -> end |
|---|---|---|
| 1 | 204.54 | u_dut.hitVecF4       -> u_sink.dq |
| 2 | 212.99 | u_dut.u_fill.state   -> u_dut.u_fill.settleCount |
| 3 | 214.68 | u_dut.u_fill.state   -> u_dut.u_fill.settleCount |
| 4 | 208.29 | u_dut.tagEntryF3     -> u_dut.hitVecF4 |
| 5 | 200.88 | u_dut.hitVecF4       -> u_dut.missValidF5 |
| 6 | 204.08 | u_dut.u_fill.state   -> u_dut.g_dataWay |
| 7 | 207.47 | u_dut.hitVecF4       -> u_sink.dq |
| 8 | 203.96 | u_dut.hitVecF4       -> u_dut.u_plruBlk.u_ebr.WEA |
| 9 | 195.08 | u_dut.hitVecF4       -> u_dut.u_plruBlk.u_ebr.WEA |
| 10 | 200.28 | u_dut.hitVecF4       -> u_dut.u_plruBlk.u_ebr.DIA2 |
| 11 | 202.27 | u_dut.hitVecF4       -> u_sink.dq |
| 12 | 197.08 | u_dut.u_fill.state   -> u_dut.u_fill.state |
| 13 | 216.08 | u_dut.u_fill.state   -> u_dut.g_dataWay |
| 14 | 217.01 | u_dut.hitVecF4       -> u_sink.dq |
| 15 | 205.30 | u_dut.lookupTagF3    -> u_dut.hitVecF4 |
| 16 | 207.60 | u_dut.u_fill.state   -> u_dut.g_dataWay |
| 17 | 214.18 | u_dut.u_fill.state   -> u_dut.u_fill.beatCount |
| 18 | 210.97 | u_dut.hitVecF4       -> u_sink.dq |
| 19 | 199.24 | u_dut.hitVecF4       -> u_sink.dq |
| 20 | 200.36 | u_dut.hitVecF4       -> u_sink.dq |
