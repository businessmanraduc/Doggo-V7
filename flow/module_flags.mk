# =================================================================================
#  module_flags.mk -- per-module tool flag policy
# =================================================================================

FLAGS_POLICY ?= on

# ---- per-module entries: YOSYS_<mod> / PNR_<mod> --------------------------------

# ---- resolution, evaluated once MOD is known ------------------------------------
ifeq ($(FLAGS_POLICY),on)
  MOD_YOSYS_FLAGS = $(YOSYS_$(MOD)) $(YOSYS_EXTRA)
  MOD_PNR_FLAGS   = $(PNR_$(MOD)) $(PNR_EXTRA)
else
  MOD_YOSYS_FLAGS = $(YOSYS_EXTRA)
  MOD_PNR_FLAGS   = $(PNR_EXTRA)
endif

