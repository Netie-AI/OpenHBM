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


def _dfi(dut, name: str, ch: int = 0):
    """DFI bridge hierarchical signal (channel ch)."""
    return getattr(dut.g_channel[ch].u_chan.u_dfi, name)


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
        _port(dut, "dfi_wrdata_ack_i", ch).value = 1
        _port(dut, "dfi_rddata_i", ch).value = 0
        _port(dut, "dfi_rddata_valid_i", ch).value = 0
        _port(dut, "dfi_ctrlupd_ack_i", ch).value = 0
        _port(dut, "dfi_phyupd_req_i", ch).value = 0
        _port(dut, "dfi_lp_ctrl_ack_i", ch).value = 0
        _port(dut, "dfi_lp_data_ack_i", ch).value = 0
        _port(dut, "pwrdn_req_i", ch).value = 0
        _port(dut, "sref_req_i", ch).value = 0
        _port(dut, "exit_req_i", ch).value = 0
        _port(dut, "temp_celsius_i", ch).value = 65


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


@cocotb.test()
async def test_dfi_act_encoding(dut) -> None:
    await _tb_begin(dut)
    bank = 0
    row = 2

    async def wait_act() -> None:
        for _ in range(500):
            await RisingEdge(dut.clk_i)
            await ReadOnly()
            await Timer(1, unit="ps")
            if int(_port(dut, "cmd_valid_o").value) and int(_port(dut, "cmd_bank_o").value) == bank:
                if int(_port(dut, "cmd_o").value) == int(Cmd.ACT):
                    assert int(_dfi(dut, "dfi_ras_n_o").value) == 0
                    assert int(_dfi(dut, "dfi_cas_n_o").value) == 1
                    assert int(_dfi(dut, "dfi_we_n_o").value) == 1
                    assert int(_dfi(dut, "dfi_cs_n_o").value) == 0
                    return
        assert False, "ACT not observed"

    mon = cocotb.start_soon(wait_act())
    await _axi_write_single(dut, bank=bank, row=row, col=0)
    await mon
    _touch("dfi", "act_encoding")
    _write_coverage()


@cocotb.test()
async def test_dfi_rd_encoding(dut) -> None:
    await _tb_begin(dut)
    bank = 0
    row = 6

    await _axi_write_single(dut, bank=bank, row=row, col=0)
    for _ in range(4):
        await RisingEdge(dut.clk_i)

    async def wait_rd() -> None:
        for _ in range(500):
            await RisingEdge(dut.clk_i)
            await ReadOnly()
            await Timer(1, unit="ps")
            if int(_port(dut, "cmd_valid_o").value) and int(_port(dut, "cmd_bank_o").value) == bank:
                if int(_port(dut, "cmd_o").value) == int(Cmd.RD):
                    assert int(_dfi(dut, "dfi_cas_n_o").value) == 0
                    assert int(_dfi(dut, "dfi_ras_n_o").value) == 1
                    assert int(_dfi(dut, "dfi_we_n_o").value) == 1
                    assert int(_dfi(dut, "dfi_rddata_en_o").value) == 1
                    return
        assert False, "RD not observed after ACT"

    mon = cocotb.start_soon(wait_rd())
    await _axi_read_single(dut, bank=bank, row=row, col=0)
    await mon
    _touch("dfi", "rd_encoding")
    _write_coverage()


@cocotb.test()
async def test_dfi_wr_encoding(dut) -> None:
    await _tb_begin(dut)
    bank = 0
    row = 8

    await _axi_write_single(dut, bank=bank, row=row, col=0)
    for _ in range(4):
        await RisingEdge(dut.clk_i)

    async def wait_wr() -> None:
        for _ in range(500):
            await RisingEdge(dut.clk_i)
            await ReadOnly()
            await Timer(1, unit="ps")
            if int(_port(dut, "cmd_valid_o").value) and int(_port(dut, "cmd_bank_o").value) == bank:
                if int(_port(dut, "cmd_o").value) == int(Cmd.WR):
                    assert int(_dfi(dut, "dfi_cas_n_o").value) == 0
                    assert int(_dfi(dut, "dfi_we_n_o").value) == 0
                    assert int(_dfi(dut, "dfi_wrdata_en_o").value) == 1
                    assert int(_dfi(dut, "dfi_wrdata_mask_o").value) == 0
                    return
        assert False, "WR not observed after ACT"

    mon = cocotb.start_soon(wait_wr())
    await _axi_write_single(dut, bank=bank, row=row, col=1)
    await mon
    _touch("dfi", "wr_encoding")
    _write_coverage()


