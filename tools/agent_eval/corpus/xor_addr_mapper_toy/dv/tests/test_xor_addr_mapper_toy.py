"""Cocotb tests for xor_addr_mapper_toy."""

from __future__ import annotations

import random

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer


def golden(sa: int, mode: int) -> tuple[int, int, int, int]:
    if mode == 0:
        ch = sa & 0x3
        bank = (sa >> 2) & 0x3
    else:
        bank = sa & 0x3
        ch = (sa >> 2) & 0x3
    row = ((sa >> 4) & 0xFFFF) ^ ((sa >> 10) & 0xFFFF)
    col = (sa >> 20) & 0x3F
    return ch, bank, row, col


async def reset(dut) -> None:
    dut.rst_ni.value = 0
    dut.sa_i.value = 0
    dut.mode_i.value = 0
    await Timer(20, units="ns")
    await RisingEdge(dut.clk_i)
    dut.rst_ni.value = 1
    await RisingEdge(dut.clk_i)


@cocotb.test()
async def test_directed(dut) -> None:
    cocotb.start_soon(Clock(dut.clk_i, 10, units="ns").start())
    await reset(dut)

    cases = [(0, 0), (0, 1), (0xDEADBEEF & ((1 << 26) - 1), 0),
             (0xCAFEBABE & ((1 << 26) - 1), 1)]
    for sa, mode in cases:
        dut.sa_i.value = sa
        dut.mode_i.value = mode
        await RisingEdge(dut.clk_i)
        ch, bank, row, col = (
            int(dut.ch_o.value),
            int(dut.bank_o.value),
            int(dut.row_o.value),
            int(dut.col_o.value),
        )
        e_ch, e_bank, e_row, e_col = golden(sa, mode)
        assert (ch, bank, row, col) == (e_ch, e_bank, e_row, e_col), (
            f"sa={sa:#x} mode={mode}: got=({ch},{bank},{row},{col}) "
            f"expected=({e_ch},{e_bank},{e_row},{e_col})"
        )


@cocotb.test()
async def test_random(dut) -> None:
    cocotb.start_soon(Clock(dut.clk_i, 10, units="ns").start())
    await reset(dut)
    rng = random.Random(0xBEEF)
    for _ in range(2000):
        sa = rng.randrange(0, 1 << 26)
        mode = rng.randint(0, 1)
        dut.sa_i.value = sa
        dut.mode_i.value = mode
        await RisingEdge(dut.clk_i)
        ch, bank, row, col = (
            int(dut.ch_o.value),
            int(dut.bank_o.value),
            int(dut.row_o.value),
            int(dut.col_o.value),
        )
        e_ch, e_bank, e_row, e_col = golden(sa, mode)
        assert (ch, bank, row, col) == (e_ch, e_bank, e_row, e_col)
