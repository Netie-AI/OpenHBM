"""Verilator elaboration stage (`verilator -Wall --timing -Wpedantic --lint-only`)."""

from __future__ import annotations

from ..scoring import StageResult
from .common import StageContext, have, list_rtl, run


def stage_elab(ctx: StageContext) -> StageResult:
    files = list_rtl(ctx.ip_dir)
    if not files:
        return StageResult("elab", 0.0, "no RTL files found")

    if not have("verilator"):
        return StageResult("elab", 0.0, "verilator not on PATH")

    cmd = [
        "verilator",
        "--lint-only",
        "-Wall",
        "-Wpedantic",
        "--timing",
        "-sv",
        "-Wno-fatal",
        "--top-module",
        ctx.ip_name,
        *[str(p) for p in files],
    ]
    # Make sure shared SVA libs and primitives are visible.
    sva_lib = ctx.repo_root / "hw/formal/sva_lib"
    prim_dir = ctx.repo_root / "hw/ip/prim_generic/rtl"
    # Verilator requires `-I<dir>` glued; `-I <dir>` mis-parses the path as a source file.
    if sva_lib.exists():
        cmd.append("-I" + str(sva_lib))
    if prim_dir.exists():
        cmd.append("-I" + str(prim_dir))

    rc, out, err = run(cmd, cwd=ctx.work, timeout=300)
    if rc == 0:
        return StageResult("elab", 1.0, "clean")

    err_lines = (err or out).strip().splitlines()
    detail = "\n".join(err_lines[:20])
    # Distinguish: warnings only (rc=0), warnings escalated to errors via -Wall (rc!=0).
    n_err = sum(1 for l in err_lines if "%Error" in l)
    n_warn = sum(1 for l in err_lines if "%Warning" in l)
    score = max(0.0, 1.0 - (n_err * 0.3 + n_warn * 0.05))
    return StageResult("elab", score, f"errors={n_err} warnings={n_warn}\n{detail}")
