#!/usr/bin/env bash
# core_suite.sh <first> <count>: the M2 core in lockstep on rvgen --profile m2
# programs, knobs drawn per seed, then the coverage the suite requires
# (inside nix-shell, from Doggo-V7-dev/). env: DIR (rtl/core), OUT, JOBS (4)
# chk_lint: no warning in the core top (a pin left off reads 0 in a 2-state sim)
set -uo pipefail
DIR=${DIR:-rtl/core}
OUT=${OUT:-test/cosim/build/core}
COSIM=test/cosim
mkdir -p $OUT
CORE=$(find $DIR -mindepth 2 \( -name build -o -name formal \) -prune -o -name '*.sv' \
  ! -name '*_tb.sv' ! -name '*_ring.sv' -print | sort)
COMMON="rtl/common/dup_reg.sv rtl/common/dup_reg_clear.sv rtl/common/cc_pmux.sv rtl/common/ecp5_models.v"

verilator --lint-only -Wall -Wno-DECLFILENAME -Wno-UNUSEDSIGNAL -Wno-UNUSEDPARAM -Wno-PINCONNECTEMPTY \
  -Irtl/common --top-module phantooom_core $DIR/phantooom_core.sv $CORE $COMMON >$OUT/lint.log 2>&1
if grep -E '^%(Warning|Error)' $OUT/lint.log | grep -v ecp5_models | grep -q "phantooom_core.sv"; then
  echo "FAIL chk_lint"
  grep -E '^%(Warning|Error)' $OUT/lint.log | grep phantooom_core.sv | head -5
  exit 1
fi

SPIKE=$(dirname "$(dirname "$(command -v spike)")")
rm -rf $OUT/obj
verilator --binary --timing -j 4 -Wno-fatal -Wno-lint -Wno-style -Irtl/common \
  --top-module phantooom_core_tb -Mdir $OUT/obj \
  -CFLAGS "-std=c++17 -O2 -I$SPIKE/include -I$PWD/$COSIM" \
  -LDFLAGS "-L$SPIKE/lib -Wl,-rpath,$SPIKE/lib -lriscv -ldisasm -lsoftfloat -lfesvr" \
  $DIR/phantooom_core_tb.sv $COSIM/cosim_order.sv $DIR/phantooom_core.sv $CORE $COMMON \
  $PWD/$COSIM/hart.cc $PWD/$COSIM/cosim.cc >$OUT/build.log 2>&1 ||
  { echo "FAIL build"; tail -20 $OUT/build.log; exit 1; }
rm -f $OUT/obj/*.gch
TB=$OUT/obj/Vphantooom_core_tb

run() {
  seed=$1
  program=$OUT/m$seed
  python3 $COSIM/gen/rvgen.py $seed $program.S --profile m2 --len $((1000 + seed % 4 * 1000)) ||
    { echo "GENFAIL m$seed"; return; }
  riscv32-none-elf-gcc -march=rv32imc_zbb -mabi=ilp32 -nostdlib -nostartfiles \
    -T $COSIM/prog/link.ld $program.S -o $program.elf 2>$program.asm.log ||
    { echo "ASMFAIL m$seed"; return; }
  riscv32-none-elf-objcopy -O binary $program.elf $program.bin
  endPc=$(riscv32-none-elf-nm $program.elf | awk '/ _end$/ {print $1}')
  knobs=(+seed=$seed +bubble=$((seed * 13 % 50)) +resets=$((seed % 4)))
  timeout 600 $TB +bin=$program.bin +end=$endPc "${knobs[@]}" +cov=$program.cov >$program.log 2>&1
  result=$(grep -E '^(PASS|FAIL)' $program.log | tail -1)
  echo "${result:-NORESULT} m$seed ${knobs[*]}"
}
export -f run; export TB OUT COSIM
seq $1 $(($1 + $2 - 1)) | xargs -P ${JOBS:-4} -I{} bash -c 'run {}' | sort -k2 -V >$OUT/summary_$1.txt
grep -c '^PASS' $OUT/summary_$1.txt | sed 's/^/pass: /'
grep -v '^PASS' $OUT/summary_$1.txt | head -20 || true
for seed in $(seq $1 $(($1 + $2 - 1))); do cat $OUT/m$seed.cov 2>/dev/null; done |
  awk '{sum[$1] += $2} END {for (key in sum) print key, sum[key]}' | sort >$OUT/coverage_$1.txt
REQUIRED="add sub and or xor andn orn xnor addi andi ori xori lui auipc jal
  c.addi c.nop c.jal c.li c.addi16sp c.lui c.andi c.sub c.xor c.or c.and c.j c.mv c.add c.addi4spn
  x0dest stallHeld longStall retireRun16 resetInFlight"
missing=""
for key in $REQUIRED; do grep -q "^$key " $OUT/coverage_$1.txt || missing="$missing $key"; done
if [ -n "$missing" ]; then
  echo "FAIL chk_cov:$missing"
else
  echo "coverage: $OUT/coverage_$1.txt (all required)"
fi
