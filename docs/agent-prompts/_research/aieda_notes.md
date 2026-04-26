# Research notes: AiEDA + AiMap (OSCC-Project)

References:

- AiEDA, ISEDA 2024 -- "AiEDA: An Open-source AI-native EDA Library."
- AiMap, ICCD 2023 -- "AiMap: Learning to Improve Technology Mapping for
  ASICs via Delay Prediction."
- iPL-3D, ICCAD 2023 -- "A Novel Bilevel Programming Model for Die-to-Die
  Placement."
- Source: <https://github.com/OSCC-Project/iEDA>
- License: MulanPSL-2.0 (OSI-approved).

## Why we are studying these

AiEDA and AiMap are the most relevant academic prior art for a working
ML-driven EDA loop. The Track-B agent-eval harness in this repo and the
ML-driven scoring/feedback loop it represents are conceptually adjacent.
Reading these papers (and the open-source library that backs them) lets
us pick up patterns instead of inventing them.

This document is **notes-only**. We do NOT vendor any iEDA code into
`hw/vendor/` until license counsel has cleared MulanPSL-2.0 ↔ Apache-2.0
outbound compatibility for any combined work we ship inside our RTL repo.
See [`docs/legal/export_control.md`](../../legal/export_control.md).

## Patterns extracted

### From AiMap (ICCD 2023)

- ML model: a delay-prediction network trained on a large corpus of
  real ABC-mapped netlists.
- Feature set: AIG (And-Inverter Graph) structural features per cone,
  cell-library timing features, target-frequency conditioning.
- Loss: regression on per-cone delay, with a downstream Pareto check on
  area.
- Why this is interesting for us: our `tools/agent_eval/harness` loop
  runs the agent, scores its RTL, and feeds the failure pattern back as
  prompt conditioning. AiMap's structural feature extraction is the
  canonical recipe for going from a graph (RTL syntax tree) to a
  feature vector that a model can predict on. We can adopt the
  AIG-feature-extraction step verbatim once we want to ML-rank
  candidate prompts (Phase 2+).

### From AiEDA (ISEDA 2024)

- A library of feature extractors and label datasets across the EDA
  flow stages (synth, place, route).
- Standardised dataset format that lets multiple ML models share
  training data.
- Why this is interesting for us: our agent-eval `score.json` is
  effectively a label vector. If we mirror AiEDA's dataset format we
  can release a public dataset of (prompt, generated RTL, score, stage
  detail) triples, which becomes a community contribution and an
  external moat (whoever curates the largest public RTL-eval corpus
  drives the field).

### From iPL-3D (ICCAD 2023)

- Bilevel optimisation: outer level minimises bridge area, inner level
  minimises wirelength under a placement constraint.
- We use this directly via the iEDA Docker image; see
  `pd/chiplet/ipl3d/`.

## Action items (notes only -- no code yet)

1. Build a feature extractor for our cocotb test traces analogous to the
   AIG features in AiMap. Output: a fixed-length vector per (prompt,
   generated module) pair.
2. Mirror AiEDA's dataset format for our `score.json` files so the
   public corpus is reusable in other projects' evaluation harnesses.
3. Sponsor an MSc/PhD project at USM or UM (per `Plan.md` s3 Phase 2)
   on the cross-application of AiEDA features to RTL-generation
   scoring; this is exactly the kind of CREST-eligible research grant
   we should be applying for in parallel with NLnet.

## Risks / things we will NOT copy

- iEDA's coding style and license posture differ from ours; do NOT copy
  any C++ / TCL source into the repo without legal review.
- Their training datasets may include vendor-PDK-derived data that
  cannot be reproduced under open licenses; do NOT lift such datasets.
