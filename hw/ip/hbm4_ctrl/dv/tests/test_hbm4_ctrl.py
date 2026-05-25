# Copyright 2026 The Netie Open HBM Authors
# SPDX-License-Identifier: Apache-2.0
"""Cocotb tests for hbm4_ctrl AXI4 front-end + bank FSM + scheduler."""

from __future__ import annotations

import os
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ReadOnly, RisingEdge, Timer

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "env"))
from hbm4_ctrl_ref import Cmd, Hbm4CtrlRef  # noqa: E402

NUM_CH = int(os.environ.get("NUM_CHANNELS", "1"))

COV: dict[str, dict[str, int]] = {}


def _port(dut, name: str, ch: int = 0):
    """Per-channel slice of unpacked-array top ports."""
    sig = getattr(dut, name)
    if NUM_CH == 1:
        try:
            return sig[0]
        except TypeError:
            return sig
    return sig[ch]


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


def axi_pack_addr(bank: int, row: int, col: int) -> int:
    """Pack (bank,row,col) to match rtl/hbm4_ctrl_axi4_slave.sv address decode."""
    col_w = 6
    banks_per_bg = 4
    bg = bank // banks_per_bg
    bk = bank % banks_per_bg
    return (row << (col_w + 4)) | (bg << (col_w + 2)) | (bk << col_w) | col


BURST_INCR = 1


def _drive_all_inputs_idle(dut) -> None:
    """Drive every top-level input to a deterministic idle value before reset release."""
    for ch in range(NUM_CH):
        _port(dut, "awid_i", ch).value = 0
        _port(dut, "awaddr_i", ch).value = 0
        _port(dut, "awlen_i", ch).value = 0
        _port(dut, "awsize_i", ch).value = 0
        _port(dut, "awburst_i", ch).value = 0
        _port(dut, "awvalid_i", ch).value = 0
        _port(dut, "wdata_i", ch).value = 0
        _port(dut, "wstrb_i", ch).value = 0
        _port(dut, "wlast_i", ch).value = 0
        _port(dut, "wvalid_i", ch).value = 0
        _port(dut, "bready_i", ch).value = 0
        _port(dut, "arid_i", ch).value = 0
        _port(dut, "araddr_i", ch).value = 0
        _port(dut, "arlen_i", ch).value = 0
        _port(dut, "arsize_i", ch).value = 0
        _port(dut, "arburst_i", ch).value = 0
        _port(dut, "arvalid_i", ch).value = 0
        _port(dut, "rready_i", ch).value = 0
        _port(dut, "drfm_ack_i", ch).value = 0


async def _tb_begin(dut, watchdog_cycles: int = 2000) -> None:
    """TB preamble per contract: clock, watchdog, idle AXI during reset, synchronous reset release."""
    clock = Clock(dut.clk_i, 10, unit="ns")
    cocotb.start_soon(clock.start())

    async def timeout_task():
        for _ in range(watchdog_cycles):
            await RisingEdge(dut.clk_i)
        assert False, "TIMEOUT"

    cocotb.start_soon(timeout_task())

    dut.rst_ni.value = 0
    for ch in range(NUM_CH):
        _port(dut, "awvalid_i", ch).value = 0
        _port(dut, "wvalid_i", ch).value = 0
        _port(dut, "arvalid_i", ch).value = 0
        _port(dut, "bready_i", ch).value = 0
        _port(dut, "rready_i", ch).value = 0
    _drive_all_inputs_idle(dut)
    for _ in range(5):
        await RisingEdge(dut.clk_i)
    dut.rst_ni.value = 1
    await RisingEdge(dut.clk_i)


