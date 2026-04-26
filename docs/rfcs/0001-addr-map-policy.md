# RFC 0001 -- Address-mapping policy for `hw/ip/addr_map`

| | |
|---|---|
| Status     | Accepted |
| Authors    | Founder |
| Reviewers  | TBA (TSC stand-up at Phase B) |
| Created    | 2026-04-26 |
| Supersedes | -- |

## Context

HBM4 controllers must translate a system address into the JEDEC channel /
pseudo-channel / bank-group / bank / row / column tuple in one cycle.
The choice of mapping shapes the achievable bandwidth more than almost
any other knob in the controller (see Liu/Ferdman/Sair, "Locality
Implications of DRAM Mapping," ISCA 2016; Jacob et al, "Memory Systems"
ch.10). For `Plan.md` s11 risk #4 the project's wager is that **no
single XOR scheme is optimal** for all three workload patterns the LPU
will mix in production:

- **Weight streaming** (large sequential): wants channel-stripe.
- **Paged KV-cache** (random pages, internal locality): wants
  bank-interleave with row hashing.
- **Dense attention** (intra-row reuse): wants row-stationary.

## Decision

We adopt a **programmable per-region** address mapper with three preset
modes (`CH_STRIPED`, `BANK_INTERLEAVED`, `ROW_STATIONARY`), each backed
by a **programmable XOR polynomial** that scrambles the row field
against the high address bits.

A 16-entry region table (CSR-managed shadow + LIVE on `COMMIT`) lets
software assign a different mode to each memory region (a vLLM weight
arena, a KV cache, a scratch buffer, etc.).

### Why XOR hashing rather than a bare bit-slice

Bit-slice mapping leaves stride-2^k traffic permanently colliding on the
same bank. XOR hashing of the high bits into the row index breaks those
collisions for any stride that is not also an XOR-fixed-point of the
polynomial. The only design knob is which polynomial.

### Why three modes, not "fully programmable"

A fully-programmable mapping fabric (one mux per output bit) costs an
extra ~6k gates per channel and forces formal proof of bijection on a
much larger state space. The three-mode scheme covers the workload
patterns the project's TVM backend (`sw/tvm_backend/`) actually emits;
extending to a fourth mode is a one-line `enum` change.

### Why store the polynomial per region

This is the cheapest way to support a `Should:` requirement -- different
tenants on the same chip want different randomisation domains. With a
per-region polynomial, the host kernel can use the region table as a
poor-person's MMU for HBM mapping policy.

### Default polynomials

| Mode               | Polynomial   | Source                                        |
| ------------------ | ------------ | --------------------------------------------- |
| `CH_STRIPED`       | `0xA1B2C3D4` | Empirical from vLLM 0.6 traces, mid-2025      |
| `BANK_INTERLEAVED` | `0x5A5AA5A5` | Standard bit-pair pattern; max linear weight  |
| `ROW_STATIONARY`   | `0xCAFEBABE` | Random-but-non-degenerate seed                |

These are starting points only; the IP exposes them per-region for
software override.

## Alternatives rejected

- **Single global XOR** (one polynomial for the whole chip): rejected
  because the three workload classes have conflicting optima; see
  `Plan.md` s11 risk #4.
- **Hash-of-hash double XOR**: marginally better mixing but doubles the
  combinational depth, missing the 1-cycle latency target.
- **A fully-tabular mapping ROM** (lookup-table-driven): infeasible at 64-bit
  input, prohibitive ROM cost.

## Consequences

- The mapper is small enough (low thousands of gates per channel) that
  full bijection-proof BMC is tractable.
- Mode selection adds 2 bits to every region-table entry; trivial.
- Test plan must include trace-driven scoreboarding (vLLM, FlashAttn-3,
  SGLang) to demonstrate the three-mode story is empirically real.

## References

- Liu, Ferdman, Sair, ISCA 2016.
- Jacob, Wang, Ng, "Memory Systems," 2008.
- Plan.md s4 prompt for `addr_map`.
- Plan.md s11 risk #4.
