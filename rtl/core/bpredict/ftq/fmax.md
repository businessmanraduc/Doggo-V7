# ftq solo Fmax

ring-of-regs, nextpnr --85k CABGA381, tw=100, 20 seeds

| floor | mean | ceil |
|---|---|---|
| 185.15 | 196.75 | 211.15 |

## census (worst path per seed)

| seed | fmax | start -> end |
|---|---|---|
| 1 | 199.32 | u1.perturb           -> u_dut.unissued |
| 2 | 194.74 | u1.perturb           -> u_dut.unissued |
| 3 | 207.47 | u_dut.push_validB    -> u_dut.unissued |
| 4 | 185.15 | u_dut.push_validB    -> u_dut.unissued |
| 5 | 190.77 | u1.perturb           -> u_dut.unissued |
| 6 | 190.19 | u1.perturb           -> u_dut.unissued |
| 7 | 197.43 | u1.perturb           -> u_dut.unissued |
| 8 | 195.69 | u_dut.push_validB    -> u_dut.unissued |
| 9 | 211.15 | u1.perturb           -> u_dut.unissued |
| 10 | 190.01 | u_dut.push_validB    -> u_dut.unissued |
| 11 | 205.34 | u1.perturb           -> u_dut.unissued |
| 12 | 189.43 | u_dut.push_validB    -> u_dut.unissued |
| 13 | 196.00 | u_dut.push_validB    -> u_dut.unissued |
| 14 | 198.93 | u_dut.push_validB    -> u_dut.unissued |
| 15 | 199.56 | u1.perturb           -> u_dut.unissued |
| 16 | 201.86 | u1.perturb           -> u_dut.unissued |
| 17 | 190.04 | u_dut.push_validB    -> u_dut.unissued |
| 18 | 198.22 | u_dut.push_validB    -> u_dut.unissued |
| 19 | 203.92 | u_dut.push_validB    -> u_dut.unissued |
| 20 | 189.83 | u_dut.push_validB    -> u_dut.unissued |
