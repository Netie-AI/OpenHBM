# Agent prompt: `hw/ip/mbist_wrapper`

Read [`_preamble.md`](_preamble.md) first.

## Mission

Wrap every memory macro instantiated in the design with **IEEE 1500** test
isolation and an **IEEE 1687 (IJTAG)** access network. Provide
March-C+ and TSV-continuity BIST patterns. Gate all DFT under the
OpenTitan **lifecycle TEST_UNLOCKED** state -- BIST may not run in
production silicon without an explicit lifecycle-state-controlled enable.

## Required modes

- **March-C+ algorithm** for SRAM/scratchpad fault detection.
- **TSV continuity** for the through-silicon-via array between the HBM4
  base die conceptual model and the LPU (Phase 4 only -- Phase 1 ships
  an RTL stub).
- **Self-repair hooks** to a row-redundancy table (placeholder; Phase 2).

## Required SVA

- DFT signals MUST be `'0` (off) when lifecycle != TEST_UNLOCKED.
- BIST done flag MUST go high within a parameterised `BIST_MAX_CYCLES`
  bound for any pattern.

## Reference reading

- IEEE 1500 SECT spec.
- OpenTitan lifecycle controller (vendored under `hw/vendor/lowrisc_prim/`).
