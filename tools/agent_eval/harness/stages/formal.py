"""SymbiYosys (sby) formal stage."""

from __future__ import annotations

from ..scoring import StageResult
from .common import StageContext, have, list_sby, run


def stage_formal(ctx: StageContext) -> StageResult:
    sbys = list_sby(ctx.ip_dir)
    if not sbys:
        return StageResult("formal", 0.0, "no .sby files in fpv/")

    if not have("sby"):
        return StageResult("formal", 0.0, "sby (SymbiYosys) not on PATH")

    # Hard-fail tag: any .sby that contains the word `bijection` or `liveness`
    # is treated as load-bearing. Failing one zeros the score.
    hard_fail_keywords = ("bijection", "no_aliasing", "liveness", "no_overlap")

    passed = 0
    total = 0
    failed_load_bearing = False
    detail_lines: list[str] = []
    for sby in sbys:
        total += 1
        # Run sby from repo root so [files] paths stay repo-root-relative (not harness tmp cwd).
        rc, out, err = run(
            ["sby", "-f", str(sby.relative_to(ctx.repo_root))],
            cwd=ctx.repo_root,
            timeout=3600,
        )
        ok = rc == 0
        if ok:
            passed += 1
        else:
            if any(k in sby.name.lower() for k in hard_fail_keywords):
                failed_load_bearing = True
            detail_lines.append(f"FAIL: {sby.name} (rc={rc})")
    if total == 0:
        return StageResult("formal", 0.0, "no tasks ran")
    score = passed / total
    detail = f"{passed}/{total} sby tasks passed"
    if detail_lines:
        detail += "\n" + "\n".join(detail_lines[:10])
    return StageResult("formal", score, detail, hard_fail=failed_load_bearing)
