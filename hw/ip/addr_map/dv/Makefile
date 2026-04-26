SIM ?= verilator
TOPLEVEL_LANG ?= verilog
TOPLEVEL = addr_map
MODULE   = test_addr_map

VERILOG_SOURCES = \
  $(PWD)/../rtl/addr_map_pkg.sv \
  $(PWD)/../rtl/addr_map_xor.sv \
  $(PWD)/../rtl/addr_map_region_table.sv \
  $(PWD)/../rtl/addr_map_reg_top.sv \
  $(PWD)/../rtl/addr_map.sv

include $(shell cocotb-config --makefiles)/Makefile.sim
