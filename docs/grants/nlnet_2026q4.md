# NLnet NGI0 Commons Fund -- 2026 Q4 application draft

| | |
|---|---|
| Round         | NGI Zero Commons Fund, October 2026 |
| Target ask    | EUR 50,000 |
| Period        | 12 months from grant award |
| Lead applicant| Netie Open HBM project (Malaysian Sdn Bhd, in formation) |
| Status        | DRAFT v0.1 |

## Project name

Netie Open HBM -- "The RISC-V of memory and AI accelerators."

## What we want to build

An open-source, JEDEC JESD270-4A-compliant HBM4 controller, PHY-shim, and
RISC-V-native LPU reference design released under Apache-2.0 (RTL),
CERN-OHL-W-2.0 (analog/GDSII), and CC-BY-4.0 (docs). Specifically, by the
end of the grant period:

1. A simulation-grade HBM4 controller (`hw/ip/hbm4_ctrl`) with full
   command/data/refresh FSMs across 32 channels x 2 pseudo-channels,
   verified via cocotb + Verilator + SymbiYosys.
2. A clean-room HBM4 behavioural BFM (`hw/vip/dramsim4`, fork of
   DRAMsim3) with the JESD270-4A timing parameters, packaged for cocotb
   DPI integration.
3. A 4-tile LPU prototype (`hw/ip/accel_core`, building on PULP RedMulE
   under Solderpad-0.51) running BERT-Base inference end-to-end in
   simulation.
4. The CHIPS-Alliance-track infrastructure (CI, eval harness, governance
   docs) needed for the project to graduate into a Linux Foundation
   directed fund in Phase B.

## Why this matters

The HBM4 base-die ecosystem is locked behind two NDAs (SK Hynix and
Samsung) and one packaging cartel (TSMC CoWoS, ~85% pre-booked through
2027). NVIDIA Rubin lands H2 2026 with 288 GB HBM4 at 22 TB/s; AMD MI455X
in late 2026 with 432 GB at 19.6 TB/s. By 2028, the closed stacks are
entrenched for another decade. **A royalty-free, JEDEC-compliant
controller -- the way RISC-V commoditised the ISA -- is the
intervention with the highest leverage and the narrowest window.** The
NLnet grant funds the founder year; the rest of the stack
(HACC for FPGA emulation, ChipFoundry for SkyWater 130 silicon,
Europractice for ASAP7 / IHP shuttles) is already free or grant-funded.

Without it, this opportunity passes to whichever closed-source vendor
is fastest, and the Malaysian and ASEAN sovereign-AI ecosystem inherits
the same NVIDIA-/SK Hynix-/CUDA stack the EU has spent five years
fighting.

## Why us

The project's design document (arXiv preprint at
[`docs/arxiv/preprint.tex`](../arxiv/preprint.tex)) is in flight. The
Phase-0 substrate -- repository, AI-agent training pipeline, open EDA
flows down to ASAP7 7 nm FinFET, JEDEC clean-room timing summary, full
verification harness -- is already public at
<https://github.com/netie-open-hbm/netie-open-hbm>.

## Deliverables

| #  | Deliverable                                       | Month |
| -- | ------------------------------------------------- | ----: |
| D1 | `hw/ip/addr_map` formally proved bijection         |     1 |
| D2 | `hw/ip/ecc` SEC-DED + chipkill-class verified      |     3 |
| D3 | `hw/ip/refresh_mgr` DRFM liveness proof            |     5 |
| D4 | `hw/vip/dramsim4` HBM4 BFM cocotb-DPI integration  |     7 |
| D5 | `hw/ip/hbm4_ctrl` 32-channel cocotb regression     |     9 |
| D6 | 4-tile LPU running BERT-Base on Alveo U55C (HACC) |    11 |
| D7 | arXiv preprint, FOSDEM 2027 talk, ORConf 2027     |    12 |

## Open-source DNA

- Apache-2.0 RTL, CERN-OHL-W-2.0 analog, CC-BY-4.0 docs.
- DCO sign-off on every commit; ICLA before Phase-2 silicon-bound RTL freeze.
- Public RFC process (`docs/rfcs/`) modelled on RISC-V International.
- OIN small-organisation membership before any Track-A code lands.
- Trademark "Netie Open HBM Compatible(TM)" -- compatibility certification mark
  modelled on RISC-V CSC.

## Budget (preliminary)

| Item                                            | EUR     |
| ----------------------------------------------- | ------- |
| Founder stipend (12 months, MY cost-of-living)  | 30,000  |
| Cloud + CI + storage                            | 4,000   |
| Travel (FOSDEM, ORConf, RISC-V Summit Asia)     | 5,000   |
| Tiny Tapeout submissions (TTSKY26b + TTIHP26a)  | 800     |
| Trademark + ICLA legal                          | 5,000   |
| Contingency (10%)                               | 5,200   |
| **Total**                                       | **50,000** |

## Reference reading for the reviewer

- [Plan.md](../../Plan.md) -- the 36-month strategic plan.
- [docs/spec/hbm4_timing.adoc](../spec/hbm4_timing.adoc) -- clean-room HBM4 timing summary.
- [hw/ip/addr_map/](../../hw/ip/addr_map/) -- the lighthouse IP, formally
  proved bijection, with cocotb golden ref and 3 trace-driven tests.
- [tools/agent_eval/](../../tools/agent_eval/) -- AI-agent training pipeline
  with lint -> sim -> formal -> mutation gating.
