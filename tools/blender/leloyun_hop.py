"""Ləlöyün (rabbit) + Hop Rocket kart for Yaska Racing (0.14.x Blender karts).

  blender --background --factory-startup --python tools/blender/leloyun_hop.py -- [--preview] [--no-bake]
Short tall lavender tub with a yellow belt, a big carrot nose cone with a leafy
tuft, carrot exhausts and a round yellow wing; a white-lavender rabbit with long
pink-lined ears, goggles on the forehead and a pink vest. Rig numbers match
KartModel._hop (rf 0.28, rr 0.32) and AnimalDriver (rabbit ears: head +
(+-0.1, 0.34, 0.04)). The puff tail hides behind the seat, so it has no mesh.
"""

import math
import os
import sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from kart_common import *  # noqa: F401,F403
import kart_common as K
from mathutils import Vector, Matrix, Euler, Quaternion

PALETTE = {
    "body_lav": ("B9A2F0", 0.26, 0.45),
    "body_pink": ("FFD23F", 0.3, 0.3),     # steering hub
    "yellow": ("FFD23F", 0.3, 0.3),
    "carrot": ("FF8A3D", 0.45, 0.0),
    "carrot_dark": ("D9652A", 0.5, 0.0),
    "leaf": ("5CC46A", 0.45, 0.0),
    "stripe_white": ("FFFFFF", 0.35, 0.0),
    "heart": ("FF9FC0", 0.4, 0.0),
    "gold": ("F5B82E", 0.22, 1.0),
    "chrome": ("DDE1E6", 0.12, 1.0),
    "graphite": ("2E2B36", 0.6, 0.2),
    "engine": ("8E909A", 0.35, 0.9),
    "tire": ("2B2830", 0.85, 0.0),
    "tread": ("4A4452", 0.8, 0.0),
    "tire_text": ("E4E0EA", 0.75, 0.0),
    "rim_purple": ("FFD23F", 0.3, 0.5),
    "seat": ("8F7AB8", 0.55, 0.0),
    "fur": ("F1ECFB", 0.75, 0.0),
    "fur_dark": ("8F7AB8", 0.75, 0.0),
    "inner_ear": ("FF9FC0", 0.6, 0.0),
    "nose": ("FF7FA0", 0.3, 0.0),
    "vest": ("FF9FC0", 0.6, 0.0),
    "goggle": ("7FD4F5", 0.08, 0.0),
    "mouth": ("6E1A22", 0.5, 0.0),
    "teeth": ("FFFFFF", 0.3, 0.0),
    "blush": ("FFB3C8", 0.6, 0.0),
    "brow": ("8F7AB8", 0.6, 0.0),
    "eye_white": ("FFFFFF", 0.32, 0.0),
    "iris": ("7A4FB8", 0.35, 0.0),
    "iris_ring": ("3A2460", 0.35, 0.0),
    "pupil": ("0C0806", 0.32, 0.0),
    "lash": ("1E1410", 0.5, 0.0),
    "leggings": ("8F7AB8", 0.65, 0.0),
    "sock": ("FFFFFF", 0.7, 0.0),
    "shoe": ("FFD23F", 0.45, 0.0),
    "sole": ("F4F1EE", 0.6, 0.0),
    "star_yellow": ("FF8A3D", 0.35, 0.0),
}
PAINT_MAT = "body_lav"
GROUPS = ["Body", "WheelFL", "WheelFR", "WheelRear", "SteeringWheel", "Torso", "Head",
          "Eyes", "EarL", "EarR", "ArmL", "ArmR"]
UV_SCALE = {"Body": 1.0, "WheelFL": 1.0, "WheelFR": 1.0, "WheelRear": 1.0, "SteeringWheel": 1.0,
            "Torso": 1.3, "Head": 2.2, "Eyes": 2.6, "EarL": 1.3, "EarR": 1.3, "ArmL": 1.2, "ArmR": 1.2}
FAR_RATIO = {"Body": 0.13, "WheelFL": 0.07, "WheelFR": 0.07, "WheelRear": 0.07, "SteeringWheel": 0.2,
             "Torso": 0.2, "Head": 0.10, "Eyes": 0.2, "EarL": 0.3, "EarR": 0.3, "ArmL": 0.25, "ArmR": 0.25}

FRONT_WHEEL = (0.62, 0.28, -0.72)
REAR_WHEEL = (0.66, 0.32, 0.68)
FRONT_W, REAR_W = 0.26, 0.34
EAR_PIVOT = (0.10, 1.40, 0.22)


