# Fmax Ledger (Doggo-V7)

The running record of every module's **standalone** Fmax (ring-of-registers
wrapper, nextpnr --85k --package CABGA381, tw=100 unless noted). Numbers are
floor / mean / ceiling across the seed sweep.

## Per-module standalone Fmax

| module | seeds | tw | floor | mean | ceil | worst-path census | date |
|---|---|---|---|---|---|---|---|
| alu | 20 | 100 | 175.07 | 183.17 | 192.83 | 20/20 operand -> result | 2026-07-15 |
| shifter | 20 | 100 | 187.48 | 195.69 | 203.87 | 19/20 fine stage, 1/20 coarse | 2026-07-15 |
| rob | 20 | 100 | 160.15 | 183.73 | 199.56 | 7/20 head -> count, 7/20 done -> full | 2026-07-16 |
| rvc_expand | 20 | 100 | 181.82 | 187.93 | 196.66 | 20/20 instr16 -> instr32 | 2026-07-16 |
| dispatch_fifo | 20 | 100 | 196.23 | 215.92 | 232.40 | 20/20 count -> count | 2026-07-16 |
| decoder | 20 | 100 | 164.77 | 176.62 | 190.33 | 15/20 instr -> uop, 5/20 pc -> uop | 2026-07-18 |
## Placer timing-weight calibration

| module | seeds | tw | floor | mean | ceil | spread |
|---|---|---|---|---|---|---|
| alu | 20 | 90 | 172.06 | 183.41 | 193.46 | 21.40 |
| alu | 20 | 100 | 175.07 | 183.17 | 192.83 | 17.76 |
| shifter | 20 | 90 | 176.18 | 194.56 | 205.55 | 29.37 |
| shifter | 20 | 100 | 187.48 | 195.69 | 203.87 | 16.39 |

## Full-SoC integration Fmax

| revision | seeds | tw | floor | mean | ceil | notes | date |
|---|---|---|---|---|---|---|---|
| _(none yet)_ | | | | | | | |
