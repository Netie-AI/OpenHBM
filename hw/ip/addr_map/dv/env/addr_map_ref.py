"""Pure-Python golden reference for the addr_map IP.

Exposes a `map_addr(sa, region, default_mode)` function whose output the
cocotb scoreboard compares against the DUT.

Geometry mirrors `addr_map_pkg.sv`:

  NUM_CHANNELS         = 32   (5 bits)
  NUM_PSEUDO_CHANNELS  = 2    (1 bit)
  NUM_BANK_GROUPS      = 4    (2 bits)
  NUM_BANKS_PER_GROUP  = 4    (2 bits)
  NUM_ROWS             = 1<<17
  NUM_COLS             = 64   (32 B granules)
"""

from __future__ import annotations

from dataclasses import dataclass
from enum import IntEnum

# Geometry
CH_W   = 5
PCH_W  = 1
BG_W   = 2
BA_W   = 2
ROW_W  = 17
COL_W  = 6
SA_W   = 64
BASE_W = 40
POLY_W = 32

NUM_CHANNELS         = 1 << CH_W
NUM_PSEUDO_CHANNELS  = 1 << PCH_W
NUM_BANK_GROUPS      = 1 << BG_W
NUM_BANKS_PER_GROUP  = 1 << BA_W
NUM_ROWS             = 1 << ROW_W
NUM_COLS             = 1 << COL_W


class Mode(IntEnum):
    CH_STRIPED       = 0
    BANK_INTERLEAVED = 1
    ROW_STATIONARY   = 2
    RESERVED         = 3


@dataclass
class Region:
    valid: bool
    base_sa: int          # upper 40 bits of base
    size_log2: int        # in bytes
    mode: Mode
    xor_poly: int

    @property
    def base_full(self) -> int:
        return (self.base_sa & ((1 << BASE_W) - 1)) << (SA_W - BASE_W)

    def contains(self, sa: int) -> bool:
        return self.valid and self.base_full <= sa < self.base_full + (1 << self.size_log2)


@dataclass
class PA:
    ch: int
    pch: int
    bg: int
    ba: int
    row: int
    col: int

    def as_tuple(self) -> tuple[int, int, int, int, int, int]:
        return (self.ch, self.pch, self.bg, self.ba, self.row, self.col)


def xor_fold32(sa: int, poly: int) -> int:
    hi = (sa >> (SA_W - 32)) & 0xFFFFFFFF
    lo = sa & 0xFFFFFFFF
    return (hi & poly) ^ (lo & ((~poly) & 0xFFFFFFFF))


def _slice(value: int, lo: int, width: int) -> int:
    return (value >> lo) & ((1 << width) - 1)


def map_addr(sa: int, region: Region, default_mode: Mode) -> PA:
    """Compute PA for a system address.

    The ordering matches `addr_map_xor.sv`. Keep the bit positions in lock
    step with the RTL file.
    """
    sa &= (1 << SA_W) - 1
    if region.valid:
        offs = (sa - region.base_full) & ((1 << SA_W) - 1)
        mode = region.mode
        poly = region.xor_poly
    else:
        offs = sa
        mode = default_mode
        poly = 0

    xor_for_row = xor_fold32(offs, poly) & ((1 << ROW_W) - 1)

    if mode == Mode.CH_STRIPED:
        pch = _slice(offs, 5, PCH_W)
        ch  = _slice(offs, 6, CH_W)
        bg  = _slice(offs, 6 + CH_W, BG_W)
        ba  = _slice(offs, 6 + CH_W + BG_W, BA_W)
        col = _slice(offs, 6 + CH_W + BG_W + BA_W, COL_W)
        row = _slice(offs, 6 + CH_W + BG_W + BA_W + COL_W, ROW_W) ^ xor_for_row
    elif mode == Mode.BANK_INTERLEAVED:
        pch = _slice(offs, 5, PCH_W)
        bg  = _slice(offs, 6, BG_W)
        ba  = _slice(offs, 6 + BG_W, BA_W)
        ch  = _slice(offs, 6 + BG_W + BA_W, CH_W)
        col = _slice(offs, 6 + BG_W + BA_W + CH_W, COL_W)
        row = _slice(offs, 6 + BG_W + BA_W + CH_W + COL_W, ROW_W) ^ xor_for_row
    elif mode == Mode.ROW_STATIONARY:
        col = _slice(offs, 5, COL_W)
        bg  = _slice(offs, 5 + COL_W, BG_W)
        ba  = _slice(offs, 5 + COL_W + BG_W, BA_W)
        pch = _slice(offs, 6 + COL_W + BG_W + BA_W, PCH_W)
        ch  = _slice(offs, 7 + COL_W + BG_W + BA_W, CH_W)
        row = _slice(offs, 7 + COL_W + BG_W + BA_W + CH_W, ROW_W) ^ xor_for_row
    else:
        # Reserved -- pass-through, no XOR.
        pch = _slice(offs, 5, PCH_W)
        ch  = _slice(offs, 6, CH_W)
        bg  = _slice(offs, 6 + CH_W, BG_W)
        ba  = _slice(offs, 6 + CH_W + BG_W, BA_W)
        col = _slice(offs, 6 + CH_W + BG_W + BA_W, COL_W)
        row = _slice(offs, 6 + CH_W + BG_W + BA_W + COL_W, ROW_W)

    return PA(ch=ch, pch=pch, bg=bg, ba=ba, row=row, col=col)
