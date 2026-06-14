# Netie Open HBM -- top-level Makefile
# This is a thin orchestrator. Real work lives in:
#   - hw/ip/<ip>/dv/Makefile         (cocotb sims)
#   - hw/ip/<ip>/fpv/<ip>.sby        (formal proofs)
#   - pd/sc_flows/<target>.py        (SiliconCompiler flows)
#   - tools/agent_eval/harness/run.py (agent eval harness)
#
# Run `make help` to see the surface area.

# Prefer repo venv Python (has rich, cocotb, etc.); never use system pip on PATH.
PY              ?= $(firstword $(wildcard .venv/bin/python3) $(wildcard .venv/bin/python) python3)
UV              ?= uv
VERILATOR       ?= verilator
YOSYS           ?= yosys
SBY             ?= sby
VERIBLE_LINT    ?= verible-verilog-lint
COCOTB_MAKE     ?= make
SC              ?= sc

ALL_RTL := $(shell find hw/ip hw/subsystems hw/top hw/formal hw/vip -name '*.sv' 2>/dev/null)

.PHONY: help install lint synth-check sim formal pd agent-eval smoke clean

help:
	@echo "Netie Open HBM make targets:"
	@echo ""
	@echo "  install                       -- install Python deps via uv"
	@echo "  lint                          -- verible-verilog-lint over hw/"
	@echo "  synth-check                   -- yosys hierarchy -check on every IP"
	@echo "  sim       TOP=<ip>            -- cocotb regression (Verilator) for one IP"
	@echo "  sim-all                       -- cocotb regression for every IP"
	@echo "  formal    TOP=<ip>            -- SymbiYosys BMC + PROVE for one IP"
	@echo "  pd        FLOW=<target> TOP=<ip>"
	@echo "                                -- SiliconCompiler flow (sky130, ihp130, asap7,"
	@echo "                                   freepdk45, ieda_sky130) for one IP"
	@echo "  agent-eval PROMPT=<path>      -- run the AI-agent eval harness"
	@echo "  smoke                         -- minimum-effort end-to-end sanity"
	@echo "  clean                         -- remove build artefacts"
	@echo ""
	@echo "Examples:"
	@echo "  make sim TOP=addr_map"
	@echo "  make formal TOP=addr_map"
	@echo "  make pd FLOW=asap7 TOP=addr_map"
	@echo "  make agent-eval PROMPT=docs/agent-prompts/addr_map.md"

install:
	$(UV) sync

lint:
	@echo "[lint] verible over hw/"
	@$(VERIBLE_LINT) --rules_config_search $(ALL_RTL) || (echo "[lint] FAILED"; exit 1)
	@echo "[lint] OK"

synth-check:
	@for ip in $$(ls hw/ip); do \
	  echo "[synth-check] $$ip"; \
	  $(YOSYS) -q -p "read_verilog -sv hw/ip/$$ip/rtl/*.sv 2>/dev/null; hierarchy -check; proc; opt; check" \
	    || (echo "[synth-check] FAILED: $$ip"; exit 1); \
	done
	@echo "[synth-check] OK"

sim:
ifndef TOP
	$(error sim requires TOP=<ip>; e.g. make sim TOP=addr_map)
endif
	$(COCOTB_MAKE) -C hw/ip/$(TOP)/dv

sim-all:
	@for ip in $$(ls hw/ip); do \
	  if [ -d hw/ip/$$ip/dv ]; then \
	    echo "[sim] $$ip"; \
	    $(COCOTB_MAKE) -C hw/ip/$$ip/dv || exit 1; \
	  fi; \
	done

formal:
ifndef TOP
	$(error formal requires TOP=<ip>)
endif
	@for sby in hw/ip/$(TOP)/fpv/*.sby; do \
	  if [ -f "$$sby" ]; then \
	    echo "[formal] $$sby"; \
	    $(SBY) -f "$$sby" || exit 1; \
	  fi; \
	done

pd:
ifndef FLOW
	$(error pd requires FLOW=<target>; one of sky130, ihp130, asap7, freepdk45, ieda_sky130)
endif
ifndef TOP
	$(error pd requires TOP=<ip>)
endif
	$(PY) pd/sc_flows/runner.py --flow $(FLOW) --top $(TOP)

agent-eval:
ifndef PROMPT
	$(error agent-eval requires PROMPT=<path-to-prompt.md>)
endif
	$(PY) tools/agent_eval/harness/run.py --prompt $(PROMPT)

smoke:
	@echo "[smoke] checking toolchain..."
	@command -v $(YOSYS)        >/dev/null 2>&1 || { echo "MISSING: yosys"; exit 1; }
	@command -v $(VERILATOR)    >/dev/null 2>&1 || { echo "MISSING: verilator"; exit 1; }
	@command -v $(SBY)          >/dev/null 2>&1 || { echo "MISSING: sby"; exit 1; }
	@command -v $(VERIBLE_LINT) >/dev/null 2>&1 || { echo "MISSING: verible-verilog-lint"; exit 1; }
	@$(YOSYS) -V        | head -n 1
	@$(VERILATOR) --version | head -n 1
	@$(SBY) --version   | head -n 1
	@echo "[smoke] toolchain OK"

clean:
	@find . -name 'sim_build' -type d -exec rm -rf {} + 2>/dev/null || true
	@find . -name 'obj_dir'   -type d -exec rm -rf {} + 2>/dev/null || true
	@find . -name '__pycache__' -type d -exec rm -rf {} + 2>/dev/null || true
	@find . -name '*.vcd' -delete 2>/dev/null || true
	@find . -name '*.fst' -delete 2>/dev/null || true
	@rm -rf build/
	@echo "[clean] done"
