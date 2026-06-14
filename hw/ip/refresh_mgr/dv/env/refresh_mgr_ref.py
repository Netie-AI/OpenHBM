"""Cycle-accurate golden model for hw/ip/refresh_mgr (DRFM + Misra-Gries PRAC + credits)."""

from __future__ import annotations

from copy import deepcopy
from dataclasses import dataclass, field


@dataclass
class PracEntry:
    valid: bool = False
    row: int = 0
    count: int = 0


@dataclass
class RefreshMgrRef:
    """Matches refresh_mgr.sv g_seq ordering (Misra-Gries top-K, sticky pending)."""

    prac_thresh: int = 1024
    prac_topk: int = 64
    num_banks: int = 16
    credit_max: int = 4
    row_w: int = 17
    bg_w: int = 2
    ba_w: int = 2
    count_w: int = 16

    entry: list[list[PracEntry]] = field(default_factory=list)
    credits: list[int] = field(default_factory=list)
    pending: bool = False
    lat_bg: int = 0
    lat_ba: int = 0
    lat_row: int = 0

    def __post_init__(self) -> None:
        if not self.entry:
            self.entry = [
                [PracEntry() for _ in range(self.prac_topk)] for _ in range(self.num_banks)
            ]
        if not self.credits:
            self.credits = [self.credit_max] * self.num_banks

    def bank_idx(self, bg: int, ba: int) -> int:
        return ((bg & ((1 << self.bg_w) - 1)) << self.ba_w) | (ba & ((1 << self.ba_w) - 1))

    def _sat_inc(self, c: int) -> int:
        m = (1 << self.count_w) - 1
        return m if c >= m else c + 1

    def tbl_decay(self, tbl: list[PracEntry]) -> None:
        for e in tbl:
            if e.valid and e.count != 0:
                e.count -= 1
                if e.count == 0:
                    e.valid = False
                    e.row = 0

    def mg_activate(self, tbl: list[PracEntry], r: int) -> None:
        mask_r = (1 << self.row_w) - 1
        r &= mask_r

        matched_ix = None
        for kk, slot in enumerate(tbl):
            if slot.valid and slot.row == r:
                matched_ix = kk
                break
        if matched_ix is not None:
            tbl[matched_ix].count = self._sat_inc(tbl[matched_ix].count)
            return

        free_ix = None
        for kk, slot in enumerate(tbl):
            if (not slot.valid) or slot.count == 0:
                free_ix = kk
                break
        if free_ix is not None:
            tbl[free_ix].valid = True
            tbl[free_ix].row = r
            tbl[free_ix].count = 1
            return

        for slot in tbl:
            if slot.valid and slot.count != 0:
                slot.count -= 1
            if slot.count == 0:
                slot.valid = False
        free_ix = None
        for kk, slot in enumerate(tbl):
            if (not slot.valid) or slot.count == 0:
                free_ix = kk
                break
        if free_ix is not None:
            tbl[free_ix].valid = True
            tbl[free_ix].row = r
            tbl[free_ix].count = 1

    def scan_hit(self, mem: list[list[PracEntry]]) -> tuple[bool, int, int, int]:
        """Return (hit, bg, ba, bank_index). Same scan order as scan_hit_mem in RTL."""
        for bb in range(self.num_banks):
            for slot in mem[bb]:
                if slot.valid and slot.count >= self.prac_thresh:
                    ba = bb & ((1 << self.ba_w) - 1)
                    bg = (bb >> self.ba_w) & ((1 << self.bg_w) - 1)
                    return True, bg, ba, bb
        return False, 0, 0, 0

    def scan_hit_detail(self, mem: list[list[PracEntry]]) -> tuple[bool, int, int, int, int]:
        for bb in range(self.num_banks):
            for slot in mem[bb]:
                if slot.valid and slot.count >= self.prac_thresh:
                    ba = bb & ((1 << self.ba_w) - 1)
                    bg = (bb >> self.ba_w) & ((1 << self.bg_w) - 1)
                    return True, bg, ba, bb, slot.row
        return False, 0, 0, 0, 0

    def remove_row(self, mem_bank: list[PracEntry], rr: int) -> None:
        mask_r = (1 << self.row_w) - 1
        rr &= mask_r

        for e in mem_bank:
            if e.valid and e.row == rr:
                e.valid = False
                e.count = 0
                e.row = 0

    def step(
        self,
        *,
        trefw_tick: bool,
        act_valid: bool,
        act_bg: int,
        act_ba: int,
        act_row: int,
        credit_release: bool,
        drfm_ack: bool,
    ) -> tuple[int, int, int, bool, bool]:
        """One clock. Returns (drfm_target_bg, ba, row, drfm_pending, prac_overflow)."""
        hit_pre_vis, _, _, hit_pre_bb = self.scan_hit(self.entry)
        start_pend = self.pending

        mem = deepcopy(self.entry)
        cred = list(self.credits)
        pend = self.pending
        nlat_bg, nlat_ba, nlat_rw = self.lat_bg, self.lat_ba, self.lat_row

        if drfm_ack and pend:
            bk = self.bank_idx(nlat_bg, nlat_ba)
            if cred[bk] > 0:
                cred[bk] -= 1
            self.remove_row(mem[bk], nlat_rw)

            pend = False

        if trefw_tick:
            for bb in range(self.num_banks):
                self.tbl_decay(mem[bb])
                cred[bb] = self.credit_max
        elif credit_release:
            if start_pend:
                rb = self.bank_idx(self.lat_bg, self.lat_ba)
            elif hit_pre_vis:
                rb = hit_pre_bb
            else:
                rb = 0

            if cred[rb] < self.credit_max:
                cred[rb] += 1

        if (not trefw_tick) and act_valid:
            bk = self.bank_idx(act_bg, act_ba)
            self.mg_activate(mem[bk], act_row)

        post_hit_vis, ph_bg, ph_ba, ph_bb, ph_row = self.scan_hit_detail(mem)
        if (not pend) and post_hit_vis and cred[ph_bb] > 0:
            pend = True
            nlat_bg, nlat_ba, nlat_rw = ph_bg, ph_ba, ph_row

        self.entry = mem
        self.credits = cred
        self.pending = pend
        self.lat_bg = nlat_bg

        self.lat_ba = nlat_ba
        self.lat_row = nlat_rw

        fv, _, _, fv_bb, _ = self.scan_hit_detail(self.entry)

        prac_ov = fv and (not pend) and (self.credits[fv_bb] == 0)
        return nlat_bg, nlat_ba, nlat_rw, pend, prac_ov
