# =================================================================================
#  module_sim.mk -- standalone functional sim of a module's testbench
#  usage: make -f flow/module_sim.mk MOD=<name> DIR=<folder> [TOP=<name>_tb]
# =================================================================================
MOD   ?=
DIR   ?= .
TOP   ?= $(MOD)_tb
BUILD := $(DIR)/build
SRCS  := $(filter-out %_ring.sv,$(wildcard $(DIR)/*.sv))

.PHONY: sim clean

sim:
	verilator --binary --timing -j 0 -Mdir $(BUILD) --top-module $(TOP) $(SRCS)
	@$(BUILD)/V$(TOP)

clean:
	@rm -rf $(BUILD)

