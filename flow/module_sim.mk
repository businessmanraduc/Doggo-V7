# =================================================================================
#  module_sim.mk -- standalone functional sim of a module's testbench
#  usage: make -f flow/module_sim.mk MOD=<name> DIR=<folder> [TOP=<name>_tb]
#         submodules in DIR/*/ are picked up (build/ and formal/ skipped)
#         EXTRA="<paths>" adds sources outside DIR (rtl/common cells)
# =================================================================================
MOD   ?=
DIR   ?= .
override DIR := $(DIR:%/=%)
EXTRA ?=
TOP   ?= $(MOD)_tb
BUILD := $(DIR)/build
INC   := rtl/common
SUBS  := $(shell find $(DIR) \( -name build -o -name formal \) -prune -o -path '$(DIR)/*/*.sv' \
           ! -name '*_tb.sv' ! -name '*_ring.sv' -print | sort)
SRCS  := $(filter-out %_ring.sv,$(wildcard $(DIR)/*.sv)) $(SUBS) $(EXTRA)

TOOLCHECK := verilator
include flow/toolcheck.mk

.PHONY: sim clean

sim:
	verilator --binary --timing -j 0 -I$(INC) -I$(DIR) -Mdir $(BUILD) --top-module $(TOP) $(SRCS)
	@rm -f $(BUILD)/*.gch
	@$(BUILD)/V$(TOP)

clean:
	@rm -rf $(BUILD)