@cocotb.test()
async def test_dfi_ctrlupd_handshake(dut) -> None:
    await _tb_begin(dut, watchdog_cycles=6000)

    saw_req = False
    for _ in range(5000):
        await RisingEdge(dut.clk_i)
        await ReadOnly()
        await Timer(1, unit="ps")
        if int(_port(dut, "dfi_ctrlupd_req_o").value):
            saw_req = True
            break
    assert saw_req, "dfi_ctrlupd_req_o never asserted"

    for _ in range(2):
        _port(dut, "dfi_ctrlupd_ack_i").value = 1
        await RisingEdge(dut.clk_i)
        await ReadOnly()
        await Timer(1, unit="ps")
        assert int(_port(dut, "dfi_ctrlupd_req_o").value) == 1, "req must stay high while ack"

    _port(dut, "dfi_ctrlupd_ack_i").value = 0
    deasserted = False
    for _ in range(2):
        await RisingEdge(dut.clk_i)
        await ReadOnly()
        await Timer(1, unit="ps")
        if not int(_port(dut, "dfi_ctrlupd_req_o").value):
            deasserted = True
            break
    assert deasserted, "dfi_ctrlupd_req_o did not deassert within 2 cycles after ack drop"
    _touch("dfi", "ctrlupd_handshake")
    _write_coverage()


@cocotb.test()
async def test_dfi_phyupd_ack(dut) -> None:
    await _tb_begin(dut)

    _port(dut, "dfi_phyupd_req_i").value = 1
    await RisingEdge(dut.clk_i)
    await ReadOnly()
    await Timer(1, unit="ps")
    assert int(_port(dut, "dfi_phyupd_ack_o").value) == 1, "phyupd_ack within 1 cycle of req"

    for _ in range(2):
        await RisingEdge(dut.clk_i)

    _port(dut, "dfi_phyupd_req_i").value = 0
    await RisingEdge(dut.clk_i)
    await ReadOnly()
    await Timer(1, unit="ps")
    assert int(_port(dut, "dfi_phyupd_ack_o").value) == 0, "phyupd_ack must drop within 1 cycle of req deassert"
    _touch("dfi", "phyupd_ack")
    _write_coverage()


@cocotb.test()
async def test_powerdown_entry(dut) -> None:
    """All banks idle + pwrdn_req enters CHAN_PD and asserts LP req."""
    await _tb_begin(dut)
    _port(dut, "pwrdn_req_i", 0).value = 1
    for _ in range(5):
        await RisingEdge(dut.clk_i)
        await Timer(1, unit="ps")
    _port(dut, "pwrdn_req_i", 0).value = 0
    for _ in range(3):
        await RisingEdge(dut.clk_i)
        await Timer(1, unit="ps")
    assert int(_port(dut, "pw_state_o", 0).value) == 1, (
        f"Expected CHAN_PD(1), got {_port(dut, 'pw_state_o', 0).value}"
    )
    assert int(_port(dut, "dfi_lp_ctrl_req_o", 0).value) == 1, "LP req not asserted"
    _touch("pwrdn", "entry")


@cocotb.test()
async def test_powerdown_exit(dut) -> None:
    """From CHAN_PD, exit_req returns to CHAN_ACTIVE after T_XPDLL."""
    await _tb_begin(dut)
    _port(dut, "pwrdn_req_i", 0).value = 1
    for _ in range(5):
        await RisingEdge(dut.clk_i)
        await Timer(1, unit="ps")
    _port(dut, "pwrdn_req_i", 0).value = 0
    _port(dut, "dfi_lp_ctrl_ack_i", 0).value = 1
    await RisingEdge(dut.clk_i)
    await Timer(1, unit="ps")
    _port(dut, "dfi_lp_ctrl_ack_i", 0).value = 0
    for _ in range(2):
        await RisingEdge(dut.clk_i)
        await Timer(1, unit="ps")
    _port(dut, "exit_req_i", 0).value = 1
    await RisingEdge(dut.clk_i)
    await Timer(1, unit="ps")
    _port(dut, "exit_req_i", 0).value = 0
    for _ in range(15):
        await RisingEdge(dut.clk_i)
        await Timer(1, unit="ps")
    assert int(_port(dut, "pw_state_o", 0).value) == 0, (
        f"Expected CHAN_ACTIVE(0), got {_port(dut, 'pw_state_o', 0).value}"
    )
    _touch("pwrdn", "exit")


