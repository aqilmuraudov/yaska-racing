"""Çəpiş (lamb) + Cloud Booster kart for Yaska Racing (0.14.x Blender karts).

  blender --background --factory-startup --python tools/blender/cepis_cloud.py -- [--preview] [--no-bake]
Rounded coral tub wrapped in cream cloud puffs, a cloud bumper, a cloud pile
over the engine and two big chrome boosters; a lamb with a woolly cap and body,
tan face, droopy ears with pink insides and two pink bows. Rig numbers match
KartModel._cloud (rf 0.30, rr 0.34) and AnimalDriver (lamb ears: head +
(+-0.24, 0.16, 0.02)). The puff tail hides behind the seat, so it has no mesh.
"""

import math
import os
import sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from kart_common import *  # noqa: F401,F403
import kart_common as K
from mathutils import Vector, Matrix, Euler, Quaternion

PALETTE = {
    "body_coral": ("FF7B6B", 0.26, 0.45),
    "body_pink": ("FFB3A7", 0.3, 0.2),      # steering hub
    "cloud": ("FBF1DC", 0.6, 0.0),
    "brown": ("6B4A3A", 0.45, 0.2),
    "stripe_white": ("FFFFFF", 0.35, 0.0),
    "gold": ("F5B82E", 0.22, 1.0),
    "chrome": ("DDE1E6", 0.12, 1.0),
    "graphite": ("2E2B36", 0.6, 0.2),
    "engine": ("8E909A", 0.35, 0.9),
    "tire": ("2B2830", 0.85, 0.0),
    "tread": ("4A4452", 0.8, 0.0),
    "tire_text": ("E4E0EA", 0.75, 0.0),
    "rim_purple": ("6B4A3A", 0.3, 0.5),
    "seat": ("6B4A3A", 0.55, 0.0),
    "wool": ("F8F1E0", 0.85, 0.0),
    "face": ("E9D2B0", 0.7, 0.0),
    "hoof": ("7A5A48", 0.5, 0.0),
    "pink": ("FFB3A7", 0.5, 0.0),
    "nose": ("7A5A48", 0.3, 0.0),
    "mouth": ("6E1A22", 0.5, 0.0),
    "tongue": ("FF6F8E", 0.45, 0.0),
    "blush": ("FFB3B8", 0.6, 0.0),
    "eye_white": ("FFFFFF", 0.32, 0.0),
    "iris": ("6B4A3A", 0.35, 0.0),
    "iris_ring": ("3A2418", 0.35, 0.0),
    "pupil": ("0C0806", 0.32, 0.0),
    "lash": ("1E1410", 0.5, 0.0),
    "leggings": ("7A5A48", 0.65, 0.0),
    "sock": ("F8F1E0", 0.8, 0.0),
    "shoe": ("FFB3A7", 0.45, 0.0),
    "sole": ("F4F1EE", 0.6, 0.0),
    "star_yellow": ("FFFFFF", 0.35, 0.0),
}
PAINT_MAT = "body_coral"
GROUPS = ["Body", "WheelFL", "WheelFR", "WheelRear", "SteeringWheel", "Torso", "Head",
          "Eyes", "EarL", "EarR", "ArmL", "ArmR"]
UV_SCALE = {"Body": 1.0, "WheelFL": 1.0, "WheelFR": 1.0, "WheelRear": 1.0, "SteeringWheel": 1.0,
            "Torso": 1.3, "Head": 2.2, "Eyes": 2.6, "EarL": 1.3, "EarR": 1.3, "ArmL": 1.2, "ArmR": 1.2}
FAR_RATIO = {"Body": 0.12, "WheelFL": 0.12, "WheelFR": 0.12, "WheelRear": 0.12, "SteeringWheel": 0.2,
             "Torso": 0.15, "Head": 0.13, "Eyes": 0.3, "EarL": 0.35, "EarR": 0.35, "ArmL": 0.25, "ArmR": 0.25}

FRONT_WHEEL = (0.62, 0.30, -0.72)
REAR_WHEEL = (0.66, 0.34, 0.68)
FRONT_W, REAR_W = 0.26, 0.34
EAR_PIVOT = (0.24, 1.22, 0.20)


