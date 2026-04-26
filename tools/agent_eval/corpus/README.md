# tools/agent_eval/corpus -- regression set for prompt changes

Each subdirectory is a **mini-block** with full lint / sim / formal / mutation
evidence. The corpus is the regression set we run on every change to:

- `CLAUDE.md`
- `AGENTS.md`
- `docs/agent-prompts/**`
- `tools/agent_eval/harness/**`

Adding a new mini-block: copy `_template/` and follow the `MANIFEST.md` pattern.

The full corpus (target: 30 blocks) is being built out in priority order:

| #  | Block                       | Status   | Notes                                           |
| -- | --------------------------- | -------- | ----------------------------------------------- |
| 01 | `fifo_sync`                 | landed   | Synchronous FIFO with full/empty flags          |
| 02 | `cdc_2flop`                 | landed   | 2-flop CDC synchroniser                         |
| 03 | `arbiter_rr`                | landed   | Round-robin arbiter                             |
| 04 | `hsiao_secded`              | landed   | (72,64) Hsiao SEC-DED                           |
| 05 | `xor_addr_mapper_toy`       | landed   | 4-channel XOR address mapper                    |
| 06 | `fifo_async`                | stub     | Async FIFO with gray pointers                   |
| 07 | `cdc_pulse`                 | stub     | Pulse CDC                                       |
| 08 | `arbiter_lru`               | stub     | Pseudo-LRU tree arbiter                         |
| 09 | `count_leading_zeros`       | stub     | Parameterised CLZ                               |
| 10 | `popcount`                  | stub     | Population count                                |
| 11 | `gray_counter`              | stub     | Gray-code counter                               |
| 12 | `prim_subreg_rw`            | stub     | Read-write CSR primitive                        |
| 13 | `prim_subreg_ro`            | stub     | Read-only CSR primitive                         |
| 14 | `axi4_skid_buffer`          | stub     | AXI4 skid buffer                                |
| 15 | `apb_to_csr_decoder`        | stub     | APB to internal-CSR decoder                     |
| 16 | `tilelink_c_xbar_2x2`       | stub     | TileLink-C 2x2 crossbar                         |
| 17 | `prim_count`                | stub     | Saturating counter                              |
| 18 | `prim_lfsr`                 | stub     | LFSR (random + scrambler)                       |
| 19 | `prim_onehot_check`         | stub     | One-hot integrity checker                       |
| 20 | `prim_alert_sender`         | stub     | OpenTitan-style alert sender                    |
| 21 | `prim_keccak_round`         | stub     | One Keccak-f permutation round                  |
| 22 | `prim_aes_sbox`             | stub     | AES S-box                                       |
| 23 | `prim_galois_mult8`         | stub     | GF(2^8) multiply (RS support)                   |
| 24 | `bank_state_fsm`            | stub     | Bank-machine state FSM (idle/active/refresh)    |
| 25 | `refresh_credit_pool`       | stub     | DRFM credit pool                                |
| 26 | `prac_topk_table`           | stub     | Misra-Gries top-K table                         |
| 27 | `dfi_skid_register`         | stub     | DFI skid register                               |
| 28 | `prim_clock_gating`         | stub     | ICG with TE                                     |
| 29 | `prim_clock_buf`            | stub     | Clock buffer                                    |
| 30 | `prim_rst_sync`             | stub     | Reset synchroniser                              |

"Landed" = RTL + dv + sby exist and the harness scores the block 100/100 on
the OSS CAD Suite 2026-04-02 image. "Stub" = manifest exists, RTL is a
single-cycle placeholder so the harness can still execute end-to-end without
NaN propagation.

The reason all 30 are scaffolded even when the RTL is stubbed: the harness
itself needs a non-empty corpus to regression-test, and any prompt change
that breaks the harness is caught even before any block has been
implemented.
