"""Driver for the iPL-3D two-die placement experiment.

Phase-0: stubs out a placeholder DEF so `pkg/openems/run_screen.py` has
something to consume. Phase-2 replaces the body with a real Docker call
into `iedaopensource/release` driving the iPL-3D demo flow.
"""

from __future__ import annotations

import argparse
import textwrap
from pathlib import Path

PLACEHOLDER_DEF = textwrap.dedent(
    """\
    # Placeholder two-die DEF. Replace with iPL-3D output once enabled.
    VERSION 5.8 ;
    DESIGN chiplet_partition ;
    UNITS DISTANCE MICRONS 1000 ;
    DIEAREA ( 0 0 ) ( 6000 3000 ) ;
    COMPONENTS 2 ;
      - die_A addr_map + PLACED ( 100 100 ) N ;
      - die_B ecc      + PLACED ( 4000 100 ) N ;
    END COMPONENTS
    END DESIGN
    """
)


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--die-a", required=True)
    ap.add_argument("--die-b", required=True)
    ap.add_argument("--output", required=True, type=Path)
    args = ap.parse_args()

    args.output.mkdir(parents=True, exist_ok=True)
    (args.output / "floorplan.def").write_text(PLACEHOLDER_DEF)
    print(f"Wrote placeholder floorplan to {args.output / 'floorplan.def'}")
    print(f"Dies: {args.die_a}, {args.die_b}")


if __name__ == "__main__":
    main()
