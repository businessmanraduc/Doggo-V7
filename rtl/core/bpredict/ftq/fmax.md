# ftq solo Fmax

ring-of-regs, nextpnr --85k CABGA381, tw=100, 20 seeds

| floor | mean | ceil |
|---|---|---|
| 180.67 | 195.45 | 210.84 |

## census (worst path per seed)

| seed | fmax | start -> end |
|---|---|---|
| 1 | 196.81 | u1.perturb           -> u_dut.unissued |
| 2 | 209.34 | u_dut.push_validB    -> u_dut.unissued |
| 3 | 187.65 | u1.perturb           -> u_dut.unissued |
| 4 | 191.50 | u1.perturb           -> u_dut.unissued |
| 5 | 187.37 | u_dut.push_validB    -> u_dut.unissued |
| 6 | 208.03 | u_dut.push_validB    -> u_dut.unissued |
| 7 | 180.67 | u_dut.push_validB    -> u_dut.unissued |
| 8 | 195.54 | u1.perturb           -> u_dut.unissued |
| 9 | 196.16 | u_dut.push_validB    -> u_dut.unissued |
| 10 | 182.72 | u_dut.push_validB    -> u_dut.unissued |
| 11 | 207.77 | u1.perturb           -> u_dut.unissued |
| 12 | 206.61 | u_dut.push_validB    -> u_dut.unissued |
| 13 | 199.52 | u1.perturb           -> u_dut.unissued |
| 14 | 188.82 | u_dut.push_validB    -> u_dut.unissued |
| 15 | 195.24 | u1.perturb           -> u_dut.unissued |
| 16 | 210.84 | u1.perturb           -> u_dut.unissued |
| 17 | 190.40 | u1.perturb           -> u_dut.unissued |
| 18 | 193.61 | u1.perturb           -> u_dut.unissued |
| 19 | 195.54 | u1.perturb           -> u_dut.unissued |
| 20 | 184.88 | u_dut.push_validB    -> u_dut.unissued |
