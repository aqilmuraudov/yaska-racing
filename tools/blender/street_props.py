"""Boulevard street props for Yaska Racing (0.14.2 Blender models): the
seaside balustrade segment (baluster) and the Baku triple-globe lamp (lamp).

  blender --background --factory-startup --python tools/blender/street_props.py -- --bake-res 2048 --tex-res 1024
These are the most instanced props on every map (profiled: balusters were
~40 % of the seafront triangles, lamps 978 triangles x3 materials and
shadow casters), so the low models are very light and the turned shapes,
mouldings and cast-iron ornament live in the baked normal / AO. Shapes,
sizes and origins match PropKit._baluster_segment and BakuExtras._lamp_baku.
albedo alpha marks limestone (world stone detail), orm alpha the lamp globes
(glow follows TimeOfDay lamps).
"""

import math
import os
import sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from kart_common import *  # noqa: F401,F403
import kart_common as K
from mathutils import Vector, Matrix, Euler, Quaternion

PALETTE = {
    "limestone": ("D9C29A", 0.85, 0.0),
    "plaster_white": ("F2ECE0", 0.6, 0.0),
    "iron": ("2B2D33", 0.45, 0.55),
    "gold": ("F2C14E", 0.25, 1.0),
    "globe": ("FFF6DC", 0.2, 0.0),
}
PAINT_MAT = "globe"
STONE = ["limestone"]
GROUPS = ["baluster", "lamp"]
UV_SCALE = {"baluster": 1.0, "lamp": 1.4}
FAR_RATIO = {"baluster": 0.45, "lamp": 0.4}
UP = Matrix.Rotation(math.pi / 2, 4, "Z")  # lathe axis X -> Y


def turned(name, profile, base, mat, g, hi, steps):
    """Lathe around the vertical axis: profile = [(height, radius), ...]."""
    ob = lathe(name, profile, (0, 0, 0), mat, g, hi, steps)
    ob.data.transform(Matrix.Translation(Vector(base)) @ UP)
    return ob


def build_baluster(hi):
    tag = "H" if hi else "L"
    g = "baluster"
    bbox(f"bal_base_{tag}", (2.0, 0.16, 0.36), (0, 0.08, 0), "limestone", g, hi, L(hi, 0.0, 0.05))
    bbox(f"bal_rail_{tag}", (2.04, 0.12, 0.32), (0, 0.98, 0), "plaster_white", g, hi, L(hi, 0.0, 0.05))
    if hi:
        bbox("bal_rail_lip", (2.06, 0.04, 0.36), (0, 0.93, 0), "plaster_white", g, True, 0.015)
        bbox("bal_base_lip", (2.02, 0.04, 0.38), (0, 0.17, 0), "limestone", g, True, 0.015)
    # Turned vase balusters: rich profile high, 5-sided low.
    vase = [(0.0, 0.07), (0.06, 0.07), (0.1, 0.05), (0.2, 0.075), (0.36, 0.085), (0.5, 0.06), (0.6, 0.042),
            (0.66, 0.05), (0.7, 0.065), (0.74, 0.065), (0.74, 0.0)]
    lo_vase = [(0.0, 0.07), (0.34, 0.08), (0.74, 0.055)]
    for i in range(5):
        x = -0.8 + i * 0.4
        turned(f"bal_vase{i}_{tag}", vase if hi else lo_vase, (x, 0.17, 0), "plaster_white", g, hi, L(hi, 4, 32))
    bbox(f"bal_post_{tag}", (0.28, 1.1, 0.34), (1.0, 0.55, 0), "limestone", g, hi, L(hi, 0.0, 0.04))
    bbox(f"bal_cap_{tag}", (0.34, 0.08, 0.40), (1.0, 1.12, 0), "plaster_white", g, hi, L(hi, 0.0, 0.03))
    if hi:
        for z in (-1, 1):
            puffy(f"bal_panel{z}", [(-0.08, -0.32), (0.08, -0.32), (0.08, 0.32), (-0.08, 0.32)], 0.012, 0.004,
                  facing((1.0, 0.55, z * 0.171), (0, 0, z)), "limestone", g, True)