def puffs(name, centers, r, mat, g, hi):
    tag = "H" if hi else "L"
    for i, c in enumerate(centers):
        rr = r[i] if isinstance(r, (list, tuple)) else r
        ellipsoid(f"{name}{i}_{tag}", (rr, rr * 0.9, rr), c, mat, g, hi, L(hi, (10, 7), (36, 24)))


def build_body(hi):
    tag = "H" if hi else "L"
    g = "Body"
    se = lambda n, *a, **k: superellipsoid(f"{n}_{tag}", *a, **k)
    floor = se("floor", (0.40, 0.05, 0.98), (0, 0.19, 0.0), "graphite", g, hi, (0.3, 0.35), L(hi, (10, 4), (48, 16)))
    if not hi:
        drop_faces(floor, lambda c, n: n.y < -0.7)

    def tub_def(p, n):
        k = max(0.0, -n.z)
        return Vector((p.x * (1 - 0.3 * k), p.y * (1 - 0.15 * k), p.z))
    tub = se("tub", (0.36, 0.20, 0.62), (0, 0.40, -0.18), "body_coral", g, hi, (0.75, 0.78), L(hi, (18, 12), (72, 40)),
             deform=tub_def)
    se("deck", (0.28, 0.12, 0.2), (0, 0.38, 0.62), "body_coral", g, hi, (0.6, 0.6), L(hi, (14, 8), (56, 24)))
    se("seat_back", (0.23, 0.26, 0.06), (0, 0.80, 0.45), "seat", g, hi, (0.45, 0.5), L(hi, (14, 8), (48, 24)),
       rot=(-0.2, 0, 0))
    se("seat_base", (0.21, 0.06, 0.19), (0, 0.56, 0.24), "seat", g, hi, (0.45, 0.5), L(hi, (12, 6), (40, 16)))
    side = []
    for s in (-1, 1):
        side += [(s * 0.44, 0.42, -0.2), (s * 0.47, 0.47, 0.03), (s * 0.44, 0.43, 0.22)]
    puffs("side_puff", side, 0.15, "cloud", g, hi)
    puffs("engine_puff", [(0, 0.66, 0.74), (-0.18, 0.62, 0.80), (0.18, 0.62, 0.80), (0, 0.76, 0.86)],
          [0.19, 0.15, 0.15, 0.13], "cloud", g, hi)
    puffs("bumper_puff", [(-0.32, 0.30, -1.10), (-0.11, 0.33, -1.16), (0.11, 0.33, -1.16), (0.32, 0.30, -1.10)],
          0.13, "cloud", g, hi)
    # Twin chrome boosters with coral rings.
    for s in (-1, 1):
        prof = [(0.0, 0.10), (0.30, 0.15), (0.42, 0.16), (0.42, 0.12), (0.30, 0.10)]
        ob = lathe(f"booster{s}_{tag}", prof, (0, 0, 0), "chrome", g, hi, L(hi, 14, 40), True, True)
        ob.data.transform(Matrix.Translation(Vector((s * 0.26, 0.62, 0.82))) @ Matrix.Rotation(-math.pi / 2, 4, "Y"))
        torus(f"booster_ring{s}_{tag}", 0.16, 0.025, Matrix.Translation(Vector((s * 0.26, 0.62, 1.20)))
              @ Matrix.Rotation(math.pi / 2, 4, "X"), "body_coral", g, hi, L(hi, (14, 5), (40, 12)))
        ellipsoid(f"booster_core{s}_{tag}", (0.11, 0.11, 0.015), (s * 0.26, 0.62, 1.235), "graphite", g, hi,
                  L(hi, (10, 4), (28, 8)))
    ts, tn = L(hi, 3, 10), L(hi, 8, 20)
    for s in (-1, 1):
        tube(f"bar{s}_{tag}", [(s * 0.36, 0.22, -0.40), (s * 0.60, 0.26, -0.34), (s * 0.64, 0.28, -0.04),
                               (s * 0.60, 0.26, 0.22), (s * 0.36, 0.22, 0.28)], 0.03, "brown", g, hi, ts, tn)
        tube(f"arm_front{s}_{tag}", [(s * 0.22, 0.24, -0.70), (s * 0.48, 0.30, -0.72)], 0.025, "graphite", g, hi, 1,
             L(hi, 6, 12))
    tube(f"hoop_{tag}", [(-0.25, 0.42, 0.56), (-0.25, 0.92, 0.58), (-0.12, 1.04, 0.59), (0.12, 1.04, 0.59),
                         (0.25, 0.92, 0.58), (0.25, 0.42, 0.56)], 0.03, "brown", g, hi, ts, tn)
    tube(f"axle_rear_{tag}", [(-0.5, 0.34, 0.68), (0.5, 0.34, 0.68)], 0.03, "graphite", g, hi, 1, L(hi, 6, 12))
    tube(f"column_{tag}", [(0, 0.58, -0.55), (0, 0.85, -0.32)], 0.024, "graphite", g, hi, 1, L(hi, 6, 12))
    K.build_legs(g, hi)
    if hi:
        for s in (-1, 1):
            for k, (z, y) in enumerate(((-0.75, 0.45), (-0.50, 0.50))):
                m = facing((s * 0.29, y, z), (s, 0.4, 0))
                for j, (dx, dy, rr) in enumerate(((-0.035, 0, 0.03), (0.0, 0.015, 0.038), (0.04, 0, 0.03))):
                    decal(f"cloudmark{s}{k}{j}", circle_outline(rr, rr * 0.85, 14),
                          m @ Matrix.Translation(Vector((dx, dy, 0))), "stripe_white", g, tub, 0.003, 1)