async def _axi_write_single(
    dut, *, bank: int, row: int, col: int, axid: int = 0, ch: int = 0
) -> None:
    addr = axi_pack_addr(bank, row, col)
    _port(dut, "awid_i", ch).value = axid
    _port(dut, "awaddr_i", ch).value = addr
    _port(dut, "awlen_i", ch).value = 0
    _port(dut, "awsize_i", ch).value = 3
    _port(dut, "awburst_i", ch).value = BURST_INCR
    _port(dut, "awvalid_i", ch).value = 1
    while True:
        await RisingEdge(dut.clk_i)
        await ReadOnly()
        await Timer(1, unit="ps")
        if int(_port(dut, "awready_o", ch).value):
            break
    _port(dut, "awvalid_i", ch).value = 0

    _port(dut, "wdata_i", ch).value = 0
    _port(dut, "wstrb_i", ch).value = 0xFF
    _port(dut, "wlast_i", ch).value = 1
    _port(dut, "wvalid_i", ch).value = 1
    while True:
        await RisingEdge(dut.clk_i)
        await ReadOnly()
        await Timer(1, unit="ps")
        if int(_port(dut, "wready_o", ch).value) and int(_port(dut, "wvalid_i", ch).value):
            break
    await RisingEdge(dut.clk_i)
    await ReadOnly()
    await Timer(1, unit="ps")
    _port(dut, "wvalid_i", ch).value = 0

    _port(dut, "bready_i", ch).value = 1
    while True:
        await RisingEdge(dut.clk_i)
        await ReadOnly()
        await Timer(1, unit="ps")
        if int(_port(dut, "bvalid_o", ch).value):
            assert int(_port(dut, "bresp_o", ch).value) == 0
            assert int(_port(dut, "bid_o", ch).value) == axid
            break


async def _axi_read_single(
    dut, *, bank: int, row: int, col: int, axid: int = 0, ch: int = 0
) -> int:
    addr = axi_pack_addr(bank, row, col)
    _port(dut, "arid_i", ch).value = axid
    _port(dut, "araddr_i", ch).value = addr
    _port(dut, "arlen_i", ch).value = 0
    _port(dut, "arsize_i", ch).value = 3
    _port(dut, "arburst_i", ch).value = BURST_INCR
    _port(dut, "arvalid_i", ch).value = 1
    while True:
        await RisingEdge(dut.clk_i)
        await ReadOnly()
        await Timer(1, unit="ps")
        if int(_port(dut, "arready_o", ch).value):
            break
    _port(dut, "arvalid_i", ch).value = 0

    _port(dut, "rready_i", ch).value = 1
    rdata = 0
    while True:
        await RisingEdge(dut.clk_i)
        await ReadOnly()
        await Timer(1, unit="ps")
        if int(_port(dut, "rvalid_o", ch).value):
            assert int(_port(dut, "rresp_o", ch).value) == 0
            assert int(_port(dut, "rid_o", ch).value) == axid
            assert int(_port(dut, "rlast_o", ch).value) == 1
            rdata = int(_port(dut, "rdata_o", ch).value)
            break
    return rdata


@cocotb.test()
async def test_single_rw_no_conflict(dut) -> None:
    await _tb_begin(dut)
    ref = Hbm4CtrlRef()
    bank = 0
    row = 5
    cmds: list[int] = []

    async def collect_cmds() -> None:
        for _ in range(400):
            await RisingEdge(dut.clk_i)
            await ReadOnly()
            await Timer(1, unit="ps")
            if int(_port(dut, "cmd_valid_o").value) and int(_port(dut, "cmd_bank_o").value) == bank:
                cmds.append(int(_port(dut, "cmd_o").value))

    collector = cocotb.start_soon(collect_cmds())
    await _axi_read_single(dut, bank=bank, row=row, col=0)
    await collector
    assert int(Cmd.RD) in cmds, cmds
    assert int(Cmd.PRE) in cmds, cmds
    assert cmds.index(int(Cmd.RD)) < cmds.index(int(Cmd.PRE)), cmds
    for c in cmds:
        ref.record(c, bank, row, 0)
    ref.assert_act_before_first_rw()
    _touch("flow", "single_rw")
    _write_coverage()


@cocotb.test()
async def test_timing_t_rcd(dut) -> None:
    await _tb_begin(dut)
    bank = 0
    row = 7
    act_c: int | None = None
    rd_c: int | None = None

    async def monitor_cmds() -> None:
        nonlocal act_c, rd_c
        for cyc in range(500):
            await RisingEdge(dut.clk_i)
            await ReadOnly()
            await Timer(1, unit="ps")
            if int(_port(dut, "cmd_valid_o").value) and int(_port(dut, "cmd_bank_o").value) == bank:
                cmd = int(_port(dut, "cmd_o").value)
                if cmd == int(Cmd.ACT):
                    act_c = cyc
                    rd_c = None
                elif cmd == int(Cmd.RD) and act_c is not None:
                    rd_c = cyc
                    return

    mon = cocotb.start_soon(monitor_cmds())
    await _axi_read_single(dut, bank=bank, row=row, col=1)
    await mon
    assert act_c is not None and rd_c is not None
    assert rd_c - act_c >= 4, f"cycles {rd_c - act_c} < tRCD(4)"


