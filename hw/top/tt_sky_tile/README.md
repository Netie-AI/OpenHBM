# `hw/top/tt_sky_tile` -- Tiny Tapeout TTSKY26b submission

Phase-2 community rite-of-passage tile per `Plan.md` s3 Phase 2.

The tile carries:

- An 8-bit Galois LFSR (taps `x^8 + x^6 + x^5 + x^4 + 1`) seeded by `ui_in`.
- A tiny multiply-accumulate (4 bit x 4 bit -> 8 bit) of the LFSR halves.

It is intentionally tiny so it fits in a 1x1 TTSKY26b tile and gets us
silicon faster than any single full IP from `hw/ip/`. The full
implementation of any IP in this repo is too large for Tiny Tapeout's
~150 mu**2 budget.

## Building

```bash
make -C hw/top/tt_sky_tile harden     # invokes the Tiny Tapeout harness
```

This wraps the SkyWater 130 PD flow (`pd/sc_flows/sky130.py`) for the
TTSKY26b template and produces the GDS the Tiny Tapeout submission
tooling expects.

## Why TTSKY26b not TTSKY26a

Plan.md s3 Phase 2 picks the b-cycle so we have time to land the full
addr_map and ecc cocotb regressions before submitting.
