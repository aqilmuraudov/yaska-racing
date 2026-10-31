"""Yaska Star kart + Yaska driver for Yaska Racing (0.14.0 Blender pilot).

Run (Blender 4.5, no GUI):
  blender --background --factory-startup --python tools/blender/yaska_star.py -- [--out-dir assets/models/yaska] [--no-bake] [--preview]

What it does
  1. Builds every part twice in Godot space (x right, y up, -z forward, metres,
     origin on the ground under the kart centre): a HIGH model (dense, with
     detail: tyre tread, sidewall text, face, hair strands, decals) and a LOW
     game model. Both come from the same parametric surfaces so they line up.
  2. Joins the low parts per rig node (Body, WheelFL, WheelFR, WheelRear,
     SteeringWheel, Torso, Head, Eyes, BraidL, BraidR, ArmL, ArmR). Names must
     match KartModel._attach_gltf(); pivots are defined there / in AnimalDriver,
     the meshes here are authored in kart space at rest pose.
  3. One shared UV atlas, then Cycles bakes (GPU) colour, roughness, metallic,
     tangent normal and AO from high to low, per rig group (no colour bleeding
     between parts), at 2048 px, downsampled to 1024 px:
       albedo.png (sRGB, AO partly multiplied in), normal.png (OpenGL),
       orm.png (R occlusion, G roughness, B metallic, A garage-paint mask).
  4. Exports yaska_star.glb (near) and yaska_star_far.glb (decimated, ~1.5k
     triangles) without materials; Godot applies kart_baked.gdshader.
  5. Saves tools/blender/out/yaska_star.blend (Z-up, editable) and optional
     preview renders.
Everything is deterministic; re-run after editing the numbers below.
"""

import math
import os
import sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from kart_common import *  # noqa: F401,F403  (helpers + shared parts)
import kart_common as K
from mathutils import Vector, Matrix, Euler, Quaternion

# --- Palette (sRGB hex, roughness, metallic) -------------------------------------
# Owner's choice (2026-10-31): brighter metallic pink / purple body, gold tubes.
PALETTE = {
    "body_pink": ("E8409E", 0.24, 0.55),
    "body_purple": ("8B3FD9", 0.28, 0.5),
    "stripe_white": ("FFFFFF", 0.35, 0.0),
    "gold": ("F5B82E", 0.22, 1.0),
    "chrome": ("DDE1E6", 0.12, 1.0),
    "graphite": ("2E2B36", 0.6, 0.2),
    "engine": ("8E909A", 0.35, 0.9),
    "tire": ("2B2830", 0.85, 0.0),
    "tire_text": ("E4E0EA", 0.75, 0.0),
    "tread": ("4A4452", 0.8, 0.0),
    "rim_purple": ("6B2FB0", 0.3, 0.6),
    "seat": ("7A35C4", 0.55, 0.0),
    "seat_trim": ("FF8CC6", 0.5, 0.0),
    "skin": ("FCD7BF", 0.55, 0.0),
    "blush": ("FF9EB0", 0.6, 0.0),
    "mouth": ("8E1F33", 0.5, 0.0),
    "tongue": ("FF6F8E", 0.45, 0.0),
    "teeth": ("FFFFFF", 0.3, 0.0),
    "hair": ("8C5530", 0.45, 0.0),
    "brow": ("5A2F17", 0.6, 0.0),
    "eye_white": ("FFFFFF", 0.32, 0.0),
    "iris": ("7A4A20", 0.35, 0.0),
    "iris_ring": ("3A2010", 0.35, 0.0),
    "pupil": ("140C08", 0.32, 0.0),
    "lash": ("1E1410", 0.5, 0.0),
    "dress": ("5285CB", 0.7, 0.0),
    "dress_dark": ("3D6AAE", 0.7, 0.0),
    "shirt": ("FFFFFF", 0.6, 0.0),
    "star_yellow": ("FFD84D", 0.35, 0.0),
    "leggings": ("8B3FD9", 0.65, 0.0),
    "sock": ("FFFFFF", 0.7, 0.0),
    "shoe": ("FF5FA8", 0.45, 0.0),
    "sole": ("F4F1EE", 0.6, 0.0),
    "hair_tie": ("FF5FA8", 0.4, 0.0),
    "petal": ("FF7FB2", 0.45, 0.0),
    "flower_mid": ("FFD84D", 0.4, 0.0),
}

