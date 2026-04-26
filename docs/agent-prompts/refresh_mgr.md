# Agent prompt: `hw/ip/refresh_mgr`

Read [`_preamble.md`](_preamble.md) first.

## Mission

Implement DRAM Refresh Management (DRFM) with Per-Row Activation Counters
(PRAC) for HBM4 16-high stacks. This is the project's **publishable
research wedge** -- the ISCA 2025 DREAM paper showed 12-49% overhead in
current designs, and this block is where Netie Open HBM tries to do better.

## Functional spec

Inputs (per pseudo-channel):
- `act_valid_i`, `act_bank_i`, `act_row_i` -- activation events from the
  bank machine.
- `tref_window_tick_i` -- a coarse clock at the `tREFW` boundary.

Outputs (per pseudo-channel):
- `drfm_pending_o` -- DRFM should be issued for this pseudo-channel.
- `drfm_target_bank_o`, `drfm_target_row_o` -- which row to refresh.
- `prac_overflow_alert_o` -- a row exceeded the PRAC threshold; the
  rowhammer-detection alert handler must fire.

## Implementation notes

- **PRAC counters** use a Misra-Gries-style top-K table (default K=64) per
  bank to track most-frequently-activated rows. Aging policy: decay all
  counters by 1 per `tREFW`.
- **Credit-based deferral** per `Plan.md` s4. Each bank has a small credit
  pool (default 4) that the bank-machine spends to defer DRFM during
  KV-cache write bursts and weight-streaming reads.
- **Per-bank state** -- one PRAC table per (BG, BA) pair = 16 tables per
  pseudo-channel = 32 per channel.

## Required SVA / formal

- **Liveness**: no bank misses its `tREFW` window. Prove with SymbiYosys
  in `mode prove`. State space is bounded once you abstract the bank
  machine into a non-deterministic activation generator (write the
  abstraction in `fpv/abs_bank_machine.sv`).
- **No false PRAC overflow**: an alert fires only when the ground-truth
  activation count of some row exceeds the threshold within `tREFW`.

## Test plan

- **Adversarial fuzzing harness** (`dv/tests/test_rowhammer_adv.py`):
  emulate the USENIX Security 2025 16-high attacker model. Plot
  detection latency vs. row-pressure intensity.
- **Workload traces**: replay vLLM decode trace and confirm credit policy
  reduces stall percentage compared to a naive eager-refresh policy.

## Reference reading

- DREAM (ISCA 2025) -- DRFM overhead numbers.
- USENIX Security 2025 -- 16-high rowhammer attack model.
- JESD79-5 / JESD270-4A on the DRFM command itself.
