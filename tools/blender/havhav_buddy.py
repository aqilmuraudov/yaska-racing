"""HavHav (dog) + Buddy Rally kart for Yaska Racing (0.14.x Blender karts).

  blender --background --factory-startup --python tools/blender/havhav_buddy.py -- [--preview] [--no-bake]
Same pipeline as yaska_star.py (kart_common.run). Blue rally kart with yellow
twin stripes, navy roll cage, a four-lamp bull bar, mud flaps with bones and a
yellow wing; a brown dog with floppy dark ears, light muzzle, red collar with a
gold bone tag and red sneakers. Rig numbers match KartModel._buddy and
AnimalDriver (dog): ears pivot head + (+-0.27, 0.26, 0.03), tail pivot torso + (0, 0.1, 0.2).
"""

import math
import os
import sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from kart_common import *  # noqa: F401,F403  (helpers + shared parts)
import kart_common as K
from mathutils import Vector, Matrix, Euler, Quaternion

# Material names are roles shared with kart_common's parts (e.g. "rim_purple"
# is the inner rim / hub colour, "body_pink" the steering hub).
PALETTE = {
    "body_blue": ("2F74C9", 0.24, 0.5),
    "body_pink": ("2F74C9", 0.24, 0.5),
    "stripe": ("FFC93C", 0.3, 0.2),
    "navy": ("1B2A4A", 0.35, 0.4),
    "stripe_white": ("FFFFFF", 0.35, 0.0),
    "gold": ("F5B82E", 0.22, 1.0),
    "chrome": ("DDE1E6", 0.12, 1.0),
    "graphite": ("2E2B36", 0.6, 0.2),
    "engine": ("8E909A", 0.35, 0.9),
    "tire": ("2B2830", 0.85, 0.0),
    "tread": ("4A4452", 0.8, 0.0),
    "tire_text": ("E4E0EA", 0.75, 0.0),
    "rim_purple": ("FFC93C", 0.3, 0.6),
    "seat": ("D7263D", 0.55, 0.0),
    "lamp": ("FFF3C0", 0.15, 0.0),
    "flap": ("D7263D", 0.7, 0.0),
    "fur": ("A86A3C", 0.75, 0.0),
    "fur_light": ("F4DFBF", 0.75, 0.0),
    "fur_dark": ("5A3420", 0.75, 0.0),
    "nose": ("2B1D1A", 0.15, 0.0),
    "collar": ("E0344B", 0.5, 0.0),
    "mouth": ("6E1A22", 0.5, 0.0),
    "tongue": ("FF6F8E", 0.45, 0.0),
    "teeth": ("FFFFFF", 0.3, 0.0),
    "brow": ("4A2A18", 0.6, 0.0),
    "eye_white": ("FFFFFF", 0.32, 0.0),
    "iris": ("5A3A1C", 0.35, 0.0),
    "iris_ring": ("2A1A0C", 0.35, 0.0),
    "pupil": ("140C08", 0.32, 0.0),
    "lash": ("1E1410", 0.5, 0.0),
    "leggings": ("A86A3C", 0.75, 0.0),
    "sock": ("FFFFFF", 0.7, 0.0),
    "shoe": ("D7263D", 0.45, 0.0),
    "sole": ("F4F1EE", 0.6, 0.0),
    "star_yellow": ("FFC93C", 0.35, 0.0),
}
PAINT_MAT = "body_blue"
GROUPS = ["Body", "WheelFL", "WheelFR", "WheelRear", "SteeringWheel", "Torso", "Head",
          "Eyes", "EarL", "EarR", "Tail", "ArmL", "ArmR"]
UV_SCALE = {"Body": 1.0, "WheelFL": 1.0, "WheelFR": 1.0, "WheelRear": 1.0, "SteeringWheel": 1.0,
            "Torso": 1.3, "Head": 2.2, "Eyes": 2.6, "EarL": 1.3, "EarR": 1.3, "Tail": 1.2,
            "ArmL": 1.2, "ArmR": 1.2}
