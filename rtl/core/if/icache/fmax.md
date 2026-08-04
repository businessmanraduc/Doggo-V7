# icache solo Fmax

ring-of-regs, nextpnr --85k CABGA381, tw=100, 20 seeds

| floor | mean | ceil |
|---|---|---|
| 161.94 | 170.06 | 177.59 |

## census (worst path per seed)

| seed | fmax | start -> end |
|---|---|---|
| 1 | 175.56 | u_dut.lookupSetF1    -> u_dut.tagEntry |
| 2 | 161.94 | u_dut.lookupTagF2    -> u_dut.hitVecF3 |
| 3 | 168.61 | u_dut.lookupTagF2    -> u_dut.hitVecF3 |
| 4 | 172.74 | u_dut.lookupSetF1    -> u_dut.tagEntry |
| 5 | 163.61 | u_dut.lookupSetF1    -> u_dut.tagEntry |
| 6 | 167.11 | u_dut.lookupSetF1    -> u_dut.tagEntry |
| 7 | 168.12 | u_dut.lookupSetF1    -> u_dut.tagEntry |
| 8 | 169.12 | u_dut.lookupSetF1    -> u_dut.tagEntry |
| 9 | 166.03 | u_dut.lookupSetF1    -> u_dut.tagEntry |
| 10 | 168.44 | u_dut.lookupSetF1    -> u_dut.tagEntry |
| 11 | 177.59 | u_dut.lookupSetF1    -> u_dut.tagEntry |
| 12 | 166.53 | u_dut.lookupSetF1    -> u_dut.tagEntry |
| 13 | 169.09 | u_dut.lookupSetF1    -> u_dut.tagEntry |
| 14 | 169.12 | u_dut.lookupSetF1    -> u_dut.tagEntry |
| 15 | 175.32 | u_dut.lookupSetF1    -> u_dut.tagEntry |
| 16 | 167.53 | u_dut.hitVecF3       -> u_sink.dq |
| 17 | 169.84 | u_dut.lookupSetF1    -> u_dut.tagEntry |
| 18 | 176.71 | u_dut.lookupSetF1    -> u_dut.lookupState |
| 19 | 170.94 | u_dut.lookupSetF1    -> u_dut.tagEntry |
| 20 | 177.15 | u_dut.lookupSetF1    -> u_dut.tagEntry |
