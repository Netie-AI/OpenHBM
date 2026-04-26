# Agent prompt: `hw/ip/accel_core`

Read [`_preamble.md`](_preamble.md) first.

## Mission

Instantiate **16 LPU tiles** in a 4x4 mesh, each tile containing:

- One `redmule_systolic` (FP16/FP8, 32x32 MACs) -- vendored from
  `hw/vendor/pulp_redmule/`.
- One SFPU (special function: exp/log/softmax) at a 1:2 op:MAC ratio.
- Five RISC-V "baby" cores (CV32E40X-class) -- one each for unpack,
  math, pack, and two data-movement engines.
- 1.5 MiB L1 scratchpad with HCI-style streamers.
- Two NoC ports (north/south or east/west routing).

The tile NoC is a 2D-mesh TileLink-C fabric. Tile programming model is
reader / compute / writer, like Tenstorrent's `tt-metal`.

## What lives in this IP

- The tile **wrapper** that ties RedMulE + SFPU + 5 babies + scratchpad +
  NoC ports together.
- The **mesh top** that instantiates the 4x4 grid and the inter-tile
  links.
- The **CSR block** for tile-level configuration (mesh address, debug
  taps, performance counters).

## What does NOT live here

- The compiler backend -- that is `sw/tvm_backend/`.
- The HBM4 controller interface -- that is `hw/subsystems/compute_ss/`,
  which connects the mesh edge to the controller.

## Phase 1 deliverable

A single-tile elaboration that runs a hand-written matmul kernel against a
ROM-loaded weight tensor, with cocotb scoreboarding against a NumPy
reference. The mesh wrapper is structural-only (16 instances + connect)
in Phase 1.

## Reference reading

- PULP RedMulE paper (TCAS 2023).
- Tenstorrent Tensix architecture (Hot Chips 2023, Hot Chips 2024).
- Open FlashAttention HLS block (arXiv 2505.14314) -- to be integrated
  per `attention_engine.md`.