def carrot(name, base, direction, length, r, g, hi, leaves=3):
    """Orange cone with dark rings and a leafy tuft at the base (high + low)."""
    tag = "H" if hi else "L"
    n = L(hi, 6, 20)
    prof = [(length * k / n, r * (1 - (k / n) ** 1.3) + 0.012 * (k < n)) for k in range(n + 1)]
    ob = lathe(f"{name}_{tag}", prof, (0, 0, 0), "carrot", g, hi, L(hi, 12, 40), True, False)
    m = Matrix.Translation(Vector(base)) @ Vector((1, 0, 0)).rotation_difference(Vector(direction).normalized()).to_matrix().to_4x4()
    ob.data.transform(m)
    for k in range(leaves):
        a = (k - (leaves - 1) / 2) * 0.55
        superellipsoid(f"{name}_leaf{k}_{tag}", (0.035 * r / 0.09, 0.12 * r / 0.09, 0.012), (0, 0, 0), "leaf", g, hi,
                       (0.7, 0.7), L(hi, (6, 4), (16, 10)),
                       matrix=m @ Matrix.Rotation(-math.pi / 2, 4, "Z") @ Matrix.Translation(Vector((0, -0.09 * r / 0.09, 0)))
                       @ Matrix.Rotation(a, 4, "Z") @ Matrix.Translation(Vector((0, -0.1 * r / 0.09, 0))))
    if hi:
        for k in range(1, 5):
            x = length * k / 5
            rr = r * (1 - (k / 5) ** 1.3) + 0.012
            torus(f"{name}_ring{k}", rr, 0.004, m @ Matrix.Translation(Vector((x, 0, 0))) @ Matrix.Rotation(math.pi / 2, 4, "Z"),
                  "carrot_dark", g, True, (24, 4))
    return ob


def build_body(hi):
    tag = "H" if hi else "L"
    g = "Body"
    se = lambda n, *a, **k: superellipsoid(f"{n}_{tag}", *a, **k)
    floor = se("floor", (0.40, 0.05, 0.98), (0, 0.18, 0.0), "graphite", g, hi, (0.3, 0.35), L(hi, (10, 4), (48, 16)))
    if not hi:
        drop_faces(floor, lambda c, n: n.y < -0.7)
    tub = se("tub", (0.40, 0.20, 0.50), (0, 0.41, -0.02), "body_lav", g, hi, (0.75, 0.78), L(hi, (18, 12), (72, 40)))
    se("belt", (0.415, 0.05, 0.515), (0, 0.30, -0.02), "yellow", g, hi, (0.5, 0.78), L(hi, (18, 4), (72, 12)))
    se("deck", (0.28, 0.12, 0.2), (0, 0.38, 0.62), "body_lav", g, hi, (0.6, 0.6), L(hi, (14, 8), (56, 24)))
    se("engine", (0.2, 0.11, 0.15), (0, 0.50, 0.80), "engine", g, hi, (0.4, 0.45), L(hi, (12, 8), (40, 20)))
    se("seat_back", (0.23, 0.26, 0.06), (0, 0.80, 0.45), "seat", g, hi, (0.45, 0.5), L(hi, (14, 8), (48, 24)),
       rot=(-0.2, 0, 0))
    se("seat_base", (0.21, 0.06, 0.19), (0, 0.56, 0.24), "seat", g, hi, (0.45, 0.5), L(hi, (12, 6), (40, 16)))
    # Big carrot nose and carrot exhausts.
    carrot("nose_carrot", (0, 0.42, -0.50), (0, -0.05, -1), 0.72, 0.24, g, hi, 3)
    for s in (-1, 1):
        carrot(f"exh{s}", (s * 0.2, 0.62, 0.86), (0, 0.05, 1), 0.30, 0.085, g, hi, 2)
    # Yellow rounded wing, yellow side bars and rear bumper.
    se("wing", (0.45, 0.04, 0.15), (0, 0.88, 0.95), "yellow", g, hi, (0.5, 0.6), L(hi, (14, 4), (48, 12)), rot=(0.1, 0, 0))
    ts, tn = L(hi, 3, 10), L(hi, 8, 20)
    for s in (-1, 1):
        tube(f"wing_post{s}_{tag}", [(s * 0.34, 0.55, 0.92), (s * 0.34, 0.86, 0.95)], 0.026, "carrot", g, hi, 1,
             L(hi, 6, 12))
        tube(f"bar{s}_{tag}", [(s * 0.38, 0.22, -0.38), (s * 0.62, 0.27, -0.32), (s * 0.66, 0.29, -0.04),
                               (s * 0.62, 0.27, 0.22), (s * 0.38, 0.22, 0.28)], 0.032, "yellow", g, hi, ts, tn)
        tube(f"arm_front{s}_{tag}", [(s * 0.22, 0.23, -0.70), (s * 0.48, 0.28, -0.72)], 0.025, "graphite", g, hi, 1,
             L(hi, 6, 12))
    tube(f"bumper_rear_{tag}", [(-0.32, 0.25, 0.95), (-0.46, 0.29, 1.10), (-0.30, 0.32, 1.18),
                                (0.30, 0.32, 1.18), (0.46, 0.29, 1.10), (0.32, 0.25, 0.95)], 0.032, "yellow", g, hi, ts, tn)
    tube(f"axle_rear_{tag}", [(-0.5, 0.32, 0.68), (0.5, 0.32, 0.68)], 0.03, "graphite", g, hi, 1, L(hi, 6, 12))
    tube(f"column_{tag}", [(0, 0.62, -0.50), (0, 0.85, -0.32)], 0.024, "graphite", g, hi, 1, L(hi, 6, 12))
    K.build_legs(g, hi)
    if hi:
        for s in (-1, 1):
            m = facing((s * 0.40, 0.44, -0.02), (s, 0, 0))
            for k, dz in enumerate((-0.18, 0.0, 0.18)):
                decal(f"heart{s}{k}", heart_outline(0.09, 24), m @ Matrix.Translation(Vector((dz * -s, 0.02, 0))),
                      "heart", g, tub, 0.003, 2)
        for k in range(5):
            bm = bmesh.new()
            bmesh.ops.create_cube(bm, size=1.0)
            K.xform(bm, K.trs((0, 0.61, 0.70 + k * 0.045), (0, 0, 0), (0.28, 0.02, 0.012)))
            K.finish(bm, f"fin{k}", "chrome", g, True, smooth=False)


