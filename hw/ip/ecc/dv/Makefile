SIM ?= verilator
TOPLEVEL_LANG ?= verilog
TOPLEVEL = ecc
MODULE   = test_ecc

VERILOG_SOURCES = \
  $(PWD)/../rtl/ecc_pkg.sv \
  $(PWD)/../rtl/ecc_secded.sv \
  $(PWD)/../rtl/ecc_chipkill.sv \
  $(PWD)/../rtl/ecc.sv

include $(shell cocotb-config --makefiles)/Makefile.sim