def build_torso(hi):
    tag = "H" if hi else "L"
    g = "Torso"
    superellipsoid(f"torso_{tag}", (0.17, 0.16, 0.14), (0, 0.83, 0.21), "wool", g, hi, (0.8, 0.85),
                   L(hi, (12, 8), (40, 20)))
    puffs("wool", [(0, 0.80, 0.08), (-0.12, 0.86, 0.10), (0.12, 0.86, 0.10), (0, 0.92, 0.10), (-0.13, 0.74, 0.12),
                   (0.13, 0.74, 0.12), (0, 0.84, 0.34)], 0.09, "wool", g, hi)
    capsule(f"neck_{tag}", (0, 0.96, 0.18), (0, 1.08, 0.18), 0.05, "face", g, hi, L(hi, (8, 4), (20, 8)))


def build_head(hi):
    tag = "H" if hi else "L"
    g = "Head"
    hc = Vector((0, 1.19, 0.16))
    head = superellipsoid(f"head_{tag}", (0.25, 0.26, 0.25), hc, "face", g, hi, (1.0, 1.0), L(hi, (20, 14), (96, 64)))
    muzzle = ellipsoid(f"muzzle_{tag}", (0.12, 0.08, 0.07), (0, 1.10, -0.06), "face", g, hi, L(hi, (12, 8), (48, 32)))
    ellipsoid(f"nose_{tag}", (0.03, 0.02, 0.02), (0, 1.14, -0.125), "nose", g, hi, L(hi, (8, 6), (24, 14)))
    puffs("cap", [(0, 1.42, 0.14), (-0.14, 1.38, 0.12), (0.14, 1.38, 0.12), (0, 1.38, -0.02), (-0.10, 1.36, -0.04),
                  (0.10, 1.36, -0.04), (0, 1.38, 0.30), (-0.16, 1.32, 0.28), (0.16, 1.32, 0.28)],
          [0.12, 0.1, 0.1, 0.09, 0.075, 0.075, 0.1, 0.09, 0.09], "wool", g, hi)
    for s in (-1, 1):
        bm_ = facing((s * 0.17, 1.44, 0.0), (s * 0.5, 0.6, -0.6))
        for t in (-1, 1):
            superellipsoid(f"bow{s}{t}_{tag}", (0.04, 0.028, 0.016), (0, 0, 0), "pink", g, hi, (0.7, 0.8),
                           L(hi, (8, 5), (20, 10)), matrix=bm_ @ Matrix.Translation(Vector((t * 0.035, 0, 0))))
    if hi:
        mouth_m = facing((0, 1.07, -0.125), (0, -0.2, -1))
        smile = [(math.cos(a) * 0.04, math.sin(a) * 0.03 - 0.004)
                 for a in [math.pi + math.pi * k / 16 for k in range(17)]]
        smile = [(-0.04, 0.004)] + smile[1:-1] + [(0.04, 0.004), (0.0, 0.008)]
        decal("mouth", smile, mouth_m, "mouth", g, muzzle, 0.003, 2)
        decal("tongue", circle_outline(0.018, 0.011, 14), mouth_m @ Matrix.Translation(Vector((0, -0.02, 0))),
              "tongue", g, muzzle, 0.0045, 1)
        for s in (-1, 1):
            decal(f"blush{s}", circle_outline(0.03, 0.02, 16), facing((s * 0.16, 1.11, -0.06), (s * 0.6, -0.1, -0.8)),
                  "blush", g, head, 0.003, 2)


