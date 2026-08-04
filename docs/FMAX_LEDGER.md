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
| legal32 | 20 | 100 | 165.76 | 186.22 | 194.06 | 20/20 instr -> illegal | 2026-07-17 |
| decoder | 20 | 100 | 164.77 | 176.62 | 190.33 | 15/20 instr -> uop, 5/20 pc -> uop | 2026-07-18 |
| regfile | 20 | 100 | 252.91 | 269.23 | 284.98 | 19/20 index -> read data | 2026-07-19 |
| rat | 20 | 100 | 159.46 | 170.88 | 184.54 | 20/20 commit-clear -> pending | 2026-07-19 |
| btb | 20 | 100 | 143.04 | 144.54 | 145.50 | 18/20 BSRAM read -> entryQ | 2026-08-04 |
| pht | 20 | 100 | 149.10 | 149.53 | 152.53 | 16/20 BSRAM read -> counter | 2026-08-04 |
| bpredict | 20 | 100 | 135.39 | 141.74 | 144.78 | 17/20 BTB BSRAM read -> entryQ | 2026-08-04 |
| icache | 20 | 100 | 160.18 | 171.08 | 176.12 | 10/20 tag LUTRAM read, 9/20 fill FSM state | 2026-08-03 |
| linefill | 20 | 100 | 200.08 | 214.66 | 225.63 | 19/20 state -> state, 1/20 sweepCount -> state | 2026-08-03 |
| fetch_queue | 20 | 100 | 170.30 | 188.94 | 202.14 | 14/20 count -> count, 4/20 push -> count | 2026-08-04 |
| align | 20 | 100 | 173.19 | 189.53 | 207.60 | 10/20 half -> out, 9/20 queue -> out | 2026-08-04 |

Frontend rows do not stack: `bpredict` is the glue over `btb` + `pht` + the BHR,
so its number is the same BSRAM read seen through one more level of hierarchy,
and it is the floor of the whole tree. `icache` has `linefill` inside it, so the
two rows overlap the same way. `ebr18` / `ebr2` are cell wrappers around DP16KD
and have no ring of their own.

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
