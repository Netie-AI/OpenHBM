# Custom-cell pipeline:
#   xschem schematic -> ngspice netlist -> magic layout -> klayout DRC ->
#   netgen LVS -> klayout GDS export.
#
# The flow uses PDK-installed model libraries; default is sky130A. Swap
# PDK=asap7 for the FinFET fallback (BSIM-CMG models drop into ngspice).

PDK ?= sky130
CELL ?= xor2

XSCHEM_RC := xschem/xschemrc.$(PDK)
NGSPICE_LIB := $(PDK_ROOT)/$(PDK)/libs.tech/ngspice/sky130.lib.spice
MAGIC_RC := magic/magicrc.$(PDK)
KLAYOUT_DRC := klayout/$(PDK)_drc.lydrc
NETGEN_RC := netgen/setup.$(PDK)

BUILD := build/$(PDK)/$(CELL)

.PHONY: help schem netlist sim layout drc lvs gds clean

help:
	@echo "Usage:"
	@echo "  make CELL=<cell> schem      # open xschem"
	@echo "  make CELL=<cell> sim        # run ngspice corner sweep + Monte-Carlo"
	@echo "  make CELL=<cell> layout     # open magic"
	@echo "  make CELL=<cell> drc        # klayout DRC"
	@echo "  make CELL=<cell> lvs        # netgen LVS schematic <-> layout"
	@echo "  make CELL=<cell> gds        # produce build/<pdk>/<cell>/<cell>.gds"

schem:
	xschem -rcfile $(XSCHEM_RC) xschem/$(CELL).sch

netlist:
	mkdir -p $(BUILD)
	xschem -rcfile $(XSCHEM_RC) -n -o $(BUILD)/$(CELL).spice xschem/$(CELL).sch

sim: netlist
	ngspice -b -o $(BUILD)/$(CELL).log ngspice/$(CELL).sp

layout:
	magic -rcfile $(MAGIC_RC) magic/$(CELL).mag

drc:
	klayout -b -r $(KLAYOUT_DRC) -rd input=$(BUILD)/$(CELL).gds -rd report=$(BUILD)/$(CELL).drc.xml

lvs:
	netgen -batch lvs $(BUILD)/$(CELL).spice $(BUILD)/$(CELL).layout.spice $(NETGEN_RC) $(BUILD)/$(CELL).lvs.log

gds:
	klayout -b klayout/$(CELL).lyt -rd cell=$(CELL) -rd output=$(BUILD)/$(CELL).gds

clean:
	rm -rf build/
