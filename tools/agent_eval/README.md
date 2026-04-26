# tools/agent_eval -- the AI-agent RTL evaluation harness

Turns "did the agent write good RTL?" into a numeric CI gate.

## Pipeline

```
prompt.md  +  generated_rtl/  +  generated_dv/
        |                     |
        v                     v
 [verible-lint] -> [verilator -Wall] -> [cocotb sim]
                                              |
                                              v
                                  [cocotb-coverage report]
                                              |
                                              v
                              [SymbiYosys BMC + PROVE]
                                              |
                                              v
                              [mcy mutation coverage]
                                              |
                                              v
                                 [score.json: 0..100]
                                              |
                          score >= 80  -> AUTO PR
                          score <  80  -> BLOCK + structured feedback
```

Score weights (default; per-IP overrides in
`docs/agent-prompts/<ip>.md`):

| Stage                  | Weight |
| ---------------------- | -----: |
| Lint                   |     10 |
| Verilator elab         |     10 |
| Cocotb sim pass        |     25 |
| Functional coverage    |     20 |
| Formal (BMC + PROVE)   |     20 |
| Mutation coverage      |     15 |

## Layout

- `harness/run.py`         -- CLI entry point (`nieda-eval`).
- `harness/scoring.py`     -- score-weight tables + 0..100 calculator.
- `harness/stages/`        -- one module per stage in the pipeline.
- `harness/feedback.py`    -- writes structured failure reports back into
                              the prompt's `feedback/` directory so the
                              next agent run can read what its predecessor
                              missed.
- `corpus/`                -- ~30 hand-authored mini-blocks with full
                              lint/sim/formal/mutation evidence. The
                              regression set we run on every prompt
                              change.
- `feedback/`              -- per-IP structured feedback (gitignored
                              except for `.gitkeep`).

## Running

```bash
make agent-eval PROMPT=docs/agent-prompts/addr_map.md
# or
nieda-eval --prompt docs/agent-prompts/addr_map.md

# Run the corpus regression (used in CI):
nieda-eval --corpus tools/agent_eval/corpus/ --gate 80 --report build/eval.json
```

## What "score 80" means

It does NOT mean the IP is silicon-ready. It means:

- Lint clean (no rule violations).
- Verilator elaborates without warning.
- All declared cocotb tests pass.
- >=95% functional coverage on protocol cross-coverage points.
- All declared SymbiYosys properties pass.
- >=80% killed mutants when measured against the IP's directed + CRT
  testsuite.

It IS the bar to merge a Phase-1 module. It is NOT the bar for tapeout.
For tapeout there is an additional gate (PD-clean, signoff-clean) that
this harness does not yet cover -- that arrives with the Track-C ASIC
flows in `pd/sc_flows/`.