def build_lamp(hi):
    tag = "H" if hi else "L"
    g = "lamp"
    st = L(hi, 6, 32)
    base = [(0.0, 0.34), (0.08, 0.34), (0.12, 0.3), (0.42, 0.28), (0.5, 0.31), (0.56, 0.2)]
    lo_base = [(0.0, 0.33), (0.5, 0.3), (0.56, 0.2)]
    turned(f"lamp_base_{tag}", base if hi else lo_base, (0, 0, 0), "iron", g, hi, st)
    shaft = [(0.0, 0.2), (0.3, 0.24), (0.9, 0.13), (1.15, 0.1), (1.2, 0.14), (1.26, 0.09)]
    lo_shaft = [(0.0, 0.22), (0.9, 0.12), (1.26, 0.09)]
    turned(f"lamp_shaft_{tag}", shaft if hi else lo_shaft, (0, 0.56, 0), "iron", g, hi, st)
    turned(f"lamp_pole_{tag}", [(0.0, 0.09), (3.6, 0.075)], (0, 1.8, 0), "iron", g, hi, L(hi, 6, 24))
    turned(f"lamp_collar_{tag}", [(0.0, 0.11), (0.08, 0.15), (0.16, 0.11)], (0, 1.68, 0), "gold", g, hi, L(hi, 6, 24))
    # Curved arms with scrolls and three globes.
    for s in (-1, 1):
        arm = [(0, 4.55, 0), (s * 0.2, 4.9, 0), (s * 0.45, 4.95, 0), (s * 0.6, 4.88, 0)]
        tube(f"lamp_arm{s}_{tag}", arm, 0.035, "iron", g, hi, L(hi, 2, 8), L(hi, 5, 10), True)
        tube(f"lamp_hook{s}_{tag}", [(s * 0.6, 4.88, 0), (s * 0.6, 4.95, 0)], 0.03, "iron", g, hi, 1, L(hi, 5, 10))
        if hi:
            sc = [(s * (0.2 + 0.08 * math.cos(a)), 4.72 + 0.08 * math.sin(a), 0) for a in
                  [math.pi * 0.5 + k * 0.5 for k in range(10)]]
            tube(f"lamp_scroll{s}", sc, 0.018, "iron", True and g, True, 3, 8, True)
        turned(f"lamp_cup{s}_{tag}", [(0.0, 0.0), (0.04, 0.14), (0.1, 0.16)], (s * 0.6, 4.86, 0), "iron", g, hi,
               L(hi, 6, 24))
        ellipsoid(f"lamp_globe{s}_{tag}", (0.26, 0.26, 0.26), (s * 0.6, 4.65, 0), "globe", g, hi, L(hi, (8, 6), (32, 20)))
    turned(f"lamp_top_cup_{tag}", [(0.0, 0.09), (0.08, 0.17), (0.12, 0.18)], (0, 5.08, 0), "iron", g, hi, L(hi, 6, 24))
    ellipsoid(f"lamp_globe_top_{tag}", (0.3, 0.3, 0.3), (0, 5.45, 0), "globe", g, hi, L(hi, (8, 6), (32, 20)))
    turned(f"lamp_finial_{tag}", [(0.0, 0.1), (0.1, 0.06), (0.35, 0.0)], (0, 5.72, 0), "gold", g, hi, L(hi, 6, 20))


OFFSET = {"baluster": Vector((0, 0, 0)), "lamp": Vector((5.0, 0, 0))}


def _built(fn, g):
    before = set(K.COLL.objects)
    fn()
    for o in set(K.COLL.objects) - before:
        o.data.transform(Matrix.Translation(OFFSET[g]))


def build(hi):
    _built(lambda: build_baluster(hi), "baluster")
    _built(lambda: build_lamp(hi), "lamp")


def _home(groups):
    for o in groups:
        o.data.transform(Matrix.Translation(-OFFSET[o.name]))


K.PRE_EXPORT.append(_home)
K.setup("street_props", "assets/models/street", PALETTE, PAINT_MAT, GROUPS, UV_SCALE, FAR_RATIO, stone_mats=STONE)
K.run(build)