def build_torso(hi):
    tag = "H" if hi else "L"
    g = "Torso"

    def torso_def(p, n):
        k = (n.y + 1) / 2
        return Vector((p.x * (1.0 - 0.15 * k), p.y, p.z * (1.0 - 0.1 * k)))
    body = superellipsoid(f"torso_{tag}", (0.18, 0.17, 0.15), (0, 0.83, 0.21), "fur", g, hi, (0.8, 0.85),
                          L(hi, (14, 8), (48, 24)), deform=torso_def)
    superellipsoid(f"vest_{tag}", (0.19, 0.11, 0.155), (0, 0.78, 0.21), "vest", g, hi, (0.6, 0.85),
                   L(hi, (14, 6), (48, 16)), deform=torso_def)
    capsule(f"neck_{tag}", (0, 0.96, 0.18), (0, 1.08, 0.18), 0.05, "fur", g, hi, L(hi, (8, 4), (20, 8)))
    if hi:
        decal("vest_heart", heart_outline(0.06, 24), facing((0, 0.80, 0.055), (0, 0.05, -1)), "stripe_white", g,
              body, 0.012, 2)


def build_head(hi):
    tag = "H" if hi else "L"
    g = "Head"
    hc = Vector((0, 1.20, 0.17))

    def head_def(p, n):
        return Vector((p.x * (1.0 + 0.07 * max(0.0, -n.y)), p.y, p.z))
    head = superellipsoid(f"head_{tag}", (0.27, 0.26, 0.26), hc, "fur", g, hi, (1.0, 1.0), L(hi, (28, 20), (96, 64)),
                          deform=head_def)
    for s in (-1, 1):
        ellipsoid(f"cheek{s}_{tag}", (0.065, 0.055, 0.055), (s * 0.05, 1.10, -0.085), "fur", g, hi,
                  L(hi, (8, 6), (28, 18)))
    ellipsoid(f"nose_{tag}", (0.028, 0.02, 0.02), (0, 1.135, -0.135), "nose", g, hi, L(hi, (8, 6), (24, 14)))
    for s in (-1, 1):
        superellipsoid(f"tooth{s}_{tag}", (0.016, 0.022, 0.008), (s * 0.017, 1.055, -0.128), "teeth", g, hi,
                       (0.5, 0.6), L(hi, (6, 4), (16, 10)), rot=(0.25, 0, 0))
    # Goggles pushed up on the forehead.
    torus(f"goggle_band_{tag}", 0.222, 0.014, Matrix.Translation(Vector((0, 1.35, 0.17))) @ Matrix.Rotation(0.18, 4, "X"),
          "yellow", g, hi, L(hi, (24, 4), (64, 8)))
    for s in (-1, 1):
        gm = facing((s * 0.075, 1.385, -0.07), (s * 0.2, 0.45, -0.85))
        lathe(f"goggle_rim{s}_{tag}", [(-0.02, 0.05), (0.02, 0.05), (0.02, 0.042)], (0, 0, 0), "chrome", g, hi,
              L(hi, 10, 32)).data.transform(gm @ Matrix.Rotation(-math.pi / 2, 4, "Y"))
        ellipsoid(f"goggle_lens{s}_{tag}", (0.044, 0.044, 0.012), (0, 0, 0), "goggle", g, hi, L(hi, (10, 6), (32, 16)),
                  matrix=gm @ Matrix.Translation(Vector((0, 0, 0.012))))
    if hi:
        mouth_m = facing((0, 1.075, -0.13), (0, -0.25, -1))
        smile = [(math.cos(a) * 0.035, math.sin(a) * 0.012 - 0.002) for a in [math.pi + math.pi * k / 12 for k in range(13)]]
        smile += [(math.cos(a) * 0.035, math.sin(a) * 0.006 - 0.004) for a in [2 * math.pi - math.pi * k / 12 for k in range(1, 12)]]
        decal("mouth", smile, mouth_m, "mouth", g, head, 0.003, 1)
        for s in (-1, 1):
            decal(f"blush{s}", circle_outline(0.032, 0.02, 16), facing((s * 0.17, 1.12, -0.06), (s * 0.6, -0.1, -0.8)),
                  "blush", g, head, 0.003, 2)
            for k in range(3):
                decal(f"whisk{s}{k}", circle_outline(0.005, 0.005, 8),
                      facing((s * (0.06 + 0.012 * k), 1.105 - 0.012 * (k % 2), -0.14), (s * 0.4, 0, -1)),
                      "fur_dark", g, head, 0.003, 0)


