"""Cocotb tests for hsiao_secded.

Verifies:
  - Round-trip encode/decode with no error has correctable=0, uncorrectable=0.
  - Single-bit flip in any of the 72 positions is corrected back.
  - Double-bit flip is signalled as uncorrectable.
"""

from __future__ import annotations

import random

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer

K = 64
N = 72


async def reset(dut) -> None:
    dut.rst_ni.value = 0
    dut.enc_valid_i.value = 0
    dut.dec_valid_i.value = 0
    dut.enc_data_i.value = 0
    dut.dec_codeword_i.value = 0
    await Timer(20, units="ns")
    await RisingEdge(dut.clk_i)
    dut.rst_ni.value = 1
    await RisingEdge(dut.clk_i)


async def encode(dut, data: int) -> int:
    dut.enc_valid_i.value = 1
    dut.enc_data_i.value = data
    await Timer(1, units="ns")
    cw = int(dut.enc_codeword_o.value)
    dut.enc_valid_i.value = 0
    return cw


async def decode(dut, codeword: int) -> tuple[int, int, int]:
    dut.dec_valid_i.value = 1
    dut.dec_codeword_i.value = codeword
    await Timer(1, units="ns")
    data = int(dut.dec_data_o.value)
    corr = int(dut.dec_correctable_o.value)
    uncorr = int(dut.dec_uncorrectable_o.value)
    dut.dec_valid_i.value = 0
    return data, corr, uncorr


@cocotb.test()
async def test_no_error(dut) -> None:
    cocotb.start_soon(Clock(dut.clk_i, 10, units="ns").start())
    await reset(dut)
    rng = random.Random(0xCAFE)
    for _ in range(64):
        data = rng.getrandbits(K)
        cw = await encode(dut, data)
        d, c, u = await decode(dut, cw)
        assert d == data and c == 0 and u == 0, f"clean roundtrip failed at {data:#x}"


@cocotb.test()
async def test_single_bit_correction(dut) -> None:
    cocotb.start_soon(Clock(dut.clk_i, 10, units="ns").start())
    await reset(dut)
    rng = random.Random(0xBEEF)
    for trial in range(8):
        data = rng.getrandbits(K)
        cw = await encode(dut, data)
        for bit in range(N):
            cw_err = cw ^ (1 << bit)
            d, c, u = await decode(dut, cw_err)
            assert d == data, f"trial={trial} bit={bit} data={data:#x} corrupted -> {d:#x}"
            assert c == 1 and u == 0, f"flags wrong at bit={bit}: c={c} u={u}"


@cocotb.test()
async def test_double_bit_detection(dut) -> None:
    cocotb.start_soon(Clock(dut.clk_i, 10, units="ns").start())
    await reset(dut)
    rng = random.Random(0xDEAD)
    for _ in range(64):
        data = rng.getrandbits(K)
        cw = await encode(dut, data)
        b0, b1 = rng.sample(range(N), 2)
        cw_err = cw ^ (1 << b0) ^ (1 << b1)
        _, c, u = await decode(dut, cw_err)
        # SEC-DED contract: double error must NOT be silently miscorrected.
        # Hsiao guarantees the (c, u) outcome here is (0, 1) for genuine
        # 2-bit errors. (Some pathological codeword pairs can fall into
        # the c=1 zone, but Hsiao's canonical odd-weight-column code
        # rules them out.)
        assert u == 1 and c == 0, f"double-bit miscategorised: c={c} u={u} bits=({b0},{b1})"
