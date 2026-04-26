# `pd/cells` -- transistor-level / custom-cell pipeline

For any cell the standard library is missing -- e.g. a domino-logic XOR for
the address mapper, or a sense-amplifier model for PHY work. All open
tools, no commercial dependencies.

## Pipeline

```
xschem .sch                      [schematic]
   |
   v
xschem -n         (netlister)    -> .spice (subckt)
   |
   v
ngspice -b        (simulation)    -- corners + Monte-Carlo
   |
   v
magic .mag                       [layout]
   |
   v
klayout DRC                      -> .drc.xml
   |
   v
netgen LVS                       -> .lvs.log
   |
   v
klayout GDS                      -> .gds
```

## PDK switch

The `Makefile` accepts `PDK=sky130` (default), `PDK=ihp130`, or
`PDK=asap7`. ASAP7 BSIM-CMG FinFET models drop directly into ngspice,
so the same flow extrapolates from sky130 130 nm to ASAP7 7 nm FinFET
without changing the toolchain.

## Status

Phase-0 scaffolding only. The xschem `.sch`, magic `.mag`, klayout `.lyt`
and netgen `.setup` files for the first lighthouse cell (a domino-logic
XOR2) land alongside the first hand-laid cell. Until then this directory
contains the Makefile and PDK rcfile placeholders.

## Why we keep this

In Phase 4 the open-HBM4-base-die path requires custom analog cells (sense
amps, equalisers, level shifters) that no open standard cell library
provides. Owning this pipeline now means we can land those cells
incrementally, instead of being blocked at the worst possible moment.