def build_ear(group, s, hi):
    tag = "H" if hi else "L"
    piv = Vector((s * EAR_PIVOT[0], EAR_PIVOT[1], EAR_PIVOT[2]))
    m = Matrix.Translation(piv) @ Euler((-0.15, 0, -s * 0.18)).to_matrix().to_4x4() @ Matrix.Translation(Vector((0, 0.2, 0)))

    def ear_def(p, n):
        k = max(0.0, n.y)
        return Vector((p.x * (1 - 0.3 * k), p.y, p.z))
    ear = superellipsoid(f"{group}_ear_{tag}", (0.065, 0.22, 0.035), (0, 0, 0), "fur", group, hi, (0.85, 0.9),
                         L(hi, (12, 10), (40, 32)), deform=ear_def, matrix=m)
    if hi:
        inner = [(math.cos(a) * 0.035, math.sin(a) * 0.17) for a in [2 * math.pi * k / 24 for k in range(24)]]
        decal(f"{group}_inner", inner, m @ facing((0, -0.01, -0.035), (0, 0, -1)), "inner_ear", group, ear, 0.003, 3)


def build_arm(group, s, hi):
    tag = "H" if hi else "L"
    sh = Vector((s * K.SHOULDER[0], K.SHOULDER[1], K.SHOULDER[2]))
    ellipsoid(f"{group}_shoulder_{tag}", (0.066, 0.064, 0.07), sh + Vector((0, 0, -0.03)), "vest", group, hi,
              L(hi, (12, 8), (32, 20)))
    capsule(f"{group}_arm_{tag}", sh + Vector((0, 0, -0.06)), sh + Vector((0, 0, -0.34)), 0.04, "fur", group, hi,
            L(hi, (10, 6), (24, 12)), r_end=0.036)
    ellipsoid(f"{group}_paw_{tag}", (0.054, 0.05, 0.06), sh + Vector((0, 0, -0.39)), "fur", group, hi,
              L(hi, (10, 6), (28, 16)))
    capsule(f"{group}_thumb_{tag}", sh + Vector((-s * 0.03, 0.025, -0.37)), sh + Vector((-s * 0.045, 0.04, -0.41)),
            0.019, "fur", group, hi, L(hi, (6, 4), (16, 8)))


def build(hi):
    build_body(hi)
    for s, name in ((-1, "WheelFL"), (1, "WheelFR")):
        K.build_wheel(name, (s * FRONT_WHEEL[0], FRONT_WHEEL[1], FRONT_WHEEL[2]), FRONT_WHEEL[1], FRONT_W, s, hi,
                      text="HOP")
    for s in (-1, 1):
        K.build_wheel("WheelRear", (s * REAR_WHEEL[0], REAR_WHEEL[1], REAR_WHEEL[2]), REAR_WHEEL[1], REAR_W, s, hi,
                      text="HOP")
    K.build_steering(hi)
    build_torso(hi)
    build_head(hi)
    K.build_eyes(hi)
    build_ear("EarL", -1, hi)
    build_ear("EarR", 1, hi)
    build_arm("ArmL", -1, hi)
    build_arm("ArmR", 1, hi)


K.setup("hop_rocket", "assets/models/leloyun", PALETTE, PAINT_MAT, GROUPS, UV_SCALE, FAR_RATIO)
K.run(build)
