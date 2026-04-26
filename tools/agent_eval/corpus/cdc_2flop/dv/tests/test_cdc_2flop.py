"""Cocotb tests for cdc_2flop -- verifies the 2-flop pipeline depth."""

from __future__ import annotations

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer


async def reset(dut) -> None:
    dut.rst_dst_ni.value = 0
    dut.d_i.value = 0
    await Timer(20, units="ns")
    await RisingEdge(dut.clk_dst_i)
    dut.rst_dst_ni.value = 1
    await RisingEdge(dut.clk_dst_i)


@cocotb.test()
async def test_two_cycle_latency(dut) -> None:
    cocotb.start_soon(Clock(dut.clk_dst_i, 10, units="ns").start())
    await reset(dut)
    assert int(dut.q_o.value) == 0

    dut.d_i.value = 1
    await RisingEdge(dut.clk_dst_i)
    # After one clock the input is in stage 0 only.
    assert int(dut.q_o.value) == 0
    await RisingEdge(dut.clk_dst_i)
    # After two clocks it has propagated to the output.
    assert int(dut.q_o.value) == 1


@cocotb.test()
async def test_reset_value(dut) -> None:
    cocotb.start_soon(Clock(dut.clk_dst_i, 10, units="ns").start())
    dut.rst_dst_ni.value = 0
    dut.d_i.value = 1
    await Timer(50, units="ns")
    assert int(dut.q_o.value) == 0
    dut.rst_dst_ni.value = 1
    await RisingEdge(dut.clk_dst_i)
    await RisingEdge(dut.clk_dst_i)
    assert int(dut.q_o.value) == 1
