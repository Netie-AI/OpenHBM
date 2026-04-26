"""SiliconCompiler flow targeting FreePDK45 (NCSU 45 nm research PDK).

Used as a cell-library research playground when ASAP7 is too restrictive.
"""

from __future__ import annotations

from .common import FlowArgs, make_chip, write_summary_stub

FLOW_NAME = "freepdk45"


def build(top: str) -> int:
    args = FlowArgs(top=top, flow_name=FLOW_NAME)
    try:
        chip = make_chip(args)
        chip.use("siliconcompiler.targets.freepdk45_demo")
        chip.set("constraint", "outline", [(0, 0), (120, 120)])
        chip.set("constraint", "corearea", [(8, 8), (112, 112)])
        chip.run()
        chip.summary()
        write_summary_stub(args, status="ok")
        return 0
    except ImportError:
        write_summary_stub(args, status="skipped: siliconcompiler not installed")
        return 0
    except Exception as exc:  # noqa: BLE001
        write_summary_stub(args, status=f"failed: {exc}")
        return 1


if __name__ == "__main__":
    import sys
    raise SystemExit(build(sys.argv[1] if len(sys.argv) > 1 else "addr_map"))
