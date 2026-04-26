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
    results = ctx.work / f"results_{simulator}.xml"
    env["COCOTB_RESULTS_FILE"] = str(results)

    rc, out, err = run(
        ["make", "-C", str(dv_dir)],
        cwd=ctx.work,
        timeout=1800,
    )
    passed, total = _parse_results(results)
    if total == 0:
        # Fallback to scraping cocotb output for "PASS"/"FAIL".
        passed = len(re.findall(r"\* TEST .* PASS", out + err))
        failed = len(re.findall(r"\* TEST .* FAIL", out + err))
        total = passed + failed
    if total == 0:
        return StageResult("sim_pass", 0.0, "no tests reported")
    score = passed / total
    return StageResult(
        "sim_pass",
        score,
        f"{passed}/{total} passed under {simulator} (rc={rc})",
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
        "func_cov", fraction, f"{hit_pts}/{total_pts} bins hit ({fraction*100:.1f}%)"
    )
