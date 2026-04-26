"""CLI runner that dispatches to the right flow module."""

from __future__ import annotations

import argparse
import importlib
import sys

KNOWN_FLOWS = ("sky130", "ihp130", "asap7", "freepdk45", "ieda_sky130")


def main() -> None:
    ap = argparse.ArgumentParser(description="Run a SiliconCompiler flow")
    ap.add_argument("--flow", required=True, choices=KNOWN_FLOWS)
    ap.add_argument("--top", required=True, help="IP name under hw/ip/<top>/")
    args = ap.parse_args()

    mod = importlib.import_module(f"pd.sc_flows.{args.flow}")
    rc = mod.build(args.top)
    sys.exit(rc)


if __name__ == "__main__":
    main()
