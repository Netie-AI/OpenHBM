"""SiliconCompiler flow targeting SkyWater 130 (open PDK)."""

from __future__ import annotations

from .common import FlowArgs, make_chip, write_summary_stub

FLOW_NAME = "sky130"


def build(top: str) -> int:
    args = FlowArgs(top=top, flow_name=FLOW_NAME)
    try:
        from siliconcompiler.targets import skywater130_demo

        chip = make_chip(args)
        chip.use(skywater130_demo)
        chip.set("constraint", "outline", [(0, 0), (200, 200)])  # microns; tune per IP
        chip.set("constraint", "corearea", [(10, 10), (190, 190)])
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
