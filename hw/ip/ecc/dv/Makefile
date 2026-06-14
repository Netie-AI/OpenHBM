# Copyright 2026 The Netie Open HBM Authors
# SPDX-License-Identifier: Apache-2.0

SIM ?= verilator
TOPLEVEL_LANG ?= verilog
TOPLEVEL = ecc
MODULE   = test_ecc

export PYTHONPATH := $(CURDIR)/tests$(if $(PYTHONPATH),:$(PYTHONPATH),)
export COCOTB_RESULTS_FILE := $(CURDIR)/results.xml

VERILOG_SOURCES = \
  $(PWD)/../rtl/ecc_pkg.sv \
  $(PWD)/../rtl/ecc_encode.sv \
  $(PWD)/../rtl/ecc_decode.sv \
  $(PWD)/../rtl/ecc.sv

COMPILE_ARGS += -Wno-fatal
EXTRA_ARGS += -Wno-fatal -I$(PWD)/../rtl

CUSTOM_COMPILE_DEPS += $(CURDIR)/Makefile

include $(shell cocotb-config --makefiles)/Makefile.sim
