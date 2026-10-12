# predisp solo Fmax

ring-of-regs, nextpnr --85k CABGA381, tw=100, 20 seeds
tools: Yosys 0.62, nextpnr-35f1433

| floor | median | mean | ceil |
|---|---|---|---|
| 147.60 | 158.13 | 158.60 | 169.58 |

## census (worst path per seed)

| seed | fmax | start -> end |
|---|---|---|
| 1 | 165.23 | u_s0.r               -> u_dut.pds_ds_depL1 |
| 2 | 158.96 | u_dut.pds_ds_rdTag   -> u_dut.pds_ds_depL4 |
| 3 | 147.60 | u_s0.r               -> u_dut.pds_ds_depL3 |
| 4 | 157.73 | u_s1.r               -> u_dut.pds_ds_rs1Wait |
| 5 | 161.52 | u_s0.r               -> u_dut.pds_ds_rs2Wait |
| 6 | 156.91 | u_s1.r               -> u_dut.pds_ds_depL4 |
| 7 | 161.63 | u_s0.r               -> u_dut.pds_ds_rs2Wait |
| 8 | 158.53 | u_s0.r               -> u_dut.pds_ds_depL5 |
| 9 | 163.32 | u_s1.r               -> u_dut.pds_ds_rs2Wait |
| 10 | 169.58 | u_s0.r               -> u_dut.pds_ds_depL5 |
| 11 | 159.46 | u_dut.pds_ds_rdTag   -> u_dut.pds_ds_depL3 |
| 12 | 154.27 | u_s1.r               -> u_dut.pds_ds_rs2Wait |
| 13 | 156.74 | u_s1.r               -> u_dut.pds_ds_rs2Wait |
| 14 | 160.69 | u_s1.r               -> u_dut.pds_ds_depL1 |
| 15 | 149.86 | u_s0.r               -> u_dut.pds_ds_rs2Wait |
| 16 | 157.33 | u_dut.pds_ds_rdTag   -> u_dut.pds_ds_depL1 |
| 17 | 163.29 | u_dut.pds_slotProducer -> u_dut.pds_ds_rs1Wait |
| 18 | 156.20 | u_dut.pds_ds_rdTag   -> u_dut.pds_ds_depL1 |
| 19 | 157.46 | u_s0.r               -> u_dut.pds_ds_rs1Wait |
| 20 | 155.74 | u_dut.pds_ds_rdTag   -> u_dut.pds_ds_depL3 |
