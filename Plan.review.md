# Plan.review.md -- redline scaffold for the GPT-5.5 review pass

This file is the **single artefact** the GPT-5.5 reviewer should write
into. It exists so the Claude-4.7 third pass has one and only one place
to merge a diff.

Workflow per the user's request:

1. Claude-4.7 wrote the original [`Plan.md`](Plan.md) and the execution
   plan at
   `.cursor/plans/openhbm4_automation_and_pipeline_bootstrap_*.plan.md`.
2. Claude-4.7 (this run) executed Tracks A, B, and C of the plan and
   landed the artefacts described under the "What we landed" heading
   below.
3. **GPT-5.5 reviews and validates this state**, fills in the
   sections marked `<<<` ... `>>>` below, and proposes a redline diff
   against `Plan.md` if it disagrees with the strategic posture.
4. Claude-4.7 takes the redline back and converges. No silicon-bound
   RTL is frozen until that third pass approves.

---

## What we landed (Claude-4.7, this pass)

This is the ground truth as of the end of execution. Keep it factual --
GPT-5.5 should call out anything it disagrees with in its
"Areas of disagreement" section below.

### Repository
- Apache-2.0 LICENSE + NOTICE + README + .gitignore.
- OpenTitan-style hw/ip / hw/subsystems / hw/top / hw/vendor / hw/vip /
  hw/formal layout, with FuseSoC `<ip>.core` manifests.
- AGENTS.md and binding CLAUDE.md (SV-2017 subset, banned constructs,
  CDC primitive list, primitive library, CSR-via-reggen rule,
  assertion-first workflow, DCO + Conventional Commits).
- `.rules.verible_lint` rules config.

### Toolchain pinning
- `flake.nix` pinning OSS CAD Suite 2026-04-02.
- `.devcontainer/devcontainer.json` plus
  `.devcontainer/install_oss_cad_suite.sh` for VSCode + Codespaces.
- `pyproject.toml` with cocotb 2.0.1, pyuvm 4.0.1, SiliconCompiler
  0.34.0, ruff, mypy, mkdocs, sphinx pinned.
- Top-level `Makefile` orchestrator with `lint` / `synth-check` / `sim`
  / `formal` / `pd` / `agent-eval` / `smoke` targets.

### CI matrix
- `.github/workflows/lint.yml` -- verible + ruff + hjson schema check.
- `.github/workflows/sim.yml` -- cocotb x (verilator, icarus) x (addr_map, ecc, refresh_mgr).
- `.github/workflows/formal.yml` -- SymbiYosys per IP, weekly deep run.
- `.github/workflows/fpga.yml` -- workflow_dispatch Vivado on Alveo U55C/U280/VCK5000.
- `.github/workflows/asic.yml` -- weekly SC sky130 + ihp130 + asap7 + ieda_sky130 + cross-flow delta.
- `.github/workflows/agent-eval.yml` -- corpus regression on prompt changes.
- `.github/workflows/chiplet.yml` -- workflow_dispatch iPL-3D + openEMS pipeline.

### Vendor system
- `util/vendor.py` (CLI: refresh / verify / list).
- Lockfiles: `lowrisc_prim`, `opentitan_regtool`, `pulp_common_cells`,
  `pulp_redmule`, `openhw_cva6`, `litedram_ref`, `dramsim3_ref`.

### AI-agent training pipeline (Track B)
- `CLAUDE.md` (binding contract).
- `docs/agent-prompts/_preamble.md` plus 8 per-IP prompts.
- `tools/agent_eval/` -- harness with stages (lint, elab, sim, func_cov, formal, mutation),
  IpScoring with per-IP weights, structured feedback writer,
  `nieda-eval` CLI.
- `tools/agent_eval/corpus/` -- 30 mini-blocks (5 fully landed:
  `fifo_sync`, `cdc_2flop`, `arbiter_rr`, `hsiao_secded`,
  `xor_addr_mapper_toy`; 25 stubs that exercise the harness end-to-end).

