# ================================================================================
#  module_fmax.mk -- per-module Fmax (ring synth + seed sweep)
#  usage: make -f flow/module_fmax.mk MOD=<name> DIR=<folder> [SEEDS=n TW=90]
# ================================================================================
MOD   ?=
DIR   ?= .
TOP   ?= $(MOD)_ring
SEEDS ?= 8
TW    ?= 90
BUILD := $(DIR)/build
SRCS  := $(filter-out %_tb.sv,$(wildcard $(DIR)/*.sv)) flow/ring_harness.sv
LPF   := flow/ring.lpf

.PHONY: fmax clean

fmax: $(BUILD)/$(MOD).json
	@flow/sweep.sh $(MOD) $< $(LPF) $(TOP) $(SEEDS) $(TW) $(DIR)/fmax.md

$(BUILD)/$(MOD).json: $(SRCS)
	@mkdir -p $(BUILD)
	yosys -q -p "read_verilog -sv $(SRCS); synth_ecp5 -top $(TOP) -json $@"

clean:
	@rm -rf $(BUILD)

