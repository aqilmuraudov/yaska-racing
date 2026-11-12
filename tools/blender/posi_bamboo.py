"""Posi (panda) + Bamboo Sprint kart for Yaska Racing (0.14.x Blender karts).

  blender --background --factory-startup --python tools/blender/posi_bamboo.py -- [--preview] [--no-bake]
White / mint rounded tub, segmented bamboo cage and bumpers, a leaf wing,
charcoal nose; a panda with round dark ears and eye patches, mint scarf and a
bamboo sprig. Rig numbers match KartModel._bamboo (rf 0.31, rr 0.36) and
AnimalDriver (panda ears: head + (+-0.22, 0.34, 0.02)). The panda tail hides
behind the seat, so it has no mesh.
"""

import math
import os
import sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from kart_common import *  # noqa: F401,F403
import kart_common as K
from mathutils import Vector, Matrix, Euler, Quaternion

PALETTE = {
    "body_white": ("F4F6F2", 0.28, 0.35),
    "body_pink": ("5FD3A8", 0.3, 0.3),      # steering hub
    "mint": ("5FD3A8", 0.3, 0.3),
    "charcoal": ("2B2D33", 0.4, 0.3),
    "bamboo": ("8FC96A", 0.45, 0.0),
    "bamboo_ring": ("5F9C4C", 0.5, 0.0),
    "leaf": ("4FBF7A", 0.4, 0.0),
    "leaf_vein": ("C8F0B0", 0.5, 0.0),
    "stripe_white": ("FFFFFF", 0.35, 0.0),
    "gold": ("F5B82E", 0.22, 1.0),
    "chrome": ("DDE1E6", 0.12, 1.0),
    "graphite": ("2E2B36", 0.6, 0.2),
    "engine": ("8E909A", 0.35, 0.9),
    "tire": ("2B2830", 0.85, 0.0),
    "tread": ("4A4452", 0.8, 0.0),
    "tire_text": ("E4E0EA", 0.75, 0.0),
    "rim_purple": ("5FD3A8", 0.3, 0.5),
    "seat": ("2B2D33", 0.55, 0.0),
    "fur": ("F7F3EA", 0.75, 0.0),
    "fur_dark": ("2A2A30", 0.75, 0.0),
    "nose": ("1E1E22", 0.15, 0.0),
    "scarf": ("6FD6A8", 0.6, 0.0),
    "mouth": ("6E1A22", 0.5, 0.0),
    "tongue": ("FF6F8E", 0.45, 0.0),
    "teeth": ("FFFFFF", 0.3, 0.0),
    "blush": ("FFB3C1", 0.6, 0.0),
    "eye_white": ("FFFFFF", 0.32, 0.0),
    "iris": ("3A2A1C", 0.35, 0.0),
    "iris_ring": ("1A120A", 0.35, 0.0),
    "pupil": ("0C0806", 0.32, 0.0),
    "lash": ("141014", 0.5, 0.0),
    "leggings": ("2A2A30", 0.75, 0.0),
    "sock": ("FFFFFF", 0.7, 0.0),
    "shoe": ("5FD3A8", 0.45, 0.0),
    "sole": ("F4F1EE", 0.6, 0.0),
    "star_yellow": ("FFFFFF", 0.35, 0.0),
}
PAINT_MAT = "body_white"
GROUPS = ["Body", "WheelFL", "WheelFR", "WheelRear", "SteeringWheel", "Torso", "Head",
          "Eyes", "EarL", "EarR", "ArmL", "ArmR"]
UV_SCALE = {"Body": 1.0, "WheelFL": 1.0, "WheelFR": 1.0, "WheelRear": 1.0, "SteeringWheel": 1.0,
            "Torso": 1.3, "Head": 2.2, "Eyes": 2.6, "EarL": 1.2, "EarR": 1.2, "ArmL": 1.2, "ArmR": 1.2}
