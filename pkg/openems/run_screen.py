"""SI/PI screen driver for the chiplet pipeline.

Invoked by `.github/workflows/chiplet.yml`. Reads a floorplan DEF or a
parameter sweep, runs openEMS in batch, and writes a JSON report.

For Phase-0 the screen is a *placeholder* that runs the geometry build
(without solving) and emits a synthesised report. Replace the inner
solver invocation with real `openEMS.Run()` once the toolchain is
provisioned in CI.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path

from .model import StackParams, build_structure


def screen(p: StackParams) -> dict:
    csx = build_structure(p)
    have_solver = csx is not None
    # Placeholder metrics derived from a simple analytic stripline model.
    # Real run replaces this with openEMS-extracted S-params.
    f_ghz = p.nyquist_ghz
    eps  = p.dielectric_eps_r
    bridge = p.bridge_length_um / 1000.0  # mm
    # Insertion loss approx: -0.05 * f * sqrt(eps) * length_mm (rule of thumb)
    s21_db = -0.05 * f_ghz * (eps ** 0.5) * bridge
    # Worst NEXT at small uBump pitch; rough analytic ceiling:
    next_db = -28 + (40 - p.ubump_pitch_um) * 0.4
    return {
        "have_openems": have_solver,
        "params": p.__dict__,
        "s21_db_at_nyquist": round(s21_db, 2),
        "next_db_worst":     round(next_db, 2),
        "fext_db_worst":     round(next_db - 4.0, 2),
        "estimated_eye_pct": max(0.0, 100.0 + s21_db * 5 + next_db * 1.5),
        "verdict_si":        "PASS" if next_db < -25 else "WARN",
    }


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--floorplan", type=Path, required=False,
                    help="DEF file from iPL-3D (optional)")
    ap.add_argument("--datarate-gbps", type=float, default=8.0)
    ap.add_argument("--lanes", type=int, default=2048)
    ap.add_argument("--ubump-pitch-um", type=float, default=35.0)
    ap.add_argument("--bridge-length-um", type=float, default=1000.0)
    ap.add_argument("--output", type=Path, required=True)
    args = ap.parse_args()

    p = StackParams(
        ubump_pitch_um=args.ubump_pitch_um,
        bridge_length_um=args.bridge_length_um,
        data_rate_gbps=args.datarate_gbps,
        lanes=args.lanes,
    )
    report = screen(p)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, indent=2))
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    main()
