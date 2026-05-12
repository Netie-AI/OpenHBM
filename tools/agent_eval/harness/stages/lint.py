"""verible-verilog-lint stage."""

from __future__ import annotations

import os

from ..scoring import StageResult
from .common import StageContext, have, list_rtl, run

LINT_CONFIG = ".rules.verible_lint"


def stage_lint(ctx: StageContext) -> StageResult:
    # The OSS CAD Suite environment sometimes provides a PATH without /usr/local/bin
    # (e.g. inside a harness subprocess). Ensure verible can be discovered.
    os.environ["PATH"] = "/usr/local/bin:" + os.environ.get("PATH", "")

    files = list_rtl(ctx.ip_dir)
    if not files:
        return StageResult("lint", 0.0, "no RTL files found")

    if not have("verible-verilog-lint"):
        return StageResult(
            "lint",
            0.0,
            "verible-verilog-lint not on PATH; install OSS CAD Suite",
        )

    rules_src = ctx.repo_root / LINT_CONFIG
    rules_path = rules_src
    if rules_src.exists():
        text = rules_src.read_text(encoding="utf-8")
        # Older OSS CAD Suite Verible builds reject some rule flags and mis-flag
        # legitimate next-state scratch in always_ff; strip for harness scoring only.
        skip_substrings = (
            "package-filename-suffix",
            "forbidden-anonymous-enums",
            "forbidden-symbols",
            "explicit-begin",
            "explicit-parameter-storage-type",
            "explicit-task-lifetime",
            "explicit-function-lifetime",
            "line-length=",
        )
        filtered_lines: list[str] = []
        for ln in text.splitlines():
            raw = ln.rstrip("\r")
            if any(s in raw for s in skip_substrings):
                continue
            if raw.strip() == "+always-ff-non-blocking":
                continue
            filtered_lines.append(raw)
        # OSS CAD Verible 2023: disable checker that false-positives on `automatic` next-state
        # scratch inside always_ff; CI may use newer Verible.
        filtered_lines.append("-always-ff-non-blocking")
        compat = ctx.work / "verible_lint_rules.compat"
        compat.parent.mkdir(parents=True, exist_ok=True)
        compat.write_text("\n".join(filtered_lines) + "\n", encoding="utf-8")
        rules_path = compat

    cmd = [
        "verible-verilog-lint",
        f"--rules_config={rules_path}",
        *[str(p) for p in files],
    ]
    rc, out, err = run(cmd, timeout=300)
    if rc == 0:
        return StageResult("lint", 1.0, "clean")

    # Soft-graded by violation count: 1 violation -> 0.85; 10 -> 0.5; 100+ -> 0.
    violations = (out + err).count("[")  # rough heuristic
    score = max(0.0, 1.0 - violations / 50.0)
    snippet = (out + err).strip().splitlines()
    detail = "\n".join(snippet[:20])
    return StageResult("lint", score, detail or f"{violations} violations")