### Lighthouse RTL: `hw/ip/addr_map`
- Full RTL: `addr_map_pkg.sv`, `addr_map_xor.sv`,
  `addr_map_region_table.sv`, `addr_map_reg_top.sv`, `addr_map.sv`.
- Hjson register description (`data/addr_map.hjson`).
- Pure-Python golden (`dv/env/addr_map_ref.py`).
- Cocotb directed + CRT + back-pressure tests.
- 2 SymbiYosys tasks: `addr_map_inj.sby`, `addr_map_bound.sby`.
- ADR `docs/rfcs/0001-addr-map-policy.md`.
- 3 trace files (`vllm_decode.trc`, `flash_attn3.trc`, `sglang_prefill.trc`).

### Skeleton RTL
- `hw/ip/hbm4_ctrl` -- `hbm4_ctrl_pkg.sv` + `hbm4_bank_machine.sv` +
  `hbm4_ctrl.sv` (Phase-1 skeleton with cycle-by-cycle narrative, SVA stubs).
- `hw/ip/ecc` -- SEC-DED Hsiao (full) + chipkill RS placeholder + dispatcher.
- `hw/ip/refresh_mgr` -- DRFM + PRAC + credit pool.
- All three: cocotb Makefiles, dv/env/<ip>_ref.py for ECC, SymbiYosys
  task files for SEC-DED correction and refresh liveness.

### Behavioural HBM4 BFM
- `hw/vip/dramsim4/README.md` -- plan of record.
- `cfg/hbm4_8gbps.ini` -- DRAMsim3-compatible config with HBM4 geometry
  and timing bounds.
- `python/dramsim4_dpi.py` -- Phase-0 transactor stub for cocotb.

### Track-C open EDA + transistor-level
- SiliconCompiler flow modules: `sky130.py`, `ihp130.py`, `asap7.py`,
  `freepdk45.py`, `ieda_sky130.py` (second-source via Docker).
- `runner.py` CLI plus `cross_flow_delta.py` PPA delta reporter.
- `pd/cells/` xschem + ngspice + magic + klayout + netgen Makefile;
  PDK-conditional rcfiles for sky130 and asap7.
- `pkg/openems/model.py` + `run_screen.py` -- parameterised organic-
  substrate stack with analytic-fallback SI metrics.
- `pd/chiplet/ipl3d/run.py` -- two-die placement driver (placeholder
  output that feeds `pkg/openems/`).
- `hw/top/tt_sky_tile/` (TTSKY26b) and `hw/top/tt_ihp_tile/` (TTIHP26a)
  Tiny Tapeout submission scaffolds.

### Documentation site
- `docs/site/conf.py` (Sphinx) and `mkdocs.yml` (MkDocs Material).
- `docs/arch/overview.md` -- top-level mermaid diagram.
- `docs/spec/hbm4_timing.adoc` -- clean-room HBM4 timing summary.
- `docs/arxiv/preprint.tex` + `preprint.bib` -- arXiv preprint scaffold.

### Legal / governance / grants
- `docs/legal/export_control.md` -- iEDA posture, contributor nationality,
  PDK-class table.
- `docs/grants/nlnet_2026q4.md` -- DRAFT v0.1 NLnet NGI0 Commons Fund
  application, EUR 50k ask.
- `docs/agent-prompts/_research/aieda_notes.md` -- AiEDA + AiMap +
  iPL-3D study notes (no code vendoring).

---

## Sections for the GPT-5.5 reviewer to fill in

### 1. Strategy validation

```
<<<
Does the trademark-enforced JEDEC-compatibility moat (Plan.md s12) still
look right under late-2026 conditions? Specifically:
  - Is the 24-month window still credible vs Rubin Ultra and MI500?
  - Are CXMT / YMTC still plausible allies-of-convenience?
  - Is the Phase-4 base-die path on TSMC N5 / SK Hynix Open Collaboration
    a realistic stretch or should it be downgraded?
GPT-5.5: write your assessment here. Cite sources.
>>>
```

### 2. Technical posture validation

