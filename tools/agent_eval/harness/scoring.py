"""Scoring schema for the agent-eval harness.

The score is a weighted sum of stage results in [0, 1], multiplied by 100.
Per-IP overrides can shift weights; defaults match `tools/agent_eval/README.md`.

A "hard fail" stage (e.g. the bijection proof for `addr_map`) zeroes the
total even if other stages are perfect.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Literal

StageId = Literal["lint", "elab", "sim_pass", "func_cov", "formal", "mutation"]


@dataclass(frozen=True)
class Weights:
    lint: float = 10.0
    elab: float = 10.0
    sim_pass: float = 25.0
    func_cov: float = 20.0
    formal: float = 20.0
    mutation: float = 15.0

    def total(self) -> float:
        return self.lint + self.elab + self.sim_pass + self.func_cov + self.formal + self.mutation


@dataclass
class StageResult:
    stage: StageId
    score_unit: float  # in [0, 1]
    detail: str = ""
    hard_fail: bool = False


@dataclass
class IpScoring:
    ip_name: str
    weights: Weights = field(default_factory=Weights)
    stages: list[StageResult] = field(default_factory=list)
    threshold: float = 80.0

    def add(
        self, stage: StageId, score_unit: float, detail: str = "", hard_fail: bool = False
    ) -> None:
        score_unit = max(0.0, min(1.0, score_unit))
        self.stages.append(StageResult(stage, score_unit, detail, hard_fail))

    def total(self) -> float:
        if any(s.hard_fail and s.score_unit < 1.0 for s in self.stages):
            return 0.0
        w = self.weights
        weight_for: dict[StageId, float] = {
            "lint": w.lint,
            "elab": w.elab,
            "sim_pass": w.sim_pass,
            "func_cov": w.func_cov,
            "formal": w.formal,
            "mutation": w.mutation,
        }
        # Normalise so a sparse staged report still maps to 0..100 cleanly.
        used = sum(weight_for[s.stage] for s in self.stages)
        if used == 0:
            return 0.0
        weighted = sum(s.score_unit * weight_for[s.stage] for s in self.stages)
        return 100.0 * weighted / used

    def passed(self) -> bool:
        return self.total() >= self.threshold

    def to_dict(self) -> dict:
        return {
            "name": self.ip_name,
            "score": round(self.total(), 2),
            "threshold": self.threshold,
            "passed": self.passed(),
            "stages": [
                {
                    "stage": s.stage,
                    "score_unit": round(s.score_unit, 4),
                    "detail": s.detail,
                    "hard_fail": s.hard_fail,
                }
                for s in self.stages
            ],
            "weights": self.weights.__dict__,
        }


# Per-IP override hook -- mirrors the table in docs/agent-prompts/<ip>.md.
PER_IP_WEIGHTS: dict[str, Weights] = {
    "addr_map": Weights(lint=10, elab=10, sim_pass=20, func_cov=20, formal=25, mutation=15),
    "ecc": Weights(lint=10, elab=10, sim_pass=20, func_cov=15, formal=30, mutation=15),
    "refresh_mgr": Weights(lint=10, elab=10, sim_pass=20, func_cov=20, formal=25, mutation=15),
}


def weights_for(ip_name: str) -> Weights:
    return PER_IP_WEIGHTS.get(ip_name, Weights())
