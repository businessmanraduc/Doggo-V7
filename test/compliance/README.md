# compliance

Third-party ISA suites at pinned commits, fetched into src/ (ignored) and
built into build/. Run inside nix-shell:

    test/compliance/fetch.sh
    test/compliance/build.sh

| suite | commit | built |
|---|---|---|
| riscv-tests (env 6de71ed) | 1eb47d9 | rv32ui, rv32um, rv32uc, rv32mi: 67 |
| riscv-arch-test 3.9.1 (BSD-3) | eb66181 | rv32i_m I, M, C, Zifencei, privilege: 92 |

act_model/ is our riscv-arch-test target: halt through the exit device, no
signature compare (the lockstep checker compares every retired instruction). The 11 Zcb tests in C/ do not assemble for rv32imc and are left out.
Run with test/cosim/rt_suite.sh and act_suite.sh.
