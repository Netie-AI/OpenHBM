# Architecture overview

Netie Open HBM at one glance.

```mermaid
flowchart TB
    subgraph host [Host]
      cpu[CPU + DMA]
    end

    subgraph chip [Netie Open HBM SoC]
      addr[addr_map]
      ctrl[hbm4_ctrl]
      ecc[ecc]
      ref[refresh_mgr]
      phy[hbm4_phy_shim]
      lpu[accel_core: 16 LPU tiles]
      noc[NoC: TileLink-C 4x4 mesh]
    end

    subgraph mem [HBM4 stack]
      hbm[(32 ch x 2 pCh x 16 banks)]
    end

    cpu -- AXI4 + APB --> addr
    addr --> ctrl
    ref --> ctrl
    ecc --> ctrl
    ctrl -- DFI --> phy
    phy <--> hbm

    cpu -- TileLink-C --> noc
    noc <--> lpu
    lpu -- AXI4 --> ctrl
```

## Reading order

1. `Plan.md` -- the 36-month strategic plan.
2. `docs/arch/overview.md` -- this file.
3. `docs/spec/hbm4_timing.adoc` -- clean-room HBM4 timing summary.
4. `docs/agent-prompts/<ip>.md` -- per-IP agent prompts.
5. `hw/ip/<ip>/doc/<ip>.md` -- per-IP detail.

## Cross-cutting concerns

| Concern              | Where it lives                                    |
| -------------------- | ------------------------------------------------- |
| Style contract       | `CLAUDE.md`, `AGENTS.md`                          |
| Toolchain            | `flake.nix`, `.devcontainer/`, `pyproject.toml`   |
| CI                   | `.github/workflows/`                              |
| Verification harness | `tools/agent_eval/`                               |
| Open EDA flows       | `pd/sc_flows/`                                    |
| Custom cells         | `pd/cells/`                                       |
| Packaging screening  | `pkg/openems/`                                    |
| Export-control posture | `docs/legal/export_control.md`                  |
