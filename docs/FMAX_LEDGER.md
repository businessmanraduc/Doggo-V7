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
| bpredict | 20 | 100 | 135.63 | 142.51 | 145.50 | 19/20 BTB BSRAM read -> entryQ | 2026-08-04 |
| icache | 20 | 100 | 161.94 | 170.06 | 177.59 | 16/20 tag LUTRAM read, 2/20 tag compare | 2026-08-04 |
| linefill | 20 | 100 | 200.08 | 214.66 | 225.63 | 19/20 state -> state, 1/20 sweepCount -> state | 2026-08-03 |
| fetch_queue | 20 | 100 | 177.24 | 190.63 | 205.34 | 15/20 count -> count, 3/20 push -> count | 2026-08-04 |
| align | 20 | 100 | 156.32 | 189.79 | 208.20 | 10/20 half -> out, 8/20 queue -> out | 2026-08-04 |
| fetch_ctrl | 20 | 100 | 228.73 | 257.85 | 281.37 | 14/20 kill -> valid chain, 3/20 -> missPC | 2026-08-04 |

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
