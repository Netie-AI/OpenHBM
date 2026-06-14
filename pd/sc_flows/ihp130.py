"""SiliconCompiler flow targeting IHP SG13G2 (open 130 nm BiCMOS)."""

from __future__ import annotations

from .common import FlowArgs, make_chip, write_summary_stub

FLOW_NAME = "ihp130"


def build(top: str) -> int:
    args = FlowArgs(top=top, flow_name=FLOW_NAME)
    try:
        from siliconcompiler.targets import ihp130_demo

        chip = make_chip(args)
        chip.use(ihp130_demo)
        chip.set("constraint", "outline", [(0, 0), (250, 250)])
        chip.set("constraint", "corearea", [(15, 15), (235, 235)])
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
