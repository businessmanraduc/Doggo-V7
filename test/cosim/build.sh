#!/usr/bin/env bash
# build.sh: refdut_tb (stand-in core + cosim_order + checker) into build/obj
# (inside nix-shell)
set -euo pipefail
cd "$(dirname "$0")"
SPIKE=$(dirname "$(dirname "$(command -v spike)")")
mkdir -p build
verilator --binary --timing -j 4 -Wno-fatal -Wno-WIDTHTRUNC -Wno-WIDTHEXPAND \
  --top-module refdut_tb -Mdir build/obj \
  -CFLAGS "-std=c++17 -O2 -I$SPIKE/include -I$PWD" \
  -LDFLAGS "-L$SPIKE/lib -Wl,-rpath,$SPIKE/lib -lriscv -ldisasm -lsoftfloat -lfesvr" \
  cosim_order.sv refdut_tb.sv hart.cc cosim.cc refdut.cc >build/build.log 2>&1 \
  || { tail -40 build/build.log; exit 1; }
rm -f build/obj/*.gch
echo "built build/obj/Vrefdut_tb"
