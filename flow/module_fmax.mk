# ================================================================================
#  module_fmax.mk -- per-module Fmax (ring synth + seed sweep)
#  usage: make -f flow/module_fmax.mk MOD=<name> DIR=<folder> [SEEDS=n TW=100 JOBS=n]
#         EXTRA="<paths>" adds sources outside DIR (submodule instances)
# ================================================================================
MOD   ?=
DIR   ?= .
EXTRA ?=
TOP   ?= $(MOD)_ring
SEEDS ?= 8
TW    ?= 100
JOBS  ?= $(shell nproc)
BUILD := $(DIR)/build
INC   := rtl/common
SRCS  := $(filter-out %_tb.sv,$(wildcard $(DIR)/*.sv)) $(EXTRA) flow/ring_harness.sv
HDRS  := $(wildcard $(INC)/*.svh)
LPF   := flow/ring.lpf

.PHONY: fmax clean

fmax: $(BUILD)/$(MOD).json
	@flow/sweep.sh $(MOD) $< $(LPF) $(TOP) $(SEEDS) $(TW) $(DIR)/fmax.md $(JOBS)

$(BUILD)/$(MOD).json: $(SRCS) $(HDRS)
	@mkdir -p $(BUILD)
	yosys -q -p "read_verilog -sv -I $(INC) $(SRCS); synth_ecp5 -top $(TOP) -json $@"

clean:
	@rm -rf $(BUILD)

