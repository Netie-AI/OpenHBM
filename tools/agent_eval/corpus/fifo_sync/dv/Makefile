SIM ?= verilator
TOPLEVEL_LANG ?= verilog
TOPLEVEL = fifo_sync
MODULE   = test_fifo_sync

VERILOG_SOURCES = $(PWD)/../rtl/fifo_sync.sv

# cocotb has its own boilerplate
include $(shell cocotb-config --makefiles)/Makefile.sim
