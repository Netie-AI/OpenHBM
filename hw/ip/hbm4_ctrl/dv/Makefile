# Copyright 2026 The Netie Open HBM Authors
# SPDX-License-Identifier: Apache-2.0

SIM ?= verilator
TOPLEVEL_LANG ?= verilog
TOPLEVEL = hbm4_ctrl
MODULE   = test_hbm4_ctrl

# Prevent venv PYTHONHOME from conflicting with oss-cad Python 3.11
unexport PYTHONHOME
unexport PYTHONPATH

export PYTHONPATH := $(CURDIR)/tests:$(PYTHONPATH)
export COCOTB_RESULTS_FILE := $(CURDIR)/results.xml
export PYTHONUNBUFFERED := 1

VERILOG_SOURCES = \
  $(CURDIR)/../rtl/hbm4_ctrl_dfi_pkg.sv \
  $(CURDIR)/../rtl/hbm4_ctrl_axi4_pkg.sv \
  $(CURDIR)/../rtl/hbm4_ctrl_pkg.sv \
  $(CURDIR)/../rtl/hbm4_ctrl_axi4_slave.sv \
  $(CURDIR)/../rtl/hbm4_ctrl_bank_fsm.sv \
  $(CURDIR)/../rtl/hbm4_ctrl_scheduler.sv \
  $(CURDIR)/../rtl/hbm4_ctrl_dfi_bridge.sv \
  $(CURDIR)/../rtl/hbm4_ctrl_pwrdn.sv \
  $(CURDIR)/../rtl/hbm4_ctrl_trefi_ctrl.sv \
  $(CURDIR)/../rtl/hbm4_ctrl_training.sv \
  $(CURDIR)/../rtl/hbm4_ctrl_ras.sv \
  $(CURDIR)/../rtl/hbm4_ctrl_pmu.sv \
  $(CURDIR)/../rtl/hbm4_ctrl_chan_top.sv \
  $(CURDIR)/../rtl/hbm4_ctrl.sv \
  $(CURDIR)/model/hbm4_phy_model.sv \
  $(CURDIR)/model/hbm4_dram_model.sv

# Default 4 channels so P2 multichan tests exercise real RTL (not vacuous skip).
# Scale to 16 via: make NUM_CHANNELS=16
NUM_CHANNELS ?= 4
export NUM_CHANNELS
EXTRA_ARGS += -Wno-fatal -GNUM_CHANNELS=$(NUM_CHANNELS) \
  -GBANK_GROUPS=4 -GBANKS_PER_BG=4 -GROW_W=15 -GCOL_W=6 \
  -GT_RCD=4 -GT_RAS=10 -GT_RP=4 -GT_RC=14

CUSTOM_COMPILE_DEPS += $(CURDIR)/Makefile

# Pre-flight: fail fast if oss-cad verilator is not on PATH
.PHONY: check-env
check-env:
	@which verilator | grep -q oss-cad || \
	  (echo "ERROR: oss-cad verilator not on PATH. Run:" && \
	   echo "  source ~/oss-cad-suite/environment" && \
	   echo "  source ~/OpenHBM/.venv/bin/activate" && \
	   exit 1)
	@echo "Environment OK: $$(verilator --version | head -1)"

.PHONY: clean-results
clean-results:
	rm -f results.xml
	rm -rf sim_build

include $(shell cocotb-config --makefiles)/Makefile.sim

.DEFAULT_GOAL := all

sim: check-env
$(COCOTB_RESULTS_FILE): check-env
sim: export PYTHONPATH := $(CURDIR)/tests:$(PYTHONPATH)

.PHONY: elab-multichan test-multichan

elab-multichan:
	verilator --lint-only -sv -Wno-fatal -GNUM_CHANNELS=4 \
	  $(VERILOG_SOURCES) 2>&1 | grep -E "Error|Warning" | head -20

test-multichan:
	rm -rf sim_build
	$(MAKE) SIM=verilator NUM_CHANNELS=4 COCOTB_TEST_FILTER=test_multichan
