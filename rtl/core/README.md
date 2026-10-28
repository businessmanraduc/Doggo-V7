# rtl/core

The CPU, one folder per module. A module is not a single file, it is a
**self-contained proven unit**. Nothing enters this tree until all four parts
below exist for it.

## Per-module folder contract

```
rtl/core/<module>/
  <module>.sv        # the RTL.
  <module>_tb.sv     # standalone functional bench (Verilator 5.044).
  <module>_ring.sv   # ring-of-registers wrapper: every path reg-to-reg,
                     #   the timing top handed to nextpnr for solo P&R.
  fmax.md            # the seed sweep result + worst-path census.
```

## Hierarchy

A top is a module whose folder also holds the folders of the modules it
instantiates, no more, no less. Cells from `rtl/common` are the only exception.
The sim and Fmax flows pick up every submodule under `DIR` on their own.

```
rtl/core/
  phantooom_core.sv  # whole core (+ _tb, _ring, fmax.md)
  fe/                # Front End
  oe/                # Out-of-order Engine: decode, rename, dispatch, ROB, IQ
  ex/                # Execution Engine
```
