# Copyright 2026 The Netie Open HBM Authors
# SPDX-License-Identifier: Apache-2.0
"""Cocotb tests for hbm4_ctrl AXI4 front-end + bank FSM + scheduler."""

from __future__ import annotations

import sys
import xml.etree.ElementTree as ET
from pathlib import Path

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ReadOnly, RisingEdge, Timer

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "env"))
from hbm4_ctrl_ref import Cmd, Hbm4CtrlRef  # noqa: E402

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
    dut.awid_i.value = 0
    dut.awaddr_i.value = 0
    dut.awlen_i.value = 0
    dut.awsize_i.value = 0
    dut.awburst_i.value = 0
    dut.awvalid_i.value = 0
    dut.wdata_i.value = 0
    dut.wstrb_i.value = 0
    dut.wlast_i.value = 0
    dut.wvalid_i.value = 0
    dut.bready_i.value = 0
    dut.arid_i.value = 0
    dut.araddr_i.value = 0
    dut.arlen_i.value = 0
    dut.arsize_i.value = 0
    dut.arburst_i.value = 0
    dut.arvalid_i.value = 0
    dut.rready_i.value = 0
    dut.drfm_ack_i.value = 0


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
    dut.awvalid_i.value = 0
    dut.wvalid_i.value = 0
    dut.arvalid_i.value = 0
    dut.bready_i.value = 0
    dut.rready_i.value = 0
    _drive_all_inputs_idle(dut)
    for _ in range(5):
        await RisingEdge(dut.clk_i)
    dut.rst_ni.value = 1
    await RisingEdge(dut.clk_i)


async def _axi_write_single(
    dut, *, bank: int, row: int, col: int, axid: int = 0
) -> None:
    addr = axi_pack_addr(bank, row, col)
    dut.awid_i.value = axid
    dut.awaddr_i.value = addr
    dut.awlen_i.value = 0
    dut.awsize_i.value = 3
    dut.awburst_i.value = BURST_INCR
    dut.awvalid_i.value = 1
    while True:
        await RisingEdge(dut.clk_i)
        await ReadOnly()
        await Timer(1, unit="ps")
        if int(dut.awready_o.value):
            break
    dut.awvalid_i.value = 0

    dut.wdata_i.value = 0
    dut.wstrb_i.value = 0xFF
    dut.wlast_i.value = 1
    dut.wvalid_i.value = 1
    while True:
        await RisingEdge(dut.clk_i)
        await ReadOnly()
        await Timer(1, unit="ps")
        if int(dut.wready_o.value) and int(dut.wvalid_i.value):
            break
    await RisingEdge(dut.clk_i)
    await ReadOnly()
    await Timer(1, unit="ps")
    dut.wvalid_i.value = 0

    dut.bready_i.value = 1
    while True:
        await RisingEdge(dut.clk_i)
        await ReadOnly()
        await Timer(1, unit="ps")
        if int(dut.bvalid_o.value):
            assert int(dut.bresp_o.value) == 0
            assert int(dut.bid_o.value) == axid
            break


