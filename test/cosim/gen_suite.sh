#!/usr/bin/env bash
# gen_suite.sh <first> <count>: rvgen programs through the stand-in core and the
# checker, knobs drawn per seed, then the coverage summed over the seeds
# (inside nix-shell, from Doggo-V7-dev/). env: JOBS (4)
set -uo pipefail
TB=test/cosim/build/obj/Vrefdut_tb
OUT=test/cosim/build/gen
mkdir -p $OUT
run() {
  seed=$1
  program=$OUT/g$seed
  python3 test/cosim/gen/rvgen.py $seed $program.S || { echo "GENFAIL g$seed"; return; }
  riscv32-none-elf-gcc -march=rv32imc_zicsr_zifencei -mabi=ilp32 -nostdlib -nostartfiles \
    -T test/cosim/prog/link.ld $program.S -o $program.elf 2>$program.asm.log ||
    { echo "ASMFAIL g$seed"; return; }
  riscv32-none-elf-objcopy -O binary $program.elf $program.bin
  knobs=(+rtpct=$((30 + seed % 70)) +pendpct=$((seed * 37 % 100)) +maxlate=$((1 + seed % 60))
         +drift=$((seed % 3 * 50)))
  [ $((seed % 3)) -eq 0 ] && knobs+=(+irq=$((seed % 5 * 1000 + 200)))
  $TB +bin=$program.bin +seed=$seed "${knobs[@]}" +cov=$program.cov +maxcyc=20000000 >$program.log 2>&1
  result=$(grep -E '^(PASS|FAIL)' $program.log | tail -1)
  echo "${result:-NORESULT} g$seed ${knobs[*]}"
}
export -f run; export TB OUT
seq $1 $(($1 + $2 - 1)) | xargs -P ${JOBS:-4} -I{} bash -c 'run {}' | sort -k2 -V >$OUT/summary_$1.txt
grep -c '^PASS' $OUT/summary_$1.txt | sed 's/^/pass: /'
grep -v '^PASS' $OUT/summary_$1.txt | head -20 || true
for seed in $(seq $1 $(($1 + $2 - 1))); do cat $OUT/g$seed.cov 2>/dev/null; done |
  awk '{sum[$1] += $2} END {for (key in sum) print key, sum[key]}' | sort >$OUT/coverage_$1.txt
echo "coverage: $OUT/coverage_$1.txt ($(grep -c '^m:' $OUT/coverage_$1.txt) mnemonics)"
