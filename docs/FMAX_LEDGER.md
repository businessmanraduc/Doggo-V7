# Fmax Ledger (Doggo-V7)

The running record of every module's **standalone** Fmax (ring-of-registers
wrapper, nextpnr --85k --package CABGA381, tw=100 unless noted). Numbers are
floor / mean / ceiling across the seed sweep.

## Per-module standalone Fmax

| module | seeds | tw | floor | mean | ceil | worst-path census | date |
|---|---|---|---|---|---|---|---|
| alu | 20 | 100 | 175.07 | 183.99 | 192.83 | 20/20 operand -> result | 2026-08-06 |
| shifter | 20 | 100 | 187.48 | 200.88 | 209.07 | 19/20 fine stage, 1/20 coarse | 2026-08-06 |
| rob | 20 | 100 | 168.21 | 185.99 | 203.79 | 7/20 head -> count, 7/20 done -> full | 2026-08-06 |
| rvc_expand | 20 | 100 | 176.09 | 192.45 | 204.16 | 20/20 instr16 -> instr32 | 2026-08-06 |
| dispatch_fifo | 20 | 100 | 186.29 | 219.19 | 256.87 | 19/20 count -> count | 2026-08-06 |
| legal32 | 20 | 100 | 173.43 | 191.99 | 198.06 | 20/20 instr -> illegal | 2026-08-06 |
| decoder | 20 | 100 | 166.72 | 182.16 | 197.28 | 15/20 instr -> uop, 5/20 pc -> uop | 2026-08-06 |
| regfile | 20 | 100 | 253.94 | 276.98 | 287.44 | 19/20 index -> read data | 2026-08-06 |
| rat | 20 | 100 | 167.08 | 175.18 | 190.01 | 20/20 commit-clear -> pending | 2026-08-06 |
| btb | 20 | 100 | 141.92 | 144.49 | 145.50 | 18/20 BSRAM read -> entryQ | 2026-08-06 |
| pht | 20 | 100 | 149.10 | 149.53 | 152.53 | 16/20 BSRAM read -> counter | 2026-08-06 |
| icache | 20 | 100 | 187.79 | 197.50 | 207.94 | 5/20 PLRU LUTRAM read, 5/20 hitVecF4 -> sink | 2026-08-06 |
| bpredict | 20 | 100 | 135.78 | 142.75 | 145.41 | 20/20 BTB BSRAM read -> entryQ | 2026-08-06 |
| linefill | 20 | 100 | 192.57 | 220.75 | 241.08 | 12/20 state -> state, 4/20 sweepCount -> state | 2026-08-06 |
| fetch_queue | 20 | 100 | 172.27 | 191.17 | 208.64 | 12/20 count -> count, 4/20 push -> count | 2026-08-06 |
| align | 20 | 100 | 156.32 | 191.66 | 213.04 | 9/20 half -> out, 8/20 queue -> out | 2026-08-06 |
| fetch_ctrl | 20 | 100 | 226.30 | 259.43 | 287.94 | 5/20 -> validF1, 4/20 hwF4 -> missPC | 2026-08-06 |
| fetch_engine | 20 | 100 | 127.08 | 135.30 | 145.14 | 9/20 NextPC cone, 7/20 fq head -> count | 2026-08-06 |

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
