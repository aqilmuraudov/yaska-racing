"""Məstan (cat) + Velvet Slide kart for Yaska Racing (0.14.x Blender karts).

  blender --background --factory-startup --python tools/blender/mestan_velvet.py -- [--preview] [--no-bake]
Low wide teal sports body with flowing coral side sweeps, cat-ear fins on the
roll hoop, navy splitter and wing, coral exhausts; an orange tabby cat with
forehead stripes, a coral bow, a gold bell collar and a curling striped tail.
Rig numbers match KartModel._velvet (rf 0.28, rr 0.34) and AnimalDriver (cat
ears: head + (+-0.18, 0.31, 0.02), tail: torso + (0, 0.1, 0.2)).
Derived from bicok_amber.py (same sleek chassis layout).
"""

import math
import os
import sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from kart_common import *  # noqa: F401,F403
import kart_common as K
from mathutils import Vector, Matrix, Euler, Quaternion

PALETTE = {
    "body_orange": ("16A39A", 0.24, 0.5),
    "body_pink": ("FF7A6B", 0.3, 0.3),     # steering hub
    "navy": ("20304A", 0.3, 0.4),
    "coral": ("FF7A6B", 0.28, 0.4),
    "cream": ("FBE6C8", 0.4, 0.0),
    "stripe_white": ("FFFFFF", 0.35, 0.0),
    "gold": ("F5B82E", 0.22, 1.0),
    "chrome": ("DDE1E6", 0.12, 1.0),
    "graphite": ("2E2B36", 0.6, 0.2),
    "engine": ("8A8F99", 0.35, 0.8),
    "tire": ("2B2830", 0.85, 0.0),
    "tread": ("4A4452", 0.8, 0.0),
    "tire_text": ("E4E0EA", 0.75, 0.0),
    "rim_purple": ("FF7A6B", 0.3, 0.5),
    "seat": ("20304A", 0.55, 0.0),
    "fur": ("E99A4A", 0.75, 0.0),
    "fur_light": ("FBE6C8", 0.75, 0.0),
    "fur_dark": ("B8632A", 0.75, 0.0),
    "nose": ("FF8FA3", 0.3, 0.0),
    "suit": ("E99A4A", 0.75, 0.0),
    "mouth": ("6E1A22", 0.5, 0.0),
    "tongue": ("FF6F8E", 0.45, 0.0),
    "teeth": ("FFFFFF", 0.3, 0.0),
    "brow": ("B8632A", 0.6, 0.0),
    "eye_white": ("FFFFFF", 0.32, 0.0),
    "iris": ("3FA36A", 0.35, 0.0),
    "iris_ring": ("1E5A34", 0.35, 0.0),
    "pupil": ("0C0806", 0.32, 0.0),
    "lash": ("1E1410", 0.5, 0.0),
    "leggings": ("16A39A", 0.65, 0.0),
    "sock": ("FFFFFF", 0.7, 0.0),
    "shoe": ("FF7A6B", 0.45, 0.0),
    "sole": ("F4F1EE", 0.6, 0.0),
    "star_yellow": ("FFFFFF", 0.35, 0.0),
}
PAINT_MAT = "body_orange"
GROUPS = ["Body", "WheelFL", "WheelFR", "WheelRear", "SteeringWheel", "Torso", "Head",
          "Eyes", "EarL", "EarR", "Tail", "ArmL", "ArmR"]
UV_SCALE = {"Body": 1.0, "WheelFL": 1.0, "WheelFR": 1.0, "WheelRear": 1.0, "SteeringWheel": 1.0,
            "Torso": 1.3, "Head": 2.2, "Eyes": 2.6, "EarL": 1.3, "EarR": 1.3, "Tail": 1.2,
            "ArmL": 1.2, "ArmR": 1.2}
FAR_RATIO = {"Body": 0.13, "WheelFL": 0.07, "WheelFR": 0.07, "WheelRear": 0.07, "SteeringWheel": 0.2,
             "Torso": 0.2, "Head": 0.10, "Eyes": 0.2, "EarL": 0.35, "EarR": 0.35, "Tail": 0.25,
             "ArmL": 0.25, "ArmR": 0.25}

