# rtl/core

The CPU, one folder per module. A module is not a single file, it is a
**self-contained proven unit**. Nothing enters this tree until all four parts
below exist for it.

## Per-module folder contract

```
rtl/core/<module>/
  <module>.sv        # the RTL. Header records the solo Fmax (see below).
  <module>_tb.sv     # standalone functional bench (Verilator 5.044).
  <module>_ring.sv   # ring-of-registers wrapper: every path reg-to-reg,
                     #   the timing top handed to nextpnr for solo P&R.
  fmax.md            # the seed sweep result + worst-path census.
```

`phantooom-core.sv` at this level is the integration top: it wires the modules
together and holds the control spine. The spine stays thin and point-to-point,
no signal fans out to hundreds of FF enables.

## Header stamp

Every `<module>.sv` records its own standalone number in the header, e.g.:

```
// Solo Fmax (ring-of-regs, nextpnr --85k, tw=90, N seeds): floor / mean / ceil
```

