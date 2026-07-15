# Fmax Ledger (Doggo-V7)

The running record of every module's **standalone** Fmax (ring-of-registers
wrapper, nextpnr --85k --package CABGA381, tw=100 unless noted). Numbers are
floor / mean / ceiling across the seed sweep.

## Per-module standalone Fmax

| module | seeds | tw | floor | mean | ceil | worst-path census | date |
|---|---|---|---|---|---|---|---|
| alu | 20 | 100 | 175.07 | 183.17 | 192.83 | 20/20 operand -> result | 2026-07-15 |
| shifter | 20 | 100 | 187.48 | 195.69 | 203.87 | 19/20 fine stage, 1/20 coarse | 2026-07-15 |

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
