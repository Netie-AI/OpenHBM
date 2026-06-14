# Copyright 2026 The Netie Open HBM Authors
# SPDX-License-Identifier: Apache-2.0
"""Python reference for RS(18,16) over GF(2^8), poly 0x11D (matches RTL)."""

from __future__ import annotations

POLY = 0x11D


def _gf_tables() -> tuple[list[int], list[int]]:
    exp = [0] * 512
    log = [0] * 256
    x = 1
    for i in range(255):
        exp[i] = x
        log[x] = i
        x <<= 1
        if x & 0x100:
            x ^= POLY
    exp[255] = exp[0]
    for i in range(255, 512):
        exp[i] = exp[i - 255]
    return exp, log


_EXP, _LOG = _gf_tables()


def gf_mul(a: int, b: int) -> int:
    if a == 0 or b == 0:
        return 0
    return _EXP[(_LOG[a] + _LOG[b]) % 255]


def gf_inv(a: int) -> int:
    return _EXP[255 - _LOG[a]]


def encode(data128: int) -> int:
    """Return 16-bit ECC (low byte = parity symbol 16, high = symbol 17)."""
    d = [(data128 >> (8 * i)) & 0xFF for i in range(16)]
    r1 = r2 = 0
    for i in range(16):
        r1 ^= gf_mul(d[i], _EXP[i])
        r2 ^= gf_mul(d[i], _EXP[i * 2])
    a1, b1 = _EXP[16], _EXP[17]
    a2, b2 = _EXP[32], _EXP[34]
    det = gf_mul(a1, b2) ^ gf_mul(a2, b1)
    invdet = gf_inv(det)
    p0 = gf_mul(gf_mul(r1, b2) ^ gf_mul(r2, b1), invdet)
    p1 = gf_mul(gf_mul(a1, r2) ^ gf_mul(a2, r1), invdet)
    return p0 | (p1 << 8)


def _syndromes(data128: int, ecc16: int) -> tuple[int, int]:
    d = [(data128 >> (8 * i)) & 0xFF for i in range(16)]
    p0, p1 = ecc16 & 0xFF, (ecc16 >> 8) & 0xFF
    c = [*d, p0, p1]
    s1 = s2 = 0
    for i in range(18):
        s1 ^= gf_mul(c[i], _EXP[i])
        s2 ^= gf_mul(c[i], _EXP[i * 2])
    return s1, s2


def decode(data128: int, ecc16: int) -> tuple[int, int, bool, bool]:
    """Return (data_out128, syndrome16, ce, ue)."""
    s1, s2 = _syndromes(data128, ecc16)
    syn16 = s1 | (s2 << 8)
    if s1 == 0 and s2 == 0:
        return data128, syn16, False, False

    d_bytes = [(data128 >> (8 * i)) & 0xFF for i in range(16)]
    p0, p1 = ecc16 & 0xFF, (ecc16 >> 8) & 0xFF
    n_sol = 0
    best_d = data128

    for pos in range(18):
        for mag in range(1, 256):
            dd = list(d_bytes)
            pp0, pp1 = p0, p1
            if pos < 16:
                dd[pos] ^= mag
            elif pos == 16:
                pp0 ^= mag
            else:
                pp1 ^= mag
            t1, t2 = _syndromes(
                sum(dd[i] << (8 * i) for i in range(16)),
                pp0 | (pp1 << 8),
            )
            if t1 == 0 and t2 == 0:
                n_sol += 1
                best_d = sum(dd[i] << (8 * i) for i in range(16))

    if n_sol == 1:
        return best_d, syn16, True, False
    return data128, syn16, False, True
