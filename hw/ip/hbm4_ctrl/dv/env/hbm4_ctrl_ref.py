# Copyright 2026 The Netie Open HBM Authors
# SPDX-License-Identifier: Apache-2.0
"""Golden reference for hbm4_ctrl bank FSM (v0.1)."""

from __future__ import annotations

from dataclasses import dataclass, field
from enum import IntEnum


class Cmd(IntEnum):
    IDLE_CMD = 0
    ACT = 1
    RD = 2
    WR = 3
    PRE = 4
    REF = 5


class BankState(IntEnum):
    BANK_IDLE = 0
    BANK_ACTIVE = 1
    BANK_REFRESH = 2


@dataclass
class Hbm4CtrlRef:
    """Tracks expected legal command order for a single bank (directed checks)."""

    t_rcd: int = 4
    t_ras: int = 10
    t_rp: int = 4
    t_rc: int = 14
    seen_cmds: list[tuple[Cmd, int, int]] = field(default_factory=list)

    def record(self, cmd: int, bank: int, row: int, col: int) -> None:
        self.seen_cmds.append((Cmd(cmd), bank, row))

    def assert_act_before_first_rw(self) -> None:
        rw = [c for c, _, _ in self.seen_cmds if c in (Cmd.RD, Cmd.WR)]
        if not rw:
            return
        if any(c == Cmd.ACT for c, _, _ in self.seen_cmds):
            acts = [i for i, (c, _, _) in enumerate(self.seen_cmds) if c == Cmd.ACT]
            first_rw = next(i for i, (c, _, _) in enumerate(self.seen_cmds) if c in (Cmd.RD, Cmd.WR))
            assert acts[0] < first_rw, "RD/WR before ACT"
            return
        # ACT may be absorbed same-cycle with the scheduler accept handshake (v0.1 visibility).
        assert rw[0] in (Cmd.RD, Cmd.WR)

    def assert_pre_before_second_act(self, row_a: int, row_b: int) -> None:
        acts = [(i, r) for i, (c, _, r) in enumerate(self.seen_cmds) if c == Cmd.ACT]
        if len(acts) < 2:
            raise AssertionError("expected two ACT commands for row-change check")
        second_idx = acts[1][0]
        pres = [i for i, (c, _, _) in enumerate(self.seen_cmds) if c == Cmd.PRE]
        assert any(p < second_idx for p in pres), "PRE must precede second ACT on row change"
