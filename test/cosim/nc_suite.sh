#!/usr/bin/env bash
# nc_suite.sh [seed]: negative controls for the checker and cosim_order. Each row
# breaks one thing and requires its message (inside nix-shell, from Doggo-V7-dev/)
set -uo pipefail
TB=test/cosim/build/obj/Vrefdut_tb
PROGRAM=test/cosim/prog/build/dv_basic.bin
OUT=test/cosim/build/nc
SEED=${1:-1}
mkdir -p $OUT
rows=(
  "f01|+fault=1|x[0-9]+: DUT"
  "f02|+fault=2|pc: DUT"
  "f03|+fault=3|store data"
  "f04|+fault=4|memory address/size|reference IO load"
  "f05|+fault=5|insn: DUT"
  "f06|+fault=6|rd: DUT"
  "f07|+fault=7|mstatus: DUT"
  "f08|+fault=8|minstret: DUT"
  "f09|+fault=9|mcause: DUT"
  "f10|+fault=10|mtval: DUT"
  "f11|+fault=11|memory access kind"
  "f12|+fault=12|reference IO load"
  "f13|+fault=13|DUT trapped, reference retired"
  "f14|+fault=14|mcause: DUT|not pending and enabled"
  "f15|+fault=15|DUT retired, reference trapped"
  "f16|+fault=16|memory address/size"
  "f17|+fault=17|not pending and enabled"
  "f18|+fault=18|pc: DUT"
  "f19|+fault=19|pc: DUT"
  "f20|+fault=20|not pending and enabled"
  "f21|+fault=21|mie: DUT"
  "f22|+fault=22|mtvec: DUT"
  "f23|+fault=23|mscratch: DUT"
  "f24|+fault=24|mepc: DUT"
  "f25|+fault=25|minstreth: DUT"
  "f26|+fault=26|x[0-9]+: DUT"
  "f27|+fault=27|mip read"
  "f28|+fault=28|mcycle went back"
  "f29|+fault=29|not taken"
  "f30|+fault=30|interrupt priority"
  "f31|+fault=31|unimplemented bits"
  "f32|+fault=32|event kind"
  "f33|+fault=33|interrupt priority"
  "f34|+fault=34|mcycleh went back"
  "f35|+fault=35|mcycle went back"
  "s01|+svfault=1|x[0-9]+: DUT"
  "s02|+svfault=2|never reached the checker|second pending load"
  "s03|+svfault=3|late value without a pending load"
  "s04|+svfault=4|second pending load"
  "s05|+svfault=5|x[0-9]+: DUT"
  "s06|+svfault=6|at finish: next pc"
  "s07|+svfault=7 +irq=20000|not in the device line history"
  "k01|+nooverride +drift=200|x[0-9]+: DUT"
  "k02|+noprofile|mtvec: DUT"
)
caught=0; total=0
for row in "${rows[@]}"; do
  IFS='|' read -r name args expect1 expect2 <<<"$row"
  total=$((total + 1))
  # faults on every event kind land anywhere in the program, the others early
  case $name in
    f01|f02|f05|f06|f07|f08|f2[1-5]|f3[12]) at=$((SEED * 7919 % 400));;
    *) at=$((SEED * 7 % 20));;
  esac
  $TB +bin=$PROGRAM +seed=$SEED +faultat=$at $args +expectfail +maxcyc=200000 >$OUT/$name.log 2>&1
  if grep -q '^PASS (expected failure seen)' $OUT/$name.log &&
     grep -Eq "${expect1}${expect2:+|$expect2}" $OUT/$name.log; then
    caught=$((caught + 1)); echo "caught  $name $args"
  else
    echo "MISSED  $name $args"
  fi
done
$TB +bin=$PROGRAM +seed=$SEED +drift=200 >$OUT/golden.log 2>&1
$TB +bin=$PROGRAM +seed=$SEED +drift=200 +irq=20000 >$OUT/golden_irq.log 2>&1
golden=0
grep -q '^PASS$' $OUT/golden.log && grep -q '^PASS$' $OUT/golden_irq.log && golden=1
[ $golden = 1 ] && echo "golden  PASS (plain, +irq)" || echo "golden  FAIL"
echo "caught $caught of $total"
[ $caught = $total ] && [ $golden = 1 ]
