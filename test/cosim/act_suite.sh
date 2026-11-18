#!/usr/bin/env bash
# act_suite.sh [plusargs]: riscv-arch-test (test/compliance) through the
# stand-in core and the checker (inside nix-shell, from Doggo-V7-dev/).
# env: SEED (1), JOBS (4)
set -uo pipefail
TB=test/cosim/build/obj/Vrefdut_tb
OUT=test/cosim/build/act
SEED=${SEED:-1}
mkdir -p $OUT
run() {
  image=$1; shift
  name=$(echo "$image" | sed 's|.*/arch-test/||; s|/|_|; s|\.bin$||')
  $TB +bin="$image" +seed=$SEED +pendpct=40 +maxcyc=5000000 "$@" >"$OUT/$name.log" 2>&1
  result=$(grep -E '^(PASS|FAIL)' "$OUT/$name.log" | tail -1)
  echo "${result:-NORESULT} $name"
}
export -f run; export TB OUT SEED
ls test/compliance/build/arch-test/*/*.bin |
  xargs -P ${JOBS:-4} -I{} bash -c 'run {} '"$*" | sort >$OUT/summary.txt
grep -c '^PASS' $OUT/summary.txt | sed 's/^/pass: /'
grep -v '^PASS' $OUT/summary.txt || true
