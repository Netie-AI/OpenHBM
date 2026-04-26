"""Parameterised openEMS structure for an organic-substrate flip-chip stack.

The model is built lazily so it imports cleanly even without openEMS or
CSXCAD on PYTHONPATH (the CI screen run pulls them via the OSS CAD Suite
extras image).

Geometry (microns):
                                 +----------------------+
                                 |  Top die (LPU)       |
                                 +----------------------+
   uBump pitch ubump_pitch_um ->   o   o   o   o   o   o
                                 +----------------------+
                                 |  Organic substrate    |
                                 |  (eps_r ~ 3.6, tan d) |
                                 +----------------------+
                                 |  Bridge die / RDL     |
                                 +----------------------+
   TSV pitch tsv_pitch_um -----> | | | | | | | | | | | |
                                 +----------------------+
                                 |  HBM4 stack (24+ um)  |
                                 +----------------------+

We model only the *signal coupling* portion of this -- the bridge plus
RDL plus uBumps. TSVs into the HBM4 stack are represented as terminated
ports.
"""

from __future__ import annotations

from dataclasses import dataclass


@dataclass
class StackParams:
    tsv_pitch_um:     float = 55.0
    ubump_pitch_um:   float = 35.0
    bridge_length_um: float = 1000.0
    bridge_width_um:  float = 50.0
    metal_thickness_um: float = 0.8
    dielectric_height_um: float = 6.0
    dielectric_eps_r: float = 3.6
    dielectric_loss_tan: float = 0.005
    data_rate_gbps:   float = 8.0
    lanes:            int   = 2048

    @property
    def nyquist_ghz(self) -> float:
        return self.data_rate_gbps / 2.0


def build_structure(p: StackParams):
    """Build a CSXCAD geometry. Returns the FDTD object on success, or
    `None` if openEMS/CSXCAD are unavailable (CI placeholder)."""
    try:
        from CSXCAD import ContinuousStructure
        from openEMS import openEMS  # noqa: F401
    except ImportError:
        return None

    csx = ContinuousStructure()

    # Organic substrate
    sub = csx.AddMaterial("organic")
    sub.SetMaterialProperty(epsilon=p.dielectric_eps_r,
                            kappa=p.dielectric_loss_tan)
    sub.AddBox(start=[0, 0, 0],
               stop=[p.bridge_length_um, p.bridge_width_um * p.lanes,
                     p.dielectric_height_um])

    # Bridge metal traces (one per lane, simplified as parallel strips)
    metal = csx.AddMetal("cu")
    for lane in range(min(p.lanes, 64)):           # cap to keep mesh tractable
        y0 = lane * p.ubump_pitch_um
        metal.AddBox(
            start=[0, y0, p.dielectric_height_um],
            stop=[p.bridge_length_um, y0 + p.metal_thickness_um,
                  p.dielectric_height_um + p.metal_thickness_um],
        )

    # uBumps (modelled as small cylinders, one per lane)
    bump = csx.AddMetal("solder")
    for lane in range(min(p.lanes, 64)):
        y = lane * p.ubump_pitch_um
        bump.AddCylinder(
            start=[0, y, p.dielectric_height_um + p.metal_thickness_um],
            stop=[0, y, p.dielectric_height_um + p.metal_thickness_um + 25.0],
            radius=10.0,
        )

    return csx


__all__ = ["StackParams", "build_structure"]