FRONT_WHEEL = (0.62, 0.28, -0.72)
REAR_WHEEL = (0.66, 0.34, 0.68)
FRONT_W, REAR_W = 0.26, 0.34
EAR_PIVOT = (0.18, 1.37, 0.20)


def build_body(hi):
    tag = "H" if hi else "L"
    g = "Body"
    se = lambda n, *a, **k: superellipsoid(f"{n}_{tag}", *a, **k)
    floor = se("floor", (0.40, 0.05, 0.98), (0, 0.17, 0.0), "graphite", g, hi, (0.3, 0.35), L(hi, (10, 4), (48, 16)))
    if not hi:
        drop_faces(floor, lambda c, n: n.y < -0.7)

    def nose_def(p, n):
        k = max(0.0, -n.z)
        return Vector((p.x * (1 - 0.35 * k * k), p.y * (1 - 0.4 * k) - 0.04 * k, p.z))
    nose = se("nose", (0.28, 0.14, 0.50), (0, 0.33, -0.66), "body_orange", g, hi, (0.5, 0.55),
              L(hi, (16, 10), (64, 32)), deform=nose_def)
    pods = []
    for s in (-1, 1):
        def pod_def(p, n, s=s):
            k = max(0.0, -n.z)
            return Vector((p.x * (1 - 0.3 * k), p.y * (1 - 0.2 * k), p.z))
        pods.append(se(f"pod{'LR'[s > 0]}", (0.11, 0.13, 0.40), (s * 0.38, 0.33, 0.02), "coral", g, hi,
                       (0.6, 0.6), L(hi, (14, 8), (56, 28)), deform=pod_def))
        # Cat-ear fins on the roll hoop.
        ear = [(-0.09, 0.0), (0.09, 0.0), (0.02, 0.19)]
        fm = Matrix.Translation(Vector((s * 0.2, 1.0, 0.58))) @ Matrix.Rotation(-s * 0.25, 4, "Z")
        puffy(f"catfin{s}_{tag}", ear, 0.04, 0.02, fm, "coral", g, hi)
    deck = se("deck", (0.30, 0.13, 0.22), (0, 0.37, 0.62), "body_orange", g, hi, (0.5, 0.5), L(hi, (14, 8), (56, 24)))
    se("engine", (0.21, 0.12, 0.16), (0, 0.51, 0.80), "engine", g, hi, (0.4, 0.45), L(hi, (12, 8), (40, 20)))
    se("seat_back", (0.23, 0.26, 0.06), (0, 0.78, 0.45), "seat", g, hi, (0.45, 0.5), L(hi, (14, 8), (48, 24)),
       rot=(-0.2, 0, 0))
    se("seat_base", (0.21, 0.06, 0.19), (0, 0.52, 0.24), "seat", g, hi, (0.45, 0.5), L(hi, (12, 6), (40, 16)))
    # Front splitter, side skirts, rear diffuser (no tube cage: a sleek racer).
    se("splitter", (0.42, 0.022, 0.13), (0, 0.17, -1.12), "navy", g, hi, (0.25, 0.4), L(hi, (12, 4), (40, 10)))
    for s in (-1, 1):
        se(f"skirt{s}", (0.05, 0.035, 0.36), (s * 0.52, 0.2, -0.02), "navy", g, hi, (0.3, 0.4), L(hi, (8, 4), (24, 10)))
    se("diffuser", (0.36, 0.05, 0.08), (0, 0.22, 1.02), "navy", g, hi, (0.3, 0.4), L(hi, (10, 4), (32, 10)))
    tube(f"hoop_{tag}", [(-0.25, 0.42, 0.56), (-0.25, 0.92, 0.58), (-0.12, 1.04, 0.59), (0.12, 1.04, 0.59),
                         (0.25, 0.92, 0.58), (0.25, 0.42, 0.56)], 0.03, "navy", g, hi, L(hi, 3, 10), L(hi, 8, 20))
    # Swept wing with pointed tips on two posts.
    wing = [(-0.64, 0.10), (-0.5, -0.02), (0.5, -0.02), (0.64, 0.10), (0.45, 0.16), (-0.45, 0.16)]
    wm = Matrix.Translation(Vector((0, 0.90, 1.0))) @ Matrix.Rotation(-math.pi / 2 + 0.12, 4, "X")
    puffy(f"wing_{tag}", wing, 0.035, 0.015, wm, "navy", g, hi)
    for s in (-1, 1):
        tube(f"wing_post{s}_{tag}", [(s * 0.32, 0.55, 0.92), (s * 0.32, 0.90, 0.98)], 0.024, "graphite", g, hi, 1,
             L(hi, 6, 12))
        tube(f"exhaust{s}_{tag}", [(s * 0.24, 0.46, 0.90), (s * 0.24, 0.48, 1.14)], 0.05, "coral", g, hi, 1,
             L(hi, 10, 24), False)
        ob = lathe(f"exhtip{s}_{tag}", [(0.0, 0.051), (0.03, 0.06), (0.05, 0.06), (0.055, 0.04)], (0, 0, 0),
                   "chrome", g, hi, L(hi, 10, 32), False, True)
        ob.data.transform(Matrix.Translation(Vector((s * 0.24, 0.48, 1.14))) @ Matrix.Rotation(-math.pi / 2, 4, "Y"))
        tube(f"arm_front{s}_{tag}", [(s * 0.22, 0.22, -0.70), (s * 0.48, 0.27, -0.72)], 0.025, "graphite", g, hi, 1,
             L(hi, 6, 12))
    tube(f"axle_rear_{tag}", [(-0.5, 0.35, 0.68), (0.5, 0.35, 0.68)], 0.03, "graphite", g, hi, 1, L(hi, 6, 12))
    tube(f"column_{tag}", [(0, 0.45, -0.62), (0, 0.85, -0.32)], 0.024, "graphite", g, hi, 1, L(hi, 6, 12))
    K.build_legs(g, hi)
    if hi:
        for z0, z1, tgt, y in ((-1.08, -0.28, nose, 0.50), (0.44, 0.82, deck, 0.51)):
            n = 6
            for i in range(n):
                z = z0 + (z1 - z0) * (i + 0.5) / n
                w = 0.05 if tgt is deck else 0.03 + 0.035 * (i + 0.5) / n
                decal(f"spine{tgt.name}{i}", [(-w, -(z1 - z0) / n * 0.55), (w, -(z1 - z0) / n * 0.55),
                                              (w, (z1 - z0) / n * 0.55), (-w, (z1 - z0) / n * 0.55)],
                      facing((0, y, z), (0, 1, 0), up=(0, 0, -1)), "coral", g, tgt, 0.003, 3)
        for s, pod in zip((-1, 1), pods):
            m = facing((s * 0.48, 0.36, -0.05), (s, 0, 0))
            for k, dz in enumerate((-0.16, 0.12)):
                pm = m @ Matrix.Translation(Vector((dz, 0.0, 0)))
                decal(f"paw{s}{k}", circle_outline(0.035, 0.03, 16), pm, "stripe_white", g, pod, 0.0035, 1)
                for t in range(3):
                    decal(f"toe{s}{k}{t}", circle_outline(0.013, 0.015, 10),
                          pm @ Matrix.Translation(Vector(((t - 1) * 0.03, 0.045 - 0.01 * abs(t - 1), 0))),
                          "stripe_white", g, pod, 0.0035, 0)
        for k in range(5):
            bm = bmesh.new()
            bmesh.ops.create_cube(bm, size=1.0)
            K.xform(bm, K.trs((0, 0.63, 0.70 + k * 0.045), (0, 0, 0), (0.30, 0.02, 0.012)))
            K.finish(bm, f"fin{k}", "chrome", g, True, smooth=False)


