# =================================================================================
#  module_fmax.mk -- per-module Fmax (ring synth + seed sweep)
#  usage: make -f flow/module_fmax.mk MOD=<name> DIR=<folder> [SEEDS=n TW=100 JOBS=n]
#         submodules in DIR/*/ are picked up (build/ and formal/ skipped)
#         EXTRA="<paths>" adds sources outside DIR (rtl/common cells)
#         OUT="<path>" redirects the report, so a diagnostic run doesn't clobber
#         a signed-off fmax.md
# =================================================================================
MOD   ?=
DIR   ?= .
override DIR := $(DIR:%/=%)
EXTRA ?=
TOP   ?= $(MOD)_ring
SEEDS ?= 20
TW    ?= 100
JOBS  ?= $(shell nproc)
BUILD := $(DIR)/build
INC   := rtl/common
SUBS  := $(shell find $(DIR) \( -name build -o -name formal \) -prune -o -path '$(DIR)/*/*.sv' \
           ! -name '*_tb.sv' ! -name '*_ring.sv' -print | sort)
SRCS  := $(filter-out %_tb.sv,$(wildcard $(DIR)/*.sv)) $(SUBS) $(EXTRA) flow/ring_harness.sv
HDRS  := $(wildcard $(INC)/*.svh)
LPF   := flow/ring.lpf
OUT   ?= $(DIR)/fmax.md

include flow/module_flags.mk

TOOLCHECK := yosys nextpnr
include flow/toolcheck.mk

FLAGSTAMP := $(BUILD)/.flags
$(shell mkdir -p $(BUILD))
$(shell printf '%s' '$(MOD_YOSYS_FLAGS)' | cmp -s $(FLAGSTAMP) 2>/dev/null \
	   || printf '%s' '$(MOD_YOSYS_FLAGS)' > $(FLAGSTAMP))

.PHONY: fmax clean flags

fmax: $(BUILD)/$(MOD).json
	@flow/sweep.sh $(MOD) $< $(LPF) $(TOP) $(SEEDS) $(TW) $(OUT) $(JOBS) "$(MOD_PNR_FLAGS)"

$(BUILD)/$(MOD).json: $(SRCS) $(HDRS) flow/module_flags.mk $(FLAGSTAMP)
	@mkdir -p $(BUILD)
	yosys -q -p "read_verilog -sv -I $(INC) -I $(DIR) $(SRCS); synth_ecp5 $(MOD_YOSYS_FLAGS) -top $(TOP) -json $@"

flags:
	@printf 'MOD=%s POLICY=%s\n  yosys: %s\n  nextpnr: --tmg-ripup %s\n' \
  '$(MOD)' '$(FLAGS_POLICY)' '$(strip $(MOD_YOSYS_FLAGS))' '$(strip $(MOD_PNR_FLAGS))'

clean:
	@rm -rf $(BUILD)