@cocotb.test()
async def test_selfref_entry(dut) -> None:
    """sref_req_i enters CHAN_SREF."""
    await _tb_begin(dut)
    _port(dut, "sref_req_i", 0).value = 1
    for _ in range(5):
        await RisingEdge(dut.clk_i)
        await Timer(1, unit="ps")
    _port(dut, "sref_req_i", 0).value = 0
    for _ in range(3):
        await RisingEdge(dut.clk_i)
        await Timer(1, unit="ps")
    assert int(_port(dut, "pw_state_o", 0).value) == 2, (
        f"Expected CHAN_SREF(2), got {_port(dut, 'pw_state_o', 0).value}"
    )
    _touch("pwrdn", "sref_entry")


@cocotb.test()
async def test_selfref_exit_timing(dut) -> None:
    """After SREF exit, remain in CHAN_SREF_EXIT until T_XSR elapses."""
    await _tb_begin(dut)
    _port(dut, "sref_req_i", 0).value = 1
    for _ in range(5):
        await RisingEdge(dut.clk_i)
        await Timer(1, unit="ps")
    _port(dut, "sref_req_i", 0).value = 0
    _port(dut, "dfi_lp_ctrl_ack_i", 0).value = 1
    await RisingEdge(dut.clk_i)
    await Timer(1, unit="ps")
    _port(dut, "dfi_lp_ctrl_ack_i", 0).value = 0
    _port(dut, "exit_req_i", 0).value = 1
    await RisingEdge(dut.clk_i)
    await Timer(1, unit="ps")
    _port(dut, "exit_req_i", 0).value = 0
    for _ in range(100):
        await RisingEdge(dut.clk_i)
        await Timer(1, unit="ps")
    assert int(_port(dut, "pw_state_o", 0).value) == 3, (
        f"Should still be CHAN_SREF_EXIT(3) at 100 cycles, got {_port(dut, 'pw_state_o', 0).value}"
    )
    for _ in range(115):
        await RisingEdge(dut.clk_i)
        await Timer(1, unit="ps")
    assert int(_port(dut, "pw_state_o", 0).value) == 0, (
        f"Expected CHAN_ACTIVE after T_XSR, got {_port(dut, 'pw_state_o', 0).value}"
    )
    _touch("pwrdn", "sref_exit")


@cocotb.test()
async def test_no_cmd_during_pd(dut) -> None:
    """While in CHAN_PD, AXI4 write must not assert DFI cs_n."""
    await _tb_begin(dut)
    _port(dut, "pwrdn_req_i", 0).value = 1
    for _ in range(5):
        await RisingEdge(dut.clk_i)
        await Timer(1, unit="ps")
    _port(dut, "pwrdn_req_i", 0).value = 0
    _port(dut, "dfi_lp_ctrl_ack_i", 0).value = 1
    await RisingEdge(dut.clk_i)
    await Timer(1, unit="ps")
    _port(dut, "dfi_lp_ctrl_ack_i", 0).value = 0
    for _ in range(2):
        await RisingEdge(dut.clk_i)
        await Timer(1, unit="ps")
    assert int(_port(dut, "pw_state_o", 0).value) == 1, "must be in PD before AXI stimulus"

    _port(dut, "awid_i", 0).value = 0
    _port(dut, "awaddr_i", 0).value = 0x0000_0040
    _port(dut, "awlen_i", 0).value = 0
    _port(dut, "awsize_i", 0).value = 3
    _port(dut, "awburst_i", 0).value = BURST_INCR
    _port(dut, "awvalid_i", 0).value = 1
    for _ in range(20):
        await RisingEdge(dut.clk_i)
        await ReadOnly()
        await Timer(1, unit="ps")
        assert int(_dfi(dut, "dfi_cs_n_o", 0).value) == 1, "DFI command issued while in power-down"
    _port(dut, "awvalid_i", 0).value = 0
    _touch("pwrdn", "no_cmd_pd")


