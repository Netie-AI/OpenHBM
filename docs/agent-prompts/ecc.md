# Agent prompt: `hw/ip/ecc`

Read [`_preamble.md`](_preamble.md) first.

## Mission

Implement multi-class ECC for HBM4 link and on-die error protection.
Selectable via the `ECC_CLASS` parameter:

| `ECC_CLASS`        | Code                              | Use case                                      |
| ------------------ | --------------------------------- | --------------------------------------------- |
| `ECC_SECDED`       | (72,64) Hsiao SEC-DED             | Default link ECC                              |
| `ECC_CHIPKILL`     | Reed-Solomon RS(8,4) byte-symbols | Whole-die failure tolerance at 16-high stacks |
| `ECC_NONE`         | identity                          | Throughput benchmarking only                  |

## Functional spec

- 64-byte cache line in, 64-byte (+ ECC syndrome) out.
- Single-cycle latency for `ECC_SECDED`. Two-cycle for `ECC_CHIPKILL`.
- Statistics counters: corrected events, uncorrectable events, alert
  output for the alert handler.

## Required formal

- **Exhaustive 72-bit BMC** for the SEC-DED Hsiao matrix proving:
  - Any single bit flip is corrected.
  - Any double bit flip is detected (`uncorrectable_o = 1`).
- **RS(8,4) symbol-level proof** under abstraction (one-symbol-error
  scenarios are exhaustive in the symbol space, not the bit space).

## ADR

`docs/rfcs/0003-ecc-stack-interaction.md` documents the layered story:
on-die DRAM ECC + link ECC + system ECC. The error taxonomy diagram lives
in `docs/arch/ecc_stack.md` as a Wavedrom block.

## Reference reading

- TU Berlin "silent data corruption at scale" paper (April 2026) -- argues
  ECC misses transient logic errors in large-scale LLM training. Sets the
  ECC strength bar.
