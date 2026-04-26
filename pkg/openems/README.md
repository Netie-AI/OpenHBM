# `pkg/openems` -- organic-substrate flip-chip SI/PI screen

A parameterised [openEMS](https://www.openems.de/) 3D EM model of an
**organic-substrate flip-chip stack** with TSV/uBump arrays. Used to bound
crosstalk and SSN at the HBM4 boundary (8 Gb/s x 2048 lanes) before
committing to a commercial Ansys HFSS / Cadence Clarity sign-off run.

This is **screening, not sign-off**, per `Plan.md` s11. Anything we ship
on real silicon has to be re-verified in HFSS / Clarity.

The target package corresponds to ASE Penang's organic-substrate
flip-chip + chiplet-bridge offering, the most leverageable advanced-
packaging route reachable from Malaysia per `Plan.md` s6.

## Files

- `model.py` -- builds the openEMS structure from parameters
  (TSV pitch, uBump pitch, bridge length, dielectric stack-up).
- `run_screen.py` -- driver invoked by `.github/workflows/chiplet.yml`.
- `cfg/` -- example sweep configurations.

## Sweep dimensions

| Parameter            | Default      | Range          |
| -------------------- | ------------ | -------------- |
| `tsv_pitch_um`       | 55           | 35..80         |
| `ubump_pitch_um`     | 35           | 25..55         |
| `bridge_length_um`   | 1000         | 500..3000      |
| `data_rate_gbps`     | 8.0          | 4.8..9.6       |
| `lanes`              | 2048         | 256..2048      |
| `dielectric_eps_r`   | 3.6 (organic) | 2.5..4.4      |

## Outputs

The screen produces a JSON file with per-corner SI metrics: insertion
loss `S21` at the Nyquist frequency, NEXT/FEXT at the worst aggressor
configuration, and an estimated eye opening at the receiver.

Crosstalk above ~ -25 dB at Nyquist is flagged as a hard fail. SSN
above the parameterised noise budget is flagged as a soft warn.