@cocotb.test()
async def test_bank_interleave(dut) -> None:
    await _tb_begin(dut, watchdog_cycles=5000)
    got = {0: False, 1: False}

    async def watch_rd() -> None:
        while not (got[0] and got[1]):
            await RisingEdge(dut.clk_i)
            await ReadOnly()
            await Timer(1, unit="ps")
            if int(_port(dut, "cmd_valid_o").value) and int(_port(dut, "cmd_o").value) == int(Cmd.RD):
                got[int(_port(dut, "cmd_bank_o").value)] = True

    watcher = cocotb.start_soon(watch_rd())
    for i in range(20):
        b = 0 if (i % 2) == 0 else 1
        await _axi_read_single(dut, bank=b, row=3, col=0)
        if got[0] and got[1]:
            break
    await watcher
    assert got[0] and got[1]
    _touch("sched", "two_banks_rd")
    _write_coverage()


@cocotb.test()
async def test_refresh_handshake(dut) -> None:
    await _tb_begin(dut)
    saw_ref = False
    for _ in range(600):
        await RisingEdge(dut.clk_i)
        await ReadOnly()
        await Timer(1, unit="ps")
        if int(_port(dut, "drfm_req_o").value):
            _port(dut, "drfm_ack_i").value = 1
        else:
            _port(dut, "drfm_ack_i").value = 0
        if int(_port(dut, "cmd_valid_o").value) and int(_port(dut, "cmd_o").value) == int(Cmd.REF):
            saw_ref = True
            break
    assert saw_ref, "REF not observed after DRFM handshake"
    _touch("refresh", "ref_cmd")
    _write_coverage()


@cocotb.test()
async def test_row_conflict(dut) -> None:
    await _tb_begin(dut, watchdog_cycles=5000)
    ref = Hbm4CtrlRef()
    bank = 0

    async def sample_cmds() -> None:
        for _ in range(2000):
            await RisingEdge(dut.clk_i)
            await ReadOnly()
            await Timer(1, unit="ps")
            if int(_port(dut, "cmd_valid_o").value):
                ref.record(
                    int(_port(dut, "cmd_o").value),
                    int(_port(dut, "cmd_bank_o").value),
                    int(_port(dut, "cmd_row_o").value),
                    int(_port(dut, "cmd_col_o").value),
                )

    sampler = cocotb.start_soon(sample_cmds())
    await _axi_read_single(dut, bank=bank, row=10, col=0)
    await _axi_read_single(dut, bank=bank, row=20, col=0)
    await sampler
    ref.assert_pre_before_second_act(10, 20)
    _touch("row", "conflict_pre")
    _write_coverage()


@cocotb.test()
async def test_axi4_single_write(dut) -> None:
    await _tb_begin(dut)
    await _axi_write_single(dut, bank=2, row=9, col=3, axid=1)
    _touch("axi", "single_write")
    _write_coverage()


@cocotb.test()
async def test_axi4_wrap_decerr(dut) -> None:
    await _tb_begin(dut)
    addr = axi_pack_addr(0, 1, 0)
    _port(dut, "awid_i").value = 2
    _port(dut, "awaddr_i").value = addr
    _port(dut, "awlen_i").value = 0
    _port(dut, "awsize_i").value = 3
    _port(dut, "awburst_i").value = 2  # WRAP
    _port(dut, "awvalid_i").value = 1
    while True:
        await RisingEdge(dut.clk_i)
        await ReadOnly()
        await Timer(1, unit="ps")
        if int(_port(dut, "awready_o").value):
            break
    _port(dut, "awvalid_i").value = 0
    _port(dut, "wdata_i").value = 0
    _port(dut, "wstrb_i").value = 0xFF
    _port(dut, "wlast_i").value = 1
    _port(dut, "wvalid_i").value = 1
    _port(dut, "bready_i").value = 1
    for _ in range(50):
        await RisingEdge(dut.clk_i)
        await ReadOnly()
        await Timer(1, unit="ps")
        if int(_port(dut, "bvalid_o").value):
            assert int(_port(dut, "bresp_o").value) == 3
            break
    else:
        assert False, "bvalid_o never asserted for WRAP DECERR"
    _port(dut, "wvalid_i").value = 0
    await RisingEdge(dut.clk_i)
    _touch("axi", "wrap_decerr")
    _write_coverage()


