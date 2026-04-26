"""Structured feedback writer for failing eval runs.

When the harness scores a candidate below the gate, this module writes
a markdown brief into `tools/agent_eval/feedback/<ip>/` that the next
agent run reads BEFORE generating its next attempt. This is the
"prompt-conditioning" loop that lets us stop running blind retries.
"""

from __future__ import annotations

import datetime as dt
import json
from pathlib import Path

from .scoring import IpScoring


def write_feedback(scoring: IpScoring, dest_root: Path) -> Path:
    dest = dest_root / scoring.ip_name
    dest.mkdir(parents=True, exist_ok=True)
    ts = dt.datetime.utcnow().strftime("%Y%m%dT%H%M%SZ")
    md = dest / f"{ts}.md"
    js = dest / f"{ts}.json"

    js.write_text(json.dumps(scoring.to_dict(), indent=2))

    lines = []
    lines.append(f"# Eval feedback: `{scoring.ip_name}` -- {ts}")
    lines.append("")
    lines.append(f"Total score: **{scoring.total():.1f} / 100**  ")
    lines.append(f"Threshold: {scoring.threshold:.0f}  ")
    lines.append(f"Result: **{'PASS' if scoring.passed() else 'FAIL'}**")
    lines.append("")
    lines.append("## Stage breakdown")
    lines.append("")
    lines.append("| stage | unit | weight | hard_fail | detail |")
    lines.append("| --- | ---: | ---: | :---: | --- |")
    weight_for = {
        "lint": scoring.weights.lint,
        "elab": scoring.weights.elab,
        "sim_pass": scoring.weights.sim_pass,
        "func_cov": scoring.weights.func_cov,
        "formal": scoring.weights.formal,
        "mutation": scoring.weights.mutation,
    }
    for s in scoring.stages:
        first_line = s.detail.splitlines()[0] if s.detail else ""
        lines.append(
            f"| {s.stage} | {s.score_unit:.2f} | {weight_for[s.stage]:.0f} | "
            f"{'YES' if s.hard_fail else ''} | {first_line} |"
        )
    lines.append("")
    lines.append("## What to fix next")
    lines.append("")
    for s in scoring.stages:
        if s.score_unit >= 0.95:
            continue
        lines.append(f"### {s.stage} -- score {s.score_unit:.2f}")
        lines.append("")
        if s.detail:
            lines.append("```")
            lines.append(s.detail)
            lines.append("```")
            lines.append("")
        lines.append(_hints_for(s.stage))
        lines.append("")
    md.write_text("\n".join(lines))
    return md


def _hints_for(stage: str) -> str:
    return {
        "lint": (
            "- Re-read `CLAUDE.md` s1.2 for banned constructs.\n"
            "- Set `default_nettype none` at every file top.\n"
            "- Use `logic`, never `wire`/`reg` in synthesisable code."
        ),
        "elab": (
            "- Verilator `--lint-only -Wall -Wpedantic --timing`.\n"
            "- Most warnings come from un-driven nets, multi-driver, or width\n"
            "  mismatches. Fix at the source; do not waive in the lint config."
        ),
        "sim_pass": (
            "- Make sure `dv/Makefile` honours `SIM=verilator` and\n"
            "  `COCOTB_RESULTS_FILE`.\n"
            "- Add a directed test for every assertion in the spec table."
        ),
        "func_cov": (
            "- Declare cocotb `CoverPoint`s for protocol cross-coverage.\n"
            "- Aim for >=95% bin hits on protocol cross-coverage.\n"
            "- Add `pyvsc`-constrained-random tests; CRT is the cheapest way\n"
            "  to lift coverage."
        ),
        "formal": (
            "- A failing `*_bijection.sby` or `*_liveness.sby` is a HARD FAIL\n"
            "  -- the merge is blocked regardless of total score.\n"
            "- Read the trace under `fpv/<task>_check/engine_*/trace.vcd`.\n"
            "- Strengthen the abstraction (`fpv/abs_*.sv`) before adding\n"
            "  `assume property` to the DUT itself."
        ),
        "mutation": (
            "- Pull `mcy` output from `database/results.txt` and look at the\n"
            "  un-killed mutants. Each one shows you a coverage hole.\n"
            "- Add the corresponding cocotb test or a `pyvsc` constraint."
        ),
    }.get(stage, "")
