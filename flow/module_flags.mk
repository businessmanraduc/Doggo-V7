# =================================================================================
#  module_flags.mk -- per-module tool flag policy
# =================================================================================

FLAGS_POLICY ?= on

# ---- reduction-shaped: -nowidelut wins ------------------------------------------
YOSYS_align         := -nowidelut     # +18.73   191.66 -> 210.39
YOSYS_dispatch_fifo := -nowidelut     # +10.32   219.19 -> 229.51
YOSYS_icache        := -nowidelut     #  +9.77   196.35 -> 206.12
YOSYS_legal32       := -nowidelut     #  +4.38   191.99 -> 196.37
YOSYS_shifter       := -nowidelut     #  +3.84   200.88 -> 204.72
YOSYS_decoder       := -nowidelut     #  +3.75   182.16 -> 185.91
YOSYS_fetch_ctrl    := -nowidelut     #  +2.86   259.43 -> 262.29
YOSYS_fetch_engine  := -nowidelut     #  +2.12   133.03 -> 135.15
YOSYS_rvc_expand    := -nowidelut     #  +1.70   192.45 -> 194.15

# ---- selection-shaped: wide muxes win -------------------------------------------
YOSYS_alu           :=                # -44.65   183.99 -> 139.34
YOSYS_regfile       :=                # -13.83   276.98 -> 263.15
YOSYS_rob           :=                # -11.48   185.99 -> 174.51
YOSYS_fetch_queue   :=                #  -9.08   191.17 -> 182.09
YOSYS_rat           :=                #  -8.96   175.18 -> 166.22
YOSYS_linefill      :=                #  -6.13   216.58 -> 210.45

# ---- BSRAM-bound: no flag moves these -------------------------------------------
YOSYS_bpredict      :=                #  decoupled engine
YOSYS_btb           :=                #  banked 2-word
YOSYS_pht           :=                #  2-word

# ---- resolution, evaluated once MOD is known ------------------------------------
ifeq ($(FLAGS_POLICY),on)
  MOD_YOSYS_FLAGS = $(YOSYS_$(MOD)) $(YOSYS_EXTRA)
  MOD_PNR_FLAGS   = $(PNR_$(MOD)) $(PNR_EXTRA)
else
  MOD_YOSYS_FLAGS = $(YOSYS_EXTRA)
  MOD_PNR_FLAGS   = $(PNR_EXTRA)
endif

