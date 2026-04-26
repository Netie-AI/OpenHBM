# `fifo_sync`

A 1-clock-domain synchronous FIFO. Power-of-2 depth. Latency 1 cycle.

## Why this is in the corpus

Single-clock FIFOs are the primitive that almost every other IP in the project
ends up wrapping (controller staging, DFI buffer, AXI skid, etc.). Getting the
SVA right (especially the "no push when full" / "no pop when empty"
contract) is the canonical "did the agent read CLAUDE.md" sniff test.

## Score history

To be filled in by the harness once the runner first exercises this block.
