#!/usr/bin/env bash
# rt_suite.sh [plusargs]: riscv-tests through the stand-in core and the checker
# (inside nix-shell, from Doggo-V7-dev/). env: SEED (1), JOBS (4)
set -uo pipefail
TESTS=test/compliance/build/riscv-tests
TB=test/cosim/build/obj/Vrefdut_tb
OUT=test/cosim/build/rt
SEED=${SEED:-1}
mkdir -p $OUT
run() {
  test=$1; shift
  tohost=$(riscv32-none-elf-nm "$test.elf" | awk '/ tohost$/ {print $1}')
  name=$(echo "$test" | sed 's|.*/riscv-tests/||; s|/|_|')
  $TB +bin="$test.bin" +tohost="$tohost" +seed=$SEED +pendpct=40 "$@" >"$OUT/$name.log" 2>&1
  result=$(grep -E '^(PASS|FAIL)' "$OUT/$name.log" | tail -1)
  # outside the core profile (0048): the program fails, the checker must stay clean
  case $name in rv32mi_breakpoint|rv32mi_pmpaddr|rv32mi_zicntr|rv32ui_ma_data)
    result=NA
    grep -q 'COSIM\|program did not end\|never reached' "$OUT/$name.log" && result=FAIL;;
  esac
  echo "${result:-NORESULT} $name"
}
export -f run; export TB OUT SEED
ls $TESTS/*/*.elf | sed 's/\.elf$//' |
  xargs -P ${JOBS:-4} -I{} bash -c 'run {} '"$*" | sort >$OUT/summary.txt
grep -c '^PASS' $OUT/summary.txt | sed 's/^/pass: /'
grep -c '^NA' $OUT/summary.txt | sed 's/^/not applicable, checker clean: /'
grep -v '^PASS\|^NA' $OUT/summary.txt || true
