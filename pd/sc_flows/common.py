"""Shared helpers for SiliconCompiler flows.

Each flow module (`sky130.py`, `ihp130.py`, `asap7.py`, `freepdk45.py`,
`ieda_sky130.py`) exposes a `build(top, args)` function that:

  1. Resolves the top IP under `hw/ip/<top>/`.
  2. Constructs a `siliconcompiler.Chip` (or an iEDA invocation) with the
     correct PDK / lib / constraints.
  3. Runs synth + floorplan + place + cts + route + DRC + LVS + reports.
  4. Writes `build/<top>/<flow>/job0/sc_summary.json` with PPA numbers.
"""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]


@dataclass
class FlowArgs:
    top: str
    flow_name: str

    @property
    def ip_dir(self) -> Path:
        return REPO_ROOT / "hw" / "ip" / self.top

    @property
    def rtl_files(self) -> list[Path]:
        return sorted((self.ip_dir / "rtl").glob("*.sv"))

    @property
    def build_dir(self) -> Path:
        d = REPO_ROOT / "build" / self.top / self.flow_name
        d.mkdir(parents=True, exist_ok=True)
        return d


def make_chip(args: FlowArgs):
    """Construct a siliconcompiler.Chip with our standard knobs."""
    import siliconcompiler  # local import so the file imports without SC installed

    chip = siliconcompiler.Chip(args.top)
    for f in args.rtl_files:
        chip.input(str(f))
    chip.set("design", args.top)
    chip.set("option", "builddir", str(args.build_dir.parent))
    chip.set("option", "jobname", "job0")
    chip.set("option", "quiet", True)
    chip.set("option", "track", True)
    return chip


def write_summary_stub(args: FlowArgs, status: str) -> None:
    """Write a minimal summary even when SC isn't installed (CI dry-runs)."""
    import json
    summary = {
        "design": args.top,
        "flow": args.flow_name,
        "status": status,
        "rtl_files": [str(f.relative_to(REPO_ROOT)) for f in args.rtl_files],
    }
    out = args.build_dir / "job0"
    out.mkdir(parents=True, exist_ok=True)
    (out / "sc_summary.json").write_text(json.dumps(summary, indent=2))
