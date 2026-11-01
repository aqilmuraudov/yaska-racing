"""Seafront small props and the Baku Eye for Yaska Racing (0.14.4 Blender
models): chevron_left, chevron_right, tire_stack, kiosk, umbrella, boat,
flower_bed_b, wheel_frame, wheel_ring.

  blender --background --factory-startup --python tools/blender/seafront_props.py -- --bake-res 4096 --tex-res 2048
Sizes, origins and facing follow PropKit (_chevron: board faces +Z, arrows to
`dir`; wheel_ring: centred at the hub, ring in the XY plane, rotates around Z;
wheel_frame: hub at 34 m). orm alpha = glass (kiosk / boat cabin glow at night).
"""

import math
import os
import sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from kart_common import *  # noqa: F401,F403
import kart_common as K
from mathutils import Vector, Matrix, Euler, Quaternion

PALETTE = {
    "red": ("E0344B", 0.5, 0.0), "white": ("F4F1EE", 0.55, 0.0), "metal_grey": ("9AA0A8", 0.4, 0.8),
    "metal_dark": ("23413A", 0.45, 0.6), "tire": ("2B2830", 0.85, 0.0), "tread": ("4A4452", 0.8, 0.0),
    "plaster_white": ("F2ECE0", 0.7, 0.0), "glass": ("2F5F86", 0.08, 0.3), "wood": ("7A4A2A", 0.7, 0.0),
    "fabric_white": ("F6F1E6", 0.9, 0.0), "fabric_red": ("E85A4F", 0.85, 0.0), "fabric_teal": ("1FA3A0", 0.85, 0.0),
    "hull_white": ("F7F7F4", 0.35, 0.0), "hull_blue": ("1E5FAE", 0.4, 0.0), "deck": ("B98A5A", 0.7, 0.0),
    "limestone": ("D9C29A", 0.85, 0.0), "hedge": ("4FB04A", 0.85, 0.0),
    "flower_yellow": ("FFD23F", 0.7, 0.0), "flower_pink": ("FF4FA3", 0.7, 0.0), "flower_white": ("FFF6EA", 0.7, 0.0),
    "cabin_pink": ("F7B6C8", 0.4, 0.0), "cabin_mint": ("A8E6CF", 0.4, 0.0), "cabin_blue": ("A7C7F2", 0.4, 0.0),
    "cabin_yellow": ("FFE6A0", 0.4, 0.0), "steel_white": ("F2F4F7", 0.35, 0.5),
}
PAINT_MAT = "glass"
STONE = ["limestone"]
GROUPS = ["chevron_left", "chevron_right", "tire_stack", "kiosk", "umbrella", "boat", "flower_bed_b",
          "wheel_frame", "wheel_ring"]
UV_SCALE = {"chevron_left": 1.6, "chevron_right": 1.6, "tire_stack": 1.2, "kiosk": 1.2, "umbrella": 1.2, "boat": 1.0,
            "flower_bed_b": 1.0, "wheel_frame": 0.35, "wheel_ring": 0.3}
FAR_RATIO = {g: 0.45 for g in GROUPS}
LEAVES = {"hedge": 5.0}


def add_leaf_bump():
    for name, scale in LEAVES.items():
        nt = K.MATS[name].node_tree
        bsdf = nt.nodes["Principled BSDF"]
        tc = nt.nodes.new("ShaderNodeTexCoord")
        vo = nt.nodes.new("ShaderNodeTexVoronoi")
        vo.inputs["Scale"].default_value = scale
        inv = nt.nodes.new("ShaderNodeMath")
        inv.operation = "SUBTRACT"
        inv.inputs[0].default_value = 1.0
        bump = nt.nodes.new("ShaderNodeBump")
        bump.inputs["Strength"].default_value = 0.9
        bump.inputs["Distance"].default_value = 0.08
        nt.links.new(tc.outputs["Object"], vo.inputs["Vector"])
        nt.links.new(vo.outputs["Distance"], inv.inputs[1])
        nt.links.new(inv.outputs["Value"], bump.inputs["Height"])
        nt.links.new(bump.outputs["Normal"], bsdf.inputs["Normal"])


