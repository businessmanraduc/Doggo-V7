#!/usr/bin/env bash
# build.sh: assemble the directed programs into build/ (inside nix-shell)
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p build
for source in *.S; do
  target=build/${source%.S}
  riscv32-none-elf-gcc -march=rv32imc_zicsr_zifencei -mabi=ilp32 -nostdlib -nostartfiles \
    -T link.ld "$source" -o "$target.elf"
  riscv32-none-elf-objcopy -O binary "$target.elf" "$target.bin"
  riscv32-none-elf-objdump -d "$target.elf" >"$target.dump"
done