FAR_RATIO = {"Body": 0.13, "WheelFL": 0.07, "WheelFR": 0.07, "WheelRear": 0.07, "SteeringWheel": 0.2,
             "Torso": 0.2, "Head": 0.10, "Eyes": 0.2, "EarL": 0.3, "EarR": 0.3, "Tail": 0.3,
             "ArmL": 0.25, "ArmR": 0.25}

FRONT_WHEEL = (0.62, 0.31, -0.72)   # KartModel._buddy: rf 0.31, wf 0.26
REAR_WHEEL = (0.66, 0.36, 0.68)     # rr 0.36, wr 0.34
FRONT_W, REAR_W = 0.26, 0.34
EAR_PIVOT = (0.27, 1.32, 0.21)
TAIL_PIVOT = (0.0, 0.76, 0.40)
TUBE = 0.034


def build_body(hi):
    tag = "H" if hi else "L"
    g = "Body"
    se = lambda n, *a, **k: superellipsoid(f"{n}_{tag}", *a, **k)
    floor = se("floor", (0.40, 0.05, 0.98), (0, 0.19, 0.0), "graphite", g, hi, (0.3, 0.35), L(hi, (10, 4), (48, 16)))
    if not hi:
        drop_faces(floor, lambda c, n: n.y < -0.7)

    def nose_def(p, n):
        k = max(0.0, -n.z)
        return Vector((p.x * (1 - 0.12 * k), p.y * (1 - 0.18 * k) - 0.03 * k, p.z))
    nose = se("nose", (0.26, 0.16, 0.40), (0, 0.38, -0.74), "body_blue", g, hi, (0.35, 0.4),
              L(hi, (16, 10), (64, 32)), deform=nose_def)
    pods = [se(f"pod{'LR'[s > 0]}", (0.10, 0.15, 0.34), (s * 0.38, 0.37, -0.02), "body_blue", g, hi, (0.35, 0.4),
               L(hi, (14, 8), (56, 28))) for s in (-1, 1)]
    deck = se("deck", (0.30, 0.13, 0.22), (0, 0.38, 0.62), "body_blue", g, hi, (0.4, 0.45), L(hi, (14, 8), (56, 24)))
    se("engine", (0.21, 0.12, 0.16), (0, 0.52, 0.80), "engine", g, hi, (0.4, 0.45), L(hi, (12, 8), (40, 20)))
    se("seat_back", (0.23, 0.26, 0.06), (0, 0.78, 0.45), "seat", g, hi, (0.45, 0.5), L(hi, (14, 8), (48, 24)),
       rot=(-0.2, 0, 0))
    se("seat_base", (0.21, 0.06, 0.19), (0, 0.52, 0.24), "seat", g, hi, (0.45, 0.5), L(hi, (12, 6), (40, 16)))
    # Navy roll cage.
    ts, tn = L(hi, 3, 10), L(hi, 8, 20)
    tube(f"bumper_front_{tag}", [(-0.28, 0.24, -0.95), (-0.44, 0.27, -1.10), (-0.30, 0.30, -1.20),
                                 (0.30, 0.30, -1.20), (0.44, 0.27, -1.10), (0.28, 0.24, -0.95)], TUBE, "navy", g, hi, ts, tn)
    for s in (-1, 1):
        tube(f"bar{'LR'[s > 0]}_{tag}", [(s * 0.40, 0.22, -0.38), (s * 0.62, 0.28, -0.32), (s * 0.66, 0.30, -0.04),
                                         (s * 0.62, 0.28, 0.22), (s * 0.40, 0.22, 0.28)], TUBE, "navy", g, hi, ts, tn)
    tube(f"bumper_rear_{tag}", [(-0.32, 0.26, 0.95), (-0.46, 0.30, 1.12), (-0.30, 0.33, 1.20),
                                (0.30, 0.33, 1.20), (0.46, 0.30, 1.12), (0.32, 0.26, 0.95)], TUBE, "navy", g, hi, ts, tn)
    tube(f"hoop_{tag}", [(-0.25, 0.42, 0.56), (-0.25, 0.92, 0.58), (-0.12, 1.04, 0.59), (0.12, 1.04, 0.59),
                         (0.25, 0.92, 0.58), (0.25, 0.42, 0.56)], 0.03, "navy", g, hi, ts, tn)
    # Bull bar with four rally lamps (facing forward).
    tube(f"bullbar_{tag}", [(-0.36, 0.58, -1.08), (0.36, 0.58, -1.08)], 0.028, "navy", g, hi, 1, tn)
    for s in (-1, 1):
        tube(f"bullpost{s}_{tag}", [(s * 0.30, 0.30, -1.18), (s * 0.30, 0.58, -1.08)], 0.024, "navy", g, hi, 1, tn)
    for k in range(4):
        x = -0.27 + k * 0.18
        cup = lathe(f"lamp_cup{k}_{tag}", [(-0.03, 0.0), (-0.03, 0.062), (0.03, 0.07)], (0, 0, 0), "chrome", g, hi,
                    L(hi, 10, 32), outward=lambda p: Vector((-1.0, p.y, p.z)))
        cup.data.transform(Matrix.Translation(Vector((x, 0.64, -1.10))) @ Matrix.Rotation(math.pi / 2, 4, "Y"))
        ellipsoid(f"lamp{k}_{tag}", (0.058, 0.058, 0.018), (x, 0.64, -1.135), "lamp", g, hi, L(hi, (10, 6), (32, 16)))
    # Yellow rally wing on two posts, single right-side exhaust.
    se("wing", (0.48, 0.025, 0.15), (0, 0.88, 0.96), "stripe", g, hi, (0.3, 0.4), L(hi, (12, 4), (40, 12)),
       rot=(-0.12, 0, 0))
    for s in (-1, 1):
        tube(f"wing_post{s}_{tag}", [(s * 0.32, 0.55, 0.92), (s * 0.32, 0.87, 0.95)], 0.022, "navy", g, hi, 1, L(hi, 6, 12))
        se(f"wing_end{s}", (0.012, 0.09, 0.17), (s * 0.48, 0.90, 0.96), "navy", g, hi, (0.3, 0.4), L(hi, (6, 4), (20, 10)))
    pts = [(0.16, 0.46, 0.86), (0.22, 0.48, 1.0), (0.27, 0.50, 1.08)]
    tube(f"exhaust_{tag}", pts, 0.045, "chrome", g, hi, L(hi, 3, 10), L(hi, 10, 24), False)
    tip, d = Vector(pts[-1]), (Vector(pts[-1]) - Vector(pts[-2])).normalized()
    ob = lathe(f"exhtip_{tag}", [(0.0, 0.046), (0.05, 0.052), (0.11, 0.064), (0.12, 0.052), (0.06, 0.038)],
               (0, 0, 0), "chrome", g, hi, L(hi, 10, 32), False, True)
    ob.data.transform(Matrix.Translation(tip) @ Vector((1, 0, 0)).rotation_difference(d).to_matrix().to_4x4())
    # Mud flaps behind the rear tyres.
    flaps = []
    for s in (-1, 1):
        flaps.append(se(f"flap{s}", (0.13, 0.12, 0.012), (s * 0.66, 0.21, 1.08), "flap", g, hi, (0.2, 0.3),
                        L(hi, (6, 4), (24, 12))))
        tube(f"flap_bar{s}_{tag}", [(s * 0.46, 0.33, 1.06), (s * 0.66, 0.33, 1.07)], 0.018, "navy", g, hi, 1, L(hi, 6, 12))
    tube(f"axle_rear_{tag}", [(-0.5, 0.36, 0.68), (0.5, 0.36, 0.68)], 0.03, "graphite", g, hi, 1, L(hi, 6, 12))
    for s in (-1, 1):
        tube(f"arm_front{s}_{tag}", [(s * 0.22, 0.24, -0.70), (s * 0.48, 0.31, -0.72)], 0.025, "graphite", g, hi, 1,
             L(hi, 6, 12))
    tube(f"column_{tag}", [(0, 0.47, -0.62), (0, 0.85, -0.32)], 0.024, "graphite", g, hi, 1, L(hi, 6, 12))
    # Bone badge on the nose front.
    bone_m = facing((0, 0.43, -1.13), (0, 0.15, -1))
    puffy(f"bone_{tag}", [(-0.07, -0.022), (0.07, -0.022), (0.07, 0.022), (-0.07, 0.022)], 0.02, 0.008, bone_m,
          "stripe_white", g, hi)
    for bx in (-0.075, 0.075):
        for by in (-0.022, 0.022):
            ellipsoid(f"bone_end{bx}{by}_{tag}", (0.028, 0.028, 0.016), (0, 0, 0), "stripe_white", g, hi,
                      L(hi, (8, 5), (20, 12)), matrix=bone_m @ Matrix.Translation(Vector((bx, by, 0))))
    K.build_legs(g, hi)
    if hi:
        # Yellow twin rally stripes over nose and deck, names and bones on the pods / flaps.
        for x in (-0.075, 0.075):
            for z in (-1.0, -0.86, -0.72, -0.58, -0.44):
                decal(f"stripe_n{x}{z}", [(-0.035, -0.075), (0.035, -0.075), (0.035, 0.075), (-0.035, 0.075)],
                      facing((x, 0.56, z), (0, 1, 0), up=(0, 0, -1)), "stripe", g, nose, 0.003, 3)
            for z in (0.48, 0.62, 0.76):
                decal(f"stripe_d{x}{z}", [(-0.035, -0.075), (0.035, -0.075), (0.035, 0.075), (-0.035, 0.075)],
                      facing((x, 0.53, z), (0, 1, 0), up=(0, 0, -1)), "stripe", g, deck, 0.003, 3)
        for s, pod in zip((-1, 1), pods):
            m = facing((s * 0.48, 0.40, -0.02), (s, 0, 0))
            decal(f"podline{s}", [(-0.30, -0.012), (0.30, -0.012), (0.30, 0.012), (-0.30, 0.012)],
                  m @ Matrix.Translation(Vector((0, -0.08, 0))), "stripe", g, pod, 0.003, 3)
            text_decal(f"podname{s}", "HAVHAV", 0.13, m @ Matrix.Translation(Vector((0, 0.03, 0))),
                       "stripe_white", g, pod, 0.0035)
        for s, flap in zip((-1, 1), flaps):
            fm = facing((s * 0.66, 0.21, 1.095), (0, 0, 1))
            decal(f"flapbone{s}", [(-0.05, -0.014), (0.05, -0.014), (0.05, 0.014), (-0.05, 0.014)], fm,
                  "stripe_white", g, flap, 0.003, 1)
            for bx in (-0.05, 0.05):
                for by in (-0.016, 0.016):
                    decal(f"flapbe{s}{bx}{by}", circle_outline(0.02, 0.02, 10),
                          fm @ Matrix.Translation(Vector((bx, by, 0))), "stripe_white", g, flap, 0.0035, 1)
        tube("seat_pipe", [(-0.2, 0.55, 0.47), (-0.22, 0.85, 0.42), (-0.1, 1.02, 0.40), (0.1, 1.02, 0.40),
                           (0.22, 0.85, 0.42), (0.2, 0.55, 0.47)], 0.012, "stripe_white", g, True, 10, 10, False)
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
        return Vector((p.x * (1.0 - 0.15 * k), p.y, p.z * (1.0 - 0.1 * k)))
    body = superellipsoid(f"torso_{tag}", (0.19, 0.17, 0.15), (0, 0.83, 0.21), "fur", g, hi, (0.75, 0.85),
                          L(hi, (14, 8), (48, 24)), deform=torso_def)
    torus(f"collar_{tag}", 0.07, 0.028, Matrix.Translation(Vector((0, 0.985, 0.19))), "collar", g, hi,
          L(hi, (12, 5), (32, 12)))
    capsule(f"neck_{tag}", (0, 0.96, 0.18), (0, 1.08, 0.18), 0.05, "fur", g, hi, L(hi, (8, 4), (20, 8)))
    tag_m = facing((0, 0.935, 0.115), (0, 0.1, -1))
    puffy(f"tag_{tag}", [(-0.03, -0.01), (0.03, -0.01), (0.03, 0.01), (-0.03, 0.01)], 0.012, 0.005, tag_m, "gold", g, hi)
    for bx in (-0.032, 0.032):
        for by in (-0.01, 0.01):
            ellipsoid(f"tag_end{bx}{by}_{tag}", (0.013, 0.013, 0.008), (0, 0, 0), "gold", g, hi, L(hi, (6, 4), (14, 8)),
                      matrix=tag_m @ Matrix.Translation(Vector((bx, by, 0))))
    if hi:
        decal("belly", circle_outline(0.11, 0.13, 24), facing((0, 0.80, 0.065), (0, 0.05, -1)), "fur_light", g,
              body, 0.003, 3)


