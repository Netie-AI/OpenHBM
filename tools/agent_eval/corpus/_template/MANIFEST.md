# Corpus mini-block: `_template`

Copy this directory to start a new mini-block. Replace every occurrence of
`_template` with your block name.

## Required files

```
<name>/
  MANIFEST.md          # this file
  rtl/<name>.sv        # the implementation
  dv/Makefile          # cocotb runner
  dv/env/<name>_ref.py # Python golden
  dv/tests/test_basic.py
  fpv/<name>.sby       # SymbiYosys task(s)
  dv/mcy/config.mcy    # mutation config (optional but encouraged)
  doc/<name>.md        # short architectural note
```

## Score expectations

A landed mini-block must score >=95 on the harness using OSS CAD Suite
2026-04-02. Anything <95 is treated as a regression and fails the
`agent-eval.yml` workflow on PRs that touch the harness or prompts.
