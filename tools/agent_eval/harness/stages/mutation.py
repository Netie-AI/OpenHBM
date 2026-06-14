"""Mutation-coverage stage using `mcy` (mutation-coverage-yosys).

We invoke `mcy run -j$NPROC` and read the `database/results.txt` file. The
metric is the fraction of mutants killed by the existing testsuite.
"""

from __future__ import annotations

import os
from pathlib import Path

from ..scoring import StageResult
from .common import StageContext, have, run


def _read_kill_rate(database: Path) -> tuple[int, int]:
    """Return (killed, total) from mcy's results file."""
    results = database / "results.txt"
    if not results.exists():
        return 0, 0
    killed = total = 0
    for line in results.read_text().splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        # Format: "<mutant_id> <FAIL|PASS|...> ..."
        parts = line.split()
        if len(parts) < 2:
            continue
        total += 1
        # mcy convention: FAIL means the mutant was caught by the test
        # (the test's expected pass turned into a fail) -- i.e. killed.
        if parts[1].upper() in {"FAIL", "ERROR", "TIMEOUT"}:
            killed += 1
    return killed, total


def stage_mutation(ctx: StageContext) -> StageResult:
    mcy_dir = ctx.ip_dir / "dv" / "mcy"
    if not (mcy_dir / "config.mcy").exists():
        return StageResult("mutation", 0.0, "no dv/mcy/config.mcy")

    if not have("mcy"):
        return StageResult("mutation", 0.0, "mcy not on PATH")

    nproc = os.cpu_count() or 4
    rc, _out, _err = run(
        ["mcy", "init", "-f"],
        cwd=mcy_dir,
        timeout=600,
    )
    if rc != 0:
        return StageResult("mutation", 0.0, f"mcy init failed: rc={rc}")
    rc, _out, _err = run(
        ["mcy", "run", "-j", str(nproc)],
        cwd=mcy_dir,
        timeout=7200,
    )
    if rc != 0:
        return StageResult("mutation", 0.0, f"mcy run failed: rc={rc}")

    killed, total = _read_kill_rate(mcy_dir / "database")
    if total == 0:
        return StageResult("mutation", 0.0, "no mutants generated")
    fraction = killed / total
    return StageResult(
        "mutation",
        fraction,
        f"{killed}/{total} mutants killed ({fraction * 100:.1f}%)",
    )