def build_chevron(g, d, hi):
    tag = "H" if hi else "L"
    for x in (-0.9, 0.9):
        tube(f"{g}_post{x}_{tag}", [(x, 0.0, -0.05), (x, 1.6, -0.05)], 0.06, "metal_grey", g, hi, 1, L(hi, 6, 16))
    board = bbox(f"{g}_board_{tag}", (2.4, 0.9, 0.08), (0, 1.55, 0), "red", g, hi, L(hi, 0.0, 0.03))
    if hi:
        bbox(f"{g}_frame", (2.44, 0.94, 0.06), (0, 1.55, -0.012), "white", g, True, 0.02)
        for k in range(3):
            cx = (-0.65 + k * 0.65) * d
            arrow = [(cx - d * 0.08, 0.3), (cx + d * 0.08, 0.3), (cx + d * 0.38, 0.0), (cx + d * 0.08, -0.3),
                     (cx - d * 0.08, -0.3), (cx + d * 0.22, 0.0)]
            if d < 0:
                arrow = list(reversed(arrow))
            puffy(f"{g}_arrow{k}", arrow, 0.012, 0.0, K.trs((0, 1.55, 0.046)), "white", g, True)


def build_tire_stack(hi):
    tag = "H" if hi else "L"
    g = "tire_stack"
    for i in range(4):
        y = 0.13 + i * 0.25
        prof = [(-0.12, 0.2), (-0.13, 0.33), (-0.1, 0.44), (0.0, 0.46), (0.1, 0.44), (0.13, 0.33), (0.12, 0.2)]
        ob = lathe(f"ts_tyre{i}_{tag}", prof if hi else [prof[0], prof[2], prof[4], prof[6]], (0, 0, 0), "tire", g, hi,
                   L(hi, 12, 40))
        ob.data.transform(K.trs((0, y, 0), (0, 0, math.pi / 2)))
        torus(f"ts_band{i}_{tag}", 0.47, 0.055, K.trs((0, y, 0)), "red" if i % 2 == 0 else "white", g, hi,
              L(hi, (12, 4), (40, 8)))
        if hi:
            for k in range(30):
                a = 2 * math.pi * k / 30
                bbox(f"ts_tread{i}_{k}", (0.04, 0.16, 0.012), (math.cos(a) * 0.462, y, math.sin(a) * 0.462), "tread",
                     g, True, 0.0, rot=(0, -a, 0))


def build_kiosk(hi):
    tag = "H" if hi else "L"
    g = "kiosk"
    bbox(f"k_body_{tag}", (3.0, 2.6, 2.4), (0, 1.3, 0), "plaster_white", g, hi, L(hi, 0.0, 0.12))
    bbox(f"k_counter_{tag}", (2.6, 0.12, 0.45), (0, 1.0, 1.35), "wood", g, hi, L(hi, 0.0, 0.03))
    window = facing((0, 1.55, 1.205), (0, 0, 1))
    bm = bmesh.new()
    vs = [bm.verts.new((x * 1.2, y * 0.5, 0)) for x, y in ((-1, -1), (1, -1), (1, 1), (-1, 1))]
    bm.faces.new(vs)
    K.xform(bm, window)
    K.finish(bm, f"k_glass_{tag}", "glass", g, hi, keep=True, smooth=False)
    # Scalloped striped awning roof.
    superellipsoid(f"k_roof_{tag}", (1.8, 0.3, 1.5), (0, 2.8, 0.2), "fabric_red", g, hi, (0.5, 0.4),
                   L(hi, (10, 6), (40, 16)))
    bbox(f"k_sign_{tag}", (3.4, 0.3, 0.12), (0, 2.45, 1.4), "white", g, hi, L(hi, 0.0, 0.03))
    if hi:
        for k in range(10):
            a = -math.pi + 2 * math.pi * (k + 0.5) / 10
            decal(f"k_stripe{k}", [(-0.13, -0.3), (0.13, -0.3), (0.13, 0.3), (-0.13, 0.3)],
                  facing((math.cos(a) * 1.6, 2.85, 0.2 + math.sin(a) * 1.35), (math.cos(a), 0.6, math.sin(a))),
                  "white", g, bpy.data.objects[f"k_roof_H"], 0.003, 2)
        text_decal("k_text", "DONDURMA", 0.2, facing((0, 2.45, 1.47), (0, 0, 1)), "red", g, None)


