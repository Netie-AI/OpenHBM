# CLAUDE.md -- the binding RTL contract for Netie Open HBM

This file is read FIRST by every AI agent (Claude 4.7, GPT-5.5, Gemini 3.1, or
any successor) before producing any code in this repository. Treat every
section below as a hard requirement, not a guideline. Violations block CI.

If you also see `AGENTS.md`, read it second -- it indexes everything else.

---

## 1. SystemVerilog subset (synthesisable code)

The synthesisable subset is **IEEE 1800-2017** with the following constraints:

### 1.1 Allowed

- `logic` for all signals (no `wire`, no `reg` in synthesisable code).
- `always_ff @(posedge clk or negedge rst_ni)` for sequential.
- `always_comb` for combinational.
- `always_latch` ONLY when justified by an inline comment explaining why a
  flop is not appropriate, and never on a clock-crossing path.
- Packed structs and unions for bundled wires.
- `enum logic [...]` for state encodings (one-hot or binary; specify in `()`).
- `parameter` and `localparam` for compile-time constants.
- `function automatic` for combinational helpers.
- Generate blocks with named labels (`for (...) begin : g_name`).
- SVA properties via `assert property`, `cover property`, `assume property`.
- `import` of an interface package into a leaf module IS allowed; declaring
  `interface` ports IS NOT (see 1.2).

### 1.2 Banned in synthesisable code

- Four-state `wire` declarations (use `logic`).
- `reg` keyword (use `logic`).
- `interface` ports on leaf IP modules. (Top-level subsystem wrappers MAY use
  interfaces; leaf IP must use packed structs to keep tools portable.)
- `force` / `release`.
- `disable fork`.
- `event` types.
- `class` / `virtual class` (verification only).
- `mailbox`, `semaphore` (verification only).
- `$random`, `$urandom`, `$urandom_range` (use `pyvsc` constrained random in
  the testbench, never inside RTL).
- Non-blocking assignment in `always_comb` (`<=` belongs only in `always_ff`).
- Blocking assignment to a flop signal (`=` belongs only in `always_comb`).
- Implicit nets. Set `default_nettype none` at every file top.
- Synchronous-active-high resets (we use synchronous and asynchronous active-low
  `rst_ni`; see 3.2).
- `casex`, `casez` (use `case ... inside` or `unique case`).
- Bare `case` without `unique` or `priority`.
- Multiple-driver nets.
- Output-port driving from more than one `always_*` block.
- `defparam`.
- Behavioural delays (`#5`) outside testbenches.

### 1.3 Required at every file top

```systemverilog
// Copyright 2026 The Netie Open HBM Authors
// SPDX-License-Identifier: Apache-2.0
`default_nettype none
`timescale 1ns/1ps
```

End every module with `endmodule : module_name` (named end labels are
mandatory).

---

## 2. File and module naming

- Files: `snake_case.sv` for modules, `snake_case_pkg.sv` for packages,
  `snake_case_if.sv` for interfaces.
- One module per file. Module name = file name.
- Package files end in `_pkg.sv` and contain only `package`/`endpackage`
  contents. No modules in package files.
- Headers (`*.svh`) are reserved for `define`s shared across files. Avoid
  unless necessary.

---

## 3. Clocks, resets, and clock-domain crossings

### 3.1 Clock signals

- Single-domain modules: `clk_i`, `rst_ni` (active-low).
- Multi-domain: `<domain>_clk_i`, `<domain>_rst_ni` (e.g. `mem_clk_i`,
  `axi_clk_i`).
- No internally-generated clocks. Clock generation is centralised in
  `hw/ip/clkrst_ctrl/` (forthcoming) and uses `prim_clock_gating`,
  `prim_clock_buf`, `prim_clock_div` only.

### 3.2 Resets

- Active-low (`_ni` suffix). `negedge rst_ni` in the sensitivity list of every
  `always_ff` that needs reset.
- Asynchronous assert, synchronous deassert. Use `prim_rst_sync` to deassert.
- No combinational logic in the reset path.

### 3.3 Clock-domain crossings

This is non-negotiable. Every CDC must use one of:

| Type                  | Primitive                  |
| --------------------- | -------------------------- |
| Single bit, level     | `prim_sync_2flop`          |
| Single bit, pulse     | `prim_sync_pulse`          |
| Multi-bit, gray       | `prim_sync_grayctr`        |
| Multi-bit, async FIFO | `prim_fifo_async`          |
| Reset deassertion     | `prim_rst_sync`            |

Direct `always_ff` capture across a clock domain WILL fail
`util/lint/cdc_check.py` and block the PR.

---

## 4. Reset behaviour

Every flop must reset to a deterministic value -- `'0` is the default unless
the IP-specific spec says otherwise. State machines reset to a named `IDLE`
state. Counters reset to `'0`. Configuration registers reset to the
`reset_value` declared in the Hjson register file (see Section 7).

---

## 5. Primitive library (mandatory)

Reusable building blocks come from one of three vendored libraries. NEVER
re-roll a primitive that already exists.

| Library                     | Source                             | Purpose                              |
| --------------------------- | ---------------------------------- | ------------------------------------ |
| `prim_generic`              | `hw/ip/prim_generic/rtl/`          | Tech-agnostic FFs, muxes, encoders   |
| `lowrisc_prim`              | `hw/vendor/lowrisc_prim/`          | OpenTitan primitives (CDC, RAM, ROM) |
| `pulp_common_cells`         | `hw/vendor/pulp_common_cells/`     | PULP FIFOs, fall-through registers   |

Common needs and their canonical primitive:

- 2-flop synchroniser: `prim_sync_2flop`
- Async FIFO: `prim_fifo_async`
- Sync FIFO: `prim_fifo_sync`
- Round-robin arbiter: `prim_arbiter_rr`
- Pseudo-LRU arbiter: `prim_arbiter_tree`
- One-hot to binary: `prim_onehot_to_bin`
- Pop count: `prim_count_ones`
- Generic register file: `prim_subreg`

---

## 6. Bus protocols

- Memory-mapped front-end: AXI4 (full, not Lite) on the channel data path,
  APB on the CSR path. Use `axi_pkg` from `hw/vendor/pulp_common_cells/`.
- Tile-link cache-coherent option: TileLink-C, vendored separately when needed.
- DRAM PHY boundary: DFI 5.x. Definition lives in `hw/ip/hbm4_phy_shim/data/`.
- Vendor IP boundary: not allowed without a `docs/rfcs/` ADR.

---

## 7. CSRs and register files

- ALL CSRs MUST be declared in an Hjson file at `hw/ip/<ip>/data/<ip>.hjson`.
- The RTL register file is generated by `util/reggen/regtool.py` (vendored from
  OpenTitan, Apache-2.0).
- Hand-written register decoders are rejected at PR review.
- The register file is regenerated as part of `make build`. Generated files
  carry the header `// GENERATED -- do not edit` and live under
  `rtl/<ip>_reg_top.sv` and `rtl/<ip>_reg_pkg.sv`.

---

## 8. Verification

### 8.1 Test bench layout

```
hw/ip/<ip>/dv/
  env/
    <ip>_ref.py        # Python golden reference model
    <ip>_env.py        # cocotb environment (pyuvm-style)
    <ip>_drv.py        # driver
    <ip>_mon.py        # monitor / scoreboard
  tests/
    test_basic.py      # directed
    test_random.py     # pyvsc-constrained-random
    test_corners.py    # corner cases
  Makefile             # cocotb runner
```

### 8.2 Mandatory coverage

- Functional coverage via `cocotb-coverage`. Target: >=95% on protocol
  cross-coverage, 100% on FSM transitions.
- Mutation coverage via `mcy`. Target: >=80% killed mutants on any module
  authored or substantially edited by an AI agent.

### 8.3 SVA assertion library

Cross-module / protocol-level assertions live in `hw/formal/sva_lib/`. Reuse
them. Examples:

- `sva_lib/axi4_assertions.sv`
- `sva_lib/apb_assertions.sv`
- `sva_lib/fsm_oh.sv` (one-hot FSM monitor)
- `sva_lib/no_x.sv` (no X propagation on observable outputs after reset)

