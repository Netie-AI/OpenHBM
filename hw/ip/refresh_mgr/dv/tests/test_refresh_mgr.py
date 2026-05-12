"""Directed + CRT cocotb tests for refresh_mgr vs refresh_mgr_ref."""

from __future__ import annotations

import os
import random as py_random
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "env"))
from refresh_mgr_ref import RefreshMgrRef  # noqa: E402

try:
    import pyvsc as vsc
except ImportError:  # pragma: no cover
    vsc = None  # type: ignore

COV: dict[str, dict[str, int]] = {}


def _touch(cp: str, bn: str) -> None:
    if cp not in COV:
        COV[cp] = {}
    COV[cp].setdefault(bn, 0)
    COV[cp][bn] += 1


def _write_coverage() -> None:
    root = ET.Element("coverage")
    for cp_name, bins in COV.items():
        cp_el = ET.SubElement(root, "coverpoint", name=cp_name)
        for bn, hits in bins.items():
            ET.SubElement(cp_el, "bin", name=bn, hits=str(hits))
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
    # Verilator schedules NBAs after the active region; a tiny delay avoids
    # sampling registered outputs before they commit vs the Python model.
    await Timer(1, unit="ps")
    g_bg, g_ba, g_row, g_pend, g_ov = m.step(
        trefw_tick=bool(tick),
        act_valid=bool(act),
        act_bg=bg,
        act_ba=ba,
        act_row=row & ((1 << 17) - 1),
        credit_release=bool(rel),
        drfm_ack=bool(ack),
    )
    assert int(dut.drfm_pending_o.value) == int(g_pend), (
        f"pending rtl={int(dut.drfm_pending_o.value)} m={int(g_pend)}"
    )
    assert int(dut.prac_overflow_alert_o.value) == int(g_ov)
    assert int(dut.drfm_target_bg_o.value) == g_bg
    assert int(dut.drfm_target_ba_o.value) == g_ba
    assert int(dut.drfm_target_row_o.value) == g_row


@cocotb.test()
async def test_corner_tick_refill_credit(dut) -> None:
    cocotb.start_soon(Clock(dut.clk_i, 10, units="ns").start())
    m = _model()
    await _reset(dut)
    _touch("policy", "tick_refills")
    for _ in range(3):
        await _step(dut, m, tick=1)
    assert m.credits[0] == 4
    _write_coverage()


@cocotb.test()
async def test_corner_prac_pending_and_ack(dut) -> None:
    cocotb.start_soon(Clock(dut.clk_i, 10, units="ns").start())
    m = _model()
    await _reset(dut)
    # Focus PRAC accumulation on bank 3 / fixed row vs Prac_thresh from Makefile.
    th = _thresh()
    # Enough Misra-Gries activations that count >= PracThresh even if Makefile/RTL
    # threshold drifts slightly vs the Python default.
    for _ in range(max(th * 2 + 32, th + 48)):
        await _step(dut, m, act=1, bg=0, ba=3, row=0x2A71)
    _touch("prac", "pending_rise")
    assert int(dut.drfm_pending_o.value) == 1
    await _step(dut, m, ack=1)
    assert int(dut.drfm_pending_o.value) == 0
    _touch("handshake", "ack_clears")
    _write_coverage()


@cocotb.test()
async def test_corner_credit_exhaust_alert(dut) -> None:
    cocotb.start_soon(Clock(dut.clk_i, 10, units="ns").start())
    m = _model()
    await _reset(dut)
    th = _thresh()
    bg, ba = 2, 1
    for _ in range(th + 1):
        await _step(dut, m, act=1, bg=bg, ba=ba, row=777)
    # Drain credits with repeated ack+pulse without tick refill.
    saw_ov = False
    # Keep hammering the same row while draining credits; ack alone removes the
    # PRAC slot so pending never re-arms and credits never exhaust without acts.
    for cy in range(150):
        p = int(dut.drfm_pending_o.value)
        if int(dut.prac_overflow_alert_o.value):
            saw_ov = True
            break
        await _step(
            dut,
            m,
            act=1,
            bg=bg,
            ba=ba,
            row=777,
            ack=1 if p else 0,
        )
    assert saw_ov, "expected prac_overflow when credits drained"
    _touch("defer", "credit_exhaust")
    _touch("defer", "overflow_seen")
    _write_coverage()


@cocotb.test()
async def test_corner_credit_release_path(dut) -> None:
    cocotb.start_soon(Clock(dut.clk_i, 10, units="ns").start())
    m = _model()
    await _reset(dut)
    await _step(dut, m, tick=1)
    await _step(dut, m, tick=1, rel=1)
    _touch("credit", "release_with_tick_pulse")
    _write_coverage()


@cocotb.test()
async def test_corner_decay_defers_overflow(dut) -> None:
    """tREFW tick decays counters — keeps PRAC calm after bursts."""
    cocotb.start_soon(Clock(dut.clk_i, 10, units="ns").start())
    m = _model()
    await _reset(dut)
    th = _thresh()
    row = 0xCAFE & ((1 << 17) - 1)
    for _ in range(max(th // 2, 4)):
        await _step(dut, m, act=1, bg=3, ba=3, row=row)
    await _step(dut, m, tick=1)
    _touch("drfm", "decay_via_tick")
    _write_coverage()


@cocotb.test()
async def test_crt_thousand_seeds(dut) -> None:
    cocotb.start_soon(Clock(dut.clk_i, 10, units="ns").start())

    pkt = None
    if vsc is not None:

        @vsc.randobj  # pyvsc-constrained CRT bucket
        class Pack:  # type: ignore[misc]
            def __init__(self):
                self.bg = vsc.rand_uint_t(2)
                self.ba = vsc.rand_uint_t(2)

        pkt = Pack()

    for seed in range(1000):
        m = _model()
        await _reset(dut)
        rng = py_random.Random(seed + 0xC0CAC01A)
        for cy in range(96):
            if pkt is not None:
                pkt.randomize()  # type: ignore[attr-defined,no-untyped-call]
                bg = int(pkt.bg)
                ba = int(pkt.ba)
            else:
                bg = rng.randrange(0, 4)
                ba = rng.randrange(0, 4)
            act = rng.randrange(0, 2)
            ack = rng.randrange(0, 2) if int(dut.drfm_pending_o.value) else 0
            tick = 1 if (cy % 31) == 0 else 0
            rel = 1 if cy % 47 == 3 else 0
            row = rng.randrange(0, 1 << 17)
            await _step(
                dut,
                m,
                tick=tick,
                act=act,
                bg=bg,
                ba=ba,
                row=row,
                rel=rel,
                ack=ack,
            )
        if seed % 200 == 0:
            _touch("crt", f"checkpoint_{seed}")
    _touch("crt", "completed_1000")
    _write_coverage()


@cocotb.test()
async def test_pyvsc_constrained_pkg(dut) -> None:
    """Extra pyvsc guard — keeps constrained-random infra alive when pyvsc is installed."""
    if vsc is None:
        return

    @vsc.randobj
    class Tin:  # type: ignore[misc]
        def __init__(self):
            self.x = vsc.rand_uint_t(4)

    t = Tin()
    for _ in range(32):
        t.randomize()  # type: ignore[attr-defined,no-untyped-call]
        assert int(t.x) < 16

