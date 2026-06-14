"""Second-source flow: wrap iEDA (OSCC-Project) for SkyWater 130.

iEDA ships 11 EDA tools (iRT, iCTS, iPL, iPD, ...) plus AiEDA and AiMap
under MulanPSL-2.0. We invoke it via the prebuilt Docker image
`iedaopensource/release:latest` and run the SkyWater 130 demo flow that
ships in the iEDA repo. The output PPA is fed into
`pd/sc_flows/cross_flow_delta.py` so it's compared against the
OpenROAD-driven `sky130.py` flow.

Usage:
    python -m pd.sc_flows.ieda_sky130 addr_map

Export-control posture: see `docs/legal/export_control.md`. Use as a tool,
not a contributor channel; never the sole sign-off path for a commercial
shuttle.
"""

from __future__ import annotations

import shutil
import subprocess
import sys

from .common import FlowArgs, REPO_ROOT, write_summary_stub

FLOW_NAME = "ieda_sky130"
IEDA_IMAGE = "iedaopensource/release:latest"

# Demo script locations vary across iEDA Docker image revisions.
_IEDA_SKY130_CANDIDATES = (
    "/opt/iEDA/scripts/sky130",
    "/iEDA/scripts/sky130",
    "/scripts/sky130",
    "/scripts/design/sky130_gcd",
)


def _ieda_run_script() -> str:
    """Return a bash snippet that selects a sky130 demo dir or exits 1."""
    lines = [
        "set -euo pipefail",
        'SKY130_DEMO=""',
    ]
    for path in _IEDA_SKY130_CANDIDATES:
        lines.append(
            f'if [ -z "$SKY130_DEMO" ] && [ -d "{path}" ] && '
            f'{{ [ -f "{path}/run_iEDA.sh" ] || [ -f "{path}/run_iEDA.py" ]; }}; then'
        )
        lines.append(f'  SKY130_DEMO="{path}"')
        lines.append("fi")
    lines.extend([
        'if [ -z "$SKY130_DEMO" ]; then',
        '  echo "iEDA sky130 demo scripts not found in image" >&2',
        "  exit 1",
        "fi",
        'cp -r "$SKY130_DEMO" /tmp/sky130_run',
    ])
    return "\n".join(lines) + "\n"


def build(top: str) -> int:
    args = FlowArgs(top=top, flow_name=FLOW_NAME)
    if not shutil.which("docker"):
        write_summary_stub(args, status="skipped: docker not on PATH")
        return 0

    try:
        subprocess.run(["docker", "pull", IEDA_IMAGE], check=True)

        rtl_files_in_repo = [
            f"hw/ip/{top}/rtl/{p.name}" for p in args.rtl_files
        ]
        if not rtl_files_in_repo:
            write_summary_stub(args, status=f"skipped: no RTL for {top}")
            return 0

        inner = (
            _ieda_run_script()
            + f"cp {' '.join(rtl_files_in_repo)} /tmp/sky130_run/ && "
            "cd /tmp/sky130_run && "
            "if [ -f run_iEDA.sh ]; then bash run_iEDA.sh; else python3 run_iEDA.py; fi && "
            f"mkdir -p /work/build/{top}/{FLOW_NAME}/job0 && "
            f"cp -r result /work/build/{top}/{FLOW_NAME}/job0/"
        )

        cmd = [
            "docker", "run", "--rm",
            "-v", f"{REPO_ROOT}:/work",
            "-w", "/work",
            IEDA_IMAGE,
            "bash", "-c", inner,
        ]
        proc = subprocess.run(cmd, check=False)
        rc = proc.returncode
        if rc == 0:
            write_summary_stub(args, status="ok")
        else:
            write_summary_stub(args, status=f"failed: docker rc={rc}")
        return rc
    except FileNotFoundError as exc:
        write_summary_stub(args, status=f"skipped: {exc}")
        return 0
    except subprocess.CalledProcessError as exc:
        write_summary_stub(args, status=f"failed: {exc}")
        return 1


if __name__ == "__main__":
    raise SystemExit(build(sys.argv[1] if len(sys.argv) > 1 else "addr_map"))
