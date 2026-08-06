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
| dispatch_fifo | 20 | 100 | 188.93 | 216.27 | 261.10 | 19/20 count -> count | 2026-08-04 |
| legal32 | 20 | 100 | 165.76 | 186.22 | 194.06 | 20/20 instr -> illegal | 2026-07-17 |
| decoder | 20 | 100 | 164.77 | 176.62 | 190.33 | 15/20 instr -> uop, 5/20 pc -> uop | 2026-07-18 |
| regfile | 20 | 100 | 252.91 | 269.23 | 284.98 | 19/20 index -> read data | 2026-07-19 |
| rat | 20 | 100 | 159.46 | 170.88 | 184.54 | 20/20 commit-clear -> pending | 2026-07-19 |
| btb | 20 | 100 | 143.04 | 144.54 | 145.50 | 18/20 BSRAM read -> entryQ | 2026-08-04 |
| pht | 20 | 100 | 149.10 | 149.53 | 152.53 | 16/20 BSRAM read -> counter | 2026-08-04 |
| icache | 20 | 100 | 181.23 | 193.28 | 203.29 | 7/20 PLRU LUTRAM read, 3/20 fill state -> state | 2026-08-06 |
| bpredict | 20 | 100 | 135.63 | 142.51 | 145.50 | 19/20 BTB BSRAM read -> entryQ | 2026-08-04 |
| linefill | 20 | 100 | 191.09 | 213.29 | 232.40 | 14/20 state -> state, 3/20 state -> tagWrTag | 2026-08-06 |
| fetch_queue | 20 | 100 | 172.86 | 187.08 | 203.33 | 14/20 count -> count, 3/20 flushShadow -> count | 2026-08-06 |
| align | 20 | 100 | 156.32 | 189.79 | 208.20 | 10/20 half -> out, 8/20 queue -> out | 2026-08-04 |
| fetch_ctrl | 20 | 100 | 224.01 | 254.46 | 287.94 | 11/20 -> validF1, 8/20 hwF4 -> rState/missPC | 2026-08-06 |

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