@cocotb.test()
async def test_trefi_normal_band(dut) -> None:
    """At 65°C, trefi_cycles must equal TREFI_BASE=7800."""
    clock = Clock(dut.clk_i, 10, unit="ns")
    cocotb.start_soon(clock.start())
    await _tb_begin(dut)
    _port(dut, "temp_celsius_i", 0).value = 65
    await RisingEdge(dut.clk_i)
    await Timer(1, unit="ps")
    val = _port(dut, "trefi_cycles_o", 0).value
    assert int(val) == 7800, f"Expected 7800, got {int(val)}"


@cocotb.test()
async def test_trefi_hot_band(dut) -> None:
    """At 90°C, trefi_cycles must equal TREFI_HOT=3900."""
    clock = Clock(dut.clk_i, 10, unit="ns")
    cocotb.start_soon(clock.start())
    await _tb_begin(dut)
    _port(dut, "temp_celsius_i", 0).value = 90
    for _ in range(3):
        await RisingEdge(dut.clk_i)
        await Timer(1, unit="ps")
    val = _port(dut, "trefi_cycles_o", 0).value
    assert int(val) == 3900, f"Expected 3900, got {int(val)}"


@cocotb.test()
async def test_trefi_cold_band(dut) -> None:
    """At 30°C, trefi_cycles must equal TREFI_COLD=15600."""
    clock = Clock(dut.clk_i, 10, unit="ns")
    cocotb.start_soon(clock.start())
    await _tb_begin(dut)
    _port(dut, "temp_celsius_i", 0).value = 30
    for _ in range(3):
        await RisingEdge(dut.clk_i)
        await Timer(1, unit="ps")
    val = _port(dut, "trefi_cycles_o", 0).value
    assert int(val) == 15600, f"Expected 15600, got {int(val)}"


@cocotb.test()
async def test_trefi_hysteresis_cold_to_normal(dut) -> None:
    """
    Enter COLD band at 30°C.
    At 46°C (below COLD→NORMAL threshold of 47), must stay COLD.
    At 47°C, must transition to NORMAL.
    """
    clock = Clock(dut.clk_i, 10, unit="ns")
    cocotb.start_soon(clock.start())
    await _tb_begin(dut)

    _port(dut, "temp_celsius_i", 0).value = 30
    for _ in range(3):
        await RisingEdge(dut.clk_i)
        await Timer(1, unit="ps")

    _port(dut, "temp_celsius_i", 0).value = 46
    for _ in range(3):
        await RisingEdge(dut.clk_i)
        await Timer(1, unit="ps")
    val = _port(dut, "trefi_cycles_o", 0).value
    assert int(val) == 15600, f"Should stay COLD at 46°C, trefi={int(val)}"

    _port(dut, "temp_celsius_i", 0).value = 47
    for _ in range(3):
        await RisingEdge(dut.clk_i)
        await Timer(1, unit="ps")
    val = _port(dut, "trefi_cycles_o", 0).value
    assert int(val) == 7800, f"Should be NORMAL at 47°C, trefi={int(val)}"


@cocotb.test()
async def test_trefi_hysteresis_hot_to_normal(dut) -> None:
    """
    Enter HOT band at 90°C.
    At 84°C (above HOT→NORMAL threshold of 83), must stay HOT.
    At 83°C, must transition to NORMAL.
    """
    clock = Clock(dut.clk_i, 10, unit="ns")
    cocotb.start_soon(clock.start())
    await _tb_begin(dut)

    _port(dut, "temp_celsius_i", 0).value = 90
    for _ in range(3):
        await RisingEdge(dut.clk_i)
        await Timer(1, unit="ps")

    _port(dut, "temp_celsius_i", 0).value = 84
    for _ in range(3):
        await RisingEdge(dut.clk_i)
        await Timer(1, unit="ps")
    val = _port(dut, "trefi_cycles_o", 0).value
    assert int(val) == 3900, f"Should stay HOT at 84°C, trefi={int(val)}"

    _port(dut, "temp_celsius_i", 0).value = 83
    for _ in range(3):
        await RisingEdge(dut.clk_i)
        await Timer(1, unit="ps")
    val = _port(dut, "trefi_cycles_o", 0).value
    assert int(val) == 7800, f"Should be NORMAL at 83°C, trefi={int(val)}"