# Garage paints (KartPaints) recolour this material only: its coverage is
# baked into orm.png alpha.
PAINT_MAT = "body_pink"

GROUPS = ["Body", "WheelFL", "WheelFR", "WheelRear", "SteeringWheel", "Torso", "Head",
          "Eyes", "BraidL", "BraidR", "ArmL", "ArmR"]
# Relative texel density per group (face and eyes get the most).
UV_SCALE = {"Body": 1.0, "WheelFL": 1.0, "WheelFR": 1.0, "WheelRear": 1.0,
            "SteeringWheel": 1.0, "Torso": 1.3, "Head": 2.3, "Eyes": 2.6,
            "BraidL": 1.3, "BraidR": 1.3, "ArmL": 1.2, "ArmR": 1.2}
# Far LOD (beyond 28 m) target share of each group.
FAR_RATIO = {"Body": 0.13, "WheelFL": 0.12, "WheelFR": 0.12, "WheelRear": 0.12,
             "SteeringWheel": 0.2, "Torso": 0.2, "Head": 0.16, "Eyes": 0.3,
             "BraidL": 0.2, "BraidR": 0.2, "ArmL": 0.25, "ArmR": 0.25}

# Rig pivots, kart space (keep in sync with KartModel / AnimalDriver).
FRONT_WHEEL = (0.62, 0.30, -0.72)   # x is mirrored, radius 0.30
REAR_WHEEL = (0.66, 0.35, 0.68)     # radius 0.35
FRONT_W, REAR_W = 0.28, 0.36
BRAID_PIVOT = (0.25, 1.42, 0.23)

# --- Model ---------------------------------------------------------------------------

