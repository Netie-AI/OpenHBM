"""Adversarial row-pressure harness — 16-high-style hammer + optional trace replay.

Workload sketch aligns with aggressive row-disturb chatter around 16-high stacks
(public USENIX Security 2025 / DREAM ISCA 2025 framing). Replay file:
`sim/traces/rowhammer_16high.trc` (minute hand-authored format).

"""

from __future__ import annotations

import os
import sys

import xml.etree.ElementTree as ET
from pathlib import Path

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "env"))

from refresh_mgr_ref import RefreshMgrRef  # noqa: E402

COV: dict[str, dict[str, int]] = {}

_REPO_ROOT = Path(__file__).resolve().parents[5]
TRACE = _REPO_ROOT / "sim" / "traces" / "rowhammer_16high.trc"


def _touch(cp: str, bn: str) -> None:
    COV.setdefault(cp, {})
    COV[cp][bn] = COV[cp].get(bn, 0) + 1


def _write_coverage() -> None:
    root = ET.Element("coverage")
    for cp_name, bins in COV.items():
        cp_el = ET.SubElement(root, "coverpoint", name=cp_name)

        for bn, hits in bins.items():
            ET.SubElement(cp_el, "bin", name=str(bn), hits=str(hits))
    out = Path(__file__).resolve().parents[1] / "coverage.xml"
    ET.ElementTree(root).write(out, encoding="utf-8", xml_declaration=True)


def _thresh() -> int:
    return int(os.environ.get("PRAC_THRESH", "24"))


def _model() -> RefreshMgrRef:
    return RefreshMgrRef(
        prac_thresh=_thresh(),
        prac_topk=64,
        num_banks=16,
        credit_max=4,
        row_w=17,
        bg_w=2,
        ba_w=2,
        count_w=16,
    )


async def _reset(dut) -> None:
    dut.rst_ni.value = 0
    dut.act_valid_i.value = 0
    dut.act_bg_i.value = 0
    dut.act_ba_i.value = 0
    dut.act_row_i.value = 0
    dut.trefw_tick_i.value = 0
    dut.credit_release_i.value = 0
    dut.drfm_ack_i.value = 0
    await Timer(20, units="ns")
    await RisingEdge(dut.clk_i)
    dut.rst_ni.value = 1
    await RisingEdge(dut.clk_i)


async def _step(
    dut,
    m: RefreshMgrRef,
    *,
    tick: int = 0,
    act: int = 0,
    bg: int = 0,
    ba: int = 0,
    row: int = 0,
    rel: int = 0,
    ack: int = 0,
) -> None:
    dut.trefw_tick_i.value = tick
    dut.act_valid_i.value = act
    dut.act_bg_i.value = bg
    dut.act_ba_i.value = ba
    dut.act_row_i.value = row & ((1 << 17) - 1)
    dut.credit_release_i.value = rel
    dut.drfm_ack_i.value = ack
    await RisingEdge(dut.clk_i)
    g_bg, g_ba, g_row, g_pend, g_ov = m.step(
        trefw_tick=bool(tick),
        act_valid=bool(act),
        act_bg=bg,
        act_ba=ba,
        act_row=row & ((1 << 17) - 1),
        credit_release=bool(rel),
        drfm_ack=bool(ack),
    )
    assert int(dut.drfm_pending_o.value) == int(g_pend)
    assert int(dut.prac_overflow_alert_o.value) == int(g_ov)
    assert int(dut.drfm_target_bg_o.value) == g_bg
    assert int(dut.drfm_target_ba_o.value) == g_ba
    assert int(dut.drfm_target_row_o.value) == g_row


async def _run_sixteen_high_hammer(dut) -> None:
    rw_mask = (1 << 17) - 1
    row_lo = 0x1A70 & rw_mask
    delta = int(os.environ.get("ROWHAMMER_DELTA_ROWS", "16"))
    row_hi = (row_lo + delta) & rw_mask
    bg, ba = 2, 3
    thr = max(_thresh(), 8)
    m = _model()
    await _reset(dut)
    seen = False
    for cy in range(thr * 24):
        rr = row_lo if (cy % 2 == 0) else row_hi
        pend = int(dut.drfm_pending_o.value)
        await _step(dut, m, act=1, bg=bg, ba=ba, row=rr, ack=pend)

        pend = int(dut.drfm_pending_o.value)
        ov = int(dut.prac_overflow_alert_o.value)


        if pend or ov:
            seen = True
            _touch("adv", "defense_trigger")
            break
    assert seen, "expected drfm_pending or prac_overflow under alternating stress"


@cocotb.test()
async def test_sixteen_high_hammer_pressure(dut) -> None:
    cocotb.start_soon(Clock(dut.clk_i, 10, units="ns").start())
    _touch("adv", "hammer_start")


    await _run_sixteen_high_hammer(dut)
    _write_coverage()


@cocotb.test()
async def test_trace_rowhammer_replay_if_present(dut) -> None:
    cocotb.start_soon(Clock(dut.clk_i, 10, units="ns").start())
    _touch("adv", "replay_entry")


    if not TRACE.exists():

        cocotb.log.info("%s absent — rerunning synthesized hammer workload", TRACE)
        await _run_sixteen_high_hammer(dut)
        _touch("adv", "trace_missing_fallback")
        _write_coverage()


        return

    m = _model()
    await _reset(dut)



    triples = []
    for raw in TRACE.read_text(encoding="utf-8").splitlines():
        s = raw.strip()
        if not s or s.startswith("#"):
            continue
        bits = [p for p in s.replace(",", " ").split() if p]
        if len(bits) < 3:
            cocotb.log.warning("skip malformed trace line %r", raw)
            continue
        try:
            gbg = int(bits[0], 0)
            gba = int(bits[1], 0)
            nrow = int(bits[2], 0)
        except ValueError:
            cocotb.log.warning("skip unparseable line %r", raw)
            continue
        triples.append((gbg, gba, nrow))

    if not triples:
        cocotb.log.warning("trace empty — hammer fallback")
        await _run_sixteen_high_hammer(dut)
        _write_coverage()
        return

    ck = int(os.environ.get("TRACE_TICK_PERIOD", "31"))
    for i, triple in enumerate(triples):

        tg, tb, rr = triple
        tick_pulse = ck > 0 and (i % ck == 0)
        pend = int(dut.drfm_pending_o.value)
        await _step(dut, m, tick=1 if tick_pulse else 0, act=1, bg=tg, ba=tb, row=rr, ack=pend)

    _touch("adv", "trace_replay_done")
    _write_coverage()