FAR_RATIO = {"Body": 0.13, "WheelFL": 0.07, "WheelFR": 0.07, "WheelRear": 0.07, "SteeringWheel": 0.2,
             "Torso": 0.2, "Head": 0.10, "Eyes": 0.2, "EarL": 0.35, "EarR": 0.35, "ArmL": 0.25, "ArmR": 0.25}

FRONT_WHEEL = (0.62, 0.31, -0.72)
REAR_WHEEL = (0.66, 0.36, 0.68)
FRONT_W, REAR_W = 0.26, 0.34
EAR_PIVOT = (0.22, 1.40, 0.20)


def bamboo(name, points, r, g, hi, rings=True):
    """Bamboo pole: tube plus nodes (rings) every ~16 cm (high + low)."""
    tag = "H" if hi else "L"
    tube(f"{name}_{tag}", points, r, "bamboo", g, hi, L(hi, 3, 10), L(hi, 8, 20))
    if not rings:
        return
    path = catmull(points, 10)
    acc = 0.0
    for i in range(1, len(path)):
        seg = (path[i] - path[i - 1]).length
        acc += seg
        if acc >= 0.16:
            acc = 0.0
            d = (path[i] - path[i - 1]).normalized()
            m = Matrix.Translation(path[i]) @ Vector((0, 1, 0)).rotation_difference(d).to_matrix().to_4x4()
            torus(f"{name}_ring{i}_{tag}", r, r * 0.28, m, "bamboo_ring", g, hi, L(hi, (8, 3), (20, 8)))


