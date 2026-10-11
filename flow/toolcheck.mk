# =================================================================================
#  toolcheck.mk -- stop unless the pinned toolchain (shell.nix) is on PATH
# =================================================================================
PIN_yosys     := Yosys 0.62
PIN_nextpnr   := nextpnr-35f1433
PIN_verilator := Verilator 5.044

VER_yosys     = $(shell yosys -V 2>/dev/null)
VER_nextpnr   = $(shell nextpnr-ecp5 --version 2>&1 | head -n 1)
VER_verilator = $(shell verilator --version 2>/dev/null)

ifneq ($(filter-out clean flags,$(or $(MAKECMDGOALS),default)),)
  $(foreach t,$(TOOLCHECK),$(if $(findstring $(PIN_$(t)),$(VER_$(t))),,\
    $(error $(t) is "$(VER_$(t))", pinned "$(PIN_$(t))": run inside nix-shell \
      from /home/raduc/CPUs)))
endif