def build_body(hi):
    tag = "H" if hi else "L"
    g = "Body"
    se = lambda n, *a, **k: superellipsoid(f"{n}_{tag}", *a, **k)
    lo_seg = lambda s: s if hi else s
    # Floor pan.
    floor = se("floor", (0.40, 0.05, 0.98), (0, 0.19, 0.0), "graphite", g, hi, (0.3, 0.35), L(hi, (10, 4), (48, 16)))
    if not hi:
        drop_faces(floor, lambda c, n: n.y < -0.7)

    # Nose cone: tapers and lowers to the front.
    def nose_def(p, n):
        k = max(0.0, -n.z)  # 0 at rear .. 1 at the tip
        return Vector((p.x * (1 - 0.32 * k), p.y * (1 - 0.3 * k) - 0.05 * k, p.z))
    nose = se("nose", (0.25, 0.17, 0.42), (0, 0.36, -0.72), "body_pink", g, hi, (0.55, 0.6),
              L(hi, (18, 10), (64, 32)), deform=nose_def)
    # Side pods.
    pods = []
    for s in (-1, 1):
        def pod_def(p, n, s=s):
            return Vector((p.x, p.y + 0.03 * max(0.0, n.z), p.z))
        pods.append(se(f"pod{'LR'[s > 0]}", (0.09, 0.13, 0.36), (s * 0.39, 0.36, 0.0), "body_pink", g, hi,
                       (0.5, 0.55), L(hi, (16, 8), (56, 28)), deform=pod_def))
    # Rear deck and engine.
    se("deck", (0.30, 0.13, 0.22), (0, 0.38, 0.62), "body_purple", g, hi, (0.5, 0.5), L(hi, (16, 8), (56, 24)))
    se("engine", (0.21, 0.12, 0.16), (0, 0.52, 0.80), "engine", g, hi, (0.4, 0.45), L(hi, (12, 8), (40, 20)))
    # Seat.
    se("seat_back", (0.23, 0.26, 0.06), (0, 0.78, 0.45), "seat", g, hi, (0.45, 0.5), L(hi, (14, 8), (48, 24)),
       rot=(-0.2, 0, 0))
    se("seat_base", (0.21, 0.06, 0.19), (0, 0.52, 0.24), "seat", g, hi, (0.45, 0.5), L(hi, (12, 6), (40, 16)))
    # Gold tube frame: front loop, side bars, rear loop, roll hoop.
    tsides = L(hi, 8, 20)
    tsamp = L(hi, 3, 10)
    r_tube = 0.034
    tube(f"bumper_front_{tag}", [(-0.30, 0.24, -0.95), (-0.46, 0.28, -1.10), (-0.30, 0.31, -1.20),
                                 (0.30, 0.31, -1.20), (0.46, 0.28, -1.10), (0.30, 0.24, -0.95)],
         r_tube, "gold", g, hi, tsamp, tsides)
    for s in (-1, 1):
        tube(f"bar{'LR'[s > 0]}_{tag}", [(s * 0.36, 0.22, -0.38), (s * 0.62, 0.28, -0.32), (s * 0.67, 0.30, -0.04),
                                         (s * 0.62, 0.28, 0.22), (s * 0.38, 0.22, 0.28)],
             r_tube, "gold", g, hi, tsamp, tsides)
    tube(f"bumper_rear_{tag}", [(-0.32, 0.26, 0.95), (-0.46, 0.30, 1.12), (-0.30, 0.33, 1.20),
                                (0.30, 0.33, 1.20), (0.46, 0.30, 1.12), (0.32, 0.26, 0.95)],
         r_tube, "gold", g, hi, tsamp, tsides)
    tube(f"hoop_{tag}", [(-0.25, 0.42, 0.56), (-0.25, 0.92, 0.58), (-0.12, 1.04, 0.59), (0.12, 1.04, 0.59),
                         (0.25, 0.92, 0.58), (0.25, 0.42, 0.56)], 0.03, "gold", g, hi, tsamp, tsides)
    # Exhausts with flared tips.
    for s in (-1, 1):
        pts = [(s * 0.13, 0.55, 0.84), (s * 0.17, 0.72, 0.98), (s * 0.21, 0.90, 1.06)]
        tube(f"exhaust{'LR'[s > 0]}_{tag}", pts, 0.042, "chrome", g, hi, L(hi, 3, 10), L(hi, 10, 24), False)
        tip = Vector(pts[-1])
        d = (tip - Vector(pts[-2])).normalized()
        q = Vector((1, 0, 0)).rotation_difference(d)
        prof = [(0.0, 0.043), (0.05, 0.05), (0.11, 0.062), (0.12, 0.05), (0.06, 0.036)]
        bm = bmesh.new()
        ob = lathe(f"exhtip{'LR'[s > 0]}_{tag}", prof, (0, 0, 0), "chrome", g, hi, L(hi, 10, 32), False, True)
        ob.data.transform(Matrix.Translation(tip) @ q.to_matrix().to_4x4())
        bm.free()
    # Axles and steering column.
    tube(f"axle_rear_{tag}", [(-0.5, 0.35, 0.68), (0.5, 0.35, 0.68)], 0.03, "graphite", g, hi, 1, L(hi, 6, 12))
    for s in (-1, 1):
        tube(f"arm_front{'LR'[s > 0]}_{tag}", [(s * 0.22, 0.24, -0.70), (s * 0.48, 0.30, -0.72)], 0.025,
             "graphite", g, hi, 1, L(hi, 6, 12))
    tube(f"column_{tag}", [(0, 0.47, -0.62), (0, 0.85, -0.32)], 0.024, "graphite", g, hi, 1, L(hi, 6, 12))
    # Heart rear wing between the exhausts, on a short post.
    heart_m = Matrix.Translation(Vector((0, 0.70, 1.02))) @ Matrix.Rotation(0.15, 4, "X")
    puffy(f"heart_{tag}", heart_outline(0.27, L(hi, 18, 64)), 0.05, 0.035, heart_m, "body_purple", g, hi)
    tube(f"heart_post_{tag}", [(0, 0.55, 0.95), (0, 0.70, 1.0)], 0.02, "chrome", g, hi, 1, L(hi, 6, 12))
    # Gold star on the nose, tilted to face up and forward.
    star_m = Matrix.Translation(Vector((0, 0.47, -1.02))) @ Matrix.Rotation(math.radians(-118), 4, "X")
    puffy(f"nose_star_{tag}", star_outline(0.10, 0.045), 0.03, 0.03, star_m, "gold", g, hi)
    build_legs(g, hi)
    if hi:
        # Decals: pod stripes and name, nose flowers, seat piping, engine fins.
        for s, pod in zip((-1, 1), pods):
            side = Vector((s, 0, 0))
            m = facing((s * 0.48, 0.40, 0.0), side, size=1.0)
            decal(f"stripe{s}", [(-0.33, -0.03), (0.33, -0.03), (0.30, 0.03), (-0.30, 0.03)],
                  m @ Matrix.Translation(Vector((0, -0.07, 0))), "body_purple", g, pod, 0.003, 3)
            decal(f"stripe2{s}", [(-0.30, -0.008), (0.30, -0.008), (0.29, 0.008), (-0.29, 0.008)],
                  m @ Matrix.Translation(Vector((0, -0.025, 0))), "stripe_white", g, pod, 0.003, 3)
            text_decal(f"podname{s}", "YASKA", 0.17, m @ Matrix.Translation(Vector((0, 0.045, 0))),
                       "stripe_white", g, pod, 0.0035)
        for s in (-1, 1):
            for k, (zz, yy) in enumerate(((-0.62, 0.42), (-0.80, 0.38))):
                c = Vector((s * 0.25 * (1 - 0.32 * ((-zz - 0.3) / 0.42)), yy, zz))
                m = facing(c, (s, 0.35, -0.1), size=1.0)
                for p in range(5):
                    a = 2 * math.pi * p / 5
                    decal(f"petal{s}{k}{p}", circle_outline(0.022, 0.022, 10),
                          m @ Matrix.Translation(Vector((math.cos(a) * 0.024, math.sin(a) * 0.024, 0))),
                          "petal", g, nose, 0.003, 1)
                decal(f"fmid{s}{k}", circle_outline(0.014, 0.014, 10), m, "flower_mid", g, nose, 0.0045, 1)
        tube("seat_pipe", [(-0.2, 0.55, 0.47), (-0.22, 0.85, 0.42), (-0.1, 1.02, 0.40), (0.1, 1.02, 0.40),
                           (0.22, 0.85, 0.42), (0.2, 0.55, 0.47)], 0.012, "seat_trim", g, True, 10, 10, False)
        for k in range(5):
            bm = bmesh.new()
            bmesh.ops.create_cube(bm, size=1.0)
            xform(bm, trs((0, 0.64, 0.70 + k * 0.045), (0, 0, 0), (0.30, 0.02, 0.012)))
            finish(bm, f"fin{k}", "chrome", g, True, smooth=False)