---

## 9. Formal verification

Each leaf IP under 10 k gates SHALL have at least one SymbiYosys property at
`hw/ip/<ip>/fpv/<ip>.sby` proving its core invariants. Bound-model-check
(`mode bmc`) for the protocol; prove (`mode prove`) for liveness on small
state spaces. Use the OpenROAD `sby` runner; output goes to `build/fpv/<ip>/`.

---

## 10. Lint

`verible-verilog-lint --rules-config=.rules.verible_lint` runs on every PR.
Configuration lives at the repo root in `.rules.verible_lint`. Override
exceptions per-line ONLY with a justification comment:

```systemverilog
// verilog_lint: waive line-length -- spec table is more readable as a single line
```

---

## 11. Synthesis sanity check

Every module must elaborate cleanly with:

```bash
yosys -p 'read_verilog -sv <files...>; hierarchy -check; proc; opt; check'
```

This is run by `make synth-check` and is a CI gate.

---

## 12. Commit hygiene

- Conventional Commits (`feat:`, `fix:`, `refactor:`, `docs:`, `ci:`,
  `chore:`, `test:`, `build:`).
- DCO sign-off mandatory: `git commit -s`.
- One logical change per commit. Squash WIP commits before PR.
- PR title = top commit subject.

---

## 13. Workflow for a new IP block (the assertion-first loop)

For any new module, follow this order:

1. **RFC.** Open `docs/rfcs/<NNNN>-<ip>-<topic>.md` describing the design
   choice and the alternatives rejected.
2. **Port and parameter table.** A markdown table at the top of the IP's
   `doc/<ip>.md`. Include directionality, width, clock domain, reset value.
3. **Cycle-by-cycle timing narrative.** Comments at the top of the RTL file
   describing what happens cycle by cycle in the canonical happy path.
4. **SVA assertions.** Encode every protocol invariant as `assert property`
   first. Make them fail. Make them pass once the impl is right.
5. **Implement.** Following all rules above.
6. **Reference model.** A pure-Python golden in `dv/env/<ip>_ref.py`.
7. **Cocotb tests.** Directed first, then pyvsc-constrained-random.
8. **SymbiYosys.** BMC + prove on the small invariants.
9. **Mutation.** Run `mcy` and fix uncaught mutants by adding tests.
10. **Synthesis sanity.** `make synth-check`.
11. **Open PR with the Track-B eval harness output attached.**

If you (the agent) skip a step, the harness will refuse to score, and the PR
will not merge.

---

## 14. AI-agent-specific rules

- ALWAYS read `CLAUDE.md` and `AGENTS.md` and the IP's
  `docs/agent-prompts/<ip>.md` before generating any code for that IP.
- ALWAYS run `make agent-eval IP=<ip>` before opening a PR. The score must
  be >=80/100.
- NEVER fabricate citations. If you reference a paper, the DOI/arXiv ID must
  resolve. If you reference a repo, the URL must be live.
- NEVER paste JEDEC spec text directly. The clean-room summary at
  `docs/spec/hbm4_timing.adoc` is the canonical source.
- NEVER bypass the formal or mutation gates. They exist because field-patching
  hardware bugs is impossible.
- If you are uncertain whether a construct is allowed, default to "no" and
  ask in the RFC.

---

## 15. Glossary

- **DFI**: DDR PHY Interface, the standardised boundary between memory
  controller and PHY.
- **DRFM**: DRAM Refresh Management, the per-bank rowhammer-mitigating refresh
  scheme (JEDEC JESD79-5).
- **PRAC**: Per-Row Activation Counter, used to decide when to issue a DRFM.
- **SEC-DED**: Single-Error-Correct, Double-Error-Detect (Hamming + parity).
- **DPI**: Direct Programming Interface, the C/C++ <-> SV bridge used to plug
  in the DRAMsim4 BFM.
- **CDC**: Clock-Domain Crossing.
- **MBIST**: Memory Built-In Self-Test (March-C+, etc.).
- **PIM**: Processing-In-Memory.
