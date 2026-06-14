"""Cocotb tests for fifo_sync."""

from __future__ import annotations

import random
import sys
from pathlib import Path

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "env"))
from fifo_sync_ref import FifoSyncRef

WIDTH = 8
DEPTH = 8


async def reset(dut) -> None:
    dut.rst_ni.value = 0
    dut.push_i.value = 0
    dut.pop_i.value = 0
    dut.push_data_i.value = 0
    await Timer(20, units="ns")
    await RisingEdge(dut.clk_i)
    dut.rst_ni.value = 1
    await RisingEdge(dut.clk_i)


@cocotb.test()
async def test_basic_push_pop(dut) -> None:
    cocotb.start_soon(Clock(dut.clk_i, 10, units="ns").start())
    await reset(dut)
    ref = FifoSyncRef(WIDTH, DEPTH)

    # Push 4 values, then pop 4.
    for v in (0xAA, 0x55, 0x12, 0xFE):
        dut.push_i.value = 1
        dut.push_data_i.value = v
        ref.push(v)
        await RisingEdge(dut.clk_i)
    dut.push_i.value = 0
    assert int(dut.fill_o.value) == ref.fill, f"fill mismatch {int(dut.fill_o.value)} vs {ref.fill}"

    for _ in range(4):
        assert int(dut.empty_o.value) == int(ref.empty)
        expected = ref.peek()
        dut.pop_i.value = 1
        await RisingEdge(dut.clk_i)
        got = int(dut.pop_data_o.value)
        # Note: pop_data_o is the head; check before advancing the ref.
        assert got == expected, f"pop_data {got:#x} != {expected:#x}"
        ref.pop()
    dut.pop_i.value = 0
    await RisingEdge(dut.clk_i)
    assert int(dut.empty_o.value) == 1


@cocotb.test()
async def test_full_then_drain(dut) -> None:
    cocotb.start_soon(Clock(dut.clk_i, 10, units="ns").start())
    await reset(dut)
    ref = FifoSyncRef(WIDTH, DEPTH)

    # Fill to capacity.
    for i in range(DEPTH):
        dut.push_i.value = 1
        dut.push_data_i.value = i
        ref.push(i)
        await RisingEdge(dut.clk_i)
    dut.push_i.value = 0
    await RisingEdge(dut.clk_i)
    assert int(dut.full_o.value) == 1

    # Drain.
    for _ in range(DEPTH):
        dut.pop_i.value = 1
        await RisingEdge(dut.clk_i)
    dut.pop_i.value = 0
    await RisingEdge(dut.clk_i)
    assert int(dut.empty_o.value) == 1


@cocotb.test()
async def test_random_traffic(dut) -> None:
    cocotb.start_soon(Clock(dut.clk_i, 10, units="ns").start())
    await reset(dut)
    ref = FifoSyncRef(WIDTH, DEPTH)
    rng = random.Random(0x4242)

    for _ in range(2000):
        do_push = rng.random() < 0.5 and not ref.full
        do_pop = rng.random() < 0.5 and not ref.empty
        data = rng.randint(0, 0xFF)
        dut.push_i.value = int(do_push)
        dut.push_data_i.value = data
        dut.pop_i.value = int(do_pop)

        await RisingEdge(dut.clk_i)

        if do_push:
            ref.push(data)
        if do_pop:
            got = int(dut.pop_data_o.value)
            popped = ref.pop()
            assert got == popped, f"pop {got:#x} != {popped:#x}"

    dut.push_i.value = 0
    dut.pop_i.value = 0
