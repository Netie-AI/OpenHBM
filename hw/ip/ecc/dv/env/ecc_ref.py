"""Pure-Python golden for the ECC IP. Exposes Hsiao SEC-DED only for
Phase-1; the chipkill RS path is a placeholder until ecc_chipkill lands."""

from __future__ import annotations

K = 64
M = 8
N = K + M


def _h_row(r: int) -> int:
    row = 0
    for p in range(M):
        if p == r:
            row |= 1 << (K + p)
    for j in range(K):
        mask = (j + 1) % ((1 << M) - 1) + 1
        if (mask >> r) & 1:
            row |= 1 << j
    return row


_H_ROWS: list[int] = [_h_row(r) for r in range(M)]


def encode(data: int) -> int:
    parity = 0
    data &= (1 << K) - 1
    for r, row in enumerate(_H_ROWS):
        bit = bin(row & data & ((1 << K) - 1)).count("1") & 1
        parity |= bit << r
    return (parity << K) | data


def decode(codeword: int) -> tuple[int, bool, bool]:
    syndrome = 0
    for r, row in enumerate(_H_ROWS):
        bit = bin(row & codeword).count("1") & 1
        syndrome |= bit << r

    flip = 0
    match_found = False
    for j in range(N):
        col = 0
        for r, row in enumerate(_H_ROWS):
            if (row >> j) & 1:
                col |= 1 << r
        if syndrome != 0 and col == syndrome:
            flip |= 1 << j
            match_found = True

    corrected = codeword ^ flip
    correctable = (syndrome != 0) and match_found
    uncorrectable = (syndrome != 0) and not match_found
    return corrected & ((1 << K) - 1), correctable, uncorrectable