def build_torso(hi):
    tag = "H" if hi else "L"
    g = "Torso"

    def torso_def(p, n):
        k = (n.y + 1) / 2
        return Vector((p.x * (1.0 - 0.18 * k), p.y, p.z * (1.0 - 0.1 * k)))
    body = superellipsoid(f"torso_{tag}", (0.18, 0.17, 0.15), (0, 0.83, 0.21), "suit", g, hi, (0.7, 0.8),
                          L(hi, (14, 8), (48, 24)), deform=torso_def)
    torus(f"collar_{tag}", 0.068, 0.024, Matrix.Translation(Vector((0, 0.985, 0.19))), "coral", g, hi,
          L(hi, (12, 5), (32, 12)))
    ellipsoid(f"bell_{tag}", (0.026, 0.026, 0.026), (0, 0.945, 0.115), "gold", g, hi, L(hi, (8, 6), (24, 16)))
    capsule(f"neck_{tag}", (0, 0.96, 0.18), (0, 1.08, 0.18), 0.05, "fur", g, hi, L(hi, (8, 4), (20, 8)))
    if hi:
        decal("chest", circle_outline(0.1, 0.12, 24), facing((0, 0.82, 0.065), (0, 0.05, -1)), "fur_light", g,
              body, 0.003, 3)
        for k in range(3):
            decal(f"backstripe{k}", [(-0.12, -0.012), (0.12, -0.012), (0.12, 0.012), (-0.12, 0.012)],
                  facing((0, 0.76 + k * 0.07, 0.36), (0, 0, 1)), "fur_dark", g, body, 0.003, 3)