def build_ear(group, s, hi):
    tag = "H" if hi else "L"
    piv = Vector((s * EAR_PIVOT[0], EAR_PIVOT[1], EAR_PIVOT[2]))
    m = Matrix.Translation(piv + Vector((s * 0.06, -0.03, 0.0))) @ Matrix.Rotation(s * 1.1, 4, "Z")
    ear = superellipsoid(f"{group}_ear_{tag}", (0.045, 0.09, 0.028), (0, 0, 0), "face", group, hi, (0.85, 0.9),
                         L(hi, (10, 8), (32, 20)), matrix=m)
    if hi:
        decal(f"{group}_inner", circle_outline(0.025, 0.06, 16), m @ facing((0, 0, -0.028), (0, 0, -1)), "pink",
              group, ear, 0.003, 2)


def build_arm(group, s, hi):
    tag = "H" if hi else "L"
    sh = Vector((s * K.SHOULDER[0], K.SHOULDER[1], K.SHOULDER[2]))
    ellipsoid(f"{group}_shoulder_{tag}", (0.08, 0.075, 0.08), sh + Vector((0, 0, -0.03)), "wool", group, hi,
              L(hi, (12, 8), (32, 20)))
    capsule(f"{group}_arm_{tag}", sh + Vector((0, 0, -0.06)), sh + Vector((0, 0, -0.34)), 0.038, "face", group, hi,
            L(hi, (10, 6), (24, 12)), r_end=0.035)
    ellipsoid(f"{group}_hoof_{tag}", (0.052, 0.048, 0.058), sh + Vector((0, 0, -0.39)), "hoof", group, hi,
              L(hi, (10, 6), (28, 16)))
    capsule(f"{group}_thumb_{tag}", sh + Vector((-s * 0.03, 0.025, -0.37)), sh + Vector((-s * 0.045, 0.04, -0.41)),
            0.018, "hoof", group, hi, L(hi, (6, 4), (16, 8)))


def build(hi):
    build_body(hi)
    for s, name in ((-1, "WheelFL"), (1, "WheelFR")):
        K.build_wheel(name, (s * FRONT_WHEEL[0], FRONT_WHEEL[1], FRONT_WHEEL[2]), FRONT_WHEEL[1], FRONT_W, s, hi,
                      text="CLOUD")
    for s in (-1, 1):
        K.build_wheel("WheelRear", (s * REAR_WHEEL[0], REAR_WHEEL[1], REAR_WHEEL[2]), REAR_WHEEL[1], REAR_W, s, hi,
                      text="CLOUD")
    K.build_steering(hi)
    build_torso(hi)
    build_head(hi)
    K.build_eyes(hi)
    build_ear("EarL", -1, hi)
    build_ear("EarR", 1, hi)
    build_arm("ArmL", -1, hi)
    build_arm("ArmR", 1, hi)


K.setup("cloud_booster", "assets/models/cepis", PALETTE, PAINT_MAT, GROUPS, UV_SCALE, FAR_RATIO)
K.run(build)
