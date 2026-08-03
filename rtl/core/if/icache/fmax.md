# icache solo Fmax

ring-of-regs, nextpnr --85k CABGA381, tw=100, 20 seeds

| floor | mean | ceil |
|---|---|---|
| 160.18 | 171.08 | 176.12 |

## census (worst path per seed)

| seed | fmax | start -> end |
|---|---|---|
| 1 | 174.58 | u_dut.lookupSetF1    -> u_dut.tagEntry |
| 2 | 169.81 | u_dut.u_fill.state   -> u_dut.plruMem.0.0 |
| 3 | 174.40 | u_dut.u_fill.state   -> u_dut.u_fill.fillTag |
| 4 | 168.69 | u_dut.lookupSetF1    -> u_dut.tagEntry |
| 5 | 168.52 | u_dut.u_fill.state   -> u_dut.plruMem.0.4 |
| 6 | 174.22 | u_dut.lookupSetF1    -> u_dut.tagEntry |
| 7 | 172.65 | u_dut.u_fill.state   -> u_dut.u_fill.fillTag |
| 8 | 168.69 | u_dut.u_fill.state   -> u_dut.u_fill.state |
| 9 | 164.04 | u_dut.u_fill.state   -> u_dut.u_fill.fillWay |
| 10 | 173.91 | u_dut.u_fill.state   -> u_dut.u_fill.fillWay |
| 11 | 171.38 | u_dut.lookupSetF1    -> u_dut.tagEntry |
| 12 | 175.25 | u_dut.lookupSetF1    -> u_dut.tagEntry |
| 13 | 170.88 | u_dut.lookupSetF1    -> u_dut.tagEntry |
| 14 | 176.12 | u_dut.lookupSetF1    -> u_dut.tagEntry |
| 15 | 174.46 | u_dut.u_fill.state   -> u_dut.u_fill.fillTag |
| 16 | 173.94 | u_dut.lookupSetF1    -> u_dut.lookupState |
| 17 | 169.75 | u_dut.u_fill.state   -> u_dut.plruMem.0.6 |
| 18 | 167.62 | u_dut.lookupSetF1    -> u_dut.tagEntry |
| 19 | 160.18 | u_dut.lookupSetF1    -> u_dut.tagEntry |
| 20 | 172.59 | u_dut.lookupSetF1    -> u_dut.tagEntry |
