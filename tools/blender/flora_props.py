"""Trees, palms and small street props for Yaska Racing (0.14.2 Blender
models): palm, palm_b, tree (çinar), pine, cypress, flower_bed, bollard, bench.

  blender --background --factory-startup --python tools/blender/flora_props.py -- --bake-res 2048 --tex-res 1024
Instanced on every map and mostly shadow casters, so the low models are light
and single-material; leaf clumps, bark rings, palm leaflets and stone come from
the bake (Voronoi bumps on the high model's leaf / hedge materials). Shapes,
sizes and origins follow PropKit (_palm, _tree, _pine, _cypress, _flower_bed,
_bollard, _bench). Colours get PropKit's Palette.vivid boost.
"""

import colorsys
import math
import os
import sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from kart_common import *  # noqa: F401,F403
import kart_common as K
from mathutils import Vector, Matrix, Euler, Quaternion


def vivid(hx):
    """Palette.vivid: saturation x1.3 + 0.04, value x1.03 (greys untouched)."""
    r, g, b = (int(hx[i:i + 2], 16) / 255 for i in (0, 2, 4))
    h, s, v = colorsys.rgb_to_hsv(r, g, b)
    if s >= 0.12:
        s, v = min(s * 1.3 + 0.04, 1.0), min(v * 1.03, 1.0)
    r, g, b = colorsys.hsv_to_rgb(h, s, v)
    return "%02X%02X%02X" % (round(r * 255), round(g * 255), round(b * 255))


RAW = {
    "trunk": ("8A6A4A", 0.9, 0.0), "trunk_dark": ("6B4F36", 0.9, 0.0), "bark_plane": ("B9AB8A", 0.9, 0.0),
    "leaf": ("5AA34A", 0.85, 0.0), "leaf_dark": ("3F8A3F", 0.85, 0.0), "leaf_light": ("78B850", 0.85, 0.0),
    "palm_leaf": ("4E9A3A", 0.75, 0.0), "palm_leaf_light": ("6FB648", 0.75, 0.0), "pine_needle": ("2F6A3A", 0.9, 0.0),
    "hedge": ("3F9A3A", 0.85, 0.0), "flower_pink": ("FF4FA3", 0.7, 0.0), "flower_magenta": ("D93A8C", 0.7, 0.0),
    "flower_white": ("FFF6EA", 0.7, 0.0), "limestone": ("D9C29A", 0.85, 0.0), "metal_dark": ("23413A", 0.45, 0.6),
    "gold": ("F2C14E", 0.25, 1.0), "wood": ("7A4A2A", 0.7, 0.0),
}
PALETTE = {k: (vivid(v[0]) if k != "limestone" else v[0], v[1], v[2]) for k, v in RAW.items()}
PAINT_MAT = ""
STONE = ["limestone"]
GROUPS = ["palm", "palm_b", "tree", "pine", "cypress", "flower_bed", "bollard", "bench"]
UV_SCALE = {"palm": 1.2, "palm_b": 1.2, "tree": 0.9, "pine": 0.8, "cypress": 0.9, "flower_bed": 1.0,
            "bollard": 1.5, "bench": 1.5}
FAR_RATIO = {"palm": 0.45, "palm_b": 0.45, "tree": 0.4, "pine": 0.45, "cypress": 0.5, "flower_bed": 0.4,
             "bollard": 0.5, "bench": 0.5}
LEAVES = {"leaf": 2.8, "leaf_dark": 2.8, "leaf_light": 2.8, "hedge": 5.0, "pine_needle": 4.0}
_bumped = False


def add_leaf_bump():
    """Lumpy leaf clumps (Voronoi F1 distance as height) on the high model."""
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


def trunk(name, path, r0, r1, mat, g, hi, sides):
    """Tapered tube along a polyline (rings follow the path)."""
    pts = catmull(path, L(hi, 1, 4))
    bm = bmesh.new()
    rows = []
    n = len(pts)
    for i, p in enumerate(pts):
        d = (pts[min(i + 1, n - 1)] - pts[max(i - 1, 0)]).normalized()
        q = Vector((0, 1, 0)).rotation_difference(d)
        r = r0 + (r1 - r0) * i / (n - 1)
        rows.append([bm.verts.new(p + q @ Vector((math.cos(2 * math.pi * k / sides) * r, 0,
                                                    math.sin(2 * math.pi * k / sides) * r))) for k in range(sides)])
    for i in range(n - 1):
        for k in range(sides):
            bm.faces.new((rows[i][k], rows[i][(k + 1) % sides], rows[i + 1][(k + 1) % sides], rows[i + 1][k]))
    bm.faces.new(list(reversed(rows[0])))
    bm.faces.new(rows[-1])
    return K.finish(bm, name, mat, g, hi)


