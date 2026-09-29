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