def build_torso(hi):
    tag = "H" if hi else "L"
    g = "Torso"

    def torso_def(p, n):
        k = (n.y + 1) / 2  # 0 bottom .. 1 top
        return Vector((p.x * (1.0 - 0.18 * k), p.y, p.z * (1.0 - 0.12 * k)))
    body = superellipsoid(f"torso_{tag}", (0.19, 0.17, 0.15), (0, 0.83, 0.21), "dress", g, hi, (0.65, 0.8),
                          L(hi, (14, 8), (48, 24)), deform=torso_def)
    torus(f"collar_{tag}", 0.065, 0.024, Matrix.Translation(Vector((0, 0.985, 0.19))), "shirt", g, hi,
          L(hi, (12, 5), (32, 12)))
    capsule(f"neck_{tag}", (0, 0.96, 0.18), (0, 1.08, 0.18), 0.045, "skin", g, hi, L(hi, (8, 4), (20, 8)))
    if hi:
        decal("chest_star", star_outline(0.055, 0.024), facing((0, 0.86, 0.06), (0, 0.1, -1)), "star_yellow", g,
              body, 0.003, 2)
        for s in (-1, 1):
            decal(f"strap{s}", [(-0.022, -0.09), (0.022, -0.09), (0.022, 0.09), (-0.022, 0.09)],
                  facing((s * 0.1, 0.9, 0.07), (0, 0.05, -1)) @ Matrix.Rotation(s * 0.12, 4, "Z"),
                  "dress_dark", g, body, 0.0025, 3)
            ellipsoid(f"button{s}", (0.016, 0.016, 0.008), (s * 0.1, 0.93, 0.065), "gold", g, True, (12, 8))
            decal(f"backstrap{s}", [(-0.022, -0.09), (0.022, -0.09), (0.022, 0.09), (-0.022, 0.09)],
                  facing((s * 0.08, 0.9, 0.35), (0, 0.05, 1)) @ Matrix.Rotation(-s * 0.2, 4, "Z"),
                  "dress_dark", g, body, 0.0025, 3)


