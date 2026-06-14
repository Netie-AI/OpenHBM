"""Shared helpers used by every stage."""

from __future__ import annotations

import shutil
import subprocess
from dataclasses import dataclass
from pathlib import Path


@dataclass
class StageContext:
    """Inputs every stage receives.

    `ip_dir` is the canonical IP directory under `hw/ip/<ip>/`.
    `work` is a scratch directory the stage may freely write into.
    `repo_root` is the monorepo root, useful for finding shared SVA libraries
    and primitives.
    """

    ip_name: str
    ip_dir: Path
    work: Path
    repo_root: Path


def run(
    cmd: list[str],
    *,
    cwd: Path | None = None,
    env: dict[str, str] | None = None,
    timeout: int = 600,
) -> tuple[int, str, str]:
    """Run a command, capture stdout/stderr. Returns (rc, out, err)."""
    res = subprocess.run(
        cmd,
        cwd=cwd,
        env=env,
        capture_output=True,
        text=True,
        timeout=timeout,
        check=False,
    )
    return res.returncode, res.stdout, res.stderr


def have(tool: str) -> bool:
    return shutil.which(tool) is not None


def list_rtl(ip_dir: Path) -> list[Path]:
    d = ip_dir / "rtl"
    if not d.exists():
        return []
    rtl = sorted(d.glob("*.sv"))
    # Verilator parses files in CLI order; `*_pkg.sv` must precede importers (lexical
    # `refresh_mgr.sv` sorts before `refresh_mgr_pkg.sv` without this).
    pkgs = [p for p in rtl if p.name.endswith("_pkg.sv")]
    rest = [p for p in rtl if not p.name.endswith("_pkg.sv")]
    return sorted(pkgs) + sorted(rest)


def list_dv(ip_dir: Path) -> list[Path]:
    out: list[Path] = []
    for sub in ("env", "tests"):
        d = ip_dir / "dv" / sub
        if d.exists():
            out.extend(sorted(d.glob("*.py")))
    return out


def list_sby(ip_dir: Path) -> list[Path]:
    return sorted((ip_dir / "fpv").glob("*.sby")) if (ip_dir / "fpv").exists() else []
