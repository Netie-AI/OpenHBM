"""Cocotb tests for hw/ip/ecc (default ECC_CLASS = ECC_SECDED)."""

from __future__ import annotations

import random
import sys
from pathlib import Path

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "env"))
from ecc_ref import K, N, encode, decode  # noqa: E402


async def reset(dut) -> None:
    dut.rst_ni.value = 0
    dut.valid_i.value = 0
    dut.is_encode_i.value = 0
    dut.data_i.value = 0
    dut.codeword_i.value = 0
    await Timer(20, units="ns")
    await RisingEdge(dut.clk_i)
    dut.rst_ni.value = 1
    await RisingEdge(dut.clk_i)


@cocotb.test()
async def test_encode(dut) -> None:
    cocotb.start_soon(Clock(dut.clk_i, 10, units="ns").start())
    await reset(dut)
    rng = random.Random(0x1234)
    for _ in range(64):
        data = rng.getrandbits(K)
        dut.valid_i.value = 1
        dut.is_encode_i.value = 1
        dut.data_i.value = data
        await Timer(1, units="ns")
        cw = int(dut.codeword_o.value)
        assert cw == encode(data), f"encode({data:#x}): got {cw:#x} expected {encode(data):#x}"


@cocotb.test()
async def test_single_bit_correction(dut) -> None:
    cocotb.start_soon(Clock(dut.clk_i, 10, units="ns").start())
    await reset(dut)
    rng = random.Random(0xBEEF)
    for trial in range(8):
        data = rng.getrandbits(K)
        cw = encode(data)
        for bit in range(N):
            err_cw = cw ^ (1 << bit)
            dut.valid_i.value = 1
            dut.is_encode_i.value = 0
            dut.codeword_i.value = err_cw
            await Timer(1, units="ns")
            d = int(dut.data_o.value)
            c = int(dut.correctable_o.value)
            u = int(dut.uncorrectable_o.value)
            ref_d, ref_c, ref_u = decode(err_cw)
            assert d == ref_d == data, f"trial={trial} bit={bit}: d={d:#x} ref={ref_d:#x} orig={data:#x}"
            assert c == int(ref_c) == 1
            assert u == int(ref_u) == 0
