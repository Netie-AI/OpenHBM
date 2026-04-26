# Netie Open HBM

> The RISC-V of memory and AI accelerators.

An open-source, JEDEC JESD270-4A-compliant HBM4 memory subsystem (controller +
PHY-shim + DFT + RAS + security wrapper) tightly coupled to an open RISC-V-native
LPU accelerator. Apache-2.0 RTL, CERN-OHL-W-2.0 analog/GDSII, trademark-controlled
compatibility certification.

## Status

**Phase 0 (months 0-3)** -- founder ramp and public commitment. Repository skeleton,
toolchain pinning, and Track-A/B/C bootstrap landing. See [Plan.md](Plan.md) for the
36-month strategic plan and
[`.cursor/plans/openhbm4_automation_and_pipeline_bootstrap_*.plan.md`](.cursor/plans/)
for the current execution plan.

## What this is

A simulation-first, verification-grade HBM4 controller + 16-tile RISC-V LPU
reference design that:

- Conforms to JEDEC JESD270-4A (32 channels x 2 pseudo-channels x 2048-bit DFI)
- Runs end-to-end on a laptop via Verilator + cocotb + a clean-room HBM4 BFM
  (`hw/vip/dramsim4/`, fork of DRAMsim3)
- Synthesises through OpenROAD (and iEDA as second source) on SkyWater 130,
  IHP SG13G2, and ASAP7 7nm FinFET predictive PDK
- Emulates on Alveo U55C / U280 via the AMD HACC cluster
- Ships with an AI-agent training pipeline (`tools/agent_eval/`) that turns
  agent-authored RTL into a numeric CI gate (lint -> sim -> coverage -> formal
  -> mutation -> score)

## Repository layout

```text
netie-open-hbm/
  CLAUDE.md AGENTS.md LICENSE NOTICE README.md
  flake.nix .devcontainer/
  .github/workflows/         # CI: lint, sim, formal, fpga, asic, agent-eval, chiplet
  docs/                      # spec, arch, rfcs, agent-prompts, legal, grants
  hw/ip/                     # leaf IP blocks
    addr_map/                # LIGHTHOUSE: programmable XOR address mapping
    hbm4_ctrl/               # HBM4 controller (LiteDRAM-fork structure)
    hbm4_phy_shim/           # DFI-compatible PHY boundary
    ecc/                     # SEC-DED Hsiao + Reed-Solomon chipkill
    refresh_mgr/             # DRFM + PRAC counters
    cdc/                     # clock-domain-crossing primitives
    mbist_wrapper/           # IEEE 1500 + IJTAG 1687 wrapper
    accel_core/              # 16-tile RedMulE-style LPU
    prim_generic/            # technology-agnostic primitives
  hw/subsystems/             # mem_ss, compute_ss, io_ss
  hw/top/                    # chiplet, monolithic, tt_sky_tile, tt_ihp_tile
  hw/vendor/                 # vendored deps (via util/vendor.py)
  hw/vip/                    # dramsim4, axi_vip, dfi_vip
  hw/formal/                 # cross-module SVA library
  fpga/                      # alveo_u55c, alveo_u280, vck5000
  syn/                       # yosys, dc
  pd/                        # ORFS / Innovus / SiliconCompiler flows
    sc_flows/                # python flows: sky130, ihp130, asap7, freepdk45, ieda_sky130
    cells/                   # xschem, ngspice, magic, klayout custom-cell pipeline
    chiplet/ipl3d/           # iPL-3D die-to-die placement
  pkg/openems/               # organic-substrate flip-chip 3D EM screening
  sw/                        # tvm_backend, drivers, firmware, benchmarks
  sim/                       # cocotb runners, traces (vLLM, FlashAttn-3, SGLang)
  tools/agent_eval/          # AI-agent RTL evaluation harness
  util/                      # vendor.py, reggen, testplanner, dvsim
  ci/                        # reusable workflow fragments
  scripts/                   # operational scripts
  third_party/               # external sources not vendored as dependencies
```

## Pinned toolchain

| Tool                  | Version     | Source                                          |
| --------------------- | ----------- | ----------------------------------------------- |
| OSS CAD Suite         | 2026-04-02  | https://github.com/YosysHQ/oss-cad-suite-build  |
| Verilator             | 5.046+      | bundled in OSS CAD Suite                        |
| cocotb                | 2.0.1       | pip                                              |
| pyuvm                 | 4.0.1       | pip                                              |
| SiliconCompiler       | 0.34.0      | pip                                              |
| ASAP7 PDK             | r1p7        | https://github.com/The-OpenROAD-Project/asap7   |
| SkyWater 130 PDK      | latest      | https://github.com/google/skywater-pdk          |
| IHP SG13G2 PDK        | latest      | https://github.com/IHP-GmbH/IHP-Open-PDK        |
| iEDA (second-source)  | docker tag `iedaopensource/release:latest` | https://github.com/OSCC-Project/iEDA |
| JESD270-4A            | v1.1 (Dec 2025) | JEDEC free registration                     |

## Getting started

```bash
nix develop                                           # or: devcontainer up
make lint                                              # verible
make sim TOP=addr_map                                  # cocotb x Verilator
make formal TOP=addr_map                               # SymbiYosys
make pd FLOW=asap7 TOP=addr_map                        # SiliconCompiler -> ASAP7
make agent-eval PROMPT=docs/agent-prompts/addr_map.md  # gate threshold 80/100
```

See [`docs/getting_started.md`](docs/getting_started.md) and the per-IP `doc/`
directories.

## License

- RTL: Apache-2.0 (this file's [LICENSE](LICENSE))
- Analog / mixed-signal PHY / GDSII: CERN-OHL-W-2.0 (forthcoming, see
  `hw/ip/hbm4_phy_shim/LICENSE`)
- Documentation: CC-BY-4.0
- Trademark: "Netie Open HBM Compatible(TM)" -- compatibility certification mark,
  managed per [`docs/legal/trademark_policy.md`](docs/legal/trademark_policy.md)

Every commit must carry a Developer Certificate of Origin sign-off
(`git commit -s`). For larger contributions an ICLA will be required before
silicon-bound RTL freeze; see [`docs/CONTRIBUTING.md`](docs/CONTRIBUTING.md).

## Citation

```bibtex
@misc{netie_open_hbm_2026,
  title  = {Netie Open HBM: an open, JEDEC-compliant HBM4 controller and RISC-V-native LPU},
  author = {{The Netie Open HBM Authors}},
  year   = {2026},
  howpublished = {\url{https://github.com/netie-open-hbm/netie-open-hbm}},
  note   = {arXiv preprint forthcoming}
}
```
