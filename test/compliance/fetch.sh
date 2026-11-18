#!/usr/bin/env bash
# fetch.sh: the two third-party suites at pinned commits into src/ (ignored)
set -euo pipefail
cd "$(dirname "$0")"
fetch() {
  name=$1 url=$2 commit=$3; shift 3
  if [ "$(git -C src/$name rev-parse HEAD 2>/dev/null)" = "$commit" ]; then
    echo "$name: $commit (present)"; return
  fi
  rm -rf src/$name
  git init -q src/$name
  git -C src/$name remote add origin "$url"
  if [ $# -gt 0 ]; then git -C src/$name sparse-checkout set "$@"; fi
  git -C src/$name fetch -q --depth 1 --filter=blob:none origin "$commit"
  git -C src/$name checkout -q FETCH_HEAD
  echo "$name: $commit"
}
fetch riscv-tests https://github.com/riscv-software-src/riscv-tests \
  1eb47d946c55f55cab8653c224c2993acc0276bd
fetch riscv-tests/env https://github.com/riscv/riscv-test-env \
  6de71edb142be36319e380ce782c3d1830c65d68
fetch riscv-arch-test https://github.com/riscv-non-isa/riscv-arch-test \
  eb66181dd27ff7847e2c3a010705b13490b0bf75 riscv-test-suite/env \
  riscv-test-suite/rv32i_m/{I,M,C,Zifencei,privilege}