def build_body(hi):
    tag = "H" if hi else "L"
    g = "Body"
    se = lambda n, *a, **k: superellipsoid(f"{n}_{tag}", *a, **k)
    floor = se("floor", (0.40, 0.05, 0.98), (0, 0.19, 0.0), "graphite", g, hi, (0.3, 0.35), L(hi, (10, 4), (48, 16)))
    if not hi:
        drop_faces(floor, lambda c, n: n.y < -0.7)

    def nose_def(p, n):
        k = max(0.0, -n.z)
        return Vector((p.x * (1 - 0.25 * k), p.y * (1 - 0.25 * k) - 0.04 * k, p.z))
    nose = se("nose", (0.26, 0.17, 0.42), (0, 0.37, -0.72), "body_white", g, hi, (0.65, 0.7),
              L(hi, (16, 10), (64, 32)), deform=nose_def)
    se("nose_tip", (0.17, 0.08, 0.12), (0, 0.39, -1.04), "charcoal", g, hi, (0.6, 0.7), L(hi, (10, 6), (32, 16)))
    pods = [se(f"pod{'LR'[s > 0]}", (0.10, 0.15, 0.34), (s * 0.38, 0.36, -0.02), "mint", g, hi, (0.6, 0.65),
               L(hi, (14, 8), (56, 28))) for s in (-1, 1)]
    se("deck", (0.30, 0.13, 0.22), (0, 0.38, 0.62), "body_white", g, hi, (0.6, 0.6), L(hi, (14, 8), (56, 24)))
    se("engine", (0.21, 0.12, 0.16), (0, 0.52, 0.80), "engine", g, hi, (0.4, 0.45), L(hi, (12, 8), (40, 20)))
    se("seat_back", (0.23, 0.26, 0.06), (0, 0.78, 0.45), "seat", g, hi, (0.45, 0.5), L(hi, (14, 8), (48, 24)),
       rot=(-0.2, 0, 0))
    se("seat_base", (0.21, 0.06, 0.19), (0, 0.52, 0.24), "seat", g, hi, (0.45, 0.5), L(hi, (12, 6), (40, 16)))
    r = 0.04
    bamboo("bumper_front", [(-0.28, 0.24, -0.98), (-0.44, 0.28, -1.12), (-0.28, 0.31, -1.22),
                            (0.28, 0.31, -1.22), (0.44, 0.28, -1.12), (0.28, 0.24, -0.98)], r, g, hi)
    for s in (-1, 1):
        bamboo(f"bar{'LR'[s > 0]}", [(s * 0.42, 0.22, -0.38), (s * 0.62, 0.28, -0.32), (s * 0.66, 0.30, -0.04),
                                     (s * 0.62, 0.28, 0.22), (s * 0.42, 0.22, 0.28)], r, g, hi)
    bamboo("bumper_rear", [(-0.32, 0.26, 0.95), (-0.46, 0.30, 1.12), (-0.30, 0.33, 1.20),
                           (0.30, 0.33, 1.20), (0.46, 0.30, 1.12), (0.32, 0.26, 0.95)], r, g, hi)
    bamboo("hoop", [(-0.25, 0.42, 0.56), (-0.25, 0.92, 0.58), (-0.12, 1.04, 0.59), (0.12, 1.04, 0.59),
                    (0.25, 0.92, 0.58), (0.25, 0.42, 0.56)], 0.034, g, hi)
    # Leaf wing on two bamboo posts.
    leaf = [(math.cos(a) * 0.52, math.sin(a) * 0.17 * (1 - 0.35 * math.cos(a)))
            for a in [2 * math.pi * k / L(hi, 16, 48) for k in range(L(hi, 16, 48))]]
    wing_m = Matrix.Translation(Vector((0, 0.90, 0.98))) @ Matrix.Rotation(-math.pi / 2 + 0.15, 4, "X")
    wing = puffy(f"wing_{tag}", leaf, 0.03, 0.03, wing_m, "leaf", g, hi)
    for s in (-1, 1):
        bamboo(f"wing_post{s}", [(s * 0.3, 0.55, 0.94), (s * 0.3, 0.88, 0.98)], 0.024, g, hi, rings=False)
    # Twin straight exhausts.
    for s in (-1, 1):
        tube(f"exhaust{s}_{tag}", [(s * 0.2, 0.58, 0.90), (s * 0.2, 0.60, 1.10)], 0.055, "chrome", g, hi, 1,
             L(hi, 10, 24), False)
        ob = lathe(f"exhtip{s}_{tag}", [(0.0, 0.056), (0.03, 0.066), (0.05, 0.066), (0.055, 0.045)], (0, 0, 0),
                   "chrome", g, hi, L(hi, 10, 32), False, True)
        ob.data.transform(Matrix.Translation(Vector((s * 0.2, 0.60, 1.10))) @ Matrix.Rotation(-math.pi / 2, 4, "Y"))
    tube(f"axle_rear_{tag}", [(-0.5, 0.36, 0.68), (0.5, 0.36, 0.68)], 0.03, "graphite", g, hi, 1, L(hi, 6, 12))
    for s in (-1, 1):
        tube(f"arm_front{s}_{tag}", [(s * 0.22, 0.24, -0.70), (s * 0.48, 0.31, -0.72)], 0.025, "graphite", g, hi, 1,
             L(hi, 6, 12))
    tube(f"column_{tag}", [(0, 0.47, -0.62), (0, 0.85, -0.32)], 0.024, "graphite", g, hi, 1, L(hi, 6, 12))
    K.build_legs(g, hi)
    if hi:
        wm = wing_m @ Matrix.Translation(Vector((0, 0, 0.03)))
        decal("vein", [(-0.45, -0.006), (0.45, -0.006), (0.45, 0.006), (-0.45, 0.006)], wm, "leaf_vein", g, wing,
              0.003, 3)
        for k in range(-3, 4):
            if k:
                decal(f"vein{k}", [(-0.004, 0.0), (0.004, 0.0), (0.004, 0.11), (-0.004, 0.11)],
                      wm @ Matrix.Translation(Vector((k * 0.11, 0, 0))) @ Matrix.Rotation(0.5 * (1 if k > 0 else -1), 4, "Z"),
                      "leaf_vein", g, wing, 0.003, 2)
        for s, pod in zip((-1, 1), pods):
            m = facing((s * 0.48, 0.40, -0.02), (s, 0, 0))
            text_decal(f"podname{s}", "POSI", 0.15, m @ Matrix.Translation(Vector((0, 0.02, 0))), "stripe_white",
                       g, pod, 0.0035)
        for x in (-0.11, 0.11):
            for z in (-0.86, -0.62):
                lm = facing((x, 0.53, z), (0, 1, 0), up=(0, 0, -1)) @ Matrix.Rotation(0.6 if x > 0 else -0.6, 4, "Z")
                decal(f"noseleaf{x}{z}", [(math.cos(a) * 0.06, math.sin(a) * 0.022) for a in
                                          [2 * math.pi * k / 16 for k in range(16)]], lm, "leaf", g, nose, 0.003, 2)
        for k in range(5):
            bm = bmesh.new()
            bmesh.ops.create_cube(bm, size=1.0)
            K.xform(bm, K.trs((0, 0.64, 0.70 + k * 0.045), (0, 0, 0), (0.30, 0.02, 0.012)))
            K.finish(bm, f"fin{k}", "chrome", g, True, smooth=False)


