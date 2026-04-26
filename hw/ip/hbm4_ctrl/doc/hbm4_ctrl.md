# `hw/ip/hbm4_ctrl` -- Phase-1 skeleton

Top-level JESD270-4A HBM4 controller. Forks the structural pattern from
LiteDRAM (BSD-2-Clause) and reworks the PHY boundary to HBM4's
32-channel x 2-pseudo-channel x 2048-bit DFI.

This is the **skeleton**: ports, parameters, and FSM stubs that elaborate
cleanly. Full implementation is gated on:

1. `hw/vip/dramsim4/` running co-simulated via cocotb DPI.
2. `hw/ip/addr_map`, `hw/ip/ecc`, `hw/ip/refresh_mgr` formally proved.

## Hierarchy

```
hbm4_ctrl
  +-- addr_map_inst        (1 instance, time-mux across channels in Phase 1)
  +-- bank_machine[N*P*B]  (NumCh x NumPCh x NumBanks grid)
  +-- (deferred to Phase 2)
       refresh_mgr_inst
       ecc_inst
       ch_arbiter
       pch_arbiter
       write_data_path
       read_data_path
       reggen-generated CSR top
```

## Phase-1 acceptance test

`hbm4_ctrl` elaborates with no Verilator warnings, passes
`yosys -p 'hierarchy -check'`, and a smoke cocotb test successfully drives
one ACT command out of `dfi_cmd_o[0][0]` after seeing one AXI AR request.

## Reading order for new contributors

1. [`Plan.md` s4 prompt for `hbm4_ctrl`](../../../Plan.md)
2. [`docs/agent-prompts/hbm4_ctrl.md`](../../../docs/agent-prompts/hbm4_ctrl.md)
3. [`docs/spec/hbm4_timing.adoc`](../../../docs/spec/hbm4_timing.adoc)
4. LiteDRAM `litedram/core/bankmachine.py` (vendored under `third_party/litedram_ref/`).

## TODO before silicon

- Replace the 1-cycle bank-machine timer stub with the real tRCD/tRP/tRAS counters.
- Wire the real DFI 5.x bundle struct (today's `dfi_cmd_o` is a bare enum).
- Plug in `refresh_mgr` once landed.
- Hook `addr_map` into all NumCh requesters in parallel (today: round-robin
  time-mux through a single instance).
