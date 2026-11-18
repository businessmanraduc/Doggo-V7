#!/usr/bin/env bash
# iodev_suite.sh: iodev against iodev_tb, golden and mutants
# (inside nix-shell, from Doggo-V7-dev/)
set -uo pipefail
DIR=test/cosim
OUT=$DIR/build/iodev
mkdir -p $OUT
run() {
  name=$1 source=$2
  verilator --binary --timing -Wno-fatal -Wno-WIDTHTRUNC -Wno-WIDTHEXPAND --top-module iodev_tb \
    -Mdir $OUT/obj_$name $DIR/iodev_tb.sv $source >$OUT/$name.build.log 2>&1 ||
    { echo "BUILDFAIL $name"; return; }
  $OUT/obj_$name/Viodev_tb >$OUT/$name.log 2>&1
  rm -rf $OUT/obj_$name
  grep -E '^(PASS|FAIL)' $OUT/$name.log | tail -1
}
mutant() {
  name=$1 edit=$2
  sed "$edit" $DIR/iodev.sv >$OUT/m_$name.sv
  cmp -s $DIR/iodev.sv $OUT/m_$name.sv && { echo "NOCHANGE $name"; return; }
  result=$(run m_$name $OUT/m_$name.sv)
  [ "$result" = FAIL ] && echo "caught $name" || echo "MISSED $name"
}
echo "golden $(run golden $DIR/iodev.sv)"
mutant be_ignored   's/if (ioBe\[b\]) dv_scratch/dv_scratch/'
mutant counter_step 's/dv_counter += 7/dv_counter += 1/'
mutant out_of_order 's/read_t oldest = dv_reads.pop_front();/read_t oldest = dv_reads.pop_back();/'
mutant timer_late   's/if (dv_timerAt >= 0 \&\& dv_cycle >= dv_timerAt)/if (dv_timerAt >= 0 \&\& dv_cycle > dv_timerAt)/'
mutant irq_mask     's/dv_irqLines = busWord \& IRQ_MASK;/dv_irqLines = busWord;/'
mutant unmapped     's/          else readData = 0;/          else readData = 32'"'"'h1;/'
mutant fifo_stuck   's/dv_fifo = (dv_fifo >> 1)/dv_fifo = (dv_fifo >> 0)/'
mutant be_regs      's/busWord = ioWData \& {{8{ioBe\[3\]}}, {8{ioBe\[2\]}}, {8{ioBe\[1\]}}, {8{ioBe\[0\]}}};/busWord = ioWData;/'