def build_torso(hi):
    tag = "H" if hi else "L"
    g = "Torso"

    def torso_def(p, n):
        k = (n.y + 1) / 2
        return Vector((p.x * (1.0 - 0.12 * k), p.y, p.z * (1.0 - 0.08 * k)))
    superellipsoid(f"torso_{tag}", (0.20, 0.17, 0.16), (0, 0.83, 0.21), "fur", g, hi, (0.8, 0.85),
                   L(hi, (14, 8), (48, 24)), deform=torso_def)
    superellipsoid(f"band_{tag}", (0.215, 0.06, 0.17), (0, 0.93, 0.21), "fur_dark", g, hi, (0.7, 0.85),
                   L(hi, (14, 6), (48, 16)))
    torus(f"scarf_{tag}", 0.075, 0.032, Matrix.Translation(Vector((0, 0.99, 0.19))), "scarf", g, hi,
          L(hi, (12, 5), (32, 12)))
    capsule(f"scarf_end_{tag}", (0.04, 0.97, 0.11), (0.07, 0.86, 0.09), 0.026, "scarf", g, hi, L(hi, (6, 4), (16, 8)))
    capsule(f"neck_{tag}", (0, 0.96, 0.18), (0, 1.08, 0.18), 0.05, "fur", g, hi, L(hi, (8, 4), (20, 8)))


def build_head(hi):
    tag = "H" if hi else "L"
    g = "Head"
    hc = Vector((0, 1.20, 0.17))
    head = superellipsoid(f"head_{tag}", (0.30, 0.27, 0.28), hc, "fur", g, hi, (1.0, 1.0), L(hi, (28, 20), (96, 64)))
    muzzle = superellipsoid(f"muzzle_{tag}", (0.12, 0.08, 0.08), (0, 1.11, -0.07), "fur", g, hi, (0.9, 0.9),
                            L(hi, (12, 8), (48, 32)))
    ellipsoid(f"nose_{tag}", (0.04, 0.026, 0.026), (0, 1.155, -0.142), "nose", g, hi, L(hi, (10, 6), (32, 20)))
    # Bamboo sprig behind the right ear (as the procedural Posi).
    tube(f"sprig_{tag}", [(0.20, 1.40, 0.28), (0.28, 1.52, 0.30)], 0.014, "bamboo", g, hi, 1, L(hi, 5, 10))
    for i in range(2):
        superellipsoid(f"sprig_leaf{i}_{tag}", (0.025, 0.008, 0.07), (0.27 + i * 0.03, 1.53, 0.31), "leaf", g, hi,
                       (0.9, 0.9), L(hi, (6, 4), (16, 10)), rot=(0.4, i * 1.2, 0.2))
    if hi:
        for s in (-1, 1):
            patch = [(math.cos(a) * 0.085, math.sin(a) * 0.11) for a in [2 * math.pi * k / 24 for k in range(24)]]
            decal(f"patch{s}", patch, facing((s * 0.095, 1.21, -0.105), (s * 0.3, 0.05, -1))
                  @ Matrix.Rotation(-s * 0.45, 4, "Z"), "fur_dark", g, head, 0.002, 3)
            decal(f"blush{s}", circle_outline(0.03, 0.02, 16), facing((s * 0.19, 1.10, -0.06), (s * 0.6, -0.1, -0.8)),
                  "blush", g, head, 0.003, 2)
        mouth_m = facing((0, 1.07, -0.135), (0, -0.2, -1))
        smile = [(math.cos(a) * 0.045, math.sin(a) * 0.034 - 0.004)
                 for a in [math.pi + math.pi * k / 16 for k in range(17)]]
        smile = [(-0.045, 0.004)] + smile[1:-1] + [(0.045, 0.004), (0.0, 0.009)]
        decal("mouth", smile, mouth_m, "mouth", g, muzzle, 0.003, 2)
        decal("tongue", circle_outline(0.022, 0.013, 14), mouth_m @ Matrix.Translation(Vector((0, -0.022, 0))),
              "tongue", g, muzzle, 0.0045, 1)
        decal("teeth", [(-0.03, 0.0), (0.03, 0.0), (0.025, -0.008), (-0.025, -0.008)],
              mouth_m @ Matrix.Translation(Vector((0, 0.002, 0))), "teeth", g, muzzle, 0.0045, 1)