def frond(name, origin, ang, length, droop, mat, g, hi):
    """Palm frond: creased blade with thickness (both sides lit, no culling
    tricks); high model adds leaflet ridges on top."""
    steps = L(hi, 5, 14)
    d = Vector((math.cos(ang), 0, math.sin(ang)))
    side = Vector((-d.z, 0, d.x))
    bm = bmesh.new()
    top, bot = [], []
    for i in range(steps + 1):
        t = i / steps
        c = origin + d * length * t + Vector((0, 0.6 * t - droop * 2.2 * t * t, 0))
        w = math.sin(t * math.pi) * 0.55 + 0.04
        crease = Vector((0, 0.12 * w, 0))
        row_t = [c - side * w, c + crease, c + side * w]
        top.append([bm.verts.new(v) for v in row_t])
        bot.append([bm.verts.new(v - Vector((0, 0.03, 0))) for v in row_t])
    for i in range(steps):
        for j in range(2):
            bm.faces.new((top[i][j], top[i + 1][j], top[i + 1][j + 1], top[i][j + 1]))
            bm.faces.new((bot[i][j + 1], bot[i + 1][j + 1], bot[i + 1][j], bot[i][j]))
    for f in bm.faces:
        pass
    bm.normal_update()
    # Top faces up, bottom faces down (blade is open at the rim, never seen edge-on).
    for f in bm.faces:
        want = 1.0 if all(v in [x for row in top for x in row] for v in f.verts) else -1.0
        if f.normal.y * want < 0:
            f.normal_flip()
    ob = K.finish(bm, name, mat, g, hi, keep=True)
    if hi:
        for i in range(1, 22):
            t = i / 22
            c = origin + d * length * t + Vector((0, 0.6 * t - droop * 2.2 * t * t, 0))
            w = math.sin(t * math.pi) * 0.55
            for s in (-1, 1):
                tube(f"{name}_lf{i}{s}", [c + Vector((0, 0.11 * w + 0.01, 0)), c + side * s * w * 0.95 + d * 0.12],
                     0.012, mat, g, True, 1, 4, True)
    return ob


def build_palm(g, height, variant, hi):
    tag = "H" if hi else "L"
    lean = 0.6 + variant * 0.3
    segs = 7
    path = [Vector((math.sin((i / segs) * 1.4) * lean, height * i / segs, 0)) for i in range(segs + 1)]
    trunk(f"{g}_trunk_{tag}", path, 0.27, 0.17, "trunk", g, hi, L(hi, 6, 16))
    if hi:
        for i in range(1, 20):
            t = i / 20
            p = Vector((math.sin(t * 1.4) * lean, height * t, 0))
            d = Vector((math.cos(t * 1.4) * 1.4 * lean / height, 1, 0)).normalized()
            torus(f"{g}_ring{i}", 0.27 - 0.1 * t + 0.004, 0.012, Matrix.Translation(p) @
                  Vector((0, 1, 0)).rotation_difference(d).to_matrix().to_4x4(), "trunk_dark", g, True, (16, 4))
    top = path[-1]
    ellipsoid(f"{g}_crown_{tag}", (0.32, 0.32, 0.32), top, "trunk_dark", g, hi, L(hi, (8, 5), (24, 14)))
    for k in range(9):
        ang = 2 * math.pi * k / 9 + variant * 0.3
        droop = 0.5 + 0.35 * (k % 3) / 2.0
        frond(f"{g}_frond{k}_{tag}", top, ang, 3.2 + 0.4 * (k % 2), droop,
              "palm_leaf" if k % 2 == 0 else "palm_leaf_light", g, hi)
    for k in range(4):
        a = 2 * math.pi * k / 4
        ellipsoid(f"{g}_nut{k}_{tag}", (0.13, 0.13, 0.13), top + Vector((math.cos(a) * 0.3, -0.35, math.sin(a) * 0.3)),
                  "trunk_dark", g, hi, L(hi, (6, 4), (16, 10)))


def build_tree(hi):
    tag = "H" if hi else "L"
    g = "tree"
    trunk(f"tree_trunk_{tag}", [Vector((0, 0, 0)), Vector((0, 3.4, 0))], 0.33, 0.22, "bark_plane", g, hi, L(hi, 7, 16))
    trunk(f"tree_br1_{tag}", [Vector((0, 3.0, 0)), Vector((0.85, 4.8, 0))], 0.16, 0.1, "bark_plane", g, hi, L(hi, 5, 12))
    trunk(f"tree_br2_{tag}", [Vector((0, 3.0, 0)), Vector((-0.8, 4.8, 0.4))], 0.16, 0.1, "bark_plane", g, hi, L(hi, 5, 12))
    seg = L(hi, (12, 8), (48, 32))
    superellipsoid(f"tree_crown_{tag}", (2.6, 1.7, 2.5), (0, 5.6, 0), "leaf", g, hi, (1.0, 1.0), seg,
                   deform=lambda p, n: p * (1.0 + 0.08 * math.sin(n.x * 7) * math.sin(n.z * 6)))
    superellipsoid(f"tree_crown2_{tag}", (1.6, 1.2, 1.6), (1.5, 6.6, 0.8), "leaf_dark", g, hi, (1.0, 1.0),
                   L(hi, (10, 7), (40, 24)))
    superellipsoid(f"tree_crown3_{tag}", (1.5, 1.1, 1.5), (-1.4, 6.2, -1.0), "leaf_light", g, hi, (1.0, 1.0),
                   L(hi, (10, 7), (40, 24)))


