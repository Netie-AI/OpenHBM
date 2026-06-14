#!/usr/bin/env python3
"""Emit gf_tables.inc.sv for ecc_pkg (GF(2^8), poly 0x11D)."""

from pathlib import Path

POLY = 0x11D


def gf_tables():
    exp = [0] * 512
    log = [0] * 256
    x = 1
    for i in range(255):
        exp[i] = x
        log[x] = i
        x <<= 1
        if x & 0x100:
            x ^= POLY
    exp[255] = exp[0]
    for i in range(255, 512):
        exp[i] = exp[i - 255]
    return exp, log


def main() -> None:
    exp, log = gf_tables()
    lines: list[str] = []
    lines.append(
        "  // verilog_lint: waive unpacked-dimensions-range-ordering -- machine-generated ROM"
    )
    lines.append("  localparam bit [7:0] GfExp [0:511] = '{")
    for i in range(512):
        sep = "," if i < 511 else ""
        lines.append(f"    8'h{exp[i]:02x}{sep}")
    lines.append("  };")
    lines.append(
        "  // verilog_lint: waive unpacked-dimensions-range-ordering -- machine-generated ROM"
    )
    lines.append("  localparam bit [7:0] GfLog [0:255] = '{")
    for i in range(256):
        sep = "," if i < 255 else ""
        lines.append(f"    8'h{log[i]:02x}{sep}")
    lines.append("  };")
    rtl = Path(__file__).resolve().parents[1] / "rtl" / "gf_tables.inc.sv"
    with rtl.open("w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(lines) + "\n")
    print(rtl)


if __name__ == "__main__":
    main()
