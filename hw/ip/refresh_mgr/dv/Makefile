SIM ?= verilator
TOPLEVEL_LANG ?= verilog
TOPLEVEL = refresh_mgr
MODULE   = test_refresh_mgr,test_rowhammer_adv

PRAC_THRESH ?= 24
export PRAC_THRESH
# cocotb imports test_refresh_mgr / test_rowhammer_adv by module name
export PYTHONPATH := $(CURDIR)/tests$(if $(PYTHONPATH),:$(PYTHONPATH),)

VERILOG_SOURCES = \
  $(PWD)/../rtl/refresh_mgr_pkg.sv \
  $(PWD)/../rtl/refresh_mgr.sv

COMPILE_ARGS += -Wno-fatal
EXTRA_ARGS += -Wno-fatal
ifeq ($(SIM),verilator)
EXTRA_ARGS += -GPracThresh=$(PRAC_THRESH)
endif
ifeq ($(SIM),icarus)
COMPILE_ARGS += -gno-assertions
EXTRA_ARGS += -Prefresh_mgr.PracThresh=$(PRAC_THRESH)
endif

# Re-run Verilator when this Makefile changes (PRAC_THRESH / EXTRA_ARGS).
CUSTOM_COMPILE_DEPS += $(CURDIR)/Makefile

include $(shell cocotb-config --makefiles)/Makefile.sim
