# predisp_payload solo Fmax

ring-of-regs, nextpnr --85k CABGA381, tw=100, 20 seeds
tools: Yosys 0.62, nextpnr-35f1433

| floor | median | mean | ceil |
|---|---|---|---|
| 268.89 | 305.49 | 307.27 | 344.00 |

## census (worst path per seed)

| seed | fmax | start -> end |
|---|---|---|
| 1 | 281.45 | u_s5.r               -> u_dut.pds_ds_immediate |
| 2 | 307.98 | u_s5.r               -> u_dut.pds_ds_immediate |
| 3 | 334.67 | u_s5.r               -> u_dut.pds_ds_seq |
| 4 | 343.29 | u_s5.r               -> u_dut.pds_ds_branchTarget |
| 5 | 313.87 | u_s5.r               -> u_dut.pds_ds_immediate |
| 6 | 321.23 | u_s5.r               -> u_dut.pds_ds_immediate |
| 7 | 268.89 | u_s5.r               -> u_dut.pds_ds_serialising |
| 8 | 293.26 | u_s5.r               -> u_dut.pds_ds_serialising |
| 9 | 302.57 | u_s5.r               -> u_dut.pds_ds_seq |
| 10 | 330.36 | u_s5.r               -> u_dut.pds_ds_selXor |
| 11 | 288.35 | u_s5.r               -> u_dut.pds_ds_branchTarget |
| 12 | 299.49 | u_s5.r               -> u_dut.pds_ds_immediate |
| 13 | 304.69 | u_s5.r               -> u_dut.pds_ds_selXor |
| 14 | 296.38 | u_s5.r               -> u_dut.pds_ds_immediate |
| 15 | 314.76 | u_s5.r               -> u_dut.pds_ds_pc |
| 16 | 336.70 | u_s5.r               -> u_dut.pds_ds_branchTarget |
| 17 | 344.00 | u_s5.r               -> u_dut.pds_ds_immediate |
| 18 | 269.91 | u_s5.r               -> u_dut.pds_ds_seq |
| 19 | 287.19 | u_s5.r               -> u_dut.pds_ds_immediate |
| 20 | 306.28 | u_s5.r               -> u_dut.pds_ds_system |
