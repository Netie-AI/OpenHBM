# Export-control posture (and iEDA / OSCC usage)

| | |
|---|---|
| Owner       | Founder (with US export-controls counsel before any sub-16nm tapeout). |
| Status      | DRAFT v0.1 -- supersedes ad-hoc statements in PRs and chats.            |
| Cadence     | Re-reviewed at every Phase boundary (`Plan.md` s3).                     |

This document captures the project's posture on US export controls, the
specific use of [iEDA](https://github.com/OSCC-Project/iEDA) (OSCC-Project,
MulanPSL-2.0), and the rules around contributor nationality and PDK
choice.

## Strategic baseline

Per [`Plan.md`](../../Plan.md) s6 ("Foundry and packaging partnership
roadmap") and s10 ("Competitive landscape"):

- The project's legal entity is a **Malaysian Sdn Bhd**.
- Malaysia is **Tier-2** under the US AI Diffusion framework (as of
  Jan 2025; the worldwide advanced-chip licence requirement was rescinded
  for Malaysia and India in May 2025).
- The project's primary advanced-node access is via **Europractice**
  (TSMC N16 / N7, IHP SG13G2, GF 22FDX), augmented by **ChipFoundry** for
  SkyWater 130 and **Tiny Tapeout** for SKY130 + IHP130.
- Chinese foundries (SMIC and similar) are explicitly **out of bounds**
  for advanced-node tapeouts because they would expose the project to
  EAR FDPR reach-through and preclude later TSMC/Samsung/Intel access.

## iEDA usage posture (the new bit)

[iEDA](https://github.com/OSCC-Project/iEDA) is published by OSCC-Project
(Chinese Academy of Sciences ecosystem) under MulanPSL-2.0. We use iEDA
because it brings four concrete things our project benefits from:

- An 11-tool open EDA flow netlist-to-GDS, with **four tape-outs already
  in production**.
- `iPL-3D` die-to-die placement (ICCAD 2023) -- the cleanest open
  analogue to TSMC CoWoS placement we have access to.
- `AiEDA` and `AiMap` ML-driven scoring patterns, immediately relevant
  to our Track-B agent-eval harness.
- A second-source path that lets us catch OpenROAD regressions before
  silicon.

### Hard rules

1. **Tool, not contributor channel.** We pull `iedaopensource/release:latest`
   from Docker Hub, run it against our own RTL, capture the output. We
   do NOT submit upstream PRs into iEDA. We do NOT accept PRs from
   OSCC-affiliated contributors into our advanced-node paths.
2. **OpenROAD shadow.** Every iEDA-produced artefact MUST have an
   OpenROAD-produced shadow before it touches any commercial-shuttle
   flow (Europractice, ChipFoundry, Intel Foundry Shuttle 16). iEDA is
   a second-source for development confidence, not a sole sign-off
   path.
3. **Open PDKs only.** For SkyWater 130 / IHP SG13G2 / ASAP7 / FreePDK45,
   iEDA usage is unrestricted.
4. **No iEDA in commercial PDK loops.** For TSMC N16 / N7 / N5 and
   Intel 16, iEDA is **not** in the loop until US export-controls
   counsel signs off (per `Plan.md` s6 "engage US export-controls
   counsel once the project touches anything below 16 nm").
5. **License posture.** MulanPSL-2.0 is OSI-approved. Inbound use of
   their binaries / containers is fine. To **vendor** any of their code
   into our repo we route through legal review first because outbound-
   license compatibility for combined works is the relevant question,
   not inbound use of the tool.

## Contributor nationality

We do not gate contributors by nationality at the **Apache-2.0 RTL
front-end**. We DO gate contributor PRs into **advanced-node
silicon-bound paths** (`pd/orfs_n16/`, `pd/innovus_n16/`, `pd/sc_flows/n7/`
when they exist) per `Plan.md` s6:

> "audit contributor nationalities before Phase-3 advanced-node tapeouts"

Practically:

- ICLA on file before any silicon-bound PR is merged.
- Maintainers from advanced-node-restricted jurisdictions can review code
  in the public RTL, but cannot be the sole approver on a silicon-bound
  PR.
- This posture is reviewed at every Phase boundary.

## PDK posture

| PDK             | Class               | Posture                                   |
| --------------- | ------------------- | ----------------------------------------- |
| SkyWater 130    | Open (Apache-2.0)   | Unrestricted; iEDA second-source allowed  |
| IHP SG13G2      | Open (Apache-2.0)   | Unrestricted; iEDA second-source allowed  |
| ASAP7           | Open (BSD-3 + ASU)  | Unrestricted; iEDA second-source allowed  |
| FreePDK45       | Open (NCSU)         | Unrestricted; iEDA second-source allowed  |
| GF 22FDX (Europractice mini@sic) | Commercial under NDA | OpenROAD only; iEDA NOT in loop |
| TSMC N16 (Europractice) | Commercial under NDA | OpenROAD + commercial shuttle tooling only; iEDA NOT in loop |
| TSMC N7 / N5    | Commercial under NDA | OpenROAD + commercial shuttle tooling only; iEDA NOT in loop |
| Intel 16        | Commercial under NDA | OpenROAD + commercial shuttle tooling only; iEDA NOT in loop |

## Audit trail

This file is the canonical place for the export-control posture. Any
deviation -- e.g. a PR that touches an advanced-node path with iEDA in
the loop -- requires an entry here AND a sign-off from US export-
controls counsel. CI for advanced-node paths gates on this file's
modification timestamp matching the relevant PR's review.
