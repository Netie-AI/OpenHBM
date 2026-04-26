# `hw/ip/addr_map`

The lighthouse mini-IP for Netie Open HBM. Programmable XOR address mapping
between the system address space and the HBM4 channel/pseudo-channel/
bank-group/bank/row/column tuple. See [RFC 0001](../../../docs/rfcs/0001-addr-map-policy.md)
for the design rationale.

## Block diagram

```
                +-------------------+         +------------------+
   sa_i ----+-> | region_table      | -- region_t --> | addr_map_xor   | -- pa_t -> [outreg] -> rsp_pa_o
            |   | (shadow + LIVE)   |         | (combinational)  |
            |   +-------------------+         +------------------+
            |              ^
            |              | cfg_we / cfg_idx / cfg_wdata / cfg_commit
            |   +-------------------+
   APB --+--+-> | addr_map_reg_top  |
         |      | (reggen-generated)|
         |      +-------------------+
         |
        CSRs: DEFAULT_MODE, COMMIT, STATUS, REGION[16], REGION_BASE_LO[16],
              REGION_XOR_POLY[16]
```

## Files

| Path                                | Purpose                                  |
| ----------------------------------- | ---------------------------------------- |
| `rtl/addr_map_pkg.sv`               | Geometry, types, default polynomials     |
| `rtl/addr_map_xor.sv`               | Combinational XOR-hash mapper            |
| `rtl/addr_map_region_table.sv`      | 16-entry shadow + LIVE region table      |
| `rtl/addr_map_reg_top.sv`           | APB CSR top (regtool placeholder)        |
| `rtl/addr_map.sv`                   | Top wrapper with 1-cycle output register |
| `data/addr_map.hjson`               | CSR description for `regtool.py`         |
| `dv/env/addr_map_ref.py`            | Pure-Python golden                       |
| `dv/tests/test_addr_map.py`         | Cocotb directed + CRT tests              |
| `fpv/addr_map_inj.sby`              | SymbiYosys: bijection BMC                |
| `fpv/addr_map_bound.sby`            | SymbiYosys: output-bound BMC             |

## Latency / throughput

- 1 cycle from `req_valid_i` accept to `rsp_valid_o`.
- 1 mapping per cycle peak.

## Open issues

- The reggen tool needs to be vendored (see `hw/vendor/opentitan_regtool.lock.hjson`)
  before `addr_map_reg_top.sv` is replaced by the generated decoder.
- The bijection assertion in `fpv/addr_map_inj.sby` currently runs on the
  combinational core only; the wrapper version is a separate task and
  may need an abstraction over the region-table state.
