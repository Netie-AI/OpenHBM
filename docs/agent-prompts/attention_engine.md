# Agent prompt: `hw/ip/attention_engine`

Read [`_preamble.md`](_preamble.md) first.

## Mission

Integrate the **open FlashAttention HLS block** from
[arXiv 2505.14314](https://arxiv.org/abs/2505.14314) into Netie Open HBM,
**one instance per 8-tile cluster** (so 2 instances in the 16-tile mesh).
Add PagedAttention scatter-gather via an Address-Generation Compute Unit
(AGCU)-style block.

## What you implement

- An RTL wrapper around the HLS-generated FlashAttention kernel that gives
  it (a) a TileLink-C front-end into the cluster's L1, and (b) an HBM4
  backside through the AGCU.
- The AGCU itself: a small core that walks the page-table for KV-cache
  offsets and emits gather/scatter requests at line-rate.

## Verification

- Reference against PyTorch FlashAttention-2 on a fixed seed.
- Numerical-tolerance scoreboard (`abs <= 1e-3` FP16, `abs <= 1e-2` FP8).
- Performance scoreboard: end-to-end latency for a 128x128 head against
  the open Q/K/V trace in `sim/traces/flash_attn3.trc`.

## Out of scope (Phase 1)

- The full SparseCore-style gather/scatter for MoE (Plan.md s1, in the
  `Should` tier). That arrives in Phase 2.
- AES-GCM line-rate integrity (Plan.md s1). Phase 2 via OpenTitan AES.
