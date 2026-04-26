"""SiliconCompiler flow targeting ASAP7 7 nm predictive PDK -- the FinFET fallback.

Per `Plan.md` Track-C, this is the path that lets us place-and-route a
FinFET tile *months* before any commercial-shuttle access. ASAP7 PDK r1.7
is BSD-3-licensed and has full LEF/Liberty/KLayout/PDN support in
OpenROAD-flow-scripts. See:
    https://github.com/The-OpenROAD-Project/asap7
"""

from __future__ import annotations

from .common import FlowArgs, make_chip, write_summary_stub

FLOW_NAME = "asap7"


def build(top: str) -> int:
    args = FlowArgs(top=top, flow_name=FLOW_NAME)
    try:
        chip = make_chip(args)
        chip.use("siliconcompiler.targets.asap7_demo")
        # ASAP7 is a 7 nm predictive PDK; coordinates in micron, smaller floorplan.
        chip.set("constraint", "outline", [(0, 0), (60, 60)])
        chip.set("constraint", "corearea", [(2, 2), (58, 58)])
        # Use the 7.5-track standard cell library by default.
        chip.set("option", "library", "asap7sc7p5t_28")
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
