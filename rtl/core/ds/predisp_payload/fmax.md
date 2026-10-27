# predisp_payload solo Fmax

ring-of-regs, nextpnr --85k CABGA381, tw=100, 20 seeds
tools: Yosys 0.62, nextpnr-35f1433

| floor | median | mean | ceil |
|---|---|---|---|
| 257.93 | 304.83 | 304.11 | 346.86 |

## census (worst path per seed)

| seed | fmax | start -> end |
|---|---|---|
| 1 | 275.56 | u_s5.r               -> u_dut.pds_ds_selXor |
| 2 | 273.30 | u_s5.r               -> u_dut.pds_ds_immediate |
| 3 | 293.43 | u_s5.r               -> u_dut.pds_ds_branchTarget |
| 4 | 287.94 | u_s5.r               -> u_dut.pds_ds_system |
| 5 | 318.88 | u_s5.r               -> u_dut.pds_ds_immediate |
| 6 | 303.58 | u_s5.r               -> u_dut.pds_ds_selXor |
| 7 | 335.68 | u_s5.r               -> u_dut.pds_ds_class |
| 8 | 315.46 | u_s5.r               -> u_dut.pds_ds_seq |
| 9 | 278.16 | u_s5.r               -> u_dut.pds_ds_system |
| 10 | 293.77 | u_s5.r               -> u_dut.pds_ds_immediate |
| 11 | 346.86 | u_s5.r               -> u_dut.pds_ds_immediate |
| 12 | 332.12 | u_s5.r               -> u_dut.pds_ds_branchTarget |
| 13 | 314.47 | u_s5.r               -> u_dut.pds_ds_pc |
| 14 | 342.94 | u_s5.r               -> u_dut.pds_ds_pc |
| 15 | 306.09 | u_s5.r               -> u_dut.pds_ds_pc |
| 16 | 332.89 | u_s5.r               -> u_dut.pds_ds_immediate |
| 17 | 306.18 | u_s5.r               -> u_dut.pds_ds_system |
| 18 | 257.93 | u_s5.r               -> u_dut.pds_ds_rvc |
| 19 | 272.63 | u_s5.r               -> u_dut.pds_ds_immediate |
| 20 | 294.29 | u_s5.r               -> u_dut.pds_ds_shiftArith |
