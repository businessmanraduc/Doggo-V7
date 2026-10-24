# dispatch solo Fmax

ring-of-regs, nextpnr --85k CABGA381, tw=100, 20 seeds
tools: Yosys 0.62, nextpnr-35f1433

| floor | median | mean | ceil |
|---|---|---|---|
| 279.33 | 317.11 | 318.02 | 359.97 |

## census (worst path per seed)

| seed | fmax | start -> end |
|---|---|---|
| 1 | 290.78 | u_dut.rob_dispatchReady -> u_dut.dp_serialBlock |
| 2 | 325.63 | u_dut.rob_dispatchReady -> u_dut.dp_serialBlock |
| 3 | 292.14 | u_dut.dp_serialBlock -> u_dut.dp_serialBlock |
| 4 | 328.19 | u_dut.pds_ds_serialising -> u_dut.dp_serialBlock |
| 5 | 358.04 | u_dut.rob_dispatchReady -> u_dut.dp_skipIq |
| 6 | 316.56 | u_dut.pds_ds_serialising -> u_dut.dp_serialBlock |
| 7 | 324.68 | u_dut.dp_serialBlock -> u_dut.dp_skipIq |
| 8 | 310.56 | u_dut.rob_dispatchReady -> u_dut.dp_serialBlock |
| 9 | 279.33 | u_dut.rob_dispatchReady -> u_dut.dp_serialBlock |
| 10 | 317.66 | u_dut.rob_dispatchReady -> u_dut.dp_serialBlock |
| 11 | 313.97 | u_dut.dp_serialBlock -> u_dut.dp_serialBlock |
| 12 | 327.87 | u_dut.rob_dispatchReady -> u_dut.dp_serialBlock |
| 13 | 306.28 | u_dut.dp_serialBlock -> u_dut.dp_serialBlock |
| 14 | 339.67 | u_dut.dp_serialBlock -> u_dut.dp_serialBlock |
| 15 | 325.63 | u_dut.rob_dispatchReady -> u_dut.dp_serialBlock |
| 16 | 301.02 | u_dut.dp_serialBlock -> u_dut.dp_serialBlock |
| 17 | 320.92 | u_dut.dp_serialBlock -> u_dut.dp_serialBlock |
| 18 | 309.50 | u_dut.dp_serialBlock -> u_dut.dp_serialBlock |
| 19 | 311.92 | u_dut.dp_serialBlock -> u_dut.dp_serialBlock |
| 20 | 359.97 | u_dut.rob_dispatchReady -> u_dut.dp_serialBlock |
