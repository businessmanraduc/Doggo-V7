# predisp solo Fmax

ring-of-regs, nextpnr --85k CABGA381, tw=100, 20 seeds
tools: Yosys 0.62, nextpnr-35f1433

| floor | median | mean | ceil |
|---|---|---|---|
| 145.41 | 156.91 | 155.76 | 163.03 |

## census (worst path per seed)

| seed | fmax | start -> end |
|---|---|---|
| 1 | 159.57 | u_s0.r               -> u_dut.pds_ds_rs2Wait |
| 2 | 163.03 | u_s0.r               -> u_dut.pds_ds_depL1 |
| 3 | 146.39 | u_s0.r               -> u_dut.pds_ds_depL4 |
| 4 | 157.63 | u_s0.r               -> u_dut.pds_ds_depL3 |
| 5 | 158.55 | u_s0.r               -> u_dut.pds_ds_depL5 |
| 6 | 159.21 | u_s1.r               -> u_dut.pds_ds_rs1Wait |
| 7 | 154.92 | u_dut.pds_slotTag    -> u_dut.pds_ds_rs1Wait |
| 8 | 153.75 | u_s0.r               -> u_dut.pds_ds_rs1Wait |
| 9 | 148.70 | u_s0.r               -> u_dut.pds_ds_rs1Wait |
| 10 | 145.41 | u_dut.pds_dsProducer -> u_dut.pds_ds_depL1 |
| 11 | 155.09 | u_dut.pds_ds_rdTag   -> u_dut.pds_ds_depL4 |
| 12 | 161.79 | u_s0.r               -> u_dut.pds_ds_depL4 |
| 13 | 156.03 | u_s0.r               -> u_dut.pds_ds_depL5 |
| 14 | 160.64 | u_s0.r               -> u_dut.pds_ds_depL4 |
| 15 | 148.72 | u_s0.r               -> u_dut.pds_ds_depL3 |
| 16 | 159.21 | u_dut.pds_ds_rdTag   -> u_dut.pds_ds_depL1 |
| 17 | 156.18 | u_s0.r               -> u_dut.pds_ds_depL1 |
| 18 | 150.35 | u_s0.r               -> u_dut.pds_ds_rs1Wait |
| 19 | 160.44 | u_dut.pds_slotProducer -> u_dut.pds_ds_rs1Wait |
| 20 | 159.64 | u_dut.pds_slotTag    -> u_dut.pds_ds_rs1Wait |
