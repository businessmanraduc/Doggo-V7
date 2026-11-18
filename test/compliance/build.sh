#!/usr/bin/env bash
# build.sh: riscv-tests (p env) and riscv-arch-test RV32 I, M, C, Zifencei,
# privilege from src/ (fetch.sh first, inside nix-shell)
# output build/{riscv-tests,arch-test}/<suite>/<test>.{elf,bin}
set -uo pipefail
cd "$(dirname "$0")"
RT=src/riscv-tests
ACT=src/riscv-arch-test/riscv-test-suite
CC="riscv32-none-elf-gcc -march=rv32imc_zicsr_zifencei -mabi=ilp32 -static -mcmodel=medany
  -fvisibility=hidden -nostdlib -nostartfiles"
built=0; failed=()

compile() {
  local out=$1; shift
  if $CC "$@" -o "$out.elf" 2>"$out.err"; then
    riscv32-none-elf-objcopy -O binary "$out.elf" "$out.bin"
    rm -f "$out.err"; built=$((built + 1))
  else
    failed+=("$out")
  fi
}

for suite in rv32ui rv32um rv32uc rv32mi; do
  mkdir -p build/riscv-tests/$suite
  for src in $RT/isa/$suite/*.S; do
    compile build/riscv-tests/$suite/$(basename "$src" .S) \
      -I$RT/env/p -I$RT/isa/macros/scalar -T$RT/env/p/link.ld "$src"
  done
done

for suite in I M C Zifencei privilege; do
  mkdir -p build/arch-test/$suite
  for src in $ACT/rv32i_m/$suite/src/*.S; do
    # "def X=Y" in RVTEST_CASE lines become -DX=Y, as the riscof flow does
    defines=$(grep -o 'def [A-Za-z_0-9]*=[A-Za-z_0-9]*' "$src" | sort -u | sed 's/^def /-D/')
    compile build/arch-test/$suite/$(basename "$src" .S) $defines -DXLEN=32 \
      -I$ACT/env -Iact_model -Tact_model/link.ld "$src"
  done
done

echo "built $built"
[ ${#failed[@]} -eq 0 ] || echo "failed: ${failed[*]}"