def build_head(hi):
    tag = "H" if hi else "L"
    g = "Head"
    hc = Vector((0, 1.20, 0.17))
    head = superellipsoid(f"head_{tag}", (0.28, 0.26, 0.27), hc, "fur", g, hi, (1.0, 1.0), L(hi, (28, 20), (96, 64)))
    muzzle = superellipsoid(f"muzzle_{tag}", (0.15, 0.10, 0.12), (0, 1.10, -0.06), "fur_light", g, hi, (0.85, 0.9),
                            L(hi, (14, 10), (64, 40)))
    ellipsoid(f"nose_{tag}", (0.055, 0.038, 0.036), (0, 1.16, -0.175), "nose", g, hi, L(hi, (10, 6), (32, 20)))
    for s in (-1, 1):
        ellipsoid(f"cheek{s}_{tag}", (0.08, 0.07, 0.07), (s * 0.15, 1.10, -0.02), "fur_light", g, hi,
                  L(hi, (8, 6), (28, 18)))
    # Three-spike fur tuft on top.
    for i, x in enumerate((-0.05, 0.0, 0.05)):
        superellipsoid(f"tuft{i}_{tag}", (0.03, 0.07, 0.03), (x, 1.47, 0.10 + abs(x)), "fur", g, hi, (0.9, 1.0),
                       L(hi, (6, 5), (20, 12)), rot=(-0.4, 0, -x * 6),
                       deform=lambda p, n: Vector((p.x * (1 - 0.6 * max(0, n.y)), p.y, p.z * (1 - 0.6 * max(0, n.y)))))
    if hi:
        mouth_m = facing((0, 1.055, -0.15), (0, -0.25, -1))
        smile = [(math.cos(a) * 0.055, math.sin(a) * 0.04 - 0.004)
                 for a in [math.pi + math.pi * k / 16 for k in range(17)]]
        smile = [(-0.055, 0.004)] + smile[1:-1] + [(0.055, 0.004), (0.0, 0.01)]
        decal("mouth", smile, mouth_m, "mouth", g, muzzle, 0.003, 2)
        decal("tongue", circle_outline(0.026, 0.016, 14), mouth_m @ Matrix.Translation(Vector((0, -0.026, 0))),
              "tongue", g, muzzle, 0.0045, 1)
        decal("teeth", [(-0.036, 0.0), (0.036, 0.0), (0.03, -0.009), (-0.03, -0.009)],
              mouth_m @ Matrix.Translation(Vector((0, 0.002, 0))), "teeth", g, muzzle, 0.0045, 1)
        decal("lip", [(-0.004, 0.0), (0.004, 0.0), (0.004, 0.05), (-0.004, 0.05)],
              mouth_m @ Matrix.Translation(Vector((0, 0.0, 0))), "mouth", g, muzzle, 0.003, 1)
        for s in (-1, 1):
            brow = [(math.cos(a) * 0.05, math.sin(a) * 0.022 - 0.012) for a in
                    [0.35 + (math.pi - 0.7) * k / 10 for k in range(11)]]
            brow += [(math.cos(a) * 0.044, math.sin(a) * 0.013 - 0.008) for a in
                     [math.pi - 0.45 - (math.pi - 0.9) * k / 10 for k in range(11)]]
            decal(f"brow{s}", brow, facing((s * 0.09, 1.33, -0.085), (s * 0.25, 0.3, -0.92))
                  @ Matrix.Rotation(s * 0.2, 4, "Z"), "brow", g, head, 0.003, 1)
            decal(f"spot{s}", circle_outline(0.006, 0.006, 8), facing((s * 0.06, 1.12, -0.165), (s * 0.3, 0, -1)),
                  "fur_dark", g, muzzle, 0.003, 0)


