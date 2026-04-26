# `hw/vip/dramsim4` -- behavioural HBM4 BFM (DRAMsim3 fork)

This is the project's most strategically important VIP. It is a fork of
[DRAMsim3](https://github.com/umd-memsys/DRAMsim3) (MIT license), patched
with HBM4 timing parameters and exposed to cocotb via DPI.

The HBM4 timing parameter set is **derived clean-room** from the
publicly-available JEDEC JESD270-4A registration PDF (which is itself
not redistributable). See
[`docs/spec/hbm4_timing.adoc`](../../../docs/spec/hbm4_timing.adoc) for
the bounds we use.

## Status

Phase-0 scaffolding only. Concretely shipped:

- `cfg/hbm4_8gbps.ini` -- a DRAMsim3-compatible config file with HBM4
  geometry (32 ch x 2 pCh x 16 banks, 17-bit row, 6-bit col).
- `python/dramsim4_dpi.py` -- thin Python wrapper that launches the
  DRAMsim3 binary and provides a cocotb-friendly transactor stub.

What is **not** here yet (lands when `third_party/dramsim3_ref` is
vendored via `util/vendor.py`):

- The actual DRAMsim3 source patches.
- The C++ DPI bridge.
- HBM4 timing-parameter unit tests.

## Plan-of-record

1. `util/vendor.py --refresh dramsim3_ref` pulls upstream into
   `third_party/dramsim3_ref/`.
2. `scripts/patch_dramsim3_for_hbm4.py` applies our timing diff into
   `hw/vip/dramsim4/src/`.
3. `hw/vip/dramsim4/dpi/dramsim4_dpi.cc` wraps the simulator in a SystemVerilog
   DPI shim.
4. cocotb tests against `hw/ip/hbm4_ctrl` connect through that DPI.

This is the project's single highest-value upstream contribution per
`Plan.md` s3 Phase 1, because no open JESD270-4 BFM exists.