def build_head(hi):
    tag = "H" if hi else "L"
    g = "Head"
    hc = Vector((0, 1.20, 0.16))

    def head_def(p, n):
        # Rounder cheeks / slightly narrower top, flatter back.
        k = (n.y + 1) / 2
        sx = 1.0 + 0.05 * (1 - k) - 0.04 * k
        return Vector((p.x * sx, p.y, p.z * (0.96 if n.z > 0 else 1.0)))
    head = superellipsoid(f"head_{tag}", (0.29, 0.28, 0.285), hc, "skin", g, hi, (1.0, 1.0), L(hi, (20, 14), (96, 64)),
                          deform=head_def)
    if not hi:
        drop_faces(head, lambda c, n: c.y > 1.42 or (c.z > 0.16 and c.y > 1.14))
    ellipsoid(f"nose_{tag}", (0.024, 0.019, 0.02), (0, 1.165, -0.125), "skin", g, hi, L(hi, (8, 5), (20, 12)))
    for s in (-1, 1):
        ellipsoid(f"ear{s}_{tag}", (0.03, 0.05, 0.035), (s * 0.29, 1.18, 0.18), "skin", g, hi, L(hi, (8, 5), (20, 12)))
    # Hair cap with the face opened.
    bm = bmesh.new()
    seg = L(hi, (20, 14), (96, 64))
    bmesh.ops.create_uvsphere(bm, u_segments=seg[0], v_segments=seg[1], radius=1.0)
    xform(bm, Matrix.Translation(Vector((0, 1.228, 0.172))) @ Matrix.Diagonal((0.306, 0.30, 0.312, 1)))
    gone = [v for v in bm.verts if (v.co.z < 0.03 and v.co.y < 1.375) or v.co.y < 1.02 or
            (v.co.z < 0.12 and v.co.y < 1.12)]
    bmesh.ops.delete(bm, geom=gone, context="VERTS")
    hair_c = Vector((0, 1.228, 0.172))
    if hi:
        grooves(bm, hair_c, 46, 0.035)
    cap = finish(bm, f"hair_{tag}", "hair", g, hi, outward=lambda p: p - hair_c)
    if hi:
        sol = cap.modifiers.new("thick", "SOLIDIFY")
        sol.thickness = 0.012
        sol.offset = -1
    # Bangs: five soft locks over the forehead.
    for i, x in enumerate((-0.17, -0.085, 0.0, 0.085, 0.17)):
        y = 1.365 - 0.012 * abs(i - 2)
        z = -0.075 + 0.03 * abs(i - 2) ** 1.5
        lock = superellipsoid(f"bang{i}_{tag}", (0.062, 0.085, 0.03), (x, y, z), "hair", g, hi, (0.9, 1.0),
                              L(hi, (8, 6), (32, 20)), rot=(-0.55, -x * 1.6, -x * 1.4),
                              deform=lambda p, n: Vector((p.x * (1 - 0.45 * max(0, -n.y)), p.y, p.z)))
        if hi:
            bmg = bmesh.new()
            bmg.from_mesh(lock.data)
            grooves(bmg, hair_c, 46, 0.12)
            bmg.to_mesh(lock.data)
            bmg.free()
    # Flower clip (right side, Yaska's signature).
    fc = Vector((0.2, 1.43, -0.02))
    fm = facing(fc, (0.55, 0.5, -0.65))
    for k in range(5):
        a = 2 * math.pi * k / 5
        ellipsoid(f"clip_petal{k}_{tag}", (0.03, 0.03, 0.014), (0, 0, 0), "petal", g, hi, L(hi, (6, 4), (16, 10)),
                  matrix=fm @ Matrix.Translation(Vector((math.cos(a) * 0.032, math.sin(a) * 0.032, 0))))
    ellipsoid(f"clip_mid_{tag}", (0.02, 0.02, 0.016), (0, 0, 0), "flower_mid", g, hi, L(hi, (6, 4), (16, 10)),
              matrix=fm @ Matrix.Translation(Vector((0, 0, 0.008))))
    if hi:
        # Face decals: open smile, tongue, teeth, blush, brows.
        mouth_m = facing((0, 1.095, -0.12), (0, -0.05, -1))
        smile = [(math.cos(a) * 0.05, math.sin(a) * 0.04 - 0.004)
                 for a in [math.pi + math.pi * k / 16 for k in range(17)]]
        smile = [(-0.05, 0.004)] + smile[1:-1] + [(0.05, 0.004), (0.0, 0.012)]
        decal("mouth", smile, mouth_m, "mouth", g, head, 0.003, 2)
        decal("tongue", circle_outline(0.026, 0.014, 14), mouth_m @ Matrix.Translation(Vector((0, -0.024, 0))),
              "tongue", g, head, 0.0045, 1)
        decal("teeth", [(-0.034, 0.0), (0.034, 0.0), (0.03, -0.01), (-0.03, -0.01)],
              mouth_m @ Matrix.Translation(Vector((0, 0.003, 0))), "teeth", g, head, 0.0045, 1)
        for s in (-1, 1):
            decal(f"blush{s}", circle_outline(0.035, 0.022, 16), facing((s * 0.165, 1.13, -0.07), (s * 0.55, -0.1, -0.8)),
                  "blush", g, head, 0.003, 2)
            brow = [(math.cos(a) * 0.05, math.sin(a) * 0.02 - 0.012) for a in
                    [0.35 + (math.pi - 0.7) * k / 10 for k in range(11)]]
            brow += [(math.cos(a) * 0.044, math.sin(a) * 0.012 - 0.008) for a in
                     [math.pi - 0.45 - (math.pi - 0.9) * k / 10 for k in range(11)]]
            decal(f"brow{s}", brow, facing((s * 0.09, 1.325, -0.105), (s * 0.25, 0.25, -0.93))
                  @ Matrix.Rotation(-s * 0.15, 4, "Z"), "brow", g, head, 0.003, 1)
    return head


