#!/usr/bin/env bash
# prog_run.sh <elf> [plusargs]: one program through the stand-in core and the
# checker (inside nix-shell, from Doggo-V7-dev/). It ends on the exit device;
# riscv-tests style programs pass +tohost=<hex address>.
set -euo pipefail
elf=$1; shift
TB=test/cosim/build/obj/Vrefdut_tb
image=test/cosim/build/$(basename "${elf%.elf}").bin
riscv32-none-elf-objcopy -O binary "$elf" "$image"
$TB +bin="$image" +maxcyc=2000000000 "$@"