def build_ear(group, s, hi):
    tag = "H" if hi else "L"
    piv = Vector((s * EAR_PIVOT[0], EAR_PIVOT[1], EAR_PIVOT[2]))
    m = Matrix.Translation(piv + Vector((s * 0.05, -0.12, 0.0))) @ Matrix.Rotation(s * 0.3, 4, "Z")

    def ear_def(p, n):
        # Wider and rounder at the tip (bottom), slight cup.
        k = (1 - n.y) / 2
        return Vector((p.x - 0.01 * abs(n.z) * s, p.y, p.z * (0.75 + 0.35 * k)))
    ear = superellipsoid(f"{group}_ear_{tag}", (0.032, 0.15, 0.09), (0, 0, 0), "fur_dark", group, hi, (0.8, 0.9),
                         L(hi, (12, 8), (40, 24)), deform=ear_def, matrix=m)
    if hi:
        decal(f"{group}_inner", circle_outline(0.05, 0.11, 20), m @ facing((-s * 0.03, -0.02, 0), (-s, 0, 0)),
              "fur", group, ear, 0.003, 2)


def build_tail(hi):
    tag = "H" if hi else "L"
    g = "Tail"
    capsule(f"tail_{tag}", (0, 0.98, 0.53), (0, 1.13, 0.68), 0.04, "fur", g, hi, L(hi, (8, 6), (24, 12)), r_end=0.03)
    ellipsoid(f"tail_tip_{tag}", (0.045, 0.06, 0.045), (0, 1.17, 0.72), "fur_light", g, hi, L(hi, (8, 6), (24, 14)),
              rot=(-0.8, 0, 0))


