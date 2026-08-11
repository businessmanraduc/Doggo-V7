# Fmax Ledger (Doggo-V7)

The running record of every module's **standalone** Fmax (ring-of-registers
wrapper, nextpnr --85k --package CABGA381, tw=100 unless noted). Numbers are
floor / mean / ceiling across the seed sweep.

## Per-module standalone Fmax

| module | seeds | tw | floor | mean | ceil | flags | worst-path census | date |
|---|---|---|---|---|---|---|---|---|
| alu | 20 | 100 | 175.07 | 183.99 | 192.83 | - | 20/20 operand -> result | 2026-08-06 |
| shifter | 20 | 100 | 185.67 | 204.72 | 213.77 | nwl | 16/20 data stage, 4/20 amount | 2026-08-07 |
| rob | 20 | 100 | 168.21 | 185.99 | 203.79 | - | 7/20 head -> count, 7/20 done -> full | 2026-08-06 |
| rvc_expand | 20 | 100 | 188.86 | 194.15 | 199.68 | nwl | 20/20 instr16 -> instr32 | 2026-08-07 |
| dispatch_fifo | 20 | 100 | 180.31 | 229.51 | 262.74 | nwl | 17/20 count -> count, 3/20 enq -> count | 2026-08-07 |
| legal32 | 20 | 100 | 184.60 | 196.37 | 205.93 | nwl | 20/20 instr -> illegal | 2026-08-07 |
| decoder | 20 | 100 | 172.95 | 185.91 | 199.24 | nwl | 18/20 instr -> uop, 2/20 pc -> uop | 2026-08-07 |
| regfile | 20 | 100 | 253.94 | 276.98 | 287.44 | - | 19/20 index -> read data | 2026-08-06 |
| rat | 20 | 100 | 167.08 | 175.18 | 190.01 | - | 20/20 commit-clear -> pending | 2026-08-06 |
| icache | 20 | 100 | 195.08 | 206.12 | 217.01 | nwl | 7/20 hitVecF4 -> sink, 3/20 fill state -> data array | 2026-08-07 |
| bpredict | 20 | 100 | 149.99 | 172.03 | 183.32 | - | 4/20 ftq readPtr loop, rest rig-driven redirect/reset | 2026-08-11 |
| ras | 20 | 100 | 191.17 | 209.62 | 235.40 | - | 19/20 rig-driven pushAddr -> top, 1/20 ptr -> top | 2026-08-10 |
| ftq | 20 | 100 | 185.15 | 196.75 | 211.15 | - | 20/20 rig-driven push_validB -> word counters | 2026-08-10 |
| btb | 20 | 100 | 187.83 | 201.45 | 213.54 | - | 20/20 BSRAM out -> sink; ceil above the 211.9 BSRAM cap | 2026-08-10 |
| pht | 20 | 100 | 362.98 | 400.61 | 447.43 | - | fabric slack only, the whole range is above the 211.9 BSRAM cap | 2026-08-10 |
| linefill | 20 | 100 | 192.75 | 216.58 | 228.41 | - | 9/20 state -> settleCount, 8/20 state -> state | 2026-08-07 |
| fetch_queue | 20 | 100 | 171.82 | 188.09 | 204.75 | - | 13/20 count -> count, 5/20 flushShadow -> count | 2026-08-11 |
| align | 20 | 100 | 193.80 | 214.02 | 236.91 | nwl | 12/20 half -> sink, 8/20 rig ctl -> sink | 2026-08-11 |
| fetch_ctrl | - | - | - | - | - | - | STALE: metadata delay and miss replay both move into the FTQ | 2026-08-11 |
| fetch_engine | - | - | - | - | - | - | STALE: being rewritten around the FTQ, no predictor inside it | 2026-08-11 |
## Fmax observations

`fetch_engine` is a COMPOSITE row: one flag covers every module inside it, so its
`nwl` also applies to `fetch_queue`, whose own row is `-` because the flag costs it
9.08. Its 135.15 is therefore a mixed measurement, not the per-module policy applied
faithfully. Doing that properly needs the two-pass splice (map twice, keep_hierarchy
the children, `design -copy-from`), which the ring flow does not do yet.
`nwl` = built with `-nowidelut`, `-` = default mapping;
Every row also uses `--tmg-ripup`.

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