@cocotb.test()
async def test_axi4_backpressure(dut) -> None:
    await _tb_begin(dut, watchdog_cycles=3000)
    addr = axi_pack_addr(1, 4, 0)
    _port(dut, "awid_i").value = 0
    _port(dut, "awaddr_i").value = addr
    _port(dut, "awlen_i").value = 0
    _port(dut, "awsize_i").value = 3
    _port(dut, "awburst_i").value = BURST_INCR
    _port(dut, "awvalid_i").value = 1
    while True:
        await RisingEdge(dut.clk_i)
        await ReadOnly()
        await Timer(1, unit="ps")
        if int(_port(dut, "awready_o").value):
            break
    _port(dut, "awvalid_i").value = 0
    _port(dut, "wdata_i").value = 0
    _port(dut, "wstrb_i").value = 0xFF
    _port(dut, "wlast_i").value = 1
    _port(dut, "wvalid_i").value = 1
    while True:
        await RisingEdge(dut.clk_i)
        await ReadOnly()
        await Timer(1, unit="ps")
        if int(_port(dut, "wready_o").value) and int(_port(dut, "wvalid_i").value):
            break
    await RisingEdge(dut.clk_i)
    await ReadOnly()
    await Timer(1, unit="ps")
    _port(dut, "wvalid_i").value = 0
    _port(dut, "bready_i").value = 0
    for _ in range(500):
        await RisingEdge(dut.clk_i)
        await ReadOnly()
        await Timer(1, unit="ps")
        if int(_port(dut, "bvalid_o").value):
            break
    else:
        assert False, "bvalid_o never asserted with bready=0"
    await RisingEdge(dut.clk_i)
    await ReadOnly()
    await Timer(1, unit="ps")
    assert int(_port(dut, "bvalid_o").value) == 1, (
        f"bvalid_o should stay high, got {_port(dut, 'bvalid_o').value}"
    )
    assert int(_port(dut, "bresp_o").value) == 0
    for _ in range(10):
        await RisingEdge(dut.clk_i)
        await ReadOnly()
        await Timer(1, unit="ps")
        assert int(_port(dut, "bvalid_o").value) == 1, "bvalid_o dropped while bready=0"
    _port(dut, "bready_i").value = 1
    for _ in range(20):
        await RisingEdge(dut.clk_i)
        await ReadOnly()
        await Timer(1, unit="ps")
        if not int(_port(dut, "bvalid_o").value):
            break
    _touch("axi", "bready_backpressure")
    _write_coverage()


@cocotb.test()
async def test_multichan_independent(dut) -> None:
    if NUM_CH < 4:
        return
    await _tb_begin(dut, watchdog_cycles=5000)

    async def ch0_write() -> None:
        await _axi_write_single(dut, bank=0, row=3, col=1, axid=0, ch=0)

    async def ch1_read() -> None:
        await _axi_read_single(dut, bank=1, row=4, col=2, axid=1, ch=1)

    t0 = cocotb.start_soon(ch0_write())
    t1 = cocotb.start_soon(ch1_read())
    await t0
    await t1

    for _ in range(20):
        await RisingEdge(dut.clk_i)
        await ReadOnly()
        await Timer(1, unit="ps")
        if int(_port(dut, "drfm_req_o", 1).value):
            assert int(_port(dut, "drfm_req_o", 0).value) == 0, "ch1 DRFM must not follow ch0"
            break

    _touch("multichan", "independent_rw")
    _write_coverage()


@cocotb.test()
async def test_multichan_refresh_all(dut) -> None:
    if NUM_CH < 4:
        return
    await _tb_begin(dut, watchdog_cycles=10000)

    saw0 = False
    saw1 = False
    cyc0: int | None = None
    cyc1: int | None = None

    for cyc in range(2000):
        await RisingEdge(dut.clk_i)
        await ReadOnly()
        await Timer(1, unit="ps")
        if int(_port(dut, "drfm_req_o", 0).value):
            saw0 = True
            if cyc0 is None:
                cyc0 = cyc
            _port(dut, "drfm_ack_i", 0).value = 1
        else:
            _port(dut, "drfm_ack_i", 0).value = 0
        if int(_port(dut, "drfm_req_o", 1).value):
            saw1 = True
            if cyc1 is None:
                cyc1 = cyc
            _port(dut, "drfm_ack_i", 1).value = 1
        else:
            _port(dut, "drfm_ack_i", 1).value = 0
        if saw0 and saw1 and cyc0 is not None and cyc1 is not None:
            assert abs(cyc0 - cyc1) <= 1000, f"DRFM skew {abs(cyc0 - cyc1)} > 1000 cycles"
            break

    assert saw0 and saw1, "DRFM must assert on channels 0 and 1"
    _touch("multichan", "refresh_all")
    _write_coverage()
