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

from .common import FlowArgs, write_summary_stub

FLOW_NAME = "ieda_sky130"
IEDA_IMAGE = "iedaopensource/release:latest"


def build(top: str) -> int:
    args = FlowArgs(top=top, flow_name=FLOW_NAME)
    if not shutil.which("docker"):
        write_summary_stub(args, status="skipped: docker not on PATH")
        return 0

    try:
        # Pull the image if missing.
        subprocess.run(["docker", "pull", IEDA_IMAGE], check=True)

        rtl_files_in_repo = [
            f"hw/ip/{top}/rtl/{p.name}" for p in args.rtl_files
        ]

        # Volume-mount the repo and the iEDA sky130 demo data.
        cmd = [
            "docker", "run", "--rm",
            "-v", f"{args.build_dir.parent.parent.parent}:/work",
            "-w", "/work",
            IEDA_IMAGE,
            "bash", "-c",
            "set -e && "
            f"export OUTPUT_DIR=build/{top}/{FLOW_NAME}/job0 && "
            "mkdir -p $OUTPUT_DIR && "
            # iEDA demo entry point (path inside the image).
            "cp -r /opt/iEDA/scripts/sky130 /tmp/sky130_run && "
            f"cp { ' '.join(rtl_files_in_repo) } /tmp/sky130_run/ && "
            "cd /tmp/sky130_run && "
            "bash run_iEDA.sh && "
            f"cp -r result /work/$OUTPUT_DIR/ || true",
        ]
        rc = subprocess.run(cmd).returncode
        write_summary_stub(args, status=("ok" if rc == 0 else f"failed: rc={rc}"))
        return rc
    except FileNotFoundError as exc:
        write_summary_stub(args, status=f"skipped: {exc}")
        return 0
    except subprocess.CalledProcessError as exc:
        write_summary_stub(args, status=f"failed: {exc}")
        return 1


if __name__ == "__main__":
    raise SystemExit(build(sys.argv[1] if len(sys.argv) > 1 else "addr_map"))
