# Copyright 2026 The Netie Open HBM Authors
# SPDX-License-Identifier: Apache-2.0

SIM ?= verilator
TOPLEVEL_LANG ?= verilog
TOPLEVEL = hbm4_ctrl
MODULE   = test_hbm4_ctrl

export PYTHONPATH := $(CURDIR)/tests$(if $(PYTHONPATH),:$(PYTHONPATH),)
export COCOTB_RESULTS_FILE := $(CURDIR)/results.xml
export PYTHONUNBUFFERED := 1

VERILOG_SOURCES = \
  $(CURDIR)/../rtl/hbm4_ctrl_axi4_pkg.sv \
  $(CURDIR)/../rtl/hbm4_ctrl_pkg.sv \
  $(CURDIR)/../rtl/hbm4_ctrl_axi4_slave.sv \
  $(CURDIR)/../rtl/hbm4_ctrl_bank_fsm.sv \
  $(CURDIR)/../rtl/hbm4_ctrl_scheduler.sv \
  $(CURDIR)/../rtl/hbm4_ctrl.sv

COMPILE_ARGS += --threads 20
EXTRA_ARGS += -Wno-fatal \
  -GP_BANK_GROUPS=4 -GP_BANKS_PER_BG=4 -GP_ROW_W=15 -GP_COL_W=6 \
  -GP_T_RCD=4 -GP_T_RAS=10 -GP_T_RP=4 -GP_T_RC=14

CUSTOM_COMPILE_DEPS += $(CURDIR)/Makefile

include $(shell cocotb-config --makefiles)/Makefile.sim