def build_paw_arm(group, s, hi):
    tag = "H" if hi else "L"
    sh = Vector((s * K.SHOULDER[0], K.SHOULDER[1], K.SHOULDER[2]))
    ellipsoid(f"{group}_shoulder_{tag}", (0.065, 0.065, 0.07), sh + Vector((0, 0, -0.03)), "fur", group, hi,
              L(hi, (12, 8), (32, 20)))
    capsule(f"{group}_arm_{tag}", sh + Vector((0, 0, -0.06)), sh + Vector((0, 0, -0.34)), 0.042, "fur", group, hi,
            L(hi, (10, 6), (24, 12)), r_end=0.038)
    torus(f"{group}_band_{tag}", 0.042, 0.014, Matrix.Translation(sh + Vector((0, 0, -0.32))) @
          Matrix.Rotation(math.pi / 2, 4, "X"), "collar", group, hi, L(hi, (10, 4), (24, 8)))
    ellipsoid(f"{group}_paw_{tag}", (0.056, 0.05, 0.06), sh + Vector((0, 0, -0.39)), "fur_light", group, hi,
              L(hi, (10, 6), (28, 16)))
    capsule(f"{group}_thumb_{tag}", sh + Vector((-s * 0.03, 0.025, -0.37)), sh + Vector((-s * 0.045, 0.04, -0.41)),
            0.019, "fur_light", group, hi, L(hi, (6, 4), (16, 8)))


def build(hi):
    build_body(hi)
    for s, name in ((-1, "WheelFL"), (1, "WheelFR")):
        K.build_wheel(name, (s * FRONT_WHEEL[0], FRONT_WHEEL[1], FRONT_WHEEL[2]), FRONT_WHEEL[1], FRONT_W, s, hi,
                      text="HAVHAV")
    for s in (-1, 1):
        K.build_wheel("WheelRear", (s * REAR_WHEEL[0], REAR_WHEEL[1], REAR_WHEEL[2]), REAR_WHEEL[1], REAR_W, s, hi,
                      text="HAVHAV")
    K.build_steering(hi)
    build_torso(hi)
    build_head(hi)
    K.build_eyes(hi)
    build_ear("EarL", -1, hi)
    build_ear("EarR", 1, hi)
    build_tail(hi)
    build_paw_arm("ArmL", -1, hi)
    build_paw_arm("ArmR", 1, hi)


K.setup("buddy_rally", "assets/models/havhav", PALETTE, PAINT_MAT, GROUPS, UV_SCALE, FAR_RATIO)
K.run(build)
