# `hw/ip/ecc`

Reed-Solomon symbol ECC over GF(2^8) for ChipKill-style protection on the
128-bit HBM4 data path. v0.2 replaces the legacy SEC-DED-only block with
`ecc_encode` / `ecc_decode` and a top-level `ecc` wrapper.

## Block diagram

```
  data_i[127:0] --> ecc_encode --> ecc_o[15:0]
                         |
  data_i + ecc_i ------> ecc_decode --> corrected_o, err_o, derr_o
```

## Files

| Path | Purpose |
| --- | --- |
| `rtl/ecc_pkg.sv` | GF(2^8) tables, RS(18,16) codeword helpers |
| `rtl/gf_tables.inc.sv` | Generated GF multiply tables (`dv/gen_gf_sv.py`) |
| `rtl/ecc_encode.sv` | Combinational RS encoder |
| `rtl/ecc_decode.sv` | Combinational RS decoder (corrects 1 symbol) |
| `rtl/ecc.sv` | Top wrapper |
| `data/ecc.hjson` | IP metadata (no CSRs in v0.2) |
| `dv/env/ecc_ref.py` | Pure-Python golden |
| `dv/tests/test_ecc.py` | Cocotb directed + random tests |
| `fpv/ecc_rs_roundtrip.sby` | SymbiYosys: zero-data syndrome BMC |
| `fpv/ecc_wrapper.sv` | Formal wrapper (sv2v-flattened) |
| `dv/mcy/` | Mutation coverage (MCY) |

## Latency / throughput

- Combinational encode and decode (0 cycles).
- Top `ecc` may register outputs per integration wrapper.

## Open issues

- Extend formal to cover single-symbol correction invariants at bounded depth.
- Add CSR block when runtime ECC policy knobs are needed.
