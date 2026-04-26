# AGENTS.md

This file is the entry point for any AI coding agent (Claude, GPT, Gemini, or
otherwise) operating in this repository. It is the symlink-equivalent companion
to `CLAUDE.md` -- agents that look for `AGENTS.md` first should read both.

**Read `CLAUDE.md` next.** It contains the binding contract: SystemVerilog
subset, banned constructs, clock-domain rules, primitive library, CSR
generation rule, and the assertion-first workflow.

## Operating principles

1. **Spec first, code second.** Before writing any RTL, produce a port and
   parameter table, a cycle-by-cycle timing narrative, and SVA assertions for
   every protocol invariant. Then implement.
2. **Test-with against a Python golden reference.** Every leaf IP gets a
   `dv/env/<ip>_ref.py` model. Cocotb tests check RTL output against the
   reference, not against handwritten expected values.
3. **Lint clean, formal clean, mutation-tested.** A PR is not mergeable until
   `verible-verilog-lint`, `verilator -Wall --timing`, the cocotb suite,
   `sby` (where applicable), and `mcy` mutation coverage all pass the gate
   threshold (80/100 score; see `tools/agent_eval/harness/scoring.py`).
4. **Hjson + reggen for every CSR.** Never hand-write a CSR file.
5. **DCO on every commit.** `git commit -s`. No exceptions.
6. **No JEDEC PDF redistribution.** Spec summaries go in `docs/spec/`, derived
   clean-room from the free-registration PDF held in a non-redistributable
   local cache.
7. **No iEDA / OSCC code vendored into `hw/vendor/` until export-controls
   counsel and license counsel both clear it.** See
   [`docs/legal/export_control.md`](docs/legal/export_control.md). Use iEDA via
   the prebuilt Docker image as a tool only.

## Where to look

| You want to ...                                         | Read                                              |
| ------------------------------------------------------- | ------------------------------------------------- |
| Understand the strategic plan                           | `Plan.md`                                         |
| Understand the current execution sprint                 | `.cursor/plans/openhbm4_*.plan.md`                |
| Find the binding RTL style contract                     | `CLAUDE.md`                                       |
| Generate RTL for a specific IP                          | `docs/agent-prompts/<ip>.md`                      |
| Run the eval harness                                    | `tools/agent_eval/harness/run.py`                 |
| Add a new IP                                            | `docs/rfcs/template.md`                           |
| Vendor an external dependency                           | `util/vendor.py` + `hw/vendor/*.lock.hjson`       |
| Run an ASIC flow                                        | `pd/sc_flows/<target>.py`                         |
| Reproduce the toolchain                                 | `flake.nix` or `.devcontainer/devcontainer.json`  |

## What you must NOT do

- Modify `Plan.md` or any `.cursor/plans/*.plan.md` without being explicitly
  told to. These are user-owned artefacts.
- Commit any JEDEC PDF, Cadence/Synopsys-licensed netlist, NDA-bound SDF, or
  vendor PHY model. The repository is monitored.
- Skip the formal/mutation-coverage gates because "the change is small."
- Use four-state `wire` types in synthesisable code, `force`/`release`,
  `disable fork`, or any other construct banned by `CLAUDE.md`.
- Author CSRs by hand. Use `util/reggen/regtool.py`.
- Sample signals across clock domains without `prim_sync_2flop` or
  `prim_fifo_async`.

## Communication

- All technical decisions go through `docs/rfcs/` (RFC-style ADRs).
- Bug reports and design discussion go through GitHub issues.
- Hot patches still need DCO sign-off.
