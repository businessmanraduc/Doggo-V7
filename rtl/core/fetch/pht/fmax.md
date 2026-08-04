# pht solo Fmax

ring-of-regs, nextpnr --85k CABGA381, tw=100, 20 seeds

| floor | mean | ceil |
|---|---|---|
| 149.10 | 149.53 | 152.53 |

## census (worst path per seed)

| seed | fmax | start -> end |
|---|---|---|
| 1 | 149.37 | u_dut.u_primary.u_ebr.DOB1 -> u_dut.primaryCounter |
| 2 | 149.10 | u_dut.u_alternate.u_ebr.DOB1 -> u_dut.alternateCounter |
| 3 | 149.37 | u_dut.u_primary.u_ebr.DOB1 -> u_dut.primaryCounter |
| 4 | 149.10 | u_dut.u_primary.u_ebr.DOB1 -> u_dut.primaryCounter |
| 5 | 149.37 | u_dut.u_primary.u_ebr.DOB1 -> u_dut.primaryCounter |
| 6 | 149.10 | u_dut.u_primary.u_ebr.DOB1 -> u_dut.primaryCounter |
| 7 | 149.10 | u_dut.u_primary.u_ebr.DOB1 -> u_dut.primaryCounter |
| 8 | 149.37 | u_dut.u_primary.u_ebr.DOB1 -> u_dut.primaryCounter |
| 9 | 149.10 | u_dut.u_primary.u_ebr.DOB1 -> u_dut.primaryCounter |
| 10 | 149.10 | u_dut.u_primary.u_ebr.DOB1 -> u_dut.primaryCounter |
| 11 | 149.10 | u_dut.u_alternate.u_ebr.DOB1 -> u_dut.alternateCounter |
| 12 | 149.10 | u_dut.u_primary.u_ebr.DOB1 -> u_dut.primaryCounter |
| 13 | 149.10 | u_dut.u_alternate.u_ebr.DOB1 -> u_dut.alternateCounter |
| 14 | 149.37 | u_dut.u_primary.u_ebr.DOB1 -> u_dut.primaryCounter |
| 15 | 149.37 | u_dut.u_primary.u_ebr.DOB1 -> u_dut.primaryCounter |
| 16 | 149.21 | u_dut.u_primary.u_ebr.DOB1 -> u_dut.primaryCounter |
| 17 | 149.10 | u_dut.u_primary.u_ebr.DOB1 -> u_dut.primaryCounter |
| 18 | 149.10 | u_dut.u_primary.u_ebr.DOB1 -> u_dut.primaryCounter |
| 19 | 152.53 | u_dut.u_alternate.u_ebr.DOB1 -> u_dut.alternateCounter |
| 20 | 152.53 | u_dut.u_primary.u_ebr.DOB1 -> u_dut.primaryCounter |