def build_pine(hi):
    tag = "H" if hi else "L"
    g = "pine"
    trunk(f"pine_trunk_{tag}", [Vector((0, 0, 0)), Vector((0.2, 3.5, 0)), Vector((0.3, 7.0, 0))], 0.3, 0.18,
          "trunk_dark", g, hi, L(hi, 6, 16))
    superellipsoid(f"pine_crown_{tag}", (3.2, 0.85, 3.0), (0.3, 7.6, 0), "pine_needle", g, hi, (1.0, 0.8),
                   L(hi, (14, 6), (48, 20)))
    superellipsoid(f"pine_crown2_{tag}", (2.1, 0.65, 2.0), (0.5, 8.4, 0.3), "leaf_dark", g, hi, (1.0, 0.8),
                   L(hi, (12, 5), (40, 16)))


def build_cypress(hi):
    tag = "H" if hi else "L"
    g = "cypress"
    trunk(f"cyp_trunk_{tag}", [Vector((0, 0, 0)), Vector((0, 0.8, 0))], 0.12, 0.1, "trunk", g, hi, L(hi, 5, 12))
    superellipsoid(f"cyp_crown_{tag}", (0.65, 3.0, 0.65), (0, 3.6, 0), "leaf_dark", g, hi, (1.2, 1.0),
                   L(hi, (8, 8), (32, 32)))


def build_flower_bed(hi):
    tag = "H" if hi else "L"
    g = "flower_bed"
    w = 5.0
    bbox(f"fb_box_{tag}", (w, 0.7, 1.8), (0, 0.35, 0), "limestone", g, hi, L(hi, 0.0, 0.08))
    superellipsoid(f"fb_hedge_{tag}", (w * 0.5 - 0.2, 0.45, 0.75), (0, 0.8, 0), "hedge", g, hi, (0.7, 0.5),
                   L(hi, (10, 5), (40, 16)))
    cols = ["flower_pink", "flower_magenta", "flower_white"]
    for i in range(11):
        x = -w * 0.5 + 0.5 + i * (w - 1.0) / 10.0
        z = 0.35 if i % 2 == 0 else -0.35
        ellipsoid(f"fb_fl{i}_{tag}", (0.32, 0.32, 0.32), (x, 1.25 + 0.08 * (i % 3), z), cols[i % 3], g, hi,
                  L(hi, (5, 3), (16, 10)))


def build_bollard(hi):
    tag = "H" if hi else "L"
    g = "bollard"
    superellipsoid(f"bol_body_{tag}", (0.15, 0.4, 0.15), (0, 0.4, 0), "metal_dark", g, hi, (0.6, 1.0),
                   L(hi, (8, 5), (32, 16)))
    torus(f"bol_ring_{tag}", 0.155, 0.02, Matrix.Translation(Vector((0, 0.62, 0))), "gold", g, hi, L(hi, (8, 3), (32, 8)))


def build_bench(hi):
    tag = "H" if hi else "L"
    g = "bench"
    for z in (-0.18, 0.0, 0.18):
        bbox(f"bench_seat{z}_{tag}", (1.8, 0.06, 0.14), (0, 0.46, z), "wood", g, hi, L(hi, 0.0, 0.02))
    bbox(f"bench_back_{tag}", (1.8, 0.3, 0.06), (0, 0.75, 0.3), "wood", g, hi, L(hi, 0.0, 0.02), rot=(-0.2, 0, 0))
    for x in (-0.75, 0.75):
        bbox(f"bench_leg{x}_{tag}", (0.08, 0.46, 0.5), (x, 0.23, 0.05), "metal_dark", g, hi, L(hi, 0.0, 0.015))


BUILDERS = {
    "palm": lambda hi: build_palm("palm", 7.5, 0, hi),
    "palm_b": lambda hi: build_palm("palm_b", 6.2, 1, hi),
    "tree": build_tree, "pine": build_pine, "cypress": build_cypress,
    "flower_bed": build_flower_bed, "bollard": build_bollard, "bench": build_bench,
}
OFFSET = {g: Vector((i * 14.0, 0.0, 0.0)) for i, g in enumerate(GROUPS)}


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
K.setup("flora_props", "assets/models/flora", PALETTE, PAINT_MAT, GROUPS, UV_SCALE, FAR_RATIO, stone_mats=STONE)
K.run(build)
