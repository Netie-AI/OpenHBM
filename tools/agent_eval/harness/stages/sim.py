"""Cocotb simulation stage.

Invokes `make -C hw/ip/<ip>/dv` which is expected to honour:
  - SIM=verilator|icarus
  - COCOTB_RESULTS_FILE
  - WAVES=1 to dump VCD
"""

from __future__ import annotations

import os
import re
import xml.etree.ElementTree as ET
from pathlib import Path

from ..scoring import StageResult
from .common import StageContext, have, run


def _parse_results(results_xml: Path) -> tuple[int, int]:
    """Return (passed, total)."""
    if not results_xml.exists():
        return 0, 0
    tree = ET.parse(results_xml)
    root = tree.getroot()
    total = 0
    failed = 0
    for ts in root.iter("testsuite"):
        total += int(ts.get("tests", "0"))
        failed += int(ts.get("failures", "0"))
        failed += int(ts.get("errors", "0"))
    if total > 0:
        return total - failed, total

    # Cocotb/pytest JUnit often emits <testcase> rows without testsuite counters.
    cases = list(root.iter("testcase"))
    if not cases:
        return 0, 0
    total = len(cases)
    failed = 0
    for tc in cases:
        bad = bool(list(tc.iter("failure")) or list(tc.iter("error")))
        st = (tc.get("status") or "").lower()
        if st in ("fail", "failed", "error"):
            bad = True
        if bad:
            failed += 1
    return total - failed, total


def stage_sim(ctx: StageContext, simulator: str = "verilator") -> StageResult:
    dv_dir = ctx.ip_dir / "dv"
    if not (dv_dir / "Makefile").exists():
        return StageResult("sim_pass", 0.0, "no dv/Makefile")

    if simulator == "verilator" and not have("verilator"):
        return StageResult("sim_pass", 0.0, "verilator missing")
    if simulator == "icarus" and not have("iverilog"):
        return StageResult("sim_pass", 0.0, "iverilog missing")

    env = os.environ.copy()
    env["SIM"] = simulator
    # Some IP DV Makefiles ignore COCOTB_RESULTS_FILE and always emit into dv/.
    # Prefer the canonical dv/results.xml so sim_pass can reliably locate results.
    results = dv_dir / "results.xml"
    env["COCOTB_RESULTS_FILE"] = str(results)

    rc, out, err = run(
        ["make", "-C", str(dv_dir)],
        cwd=ctx.work,
        env=env,
        # Verilator compile + full cocotb regression can exceed 30 min on WSL/C: or CI.
        timeout=3600,
    )
    passed, total = _parse_results(results)
    n_case = len(list(ET.parse(results).getroot().iter("testcase"))) if results.exists() else 0
    if total == 0:
        # Fallback: cocotb regression table uses "** <module>.<test> ... PASS|FAIL".
        blob = out + err
        passed = len(re.findall(r"\*\*\s+[\w.]+\s+PASS\b", blob))
        failed = len(re.findall(r"\*\*\s+[\w.]+\s+FAIL\b", blob))
        total = passed + failed
    if total == 0:
        return StageResult(
            "sim_pass",
            0.0,
            f"no tests reported (results={results}, testcase_nodes={n_case})",
        )
    score = passed / total
    return StageResult(
        "sim_pass",
        score,
        f"{passed}/{total} passed under {simulator} (rc={rc}); "
        f"results={results.name}; testcase_nodes={n_case}",
    )


def stage_func_cov(ctx: StageContext) -> StageResult:
    """Read the cocotb-coverage XML if present and convert to a fraction."""
    cov_file = ctx.ip_dir / "dv" / "coverage.xml"
    if not cov_file.exists():
        cov_file = ctx.work / "coverage.xml"
    if not cov_file.exists():
        return StageResult("func_cov", 0.0, "no coverage.xml")

    tree = ET.parse(cov_file)
    root = tree.getroot()
    total_pts = 0
    hit_pts = 0
    for cp in root.iter("coverpoint"):
        for bin_ in cp.iter("bin"):
            total_pts += 1
            if int(bin_.get("hits", "0")) > 0:
                hit_pts += 1
    if total_pts == 0:
        return StageResult("func_cov", 0.0, "no coverpoints declared")
    fraction = hit_pts / total_pts
    return StageResult(
        "func_cov", fraction, f"{hit_pts}/{total_pts} bins hit ({fraction * 100:.1f}%)"
    )
