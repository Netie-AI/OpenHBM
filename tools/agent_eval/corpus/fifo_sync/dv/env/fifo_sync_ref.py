"""Pure-Python golden reference for fifo_sync."""

from __future__ import annotations

from collections import deque
from dataclasses import dataclass


@dataclass
class FifoSyncRef:
    width: int
    depth: int

    def __post_init__(self) -> None:
        self._q: deque[int] = deque(maxlen=self.depth)

    @property
    def empty(self) -> bool:
        return len(self._q) == 0

    @property
    def full(self) -> bool:
        return len(self._q) == self.depth

    @property
    def fill(self) -> int:
        return len(self._q)

    def push(self, data: int) -> None:
        if self.full:
            return
        mask = (1 << self.width) - 1
        self._q.append(data & mask)

    def pop(self) -> int:
        if self.empty:
            return 0
        return self._q.popleft()

    def peek(self) -> int:
        return self._q[0] if not self.empty else 0
