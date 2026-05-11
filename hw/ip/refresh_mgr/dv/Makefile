SIM ?= verilator
TOPLEVEL_LANG ?= verilog
TOPLEVEL = refresh_mgr
MODULE   = test_refresh_mgr,test_rowhammer_adv

PRAC_THRESH ?= 24

VERILOG_SOURCES = \
  $(PWD)/../rtl/refresh_mgr_pkg.sv \
  $(PWD)/../rtl/refresh_mgr.sv

COMPILE_ARGS += -Wno-fatal
EXTRA_ARGS += -Wno-fatal
VERILATOR_ARGS += -GPracThresh=$(PRAC_THRESH)

include $(shell cocotb-config --makefiles)/Makefile.sim