async def _axi_read_single(dut, *, bank: int, row: int, col: int, axid: int = 0) -> int:
    addr = axi_pack_addr(bank, row, col)
    dut.arid_i.value = axid
    dut.araddr_i.value = addr
    dut.arlen_i.value = 0
    dut.arsize_i.value = 3
    dut.arburst_i.value = BURST_INCR
    dut.arvalid_i.value = 1
    while True:
        await RisingEdge(dut.clk_i)
        await ReadOnly()
        await Timer(1, unit="ps")
        if int(dut.arready_o.value):
            break
    dut.arvalid_i.value = 0

    dut.rready_i.value = 1
    rdata = 0
    while True:
        await RisingEdge(dut.clk_i)
        await ReadOnly()
        await Timer(1, unit="ps")
        if int(dut.rvalid_o.value):
            assert int(dut.rresp_o.value) == 0
            assert int(dut.rid_o.value) == axid
            assert int(dut.rlast_o.value) == 1
            rdata = int(dut.rdata_o.value)
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
            if int(dut.cmd_valid_o.value) and int(dut.cmd_bank_o.value) == bank:
                cmds.append(int(dut.cmd_o.value))

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
            if int(dut.cmd_valid_o.value) and int(dut.cmd_bank_o.value) == bank:
                cmd = int(dut.cmd_o.value)
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
            if int(dut.cmd_valid_o.value) and int(dut.cmd_o.value) == int(Cmd.RD):
                got[int(dut.cmd_bank_o.value)] = True

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
        if int(dut.drfm_req_o.value):
            dut.drfm_ack_i.value = 1
        else:
            dut.drfm_ack_i.value = 0
        if int(dut.cmd_valid_o.value) and int(dut.cmd_o.value) == int(Cmd.REF):
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
            if int(dut.cmd_valid_o.value):
                ref.record(
                    int(dut.cmd_o.value),
                    int(dut.cmd_bank_o.value),
                    int(dut.cmd_row_o.value),
                    int(dut.cmd_col_o.value),
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
    dut.awid_i.value = 2
    dut.awaddr_i.value = addr
    dut.awlen_i.value = 0
    dut.awsize_i.value = 3
    dut.awburst_i.value = 2  # WRAP
    dut.awvalid_i.value = 1
    while True:
        await RisingEdge(dut.clk_i)
        await ReadOnly()
        await Timer(1, unit="ps")
        if int(dut.awready_o.value):
            break
    dut.awvalid_i.value = 0
    dut.wdata_i.value = 0
    dut.wstrb_i.value = 0xFF
    dut.wlast_i.value = 1
    dut.wvalid_i.value = 1
    dut.bready_i.value = 1
    for _ in range(50):
        await RisingEdge(dut.clk_i)
        await ReadOnly()
        await Timer(1, unit="ps")
        if int(dut.bvalid_o.value):
            assert int(dut.bresp_o.value) == 3
            break
    else:
        assert False, "bvalid_o never asserted for WRAP DECERR"
    dut.wvalid_i.value = 0
    await RisingEdge(dut.clk_i)
    _touch("axi", "wrap_decerr")
    _write_coverage()


@cocotb.test()
async def test_axi4_backpressure(dut) -> None:
    await _tb_begin(dut, watchdog_cycles=3000)
    addr = axi_pack_addr(1, 4, 0)
    dut.awid_i.value = 0
    dut.awaddr_i.value = addr
    dut.awlen_i.value = 0
    dut.awsize_i.value = 3
    dut.awburst_i.value = BURST_INCR
    dut.awvalid_i.value = 1
    while True:
        await RisingEdge(dut.clk_i)
        await ReadOnly()
        await Timer(1, unit="ps")
        if int(dut.awready_o.value):
            break
    dut.awvalid_i.value = 0
    dut.wdata_i.value = 0
    dut.wstrb_i.value = 0xFF
    dut.wlast_i.value = 1
    dut.wvalid_i.value = 1
    while True:
        await RisingEdge(dut.clk_i)
        await ReadOnly()
        await Timer(1, unit="ps")
        if int(dut.wready_o.value) and int(dut.wvalid_i.value):
            break
    await RisingEdge(dut.clk_i)
    await ReadOnly()
    await Timer(1, unit="ps")
    dut.wvalid_i.value = 0
    dut.bready_i.value = 0
    for _ in range(500):
        await RisingEdge(dut.clk_i)
        await ReadOnly()
        await Timer(1, unit="ps")
        if int(dut.bvalid_o.value):
            break
    else:
        assert False, "bvalid_o never asserted with bready=0"
    await RisingEdge(dut.clk_i)
    await ReadOnly()
    await Timer(1, unit="ps")
    assert int(dut.bvalid_o.value) == 1, (
        f"bvalid_o should stay high, got {dut.bvalid_o.value}"
    )
    assert int(dut.bresp_o.value) == 0
    for _ in range(10):
        await RisingEdge(dut.clk_i)
        await ReadOnly()
        await Timer(1, unit="ps")
        assert int(dut.bvalid_o.value) == 1, "bvalid_o dropped while bready=0"
    dut.bready_i.value = 1
    for _ in range(20):
        await RisingEdge(dut.clk_i)
        await ReadOnly()
        await Timer(1, unit="ps")
        if not int(dut.bvalid_o.value):
            break
    _touch("axi", "bready_backpressure")
    _write_coverage()
