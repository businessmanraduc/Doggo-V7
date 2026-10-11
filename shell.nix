let
  nixpkgs = builtins.fetchTarball {
    url    = "https://github.com/NixOS/nixpkgs/archive/b40629efe5d6ec48dd1efba650c797ddbd39ace0.tar.gz";
    sha256 = "sha256-TJ3lSQtW0E2JrznGVm8hOQGVpXjJyXY2guAxku2O9A4=";
  };
  pkgs = import nixpkgs {};
in
pkgs.mkShell {
  packages = with pkgs; [
    pkgsCross.riscv32-embedded.buildPackages.gcc
    spike
    dtc
    verilator
    yosys
    nextpnr
    trellis
    sby
    yices
    bitwuzla
    python3
    gnumake
    autoconf
    automake
    openfpgaloader
  ];
}
