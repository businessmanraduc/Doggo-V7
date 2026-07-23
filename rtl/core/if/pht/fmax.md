# pht solo Fmax

ring-of-regs, nextpnr --85k CABGA381, tw=100, 20 seeds

| floor | mean | ceil |
|---|---|---|
| 149.10 | 150.04 | 152.84 |

## census (worst path per seed)

| seed | fmax | start -> end |
|---|---|---|
| 1 | 149.37 | u_dut.u_primary.u_ebr.DOB1 -> u_dut.primaryCounter |
| 2 | 152.84 | u_dut.u_primary.u_ebr.DOB1 -> u_dut.primaryCounter |
| 3 | 152.84 | u_dut.u_primary.u_ebr.DOB1 -> u_dut.primaryCounter |
| 4 | 149.10 | u_dut.u_alternate.u_ebr.DOB1 -> u_dut.alternateCounter |
| 5 | 149.37 | u_dut.u_primary.u_ebr.DOB1 -> u_dut.primaryCounter |
| 6 | 149.37 | u_dut.u_alternate.u_ebr.DOB1 -> u_dut.alternateCounter |
| 7 | 149.10 | u_dut.u_primary.u_ebr.DOB1 -> u_dut.primaryCounter |
| 8 | 149.37 | u_dut.u_primary.u_ebr.DOB1 -> u_dut.primaryCounter |
| 9 | 149.10 | u_dut.u_primary.u_ebr.DOB1 -> u_dut.primaryCounter |
| 10 | 149.10 | u_dut.u_primary.u_ebr.DOB1 -> u_dut.primaryCounter |
| 11 | 149.10 | u_dut.u_primary.u_ebr.DOB1 -> u_dut.primaryCounter |
| 12 | 152.53 | u_dut.u_alternate.u_ebr.DOB1 -> u_dut.alternateCounter |
| 13 | 149.10 | u_dut.u_primary.u_ebr.DOB1 -> u_dut.primaryCounter |
| 14 | 149.10 | u_dut.u_alternate.u_ebr.DOB1 -> u_dut.alternateCounter |
| 15 | 149.10 | u_dut.u_primary.u_ebr.DOB1 -> u_dut.primaryCounter |
| 16 | 152.53 | u_dut.u_primary.u_ebr.DOB1 -> u_dut.primaryCounter |
| 17 | 152.53 | u_dut.u_primary.u_ebr.DOB1 -> u_dut.primaryCounter |
| 18 | 149.10 | u_dut.u_primary.u_ebr.DOB1 -> u_dut.primaryCounter |
| 19 | 149.10 | u_dut.u_primary.u_ebr.DOB1 -> u_dut.primaryCounter |
| 20 | 149.10 | u_dut.u_primary.u_ebr.DOB1 -> u_dut.primaryCounter |
