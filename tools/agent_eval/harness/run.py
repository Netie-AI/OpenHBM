"""CLI entry point for the agent-eval harness.

Usage
-----

    # Evaluate one IP via its prompt file:
    python -m tools.agent_eval.harness.run --prompt docs/agent-prompts/addr_map.md

    # Run the full corpus regression (CI):
    python -m tools.agent_eval.harness.run --corpus tools/agent_eval/corpus/ \\
        --report build/agent_eval_report.json --gate 80
"""

from __future__ import annotations

import argparse
import json
import re
import sys
import tempfile
from pathlib import Path

from rich.console import Console
from rich.table import Table

from .feedback import write_feedback
from .scoring import IpScoring, weights_for
from .stages.common import StageContext
from .stages.elab import stage_elab
from .stages.formal import stage_formal
from .stages.lint import stage_lint
from .stages.mutation import stage_mutation
from .stages.sim import stage_func_cov, stage_sim

REPO_ROOT = Path(__file__).resolve().parents[3]


def evaluate_ip(ip_name: str, *, run_mutation: bool = True, run_formal: bool = True) -> IpScoring:
    ip_dir = REPO_ROOT / "hw" / "ip" / ip_name
    if not ip_dir.exists():
        raise FileNotFoundError(f"hw/ip/{ip_name} not found")

    scoring = IpScoring(ip_name=ip_name, weights=weights_for(ip_name))
    with tempfile.TemporaryDirectory(prefix=f"eval-{ip_name}-") as tmp:
        ctx = StageContext(
            ip_name=ip_name,
            ip_dir=ip_dir,
            work=Path(tmp),
            repo_root=REPO_ROOT,
        )
        for fn in (stage_lint, stage_elab, stage_sim, stage_func_cov):
            scoring.stages.append(fn(ctx))
        if run_formal:
            scoring.stages.append(stage_formal(ctx))
        if run_mutation:
            scoring.stages.append(stage_mutation(ctx))
    return scoring


def _ip_name_from_prompt(prompt: Path) -> str:
    text = prompt.read_text(encoding="utf-8")
    # Look for `hw/ip/<name>` in the first heading line.
    m = re.search(r"hw/ip/(\w+)", text)
    if m:
        return m.group(1)
    # Fallback: file basename minus .md.
    return prompt.stem


def main() -> None:
    ap = argparse.ArgumentParser(description="Agent-eval harness")
    g = ap.add_mutually_exclusive_group(required=True)
    g.add_argument("--prompt", type=Path, help="Path to a prompt under docs/agent-prompts/")
    g.add_argument("--ip", type=str, help="IP name to evaluate directly")
    g.add_argument("--corpus", type=Path, help="Run the full corpus regression in this directory")
    ap.add_argument("--report", type=Path, default=None, help="Write JSON report here")
    ap.add_argument("--gate", type=float, default=80.0, help="Minimum score to pass (default 80)")
    ap.add_argument("--no-formal", action="store_true")
    ap.add_argument("--no-mutation", action="store_true")
    args = ap.parse_args()

    console = Console()

    targets: list[str]
    if args.prompt:
        targets = [_ip_name_from_prompt(args.prompt)]
    elif args.ip:
        targets = [args.ip]
    else:
        # Corpus run: every subdirectory under args.corpus is a mini-block.
        targets = sorted(p.name for p in args.corpus.iterdir() if p.is_dir())

    results: list[IpScoring] = []
    for name in targets:
        try:
            sc = evaluate_ip(
                name,
                run_mutation=not args.no_mutation,
                run_formal=not args.no_formal,
            )
            sc.threshold = args.gate
        except FileNotFoundError as e:
            console.print(f"[yellow]skip:[/] {e}")
            continue
        results.append(sc)
        if not sc.passed():
            fb = write_feedback(sc, REPO_ROOT / "tools/agent_eval/feedback")
            console.print(f"[red]FAIL[/] {name}: {sc.total():.1f}/100  feedback -> {fb}")
        else:
            console.print(f"[green]PASS[/] {name}: {sc.total():.1f}/100")

    table = Table(title="Agent eval", show_lines=False)
    table.add_column("IP")
    table.add_column("Score", justify="right")
    table.add_column("Threshold", justify="right")
    table.add_column("Status", justify="center")
    for sc in results:
        table.add_row(
            sc.ip_name,
            f"{sc.total():.1f}",
            f"{sc.threshold:.0f}",
            "[green]PASS[/]" if sc.passed() else "[red]FAIL[/]",
        )
    console.print(table)

    if args.report:
        args.report.parent.mkdir(parents=True, exist_ok=True)
        args.report.write_text(
            json.dumps(
                {"modules": [s.to_dict() for s in results]},
                indent=2,
            )
        )

    n_fail = sum(1 for s in results if not s.passed())
    sys.exit(0 if n_fail == 0 else 1)


if __name__ == "__main__":
    main()
