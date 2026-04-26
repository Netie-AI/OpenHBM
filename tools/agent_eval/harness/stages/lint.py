"""verible-verilog-lint stage."""

from __future__ import annotations

from ..scoring import StageResult
from .common import StageContext, have, list_rtl, run

LINT_CONFIG = ".rules.verible_lint"


def stage_lint(ctx: StageContext) -> StageResult:
    files = list_rtl(ctx.ip_dir)
    if not files:
        return StageResult("lint", 0.0, "no RTL files found")

    if not have("verible-verilog-lint"):
        return StageResult(
            "lint",
            0.0,
            "verible-verilog-lint not on PATH; install OSS CAD Suite",
        )

    cmd = [
        "verible-verilog-lint",
        f"--rules_config={ctx.repo_root / LINT_CONFIG}",
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
