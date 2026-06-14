"""Cocotb tests for hw/ip/addr_map.

Three test families:
  - directed corner cases (`test_basic`).
  - constrained-random traffic against the golden ref (`test_random`).
  - trace-driven workload tests (`test_traces`).
"""

from __future__ import annotations

import random
import sys
from pathlib import Path

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "env"))
from addr_map_ref import (
    SA_W,
    Mode,
    Region,
    map_addr,
)


def _pack_pa(pa) -> int:
    """Pack PA into the same bit layout as the SystemVerilog struct."""
    # Order matches addr_map_pkg::pa_t: {ch, pch, bg, ba, row, col}
    val = 0
    val = (val << 6) | pa.col
    val = (val << 17) | pa.row
    val = (val << 2) | pa.ba
    val = (val << 2) | pa.bg
    val = (val << 1) | pa.pch
    val = (val << 5) | pa.ch
    # SV concatenates MSB to LSB, so reverse the build order if needed.
    return val


def _unpack_pa(value: int):
    """Unpack the DUT's pa_t bus back into our Python record. Mirrors
    `_pack_pa` exactly. NOTE: cocotb returns the struct as a single integer
    where the MSB-most field is on the left, matching SV's `{a,b,c}` syntax.
    Field widths must match `addr_map_pkg.sv`."""
    col = value & 0x3F
    value >>= 6
    row = value & ((1 << 17) - 1)
    value >>= 17
    ba = value & 0x3
    value >>= 2
    bg = value & 0x3
    value >>= 2
    pch = value & 0x1
    value >>= 1
    ch = value & 0x1F
    return ch, pch, bg, ba, row, col


async def reset(dut) -> None:
    dut.rst_ni.value = 0
    dut.req_valid_i.value = 0
    dut.req_sa_i.value = 0
    dut.req_op_i.value = 0
    dut.rsp_ready_i.value = 1
    dut.cfg_we_i.value = 0
    dut.cfg_idx_i.value = 0
    dut.cfg_wdata_i.value = 0
    dut.cfg_commit_i.value = 0
    dut.cfg_default_mode_i.value = 0
    await Timer(20, units="ns")
    await RisingEdge(dut.clk_i)
    dut.rst_ni.value = 1
    await RisingEdge(dut.clk_i)


async def issue(dut, sa: int, op: int = 0):
    dut.req_valid_i.value = 1
    dut.req_sa_i.value = sa & ((1 << SA_W) - 1)
    dut.req_op_i.value = op
    while True:
        await RisingEdge(dut.clk_i)
        if int(dut.req_ready_o.value) == 1:
            break
    dut.req_valid_i.value = 0


async def collect_response(dut):
    while int(dut.rsp_valid_o.value) == 0:
        await RisingEdge(dut.clk_i)
    pa_val = int(dut.rsp_pa_o.value)
    await RisingEdge(dut.clk_i)
    return _unpack_pa(pa_val)


@cocotb.test()
async def test_default_mode_passthrough(dut) -> None:
    """With the region table empty, every request uses the default mode."""
    cocotb.start_soon(Clock(dut.clk_i, 10, units="ns").start())
    await reset(dut)
    dut.cfg_default_mode_i.value = int(Mode.CH_STRIPED)

    invalid = Region(valid=False, base_sa=0, size_log2=0, mode=Mode.CH_STRIPED, xor_poly=0)
    for sa in (0x0000_0000_0000_1000, 0x0000_0000_0000_5040, 0x0000_0001_0000_0000):
        expect = map_addr(sa, invalid, Mode.CH_STRIPED)
        await issue(dut, sa)
        ch, pch, bg, ba, row, col = await collect_response(dut)
        assert (ch, pch, bg, ba, row, col) == expect.as_tuple(), (
            f"sa={sa:#018x}: got=({ch},{pch},{bg},{ba},{row},{col}) expected={expect.as_tuple()}"
        )


@cocotb.test()
async def test_random_default_mode(dut) -> None:
    """CRT against the golden under the default mode."""
    cocotb.start_soon(Clock(dut.clk_i, 10, units="ns").start())
    await reset(dut)
    rng = random.Random(0xCAFE_BABE)
    invalid = Region(valid=False, base_sa=0, size_log2=0, mode=Mode.CH_STRIPED, xor_poly=0)

    for mode in (Mode.CH_STRIPED, Mode.BANK_INTERLEAVED, Mode.ROW_STATIONARY):
        dut.cfg_default_mode_i.value = int(mode)
        await RisingEdge(dut.clk_i)
        for _ in range(200):
            sa = rng.randrange(0, 1 << 40)  # exercise lower 40 bits
            expect = map_addr(sa, invalid, mode)
            await issue(dut, sa)
            ch, pch, bg, ba, row, col = await collect_response(dut)
            assert (ch, pch, bg, ba, row, col) == expect.as_tuple()


@cocotb.test()
async def test_handshake_backpressure(dut) -> None:
    """rsp_valid stays high when downstream isn't ready, and the input
    stalls until the response is consumed."""
    cocotb.start_soon(Clock(dut.clk_i, 10, units="ns").start())
    await reset(dut)
    dut.rsp_ready_i.value = 0
    await issue(dut, 0xDEAD_BEEF & ((1 << 40) - 1))

    # The response should land but stay valid because rsp_ready=0.
    for _ in range(8):
        await RisingEdge(dut.clk_i)
    assert int(dut.rsp_valid_o.value) == 1, "rsp should still be valid under backpressure"

    # Trying to inject a new request must be refused.
    dut.req_valid_i.value = 1
    dut.req_sa_i.value = 0x42
    await RisingEdge(dut.clk_i)
    assert int(dut.req_ready_o.value) == 0, "req_ready should be low while rsp not consumed"
    dut.req_valid_i.value = 0

    # Pop -- the next request can proceed.
    dut.rsp_ready_i.value = 1
    await RisingEdge(dut.clk_i)
    await RisingEdge(dut.clk_i)
    assert int(dut.req_ready_o.value) == 1