def build_braid(group, s, hi):
    tag = "H" if hi else "L"
    piv = Vector((s * BRAID_PIVOT[0], BRAID_PIVOT[1], BRAID_PIVOT[2]))
    path = [piv + Vector((s * 0.03, -0.04, 0.02)), piv + Vector((s * 0.08, -0.14, 0.05)),
            piv + Vector((s * 0.1, -0.26, 0.07)), piv + Vector((s * 0.1, -0.38, 0.08))]
    pts = catmull(path, 3)
    torus(f"{group}_tie_{tag}", 0.03, 0.016, Matrix.Translation(path[0]) @
          Vector((0, 1, 0)).rotation_difference((path[1] - path[0]).normalized()).to_matrix().to_4x4(),
          "hair_tie", group, hi, L(hi, (10, 5), (28, 10)))
    n = 6
    for i in range(n):
        t = (i + 0.5) / n
        idx = t * (len(pts) - 1)
        a, b = pts[int(idx)], pts[min(int(idx) + 1, len(pts) - 1)]
        c = a.lerp(b, idx - int(idx))
        d = (b - a).normalized() if (b - a).length > 1e-6 else Vector((0, -1, 0))
        q = Vector((0, 1, 0)).rotation_difference(d)
        tw = Quaternion(d, 0.4 if i % 2 == 0 else -0.4)
        r = 0.05 - 0.016 * t
        m = Matrix.Translation(c) @ (tw @ q).to_matrix().to_4x4() @ Matrix.Rotation(0.5 if i % 2 == 0 else -0.5, 4, "Z")
        seg_ob = ellipsoid(f"{group}_seg{i}_{tag}", (r, 0.05, r * 0.8), (0, 0, 0), "hair", group, hi,
                           L(hi, (8, 6), (32, 20)), matrix=m)
        if hi:
            pass
    end = path[-1]
    torus(f"{group}_tie2_{tag}", 0.022, 0.012, Matrix.Translation(end + Vector((0, 0.015, 0))), "hair_tie", group, hi,
          L(hi, (8, 4), (24, 10)))
    tuft = superellipsoid(f"{group}_tuft_{tag}", (0.035, 0.06, 0.03), end + Vector((s * 0.005, -0.05, 0.005)), "hair",
                          group, hi, (0.9, 1.0), L(hi, (8, 6), (24, 16)),
                          deform=lambda p, n: Vector((p.x * (1 - 0.4 * max(0, -n.y)), p.y, p.z * (1 - 0.4 * max(0, -n.y)))))


def build(hi):
    build_body(hi)
    for s, name in ((-1, "WheelFL"), (1, "WheelFR")):
        build_wheel(name, (s * FRONT_WHEEL[0], FRONT_WHEEL[1], FRONT_WHEEL[2]), FRONT_WHEEL[1], FRONT_W, s, hi)
    for s in (-1, 1):
        build_wheel("WheelRear", (s * REAR_WHEEL[0], REAR_WHEEL[1], REAR_WHEEL[2]), REAR_WHEEL[1], REAR_W, s, hi)
    build_steering(hi)
    build_torso(hi)
    build_head(hi)
    build_eyes(hi)
    build_braid("BraidL", -1, hi)
    build_braid("BraidR", 1, hi)
    build_arm("ArmL", -1, hi)
    build_arm("ArmR", 1, hi)



K.setup("yaska_star", "assets/models/yaska", PALETTE, PAINT_MAT, GROUPS, UV_SCALE, FAR_RATIO)
K.run(build)