def build_ear(group, s, hi):
    tag = "H" if hi else "L"
    piv = Vector((s * EAR_PIVOT[0], EAR_PIVOT[1], EAR_PIVOT[2]))
    superellipsoid(f"{group}_ear_{tag}", (0.085, 0.08, 0.045), piv + Vector((s * 0.01, 0.02, 0.0)), "fur_dark", group,
                   hi, (0.9, 0.9), L(hi, (12, 8), (40, 24)), rot=(0, 0, -s * 0.3))


def build_arm(group, s, hi):
    tag = "H" if hi else "L"
    sh = Vector((s * K.SHOULDER[0], K.SHOULDER[1], K.SHOULDER[2]))
    ellipsoid(f"{group}_shoulder_{tag}", (0.07, 0.07, 0.075), sh + Vector((0, 0, -0.03)), "fur_dark", group, hi,
              L(hi, (12, 8), (32, 20)))
    capsule(f"{group}_arm_{tag}", sh + Vector((0, 0, -0.06)), sh + Vector((0, 0, -0.34)), 0.045, "fur_dark", group,
            hi, L(hi, (10, 6), (24, 12)), r_end=0.042)
    ellipsoid(f"{group}_paw_{tag}", (0.058, 0.052, 0.062), sh + Vector((0, 0, -0.39)), "fur_dark", group, hi,
              L(hi, (10, 6), (28, 16)))
    capsule(f"{group}_thumb_{tag}", sh + Vector((-s * 0.03, 0.025, -0.37)), sh + Vector((-s * 0.045, 0.04, -0.41)),
            0.02, "fur_dark", group, hi, L(hi, (6, 4), (16, 8)))


def build(hi):
    build_body(hi)
    for s, name in ((-1, "WheelFL"), (1, "WheelFR")):
        K.build_wheel(name, (s * FRONT_WHEEL[0], FRONT_WHEEL[1], FRONT_WHEEL[2]), FRONT_WHEEL[1], FRONT_W, s, hi,
                      text="POSI")
    for s in (-1, 1):
        K.build_wheel("WheelRear", (s * REAR_WHEEL[0], REAR_WHEEL[1], REAR_WHEEL[2]), REAR_WHEEL[1], REAR_W, s, hi,
                      text="POSI")
    K.build_steering(hi)
    build_torso(hi)
    build_head(hi)
    K.build_eyes(hi)
    build_ear("EarL", -1, hi)
    build_ear("EarR", 1, hi)
    build_arm("ArmL", -1, hi)
    build_arm("ArmR", 1, hi)


K.setup("bamboo_sprint", "assets/models/posi", PALETTE, PAINT_MAT, GROUPS, UV_SCALE, FAR_RATIO)
K.run(build)
