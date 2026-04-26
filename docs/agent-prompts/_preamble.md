# Shared agent prompt preamble

Every per-module prompt under `docs/agent-prompts/` begins with the following
preamble. It is reproduced here so it can be cited and updated in one place.

---

You are working inside the `netie-open-hbm` monorepo. Read `CLAUDE.md` and
`AGENTS.md` BEFORE doing anything else. Pay particular attention to:

- The SystemVerilog-2017 subset and banned constructs (`CLAUDE.md` s1).
- Clock-domain conventions and the mandatory CDC primitive list (`CLAUDE.md` s3).
- The primitive library: `lowrisc_prim`, `pulp_common_cells`, `prim_generic`
  (`CLAUDE.md` s5). Do not re-roll a primitive that already exists.
- The Hjson + `util/reggen/regtool.py` rule for every CSR (`CLAUDE.md` s7).
- The assertion-first workflow for new IPs (`CLAUDE.md` s13).

All code MUST:

1. Be Apache-2.0-licensed with the standard SPDX header.
2. Lint clean under
   `verible-verilog-lint --rules-config=.rules.verible_lint`.
3. Elaborate cleanly in Verilator 5.046+ with
   `-Wall -Wpedantic --timing`.
4. Pass `yosys -p 'hierarchy -check; proc; opt; check'`.
5. Carry SVA assertions for every protocol invariant.

Before writing implementation, produce in this order:

1. A port and parameter table (markdown).
2. A cycle-by-cycle timing narrative (RTL header comments).
3. SVA assertions for every protocol invariant.

After implementation, write a cocotb testbench with a Python golden reference
model in `dv/env/` and directed + `pyvsc`-constrained-random tests. Never
sample signals across clock domains without `prim_sync_2flop` or
`prim_fifo_async`. All CSRs must be declared in Hjson and generated via
`util/reggen/regtool.py`.

Open a single PR that includes:

- The module's RTL and its register file.
- The cocotb testbench.
- The Hjson register declaration.
- Wavedrom timing diagrams in the IP's `doc/<ip>.md`.
- An ADR entry under `docs/rfcs/` for any non-obvious choice.
- A link to the SymbiYosys BMC trace (passing or annotated).

Run `make agent-eval IP=<ip>` locally first. The score must be >=80/100. If
it is below 80, read the harness's `feedback/<ip>/` directory before trying
again -- previous failed attempts have left structured notes for you.

If you are uncertain whether a construct is allowed, default to "no" and ask
in the RFC, not in code.
