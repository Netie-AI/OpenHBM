"""Cocotb tests for arbiter_rr."""

from __future__ import annotations

import random

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer


N = 4


async def reset(dut) -> None:
    dut.rst_ni.value = 0
    dut.req_i.value = 0
    await Timer(20, units="ns")
    await RisingEdge(dut.clk_i)
    dut.rst_ni.value = 1
    await RisingEdge(dut.clk_i)


def _onehot_to_idx(v: int) -> int:
    assert (v & (v - 1)) == 0, f"{v:b} is not one-hot"
    return v.bit_length() - 1


@cocotb.test()
async def test_round_robin(dut) -> None:
    cocotb.start_soon(Clock(dut.clk_i, 10, units="ns").start())
    await reset(dut)

    # All requests on -- expect strict round-robin.
    dut.req_i.value = (1 << N) - 1
    grants: list[int] = []
    for _ in range(N * 3):
        await RisingEdge(dut.clk_i)
        if int(dut.any_gnt_o.value):
            grants.append(_onehot_to_idx(int(dut.gnt_o.value)))

    # Strip the first grant to align (the pointer starts at 0 either way).
    seq = grants[: N * 2]
    assert seq[N:] == seq[:N], f"non-rr sequence: {seq}"


@cocotb.test()
async def test_no_request_no_grant(dut) -> None:
    cocotb.start_soon(Clock(dut.clk_i, 10, units="ns").start())
    await reset(dut)
    dut.req_i.value = 0
    for _ in range(8):
        await RisingEdge(dut.clk_i)
        assert int(dut.any_gnt_o.value) == 0


@cocotb.test()
async def test_random_traffic(dut) -> None:
    cocotb.start_soon(Clock(dut.clk_i, 10, units="ns").start())
    await reset(dut)
    rng = random.Random(0x1234)

    grants_per_idx = [0] * N
    for _ in range(2000):
        req = rng.randint(0, (1 << N) - 1)
        dut.req_i.value = req
        await RisingEdge(dut.clk_i)
        if int(dut.any_gnt_o.value):
            grants_per_idx[_onehot_to_idx(int(dut.gnt_o.value))] += 1
            assert (int(dut.gnt_o.value) & ~req) == 0  # no spurious grant

    # Every requester eventually wins (anti-starvation).
    assert all(g > 0 for g in grants_per_idx), f"starvation: {grants_per_idx}"
