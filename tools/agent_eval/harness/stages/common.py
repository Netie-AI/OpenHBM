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


def run(cmd: list[str], *, cwd: Path | None = None, timeout: int = 600) -> tuple[int, str, str]:
    """Run a command, capture stdout/stderr. Returns (rc, out, err)."""
    res = subprocess.run(
        cmd,
        cwd=cwd,
        capture_output=True,
        text=True,
        timeout=timeout,
        check=False,
    )
    return res.returncode, res.stdout, res.stderr


def have(tool: str) -> bool:
    return shutil.which(tool) is not None


def list_rtl(ip_dir: Path) -> list[Path]:
    return sorted((ip_dir / "rtl").glob("*.sv")) if (ip_dir / "rtl").exists() else []


def list_dv(ip_dir: Path) -> list[Path]:
    out: list[Path] = []
    for sub in ("env", "tests"):
        d = ip_dir / "dv" / sub
        if d.exists():
            out.extend(sorted(d.glob("*.py")))
    return out


def list_sby(ip_dir: Path) -> list[Path]:
    return sorted((ip_dir / "fpv").glob("*.sby")) if (ip_dir / "fpv").exists() else []