def build_umbrella(hi):
    tag = "H" if hi else "L"
    g = "umbrella"
    tube(f"u_pole_{tag}", [(0, 0.0, 0), (0, 2.6, 0)], 0.05, "wood", g, hi, 1, L(hi, 6, 12))
    n = 8
    for k in range(n):
        a0, a1 = 2 * math.pi * k / n, 2 * math.pi * (k + 1) / n
        bm = bmesh.new()
        apex = bm.verts.new((0, 2.8, 0))
        rim = []
        steps = L(hi, 1, 6)
        for j in range(steps + 1):
            a = a0 + (a1 - a0) * j / steps
            rim.append(bm.verts.new((math.cos(a) * 1.6, 2.22, math.sin(a) * 1.6)))
        apex2 = bm.verts.new((0, 2.77, 0))
        rim2 = [bm.verts.new(v.co - Vector((0, 0.025, 0))) for v in rim]
        for j in range(steps):
            bm.faces.new((apex, rim[j + 1], rim[j]))      # top
            bm.faces.new((apex2, rim2[j], rim2[j + 1]))   # underside, its own verts
        K.finish(bm, f"u_panel{k}_{tag}", "fabric_teal" if k % 2 else "fabric_white", g, hi, keep=True, smooth=False)
    lathe(f"u_table_{tag}", [(0.0, 0.5), (0.05, 0.5), (0.05, 0.0)], (0, 0, 0), "white", g, hi, L(hi, 10, 32)
          ).data.transform(K.trs((0, 0.72, 0), (0, 0, math.pi / 2)))
    tube(f"u_leg_{tag}", [(0, 0.0, 0), (0, 0.72, 0)], 0.05, "metal_dark", g, hi, 1, L(hi, 5, 10))


def build_boat(hi):
    tag = "H" if hi else "L"
    g = "boat"

    def hull_def(p, n):
        k = max(0.0, -n.z)          # bow (-z) narrows and rises
        bottom = max(0.0, -n.y)     # flatter, narrower keel
        return Vector((p.x * (1 - 0.75 * k * k) * (1 - 0.35 * bottom), p.y + 0.2 * k * k, p.z))
    hull = superellipsoid(f"b_hull_{tag}", (1.2, 0.5, 3.5), (0, 0.45, 0.2), "hull_white", g, hi, (0.5, 0.6),
                          L(hi, (12, 8), (48, 24)), deform=hull_def)
    if hi:
        for s_ in (-1, 1):
            decal(f"b_stripe{s_}", [(-3.0, -0.07), (3.0, -0.07), (3.0, 0.07), (-3.0, 0.07)],
                  facing((s_ * 1.2, 0.6, 0.3), (s_, 0, 0)), "hull_blue", g, hull, 0.003, 6)
    bbox(f"b_deck_{tag}", (1.7, 0.06, 5.0), (0, 0.9, 0.5), "deck", g, hi, L(hi, 0.0, 0.02))
    bbox(f"b_cabin_{tag}", (1.6, 0.9, 2.4), (0, 1.2, 0.8), "plaster_white", g, hi, L(hi, 0.0, 0.1))
    for s in (-1, 1):
        bm = bmesh.new()
        vs = [bm.verts.new((x * 1.0, y * 0.18, 0)) for x, y in ((-1, -1), (1, -1), (1, 1), (-1, 1))]
        bm.faces.new(vs)
        K.xform(bm, facing((s * 0.81, 1.3, 0.8), (s, 0, 0)))
        K.finish(bm, f"b_win{s}_{tag}", "glass", g, hi, keep=True, smooth=False)
    tube(f"b_rail_{tag}", [(-0.82, 1.2, -1.6), (-0.82, 1.2, 2.8), (0.82, 1.2, 2.8), (0.82, 1.2, -1.6)], 0.025,
         "metal_grey", g, hi, L(hi, 1, 4), L(hi, 4, 8), True)
    tube(f"b_mast_{tag}", [(0, 1.6, 0.6), (0, 3.4, 0.6)], 0.05, "metal_grey", g, hi, 1, L(hi, 5, 10))


def build_flower_bed_b(hi):
    tag = "H" if hi else "L"
    g = "flower_bed_b"
    w = 5.0
    bbox(f"fb_box_{tag}", (w, 0.7, 1.8), (0, 0.35, 0), "limestone", g, hi, L(hi, 0.0, 0.08))
    superellipsoid(f"fb_hedge_{tag}", (w * 0.5 - 0.2, 0.45, 0.75), (0, 0.8, 0), "hedge", g, hi, (0.7, 0.5),
                   L(hi, (10, 5), (40, 16)))
    cols = ["flower_yellow", "flower_pink", "flower_white"]
    for i in range(11):
        x = -w * 0.5 + 0.5 + i * (w - 1.0) / 10.0
        z = 0.35 if i % 2 == 0 else -0.35
        ellipsoid(f"fb_fl{i}_{tag}", (0.32, 0.32, 0.32), (x, 1.25 + 0.08 * (i % 3), z), cols[i % 3], g, hi,
                  L(hi, (5, 3), (16, 10)))


