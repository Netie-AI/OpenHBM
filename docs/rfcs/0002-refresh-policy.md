# ADR 0002 — DRFM deferral, Misra-Gries PRAC, and refresh liveness proofs

## Status

Accepted (v0.1 IP bring-up)

## Context

`hw/ip/refresh_mgr` is the rowhammer-mitigation façade that turns per-bank
activation pressure into DRFM issuance plus early warning through PRAC
tracking. The Phase-1 sprint needs a verifiable story for:

- deterministic, finite state (no hidden refresh state in the controller shim);
- bounded deferral measured in abstract DRAM clock grains; and
- a formal artifact that reviewers can gate before `hbm4_ctrl` integration.

## Decision

1. **Misra-Gries top-$K$ tracker** with fixed $K = 64$, one table per $(BG,BA)$
   bank under the open port layout (16 banks pseudo-channel local). This is
   the Plan.review.md pending review item; downgrade to $K = 32$ requires a new
   ADR if GPT-5.5 redlines Plan.review §2-B.
2. **Aging** subtracts one from every populated counter on each `tREFW` tick
   input. This approximates `tREFW` credit return for the abstracted PRAM
   estimator without importing JEDEC numerics into RTL.
3. **DRFM completion** (`drfm_ack_i` while sticky `drfm_pending`) removes the
   latched hot row from the PRAC table *and* consumes one per-bank refresh
   credit. This models the controller + PHY pipeline finishing a DRFM scrub
   targeted at the offending row.
4. **Credit replenishment** restores all banks to `CreditMax` on each
   `tREFW` tick. Returned credits from the scheduler use the single
   `credit_release_i` shim: if a sticky request is active, credit returns to
   that bank; otherwise the first PRAC hit bank in enumeration order receives
   the credit; if no hit exists, bank 0 absorbs the pulse (harmless no-op when
   saturated).
5. **Formal** `fpv/refresh_liveness.sby` proves a bounded pending-streak lemma
   under fairness assumptions documented below. The lemma is not the DRAM
   analogue of full `tREFW` closure—controller integration will add the
   DRAM-side timer closure—but it is the latch-point proof that DRFM backlog
   cannot grow unbounded faster than the downstream scheduler can accept it.

## Formal fairness bundle

`fpv/refresh_liveness.sv` encodes:

- **periodic `tREFW` ticks** spaced `T_REFI_CYCLES` abstract DRAM clocks apart
  (default 48 in the wrapper, making `PendBound = 96 = 2 * tREFI_abs` at that
  grain);
- **scheduler fairness** `(drfm_pending |=> ##[1:14] drfm_ack)` forcing the
  environment to close the handshake once the IP requests help;
- **bounded streak** `pend_streak < PendBound` where `pend_streak` increments
  whenever `drfm_pending && !drfm_ack`.

The companion `fpv/abs_bank_machine.sv` file is intentionally port-free: it
documents that activation traffic remains arbitrary aside from the fairness
guarantees named above.

## Consequences

- Cocotb + golden model tests must match the exact sequencing of ack → decay →
  activation → re-arm to stay cycle-accurate with RTL.
- Silicon integration must extend this proof with DRAM-retention timers owned by
  `hbm4_ctrl`; those timers are out of scope for refresh_mgr v0.1.

## References

- `docs/spec/hbm4_timing.adoc` §DRFM (clean-room summary).
- ISCA 2025 DREAM (DRFM overhead motivation).
- Plan.md §4 agent prompt for `refresh_mgr`.
