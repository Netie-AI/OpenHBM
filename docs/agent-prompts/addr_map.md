# Agent prompt: `hw/ip/addr_map`

Read [`_preamble.md`](_preamble.md) first.

## Mission

Implement the **lighthouse** address-mapping IP for Netie Open HBM. This block
sits between the AXI4 system-address front-end and the bank-machine of
`hbm4_ctrl`. It MUST be small, formally-tractable, and demonstrably useful
enough to publish as the project's first conference paper (target: ASPLOS or
DAC short paper).

## Functional spec

`addr_map` translates a 64-bit system address `sa` into a tuple
`(ch, pch, bg, ba, row, col)` where:

| Field | Width  | Range                                        |
| ----- | ------ | -------------------------------------------- |
| `ch`  | 5 bits | 32 channels (`0..31`)                        |
| `pch` | 1 bit  | 2 pseudo-channels per channel                |
| `bg`  | 2 bits | 4 bank groups                                |
| `ba`  | 2 bits | 4 banks per bank group                       |
| `row` | 17 bits| 128k rows per bank (configurable, see param) |
| `col` | 6 bits | 64 column granules of 32 B each (= 2 KiB row buffer) |

The exact field widths are parameterised in `addr_map_pkg.sv` so the same
RTL re-targets HBM3 (16 channels, etc.) without code edits.

The mapping is a **programmable XOR-hash policy** with three preset modes
selectable per memory region via CSRs:

1. **`MODE_CH_STRIPED`** -- low system bits feed `ch` (channel-striped).
   Optimised for sequential weight streaming; maximises channel parallelism
   on contiguous reads.
2. **`MODE_BANK_INTERLEAVED`** -- low system bits feed `(bg,ba)` after a
   row-XOR hash. Optimised for paged KV-cache traffic; maximises bank-level
   parallelism and minimises bank conflicts on random access patterns.
3. **`MODE_ROW_STATIONARY`** -- column varies fastest within a row buffer
   then bank. Optimised for dense attention where rows of the QK^T matmul
   keep landing in the same row buffer.

The XOR polynomial that scrambles `row` and `bg` is itself programmable via
a `XOR_POLY` CSR (taps over the upper system-address bits). Default
polynomials per mode live in `addr_map_pkg::DEFAULT_POLY`.

## Region table

The CSR block holds a **region table** of 16 entries. Each entry has:

| Field          | Width | Meaning                                    |
| -------------- | ----- | ------------------------------------------ |
| `valid`        | 1     | Region in use                              |
| `base_sa`      | 40    | Base system address (4 KiB-aligned)        |
| `size_log2`    | 6     | Region size = 2**size_log2 bytes           |
| `mode`         | 2     | 0 = striped, 1 = bank-interleaved, 2 = row-stationary, 3 = reserved |
| `xor_poly`     | 32    | XOR polynomial taps                        |

Lookup is associative across the 16 entries (priority-encoded by index).
A miss returns a parameterised default mode (typically `MODE_CH_STRIPED`).

## Ports

| Port                | Dir | Width | Clock     | Reset      | Notes                             |
| ------------------- | --- | ----- | --------- | ---------- | --------------------------------- |
| `clk_i`             | in  | 1     | -         | -          |                                    |
| `rst_ni`            | in  | 1     | `clk_i`   | async low  |                                    |
| `req_valid_i`       | in  | 1     | `clk_i`   | `'0`       |                                    |
| `req_ready_o`       | out | 1     | `clk_i`   | `'1`       |                                    |
| `req_sa_i`          | in  | 64    | `clk_i`   | -          | system address in                 |
| `req_op_i`          | in  | 2     | `clk_i`   | -          | 0=R, 1=W, 2=ATOMIC, 3=PREFETCH    |
| `rsp_valid_o`       | out | 1     | `clk_i`   | `'0`       |                                    |
| `rsp_ready_i`       | in  | 1     | `clk_i`   | -          |                                    |
| `rsp_pa_o`          | out | struct| `clk_i`   | `'0`       | `addr_map_pkg::pa_t` packed       |
| `tl_csr_h2d_i`      | in  | apb_pkg::apb_h2d_t | `clk_i` | -  |                                    |
| `tl_csr_d2h_o`      | out | apb_pkg::apb_d2h_t | `clk_i` | -  |                                    |

Latency is **1 cycle** (registered output). Throughput is one mapping per
cycle. The block is fully pipelined and ready/valid on both ends; no
back-pressure from the bank machine is propagated past the response queue.

## Required SVA assertions (`fpv/addr_map_inj.sby`)

1. **Bijection within a region.** For any two valid system addresses
   `sa1 != sa2` whose region indices match, their mapped `pa` MUST differ.
   This is the no-aliasing property and is the most important.
2. **Bound.** `pa.ch < NUM_CHANNELS`, `pa.bg < NUM_BANK_GROUPS`,
   `pa.ba < NUM_BANKS_PER_GROUP`, `pa.row < NUM_ROWS`, `pa.col < NUM_COLS`.
3. **Mode invariant.** When `mode == MODE_CH_STRIPED`, low bits of `sa`
   reproduce `ch` modulo channel-stripe width.
4. **CSR atomicity.** Region-table writes do not perturb in-flight requests
   (use a shadow register / pause handshake).
5. **No spurious response.** `rsp_valid_o` only when there has been a
   `req_valid_i` accepted at least 1 cycle ago.

## Test plan

- **Directed tests** (`dv/tests/test_basic.py`): walk the eight corners
  (`sa=0`, `sa=2**40-1`, region boundary +/-1, mode boundary, XOR-poly all-0,
  XOR-poly all-1).
- **CRT tests** (`dv/tests/test_random.py`): `pyvsc` constraints on
  region-table contents AND on input traffic; check against
  `addr_map_ref.py`.
- **Trace tests** (`dv/tests/test_traces.py`): replay
  `sim/traces/vllm_decode.trc`, `flash_attn3.trc`, `sglang_prefill.trc` and
  measure bank-conflict rate per mode. Report goes into
  `docs/arch/addr_map_perf.md`.

## ADR

`docs/rfcs/0001-addr-map-policy.md` justifies:

- Why XOR hashing (vs. simple bit-slice).
- Why exactly three modes (vs. fully-programmable mapping fabric).
- The choice of default XOR polynomials (cite ASPLOS / ISCA prior art:
  Jacob/Wang/Ng on cache index hashing; Liu/Ferdman/Sair on DRAM mapping).

## Score gates

The agent-eval harness applies these weights to this IP specifically (above
the global defaults):

| Component             | Weight |
| --------------------- | -----: |
| Lint                  |     10 |
| Verilator elab        |     10 |
| Cocotb sim pass       |     20 |
| Functional coverage   |     20 |
| Formal (bijection)    |     25 |
| Mutation coverage     |     15 |
| **Total**             |    100 |

Threshold to merge: **>=80**. Anything that fails the bijection proof is
auto-blocked regardless of total score.

## Reference reading

- Plan.md s11 risk #4 -- single XOR scheme cannot be optimal for all three
  workloads simultaneously; this is why we have programmable per-region.
- ISCA 2025 DREAM paper -- the rowhammer-aware refresh story; tells us how
  much pressure the address mapper puts on the refresh manager.
- USENIX Security 2025 rowhammer-at-16-high paper -- reinforces why row
  scrambling matters.
