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
| btb | 20 | 100 | 141.92 | 144.49 | 145.50 | - | 18/20 BSRAM read -> entryQ | 2026-08-06 |
| pht | 20 | 100 | 149.10 | 149.53 | 152.53 | - | 16/20 BSRAM read -> counter | 2026-08-06 |
| icache | 20 | 100 | 195.08 | 206.12 | 217.01 | nwl | 7/20 hitVecF4 -> sink, 3/20 fill state -> data array | 2026-08-07 |
| bpredict | 20 | 100 | 135.78 | 142.75 | 145.41 | - | 20/20 BTB BSRAM read -> entryQ | 2026-08-06 |
| linefill | 20 | 100 | 192.75 | 216.58 | 228.41 | - | 9/20 state -> settleCount, 8/20 state -> state | 2026-08-07 |
| fetch_queue | 20 | 100 | 172.27 | 191.17 | 208.64 | - | 12/20 count -> count, 4/20 push -> count | 2026-08-06 |
| align | 20 | 100 | 193.50 | 210.39 | 232.45 | nwl | 11/20 half -> out, 8/20 queue -> out | 2026-08-07 |
| fetch_ctrl | 20 | 100 | 244.74 | 262.29 | 296.21 | nwl | 5/20 resetn -> validF1, 5/20 validF4 -> validF1 | 2026-08-07 |
| fetch_engine | 20 | 100 | 127.96 | 135.15 | 141.72 | nwl | 15/20 fq head -> count, 2/20 icache hitVec -> validF1 | 2026-08-07 |

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
