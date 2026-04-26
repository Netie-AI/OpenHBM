"""Cross-flow PPA delta reporter.

Walks the asic.yml CI artefact tree and produces a markdown table comparing
PPA across (sky130, ihp130, asap7, ieda_sky130) for each top-level IP.
A delta >threshold-pct on any metric raises a soft warning; >2x raises
a hard failure (exit 1).
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path

METRICS = ("area_um2", "fmax_mhz", "leakage_uW", "dynamic_uW")


def discover(artifacts: Path) -> dict[tuple[str, str], dict]:
    """Map (top, flow) -> sc_summary dict."""
    out: dict[tuple[str, str], dict] = {}
    for summary in artifacts.glob("**/sc_summary.json"):
        data = json.loads(summary.read_text())
        out[(data["design"], data["flow"])] = data
    return out


def render(table: dict[tuple[str, str], dict], threshold_pct: float) -> tuple[str, int]:
    tops = sorted({t for t, _ in table})
    flows = sorted({f for _, f in table})
    lines = ["# Cross-flow PPA delta", ""]
    lines.append("Threshold: " + f"{threshold_pct:.1f}%" + " (soft warn) / 200% (hard fail)")
    lines.append("")

    bad = 0
    for top in tops:
        lines.append(f"## `{top}`")
        lines.append("")
        header = "| flow | status | " + " | ".join(METRICS) + " |"
        sep    = "| --- | --- | " + " | ".join(["---:"] * len(METRICS)) + " |"
        lines.append(header)
        lines.append(sep)
        rows = []
        for f in flows:
            data = table.get((top, f))
            if not data:
                lines.append(f"| `{f}` | (no result) |" + " - |" * len(METRICS))
                continue
            row = [f"`{f}`", data.get("status", "?")]
            for m in METRICS:
                v = data.get(m)
                row.append("-" if v is None else f"{v:.2f}")
            lines.append("| " + " | ".join(row) + " |")
            rows.append((f, data))

        # Compute pairwise deltas vs the first known-good flow.
        baseline = next((d for _, d in rows if d.get("status") == "ok"), None)
        if baseline:
            for f, d in rows:
                if d is baseline or d.get("status") != "ok":
                    continue
                for m in METRICS:
                    bv = baseline.get(m)
                    dv = d.get(m)
                    if bv is None or dv is None or bv == 0:
                        continue
                    pct = abs(dv - bv) / abs(bv) * 100.0
                    if pct > 200.0:
                        bad += 1
                        lines.append(
                            f"- HARD FAIL: `{f}` vs baseline on {m}: {pct:.1f}% delta"
                        )
                    elif pct > threshold_pct:
                        lines.append(
                            f"- WARN: `{f}` vs baseline on {m}: {pct:.1f}% delta"
                        )
        lines.append("")
    return "\n".join(lines), bad


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--artifacts", required=True, type=Path)
    ap.add_argument("--output", required=True, type=Path)
    ap.add_argument("--threshold-pct", type=float, default=10.0)
    args = ap.parse_args()

    table = discover(args.artifacts)
    md, bad = render(table, args.threshold_pct)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(md)
    print(md)
    if bad:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
