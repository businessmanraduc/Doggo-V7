# =================================================================================
#  module_fmax.mk -- per-module Fmax (ring synth + seed sweep)
#  usage: make -f flow/module_fmax.mk MOD=<name> DIR=<folder> [SEEDS=n TW=100 JOBS=n]
#         EXTRA="<paths>" adds sources outside DIR (submodule instances)
#         OUT="<path>" redirects the report, so a diagnostic run doesn't clobber
#         a signed-off fmax.md
# =================================================================================
MOD   ?=
DIR   ?= .
EXTRA ?=
TOP   ?= $(MOD)_ring
SEEDS ?= 20
TW    ?= 100
JOBS  ?= $(shell nproc)
BUILD := $(DIR)/build
INC   := rtl/common
SRCS  := $(filter-out %_tb.sv,$(wildcard $(DIR)/*.sv)) $(EXTRA) flow/ring_harness.sv
HDRS  := $(wildcard $(INC)/*.svh)
LPF   := flow/ring.lpf
OUT   ?= $(DIR)/fmax.md

include flow/module_flags.mk

FLAGSTAMP := $(BUILD)/.flags
$(shell mkdir -p $(BUILD))
$(shell printf '%s' '$(MOD_YOSYS_FLAGS)' | cmp -s $(FLAGSTAMP) 2>/dev/null \
	   || printf '%s' '$(MOD_YOSYS_FLAGS)' > $(FLAGSTAMP))

.PHONY: fmax clean flags

fmax: $(BUILD)/$(MOD).json
	@flow/sweep.sh $(MOD) $< $(LPF) $(TOP) $(SEEDS) $(TW) $(OUT) $(JOBS) "$(MOD_PNR_FLAGS)"

$(BUILD)/$(MOD).json: $(SRCS) $(HDRS) flow/module_flags.mk $(FLAGSTAMP)
	@mkdir -p $(BUILD)
	yosys -q -p "read_verilog -sv -I $(INC) $(SRCS); synth_ecp5 $(MOD_YOSYS_FLAGS) -top $(TOP) -json $@"

flags:
	@printf 'MOD=%s POLICY=%s\n  yosys: %s\n  nextpnr: --tmg-ripup %s\n' \
  '$(MOD)' '$(FLAGS_POLICY)' '$(strip $(MOD_YOSYS_FLAGS))' '$(strip $(MOD_PNR_FLAGS))'

clean:
	@rm -rf $(BUILD)