```
<<<
For each of the load-bearing technical bets, validate or push back:

A. addr_map: programmable XOR, 3 modes, per-region polynomial.
   - Is the bijection-via-region-relative-offset story actually what we
     want, or are there workloads where cross-region aliasing is desirable?
   - Are 16 regions enough for vLLM + SGLang + agentic-tool tenants?

B. refresh_mgr: Misra-Gries top-K + per-bank credit deferral.
   - Do the DREAM ISCA 2025 numbers still hold against newer attacker
     models (USENIX Sec '25 16-high)?
   - Is the K=64 top-K table sized right for HBM4 row counts?

C. ecc: SEC-DED Hsiao + RS chipkill behind ECC_CLASS.
   - TU Berlin "silent data corruption at scale" (April 2026) -- does
     SEC-DED still suffice, or do we need a hybrid stack?

D. hbm4_phy_shim: Alveo U55C HBM2 backstop in Phase 1, commercial PHY
   adapter in Phase 3.
   - Is HBM2 a representative-enough emulator? Or do we need to wait for
     HBM3-on-FPGA to be meaningful?

E. agent-eval: 80/100 gate, mutation coverage mandatory, hard-fail on
   bijection / liveness proofs.
   - Is the 80 threshold too lax? Too strict? Should weights be tuned
     per phase?

GPT-5.5: write your assessment here.
>>>
```

### 3. Toolchain validation

```
<<<
Is OSS CAD Suite 2026-04-02 + cocotb 2.0.1 + SiliconCompiler 0.34.0 +
ASAP7 1.7 the right pin?
  - Any known regressions in 2026-04-02?
  - Should we pin a later release, or stay with the more-tested
    2026-02-06?
  - For ASAP7: 7.5-track vs 6-track default -- which gives us better
    PPA on addr_map?

GPT-5.5: write your assessment here.
>>>
```

### 4. iEDA / OSCC posture validation

```
<<<
Is the export-control posture in docs/legal/export_control.md
defensible?
  - Is "tool, not contributor channel" a meaningful distinction at the
    EAR level for sub-16nm?
  - Should the iEDA second-source path be quarantined further (e.g.
    forbidden even on open PDKs above 130 nm)?
  - Is the "OpenROAD shadow before commercial-shuttle flow" rule
    sufficient, or do we need a stronger separation (e.g. separate
    branches, separate maintainer set)?

GPT-5.5: write your assessment here.
>>>
```

### 5. Areas of disagreement (free-form)

```
<<<
Anything else where Claude-4.7's first pass got it wrong. Be specific.
Be redline. We will fold every accepted disagreement into Plan.md and
re-engage Claude-4.7 to converge.
>>>
```

### 6. Redline diff against Plan.md

```
<<<
If you propose changes to the canonical Plan.md (s1 PRD, s3 phases, s6
foundry roadmap, s7 governance, s8 funding, s10 competitive landscape,
s11 risk register, s12 strategic conclusion), produce a unified diff
here. Use markdown patch syntax:

  *** Plan.md (line N) ***
  - Old text
  + New text
  *** End ***
>>>
```

### 7. Sign-off

```
<<<
Reviewer:        GPT-5.5
Date:            ____
Verdict:         [ ] approve as-is
                 [ ] approve with the redlines above
                 [ ] reject, return to Claude-4.7 with this redline
Open questions:  ____
>>>
```

---

## After the GPT-5.5 review

Once GPT-5.5 has filled in the sections above, hand this file back to
Claude-4.7. Claude-4.7 will:

1. Diff the redlines against `Plan.md` and the artefacts under
   `c:\Users\oojia\OpenHBM\` produced in this pass.
2. Open one PR per accepted redline (so each change is reviewable in
   isolation).
3. Update `Plan.md` itself only if the redline crosses the strategic
   threshold (changes a Phase deliverable or a Phase boundary).
4. Re-run the eval harness against the corpus to confirm the changes
   don't regress the harness.
5. Mark this file as `RESOLVED <date>` at the top, archive it under
   `docs/reviews/`, and start the next review cycle.

No silicon-bound RTL is frozen until this loop converges.
