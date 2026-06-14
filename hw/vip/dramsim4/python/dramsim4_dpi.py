"""Thin Python wrapper around the DRAMsim4 BFM.

Phase 0: a stub transactor that records issued commands and tracks per-bank
state with a tiny FSM, so tests against `hw/ip/hbm4_ctrl` can run before
the DPI bridge is real. Phase 2 replaces this module's internals with a
shared-library call into the patched DRAMsim3 binary.

Usage from cocotb:

    from hw.vip.dramsim4.python.dramsim4_dpi import DramSim4
    bfm = DramSim4("hw/vip/dramsim4/cfg/hbm4_8gbps.ini")
    bfm.tick()                          # advance one DRAM clock
    bfm.cmd_act(ch=0, pch=0, bg=0, ba=0, row=0x1234)
    bfm.cmd_rd(ch=0, pch=0, bg=0, ba=0, col=0)
    data = bfm.poll_read(ch=0, pch=0)   # returns bytes once latency met
"""

from __future__ import annotations

import configparser
from dataclasses import dataclass, field
from pathlib import Path


@dataclass
class BankState:
    open_row: int | None = None
    last_act_cycle: int = -1
    last_rd_cycle: int = -1
    last_wr_cycle: int = -1


@dataclass
class DramSim4:
    config_path: Path | str
    cycle: int = 0
    banks: dict[tuple[int, int, int, int], BankState] = field(default_factory=dict)
    pending_reads: list[tuple[int, tuple[int, int, int, int, int], int]] = field(
        default_factory=list
    )
    cl: int = 24

    def __post_init__(self) -> None:
        cfg = configparser.ConfigParser()
        cfg.read(self.config_path)
        try:
            self.cl = int(cfg["timing"]["CL"])
        except KeyError:
            self.cl = 24

    # ---- public API ----
    def tick(self) -> None:
        self.cycle += 1

    def cmd_act(self, ch: int, pch: int, bg: int, ba: int, row: int) -> None:
        b = self.banks.setdefault((ch, pch, bg, ba), BankState())
        b.open_row = row
        b.last_act_cycle = self.cycle

    def cmd_pre(self, ch: int, pch: int, bg: int, ba: int) -> None:
        b = self.banks.setdefault((ch, pch, bg, ba), BankState())
        b.open_row = None

    def cmd_rd(self, ch: int, pch: int, bg: int, ba: int, col: int) -> None:
        b = self.banks.setdefault((ch, pch, bg, ba), BankState())
        if b.open_row is None:
            raise RuntimeError(f"RD without open row at ch={ch} pch={pch} bg={bg} ba={ba}")
        # Schedule data after CL cycles.
        deadline = self.cycle + self.cl
        self.pending_reads.append((deadline, (ch, pch, bg, ba, col), b.open_row))
        b.last_rd_cycle = self.cycle

    def cmd_wr(self, ch: int, pch: int, bg: int, ba: int, col: int) -> None:
        b = self.banks.setdefault((ch, pch, bg, ba), BankState())
        if b.open_row is None:
            raise RuntimeError(f"WR without open row at ch={ch} pch={pch} bg={bg} ba={ba}")
        b.last_wr_cycle = self.cycle

    def poll_read(self, ch: int, pch: int) -> tuple[int, int, int, int, int] | None:
        """Return one ready read at this (ch, pch) or None."""
        for i, (deadline, key, row) in enumerate(self.pending_reads):
            if key[0] == ch and key[1] == pch and self.cycle >= deadline:
                self.pending_reads.pop(i)
                return (*key, row)
        return None
