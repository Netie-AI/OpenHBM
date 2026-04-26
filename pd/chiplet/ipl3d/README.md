# `pd/chiplet/ipl3d` -- die-to-die placement via iPL-3D

iPL-3D (ICCAD 2023, "A Novel Bilevel Programming Model for Die-to-Die
Placement") is the placer in the iEDA toolchain. We use it to place a
two-die partition with an organic-substrate bridge, the cleanest open
analogue to TSMC CoWoS within reach for an open project.

First target: split `hw/ip/addr_map` (die A) from `hw/ip/ecc` (die B)
across an ASE-Penang-style bridge floorplan. The output DEF feeds
`pkg/openems/run_screen.py` for SI screening.

## Why two dies?

- It exercises the full chiplet placement flow on a workload we already
  ship (`addr_map` and `ecc` both have golden refs and SymbiYosys
  proofs).
- It produces a non-trivial inter-die signal pattern (the controller's
  data path crosses the bridge) so the SI screen is meaningful.
- It is small enough that the placer terminates in minutes.

## Status

Phase-0 scaffolding only. The runner stubs out an iEDA Docker invocation
and produces a placeholder DEF; the real placement run lands once
`hw/ip/addr_map` is fully synthesised (Phase 1) AND iEDA's `iPL-3D`
demo flow is reproduced from the upstream repo.

See `docs/legal/export_control.md` for the usage posture.