def build_wheel_frame(hi):
    tag = "H" if hi else "L"
    g = "wheel_frame"
    for z in (-3.0, 3.0):
        for x in (-9.0, 9.0):
            tube(f"wf_leg{x}{z}_{tag}", [(x, 0.0, z), (0, 34.0, z * 0.5)], 0.45, "steel_white", g, hi, 1, L(hi, 8, 20))
        if hi:
            for k in range(1, 9):
                t = k / 9
                y = 34.0 * t
                xs = 9.0 * (1 - t)
                tube(f"wf_brace{z}{k}", [(-xs, y, z * (1 - 0.5 * t)), (xs, y, z * (1 - 0.5 * t))], 0.1, "steel_white", g,
                     True, 1, 8)
    tube(f"wf_axle_{tag}", [(0, 34.0, -2.25), (0, 34.0, 2.25)], 1.0, "metal_grey", g, hi, 1, L(hi, 12, 32))
    bbox(f"wf_base_{tag}", (14.0, 3.0, 8.0), (0, 1.5, 0), "plaster_white", g, hi, L(hi, 0.0, 0.25))
    if hi:
        for k in range(6):
            bm = bmesh.new()
            vs = [bm.verts.new((x * 0.8, y * 0.9, 0)) for x, y in ((-1, -1), (1, -1), (1, 1), (-1, 1))]
            bm.faces.new(vs)
            K.xform(bm, facing((-5.5 + k * 2.2, 1.6, 4.012), (0, 0, 1)))
            K.finish(bm, f"wf_win{k}", "glass", g, True, keep=True, smooth=False)


def build_wheel_ring(hi):
    tag = "H" if hi else "L"
    g = "wheel_ring"
    r = 30.0
    ring = Matrix.Rotation(math.pi / 2, 4, "X")
    torus(f"wr_outer_{tag}", r, 0.5, ring, "steel_white", g, hi, L(hi, (48, 6), (192, 12)))
    torus(f"wr_inner_{tag}", r - 3.1, 0.4, ring, "steel_white", g, hi, L(hi, (48, 6), (192, 12)))
    for i in range(16):
        a = 2 * math.pi * i / 16
        tube(f"wr_spoke{i}_{tag}", [(0, 0, 0), (math.cos(a) * (r - 0.4), math.sin(a) * (r - 0.4), 0)], 0.12,
             "metal_grey", g, hi, 1, L(hi, 4, 8))
    if hi:
        for i in range(48):
            a = 2 * math.pi * (i + 0.5) / 48
            tube(f"wr_truss{i}", [(math.cos(a) * (r - 3.1), math.sin(a) * (r - 3.1), 0),
                                  (math.cos(a + 0.06) * r, math.sin(a + 0.06) * r, 0)], 0.08, "steel_white", g, True, 1, 6)
    cabins = ["cabin_pink", "cabin_mint", "cabin_blue", "cabin_yellow"]
    for i in range(24):
        a = 2 * math.pi * i / 24
        c = Vector((math.cos(a) * (r + 1.2), math.sin(a) * (r + 1.2), 0))
        superellipsoid(f"wr_cab{i}_{tag}", (1.25, 1.3, 1.25), c, cabins[i % 4], g, hi, (0.7, 0.8), L(hi, (6, 10), (24, 32)))
        if hi:
            torus(f"wr_cabband{i}", 1.26, 0.06, Matrix.Translation(c), "white", g, True, (32, 6))


BUILDERS = {
    "chevron_left": lambda hi: build_chevron("chevron_left", -1.0, hi),
    "chevron_right": lambda hi: build_chevron("chevron_right", 1.0, hi),
    "tire_stack": build_tire_stack, "kiosk": build_kiosk, "umbrella": build_umbrella, "boat": build_boat,
    "flower_bed_b": build_flower_bed_b, "wheel_frame": build_wheel_frame, "wheel_ring": build_wheel_ring,
}
OFFSET = {g: Vector((i * 80.0, 0.0, 0.0)) for i, g in enumerate(GROUPS)}
_bumped = False


def build(hi):
    global _bumped
    if hi and not _bumped:
        add_leaf_bump()
        _bumped = True
    for g in GROUPS:
        before = set(K.COLL.objects)
        BUILDERS[g](hi)
        for o in set(K.COLL.objects) - before:
            o.data.transform(Matrix.Translation(OFFSET[g]))


def _home(groups):
    for o in groups:
        o.data.transform(Matrix.Translation(-OFFSET[o.name]))


K.PRE_EXPORT.append(_home)
K.setup("seafront_props", "assets/models/seafront", PALETTE, PAINT_MAT, GROUPS, UV_SCALE, FAR_RATIO, stone_mats=STONE)
K.run(build)
