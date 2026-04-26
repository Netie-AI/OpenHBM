# Agent prompt: `hw/ip/hbm4_phy_shim`

Read [`_preamble.md`](_preamble.md) first.

## Mission

Implement the DFI 5.x-compatible boundary between `hbm4_ctrl` and either
(a) a hardened HBM2/HBM3 PHY on Alveo U55C/U280 (Phase-1 backstop) or
(b) a real HBM4 PHY (Phase 3+, commercial-licensed during shuttle runs).

## Spec subset

The `hw/ip/hbm4_phy_shim/data/dfi5_subset.adoc` file enumerates exactly
which DFI 5.x fields we drive and consume. NEVER add a field outside this
subset without an RFC. The full DFI spec is large, ours intentionally is not.

## Phase-1 deliverable

A behavioural shim that talks to `hw/vip/dramsim4/` over DPI on one side
and DFI on the other. This is the simulation-grade artefact.

## Phase-2 deliverable

An FPGA shim that adapts our DFI to the Alveo U55C hardened HBM2 IP. This
loses bandwidth (HBM2 is 4 channels x 1024 bits at lower rate vs HBM4
spec) but lets us emulate the controller against real silicon.

## Phase-3 stretch

A digital PHY adapter for a commercial Synopsys/Cadence HBM4 PHY,
under-NDA. Out of scope for the open repo; lives in a private overlay.

## Required SVA

- DFI command-bus mutual exclusion per pseudo-channel.
- Read-data-valid / read-data alignment (CL latency).
- Write-data-valid / write-data alignment (CWL latency).
- All SI/PI sign-off is OUT OF SCOPE -- that's the openEMS screen + a
  commercial Clarity/HFSS pass at silicon time.

## Reference reading

- JEDEC DFI 5.0 / 5.1 spec.
- Plan.md s11 risk #6 -- HBM4 link training is vendor-specific and cannot
  be validated until silicon exists.