def build_head(hi):
    tag = "H" if hi else "L"
    g = "Head"
    hc = Vector((0, 1.20, 0.17))

    def head_def(p, n):
        return Vector((p.x * (1.0 + 0.08 * max(0.0, -n.y)), p.y, p.z))
    head = superellipsoid(f"head_{tag}", (0.29, 0.25, 0.27), hc, "fur", g, hi, (1.0, 1.0), L(hi, (28, 20), (96, 64)),
                          deform=head_def)
    for s in (-1, 1):
        ellipsoid(f"puff{s}_{tag}", (0.06, 0.05, 0.05), (s * 0.045, 1.10, -0.09), "fur_light", g, hi,
                  L(hi, (8, 6), (28, 18)))
    puffy(f"nose_{tag}", [(-0.022, 0.012), (0.022, 0.012), (0.0, -0.012)], 0.02, 0.008,
          facing((0, 1.135, -0.13), (0, 0.2, -1)), "nose", g, hi)
    # Coral bow on the right side.
    bm_ = facing((0.17, 1.40, 0.02), (0.5, 0.55, -0.6))
    for s in (-1, 1):
        superellipsoid(f"bow{s}_{tag}", (0.05, 0.035, 0.02), (0, 0, 0), "coral", g, hi, (0.7, 0.8),
                       L(hi, (8, 5), (24, 12)), matrix=bm_ @ Matrix.Translation(Vector((s * 0.045, 0, 0))))
    ellipsoid(f"bow_knot_{tag}", (0.02, 0.02, 0.02), (0, 0, 0), "coral", g, hi, L(hi, (6, 4), (16, 10)), matrix=bm_)
    if hi:
        mouth_m = facing((0, 1.075, -0.135), (0, -0.2, -1))
        smile = [(math.cos(a) * 0.04, math.sin(a) * 0.03 - 0.004)
                 for a in [math.pi + math.pi * k / 16 for k in range(17)]]
        smile = [(-0.04, 0.004)] + smile[1:-1] + [(0.04, 0.004), (0.0, 0.008)]
        decal("mouth", smile, mouth_m, "mouth", g, head, 0.006, 2)
        decal("tongue", circle_outline(0.018, 0.011, 14), mouth_m @ Matrix.Translation(Vector((0, -0.02, 0))),
              "tongue", g, head, 0.0075, 1)
        for k in range(3):
            decal(f"stripe{k}", [(-0.012, -0.05), (0.012, -0.05), (0.006, 0.05), (-0.006, 0.05)],
                  facing(((k - 1) * 0.07, 1.40, -0.02 + abs(k - 1) * 0.02), (0, 0.8, -0.6))
                  @ Matrix.Rotation((k - 1) * 0.3, 4, "Z"), "fur_dark", g, head, 0.003, 2)
        for s in (-1, 1):
            for k in range(2):
                decal(f"cheekstripe{s}{k}", [(-0.03, -0.006), (0.03, -0.006), (0.03, 0.006), (-0.03, 0.006)],
                      facing((s * 0.26, 1.16 - k * 0.04, 0.06), (s, 0, -0.2)), "fur_dark", g, head, 0.003, 2)
            for k in range(3):
                decal(f"whisk{s}{k}", circle_outline(0.005, 0.005, 8),
                      facing((s * (0.055 + 0.014 * k), 1.105 - 0.012 * (k % 2), -0.13), (s * 0.4, 0, -1)),
                      "fur_dark", g, head, 0.0075, 0)


