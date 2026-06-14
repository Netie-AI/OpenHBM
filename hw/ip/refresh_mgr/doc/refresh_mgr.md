# `hw/ip/refresh_mgr`

Per-bank refresh scheduling for HBM4 with DRFM (DRAM Refresh Management) and
PRAC (Per-Row Activation Counter) rowhammer mitigation. See
[`docs/agent-prompts/refresh_mgr.md`](../../../docs/agent-prompts/refresh_mgr.md)
for the functional spec and test plan.

## Files

| Path | Purpose |
| --- | --- |
| `rtl/refresh_mgr_pkg.sv` | Types, parameters, FSM encodings |
| `rtl/refresh_mgr.sv` | Top refresh manager |
| `data/refresh_mgr.hjson` | IP metadata (no CSRs in v0.2) |
| `dv/env/refresh_mgr_ref.py` | Pure-Python golden |
| `dv/tests/test_refresh_mgr.py` | Cocotb tests |
| `fpv/refresh_liveness.sby` | SymbiYosys: pending-refresh liveness BMC |
| `fpv/abs_bank_machine.sv` | Formal abstractions |
| `fpv/refresh_liveness.sv` | Formal wrapper |
| `dv/mcy/` | Mutation coverage (MCY) |
