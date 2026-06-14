# Copyright 2026 The Netie Open HBM Authors
# SPDX-License-Identifier: Apache-2.0
"""Cocotb tests for ecc (ChipKill-style RS ECC)."""

from __future__ import annotations

import sys
import xml.etree.ElementTree as ET
from pathlib import Path

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "env"))
from ecc_ref import decode as ref_decode
from ecc_ref import encode as ref_encode

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


async def _reset(dut) -> None:
    dut.rst_ni.value = 0
    dut.data_i.value = 0
    dut.ecc_i.value = 0
    await Timer(20, unit="ns")
    await RisingEdge(dut.clk_i)
    dut.rst_ni.value = 1
    await RisingEdge(dut.clk_i)


async def _drive(dut, di: int, ecc: int) -> None:
    dut.data_i.value = int(di)
    dut.ecc_i.value = int(ecc)
    for _ in range(4):
        await RisingEdge(dut.clk_i)
    await Timer(1, unit="ps")


@cocotb.test()
async def test_no_error(dut) -> None:
    cocotb.start_soon(Clock(dut.clk_i, 10, unit="ns").start())
    await _reset(dut)
    di = 0x1234_5678_9ABC_DEF0 << 64 | 0x0FED_CBA9_8765_4321
    pe = ref_encode(di)
    await _drive(dut, di, pe)
    assert int(dut.ue_o.value) == 0
    assert int(dut.ce_o.value) == 0
    assert int(dut.data_o.value) == int(di)
    assert int(dut.ecc_o.value) == int(pe)
    _touch("ecc_mode", "clean_roundtrip")
    _write_coverage()


@cocotb.test()
async def test_single_bit_flip(dut) -> None:
    cocotb.start_soon(Clock(dut.clk_i, 10, unit="ns").start())
    await _reset(dut)
    di = 0xA5A5_5A5A_0000_FFFF << 64 | 0x3C3C_C3C3_FFFF_0000
    pe = ref_encode(di)
    d_cor = di ^ (1 << 40)
    exp_d, _, exp_ce, exp_ue = ref_decode(d_cor, pe)
    await _drive(dut, d_cor, pe)
    assert int(dut.ue_o.value) == int(exp_ue)
    assert int(dut.ce_o.value) == int(exp_ce)
    assert int(dut.data_o.value) == int(exp_d)
    _touch("ecc_mode", "single_bit")
    _write_coverage()


@cocotb.test()
async def test_single_symbol_error(dut) -> None:
    cocotb.start_soon(Clock(dut.clk_i, 10, unit="ns").start())
    await _reset(dut)
    di = 0x1111_2222_3333_4444 << 64 | 0x5555_6666_7777_8888
    pe = ref_encode(di)
    d_cor = di ^ (0xAB << 48)
    exp_d, _, exp_ce, exp_ue = ref_decode(d_cor, pe)
    await _drive(dut, d_cor, pe)
    assert int(dut.ue_o.value) == int(exp_ue)
    assert int(dut.ce_o.value) == int(exp_ce)
    assert int(dut.data_o.value) == int(exp_d)
    _touch("ecc_mode", "single_symbol")
    _write_coverage()


@cocotb.test()
async def test_double_symbol_error(dut) -> None:
    """Two corrupted symbols on all-zero data; pattern has no unique 1-flip decode."""
    cocotb.start_soon(Clock(dut.clk_i, 10, unit="ns").start())
    await _reset(dut)
    di = 0
    pe = ref_encode(di)
    d_cor = (0xFF) | (0xAA << 8)
    _, _, _, exp_ue = ref_decode(d_cor, pe)
    assert exp_ue is True
    await _drive(dut, d_cor, pe)
    assert int(dut.ue_o.value) == 1
    _touch("ecc_mode", "double_symbol")
    _write_coverage()


@cocotb.test()
async def test_ecc_bit_flip(dut) -> None:
    cocotb.start_soon(Clock(dut.clk_i, 10, unit="ns").start())
    await _reset(dut)
    di = 0xDEAD_BEEF_CAFE_BABE << 64 | 0x0123_4567_89AB_CDEF
    pe = ref_encode(di)
    p_cor = pe ^ 0x40
    exp_d, _, exp_ce, exp_ue = ref_decode(di, p_cor)
    await _drive(dut, di, p_cor)
    assert int(dut.ue_o.value) == int(exp_ue)
    assert int(dut.ce_o.value) == int(exp_ce)
    assert int(dut.data_o.value) == int(exp_d)
    _touch("ecc_mode", "ecc_parity_bit")
    _write_coverage()
