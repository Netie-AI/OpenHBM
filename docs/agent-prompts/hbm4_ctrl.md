# Agent prompt: `hw/ip/hbm4_ctrl`

Read [`_preamble.md`](_preamble.md) first.

## Mission

Implement the JEDEC JESD270-4A command, data, and refresh FSMs for HBM4
across **32 channels**, each with **2 pseudo-channels**. This is the
strategically most-important block in the project; treat it accordingly.

The structure is forked from [LiteDRAM](https://github.com/enjoy-digital/litedram)
(BSD-2-Clause). Retain LiteDRAM's scheduler, bank-machine, and refresh
architecture; rework the PHY boundary to HBM4's
**32-channel x 2-pseudo-channel x 2048-bit DFI**. See
[`docs/spec/hbm4_timing.adoc`](../spec/hbm4_timing.adoc) for the clean-room
summary of `tRCD`, `tRP`, `tRAS`, `tRFC`, `tFAW`, `tRRD_S`, `tRRD_L`,
`tWR`, `tWTR_S`, `tWTR_L`, `tCCD_S`, `tCCD_L`. ALL of these are CSR-programmable
at runtime, with reset values driven by an `HBM4_SPEED` parameter
(`SPEED_4800`, `SPEED_6400`, `SPEED_8000`, `SPEED_9600`).

## Top-level structure

```
hbm4_ctrl
  +-- channel_cluster[NumChan]                  // one per channel
        +-- pseudo_channel[NumPCh]              // 2 per channel, share BG
              +-- bank_machine[NumBanksTotal]   // 16 banks (4 BG x 4 banks)
                    +-- cmd_fsm
                    +-- precharge_arbiter
                    +-- refresh_acceptor
        +-- pch_arbiter                         // arbitrates between pCh
        +-- write_data_path
        +-- read_data_path
  +-- ch_arbiter                                // top-level scheduler
  +-- refresh_mgr_inst : refresh_mgr            // separate IP, instantiated here
  +-- ecc_inst         : ecc                    // separate IP, instantiated here
  +-- addr_map_inst    : addr_map               // separate IP, instantiated here
  +-- csr               : reggen-generated
  +-- dfi_if            : dfi 5.x to phy_shim
```

## Front-end (system side)

- **AXI4 multi-port** -- one AXI4 port per channel by default. A single
  AXI4 port that internally striped across channels is allowed under a
  `XBAR_MODE` parameter; this delegates to `hw/subsystems/mem_ss/`.
- **APB CSR** -- one APB port for the entire controller. Address space is
  declared in `data/hbm4_ctrl.hjson`.

## Back-end (PHY side)

- **DFI 5.x** -- the JEDEC-aligned PHY interface. See
  `hw/ip/hbm4_phy_shim/data/dfi5_subset.adoc` for the exact subset.
- **Per-channel** -- each channel has its own DFI bus. The shim either
  drives a hardened HBM2/HBM3 PHY (Alveo U55C/U280, used as backstop) or
  a real HBM4 PHY (commercial, gated to Phase 3+).

## Refresh modes

The controller MUST support, selectable via CSR per-channel:

1. **All-bank refresh (REF_ab)** -- legacy, simplest, lowest performance.
2. **Same-bank refresh (REF_sb)** -- HBM3+, refreshes all banks of a given
   index across BG simultaneously.
3. **Per-bank refresh (REF_pb)** -- finest-grained, highest performance.
4. **DRFM** -- DRAM Refresh Management; rowhammer mitigation. Defers to
   `refresh_mgr` IP. See [`refresh_mgr.md`](refresh_mgr.md).

## Required SVA assertions

- **No timing violation** -- e.g. no ACTIVATE before previous PRECHARGE +
  `tRP`. One assertion per timing parameter.
- **Bank-machine consistency** -- a bank in OPEN state has exactly one
  ACTIVE row.
- **No pending refresh missed** -- `tREFW` window never exceeds spec.
- **DFI command-bus mutual exclusion** -- one command per `tCK` per
  pseudo-channel.

## Phase 1 deliverables

Phase 1 is the *skeleton*: ports, parameters, register file, and FSM stubs
that elaborate cleanly and pass `hierarchy -check`. Implementation of the
inner FSM tables is Phase 2 work, gated on:

- DRAMsim4 (`hw/vip/dramsim4/`) being co-running with cocotb DPI.
- `addr_map`, `ecc`, `refresh_mgr` all formally proved.

In Phase 1 it is acceptable for the FSMs to drive a fixed NOP pattern as
long as the assertions are wired and the cocotb test exercises the
ready/valid handshake.

## Reference reading

- LiteDRAM `litedram/core/`. Mirror the bank-machine state breakdown.
- DREAM ISCA 2025 paper -- DRFM overheads (cited in Plan.md s11 risk #4).
- HBM4 JEDEC press release (Dec 2025) -- public summary of the spec.