def build_ear(group, s, hi):
    tag = "H" if hi else "L"
    piv = Vector((s * EAR_PIVOT[0], EAR_PIVOT[1], EAR_PIVOT[2]))
    m = Matrix.Translation(piv + Vector((0, 0.06, 0.0))) @ Matrix.Rotation(-s * 0.25, 4, "Z")

    def ear_def(p, n):
        k = max(0.0, n.y)
        return Vector((p.x * (1 - 0.9 * k), p.y, p.z * (1 - 0.6 * k)))
    ear = superellipsoid(f"{group}_ear_{tag}", (0.09, 0.1, 0.04), (0, 0, 0), "fur", group, hi, (0.8, 0.9),
                         L(hi, (12, 8), (40, 24)), deform=ear_def, matrix=m)
    if hi:
        decal(f"{group}_inner", [(-0.05, -0.06), (0.05, -0.06), (0.0, 0.07)], m @ facing((0, -0.01, -0.04), (0, 0, -1)),
              "nose", group, ear, 0.003, 2)


def build_tail(hi):
    tag = "H" if hi else "L"
    g = "Tail"
    pts = [(0, 0.90, 0.54), (0.02, 1.06, 0.62), (0.08, 1.20, 0.62), (0.16, 1.24, 0.56)]
    tube(f"tail_{tag}", pts, 0.035, "fur", g, hi, L(hi, 3, 8), L(hi, 8, 16))
    ellipsoid(f"tail_tip_{tag}", (0.04, 0.04, 0.04), pts[-1], "fur_dark", g, hi, L(hi, (8, 6), (20, 12)))
    if hi:
        path = catmull(pts, 8)
        for i in range(4, len(path) - 2, 6):
            d = (path[i + 1] - path[i]).normalized()
            torus(f"tail_ring{i}", 0.036, 0.008, Matrix.Translation(path[i]) @
                  Vector((0, 1, 0)).rotation_difference(d).to_matrix().to_4x4(), "fur_dark", g, True, (16, 4))


def build_arm(group, s, hi):
    tag = "H" if hi else "L"
    sh = Vector((s * K.SHOULDER[0], K.SHOULDER[1], K.SHOULDER[2]))
    ellipsoid(f"{group}_shoulder_{tag}", (0.068, 0.066, 0.072), sh + Vector((0, 0, -0.03)), "fur", group, hi,
              L(hi, (12, 8), (32, 20)))
    capsule(f"{group}_arm_{tag}", sh + Vector((0, 0, -0.06)), sh + Vector((0, 0, -0.34)), 0.041, "fur", group, hi,
            L(hi, (10, 6), (24, 12)), r_end=0.036)
    ellipsoid(f"{group}_paw_{tag}", (0.054, 0.05, 0.06), sh + Vector((0, 0, -0.39)), "fur_light", group, hi,
              L(hi, (10, 6), (28, 16)))
    capsule(f"{group}_thumb_{tag}", sh + Vector((-s * 0.03, 0.025, -0.37)), sh + Vector((-s * 0.045, 0.04, -0.41)),
            0.019, "fur_light", group, hi, L(hi, (6, 4), (16, 8)))


def build(hi):
    build_body(hi)
    for s, name in ((-1, "WheelFL"), (1, "WheelFR")):
        K.build_wheel(name, (s * FRONT_WHEEL[0], FRONT_WHEEL[1], FRONT_WHEEL[2]), FRONT_WHEEL[1], FRONT_W, s, hi,
                      text="VELVET")
    for s in (-1, 1):
        K.build_wheel("WheelRear", (s * REAR_WHEEL[0], REAR_WHEEL[1], REAR_WHEEL[2]), REAR_WHEEL[1], REAR_W, s, hi,
                      text="VELVET")
    K.build_steering(hi)
    build_torso(hi)
    build_head(hi)
    K.build_eyes(hi)
    build_ear("EarL", -1, hi)
    build_ear("EarR", 1, hi)
    build_tail(hi)
    build_arm("ArmL", -1, hi)
    build_arm("ArmR", 1, hi)


K.setup("velvet_slide", "assets/models/mestan", PALETTE, PAINT_MAT, GROUPS, UV_SCALE, FAR_RATIO)
K.run(build)
