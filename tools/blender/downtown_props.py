"""Göydələnlər şəhəri props for Yaska Racing (0.15.x Blender models):
sky_a, sky_b, sky_c, sky_d (Baku-style glass towers), mall_a, mall_b,
parking, car_a, car_b, car_c (purple Baku cab), billboard, planter.

  blender --background --factory-startup --python tools/blender/downtown_props.py -- --bake-res 4096 --tex-res 2048
Footprints, heights (16 floors x 3.6 m) and the +Z front follow CityKit so
DowntownDecor placement, the mall sign Label3Ds, occluders and the AoMap stay
valid. orm alpha = glass (prop_baked lights a random share of window cells at
night), albedo alpha = stone.
"""

import math
import os
import sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from kart_common import *  # noqa: F401,F403
import kart_common as K
from mathutils import Vector, Matrix, Euler, Quaternion

PALETTE = {
    "glass": ("3D7FC4", 0.08, 0.6), "glass_teal": ("2FA3A8", 0.08, 0.6), "glass_gold": ("D9A441", 0.1, 0.8),
    "glass_violet": ("6F5BD9", 0.08, 0.6), "glass_dark": ("1E2A3A", 0.1, 0.4),
    "white": ("F4F2EC", 0.55, 0.0), "steel": ("9AA0A8", 0.35, 0.8), "concrete": ("C9C4BA", 0.85, 0.0),
    "navy": ("1B2A4A", 0.5, 0.2), "red": ("E0344B", 0.5, 0.0), "orange": ("F07A2A", 0.5, 0.0),
    "purple": ("8B5CF6", 0.5, 0.0), "pastel_yellow": ("F6E3A1", 0.7, 0.0), "gold": ("E8B84A", 0.3, 1.0),
    "hedge": ("4FA04A", 0.9, 0.0), "asphalt": ("3A3A40", 0.9, 0.0), "paint_white": ("F2F2F0", 0.7, 0.0),
    "paint_yellow": ("FFD23F", 0.7, 0.0), "tire": ("2B2830", 0.85, 0.0), "chrome": ("DDE1E6", 0.12, 1.0),
    "car_red": ("D7263D", 0.3, 0.5), "car_blue": ("2F74C9", 0.3, 0.5), "cab_purple": ("6B3FA0", 0.3, 0.5),
    "lamp_lens": ("FFF3C0", 0.15, 0.0), "tail_lens": ("C0182C", 0.2, 0.0), "turquoise": ("1FB5B0", 0.6, 0.0),
    "trunk": ("8A6A4A", 0.9, 0.0), "leaf": ("5AA34A", 0.85, 0.0), "limestone": ("D9C29A", 0.85, 0.0),
}
PAINT_MAT = ["glass", "glass_teal", "glass_gold", "glass_violet"]  # every glass: grid + night windows
STONE = ["limestone"]
GROUPS = ["sky_a", "sky_b", "sky_c", "sky_d", "mall_a", "mall_b", "parking", "car_a", "car_b", "car_c", "billboard",
          "planter"]
UV_SCALE = {"sky_a": 0.55, "sky_b": 0.55, "sky_c": 0.55, "sky_d": 0.55, "mall_a": 0.7, "mall_b": 0.7, "parking": 0.5,
            "car_a": 1.6, "car_b": 1.6, "car_c": 1.6, "billboard": 1.4, "planter": 1.2}
FAR_RATIO = {g: 0.4 for g in GROUPS}
FLOOR_H, FLOORS = 3.6, 16
TH = FLOOR_H * FLOORS
LEAVES = {"leaf": 3.0, "hedge": 5.0}


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


def grid_lines(name, g, x0, x1, y0, y1, z, normal, dx, dy, mat="white", r=0.12):
    """High model: mullion / floor grid on a flat facade (baked)."""
    n = Vector(normal)
    side = Vector((0, 1, 0)).cross(n).normalized()
    origin = lambda u, v: side * u + Vector((0, v, 0)) + n * z
    k = 0
    u = x0
    while u <= x1 + 1e-3:
        tube(f"{name}_v{k}", [origin(u, y0), origin(u, y1)], r, mat, g, True, 1, 4, False)
        u += dx
        k += 1
    v = y0
    while v <= y1 + 1e-3:
        tube(f"{name}_h{k}", [origin(x0, v), origin(x1, v)], r, mat, g, True, 1, 4, False)
        v += dy
        k += 1


def box_grid(name, g, w, d, y0, y1, cx=0.0, cz=0.0, dx=1.8, mat="white"):
    for nrm, half_w, half_d in (((0, 0, 1), w, d), ((0, 0, -1), w, d), ((1, 0, 0), d, w), ((-1, 0, 0), d, w)):
        n = Vector(nrm)
        grid_lines(f"{name}{nrm}", g, -half_w * 0.5 + 0.3, half_w * 0.5 - 0.3, y0 + 0.2, y1 - 0.2,
                   half_d * 0.5 + 0.06, n, dx, FLOOR_H, mat)
        if cx or cz:
            pass


def lobby(name, g, w, fz, hi):
    tag = "H" if hi else "L"
    bbox(f"{name}_canopy_{tag}", (w * 0.45, 0.45, 3.2), (0, 4.3, fz + 1.6), "navy", g, hi, L(hi, 0.0, 0.08))
    bbox(f"{name}_doors_{tag}", (w * 0.3, 3.6, 0.3), (0, 1.8, fz + 0.1), "glass_dark", g, hi, 0.0)


def roof(name, g, w, d, y, hi, antenna):
    tag = "H" if hi else "L"
    bbox(f"{name}_parapet_{tag}", (w + 0.6, 1.4, d + 0.6), (0, y + 0.7, 0), "white", g, hi, L(hi, 0.0, 0.1))
    bbox(f"{name}_plant_{tag}", (w * 0.45, 3.0, d * 0.4), (0, y + 2.4, 0), "concrete", g, hi, L(hi, 0.0, 0.1))
    if antenna:
        tube(f"{name}_ant_{tag}", [(0, y + 3.9, 0), (0, y + 15.0, 0)], 0.3, "steel", g, hi, 1, L(hi, 6, 12))
        ellipsoid(f"{name}_beacon_{tag}", (0.6, 0.6, 0.6), (0, y + 15.2, 0), "red", g, hi, L(hi, (6, 4), (16, 10)))


def build_sky_a(hi):
    """Square glass tower with white corner fins, a stepped crown and antenna."""
    tag = "H" if hi else "L"
    g = "sky_a"
    w = 22.0
    bbox(f"a_body_{tag}", (w, TH, w), (0, TH * 0.5, 0), "glass", g, hi, L(hi, 0.0, 0.2))
    for sx in (-1, 1):
        for sz in (-1, 1):
            bbox(f"a_fin{sx}{sz}_{tag}", (1.2, TH + 2.0, 1.2), (sx * w * 0.5, (TH + 2.0) * 0.5, sz * w * 0.5), "white",
                 g, hi, L(hi, 0.0, 0.15))
    bbox(f"a_crown_{tag}", (w - 4.0, 3.0, w - 4.0), (0, TH + 1.5, 0), "glass", g, hi, L(hi, 0.0, 0.15))
    roof("a", g, w - 6.0, w - 6.0, TH + 3.0, hi, True)
    lobby("a", g, w, w * 0.5, hi)
    if hi:
        box_grid("a_grid", g, w, w, 6.0, TH)


def build_sky_b(hi):
    """Teal setback tower: lower block, roof garden, upper block turned a little."""
    tag = "H" if hi else "L"
    g = "sky_b"
    low_h = 12 * FLOOR_H
    bbox(f"b_low_{tag}", (26.0, low_h, 20.0), (0, low_h * 0.5, 0), "glass_teal", g, hi, L(hi, 0.0, 0.2))
    bbox(f"b_terrace_{tag}", (26.6, 0.7, 20.6), (0, low_h + 0.35, 0), "white", g, hi, L(hi, 0.0, 0.1))
    bbox(f"b_garden_{tag}", (22.0, 0.8, 4.0), (0, low_h + 1.1, 7.0), "hedge", g, hi, L(hi, 0.0, 0.2))
    up_h = TH - low_h
    bbox(f"b_up_{tag}", (17.0, up_h, 13.0), (0, low_h + up_h * 0.5, -2.5), "glass_teal", g, hi, L(hi, 0.0, 0.2),
         rot=(0, 0.12, 0))
    bbox(f"b_cap_{tag}", (17.6, 1.4, 13.6), (0, TH + 0.7, -2.5), "white", g, hi, L(hi, 0.0, 0.1), rot=(0, 0.12, 0))
    lobby("b", g, 26.0, 10.0, hi)
    if hi:
        box_grid("b_grid", g, 26.0, 20.0, 6.0, low_h)
        for k in range(10):
            ellipsoid(f"b_shrub{k}", (0.9, 0.7, 0.9), (-9.0 + k * 2.0, low_h + 1.7, 7.0), "hedge", g, True, (12, 8))


def build_sky_c(hi):
    """Twisted gold-glass tower (SOCAR-like) with a crown ring and spire."""
    tag = "H" if hi else "L"
    g = "sky_c"
    lv, n = L(hi, 12, 48), L(hi, 16, 48)
    rings = []
    for i in range(lv + 1):
        y = TH * i / lv
        t = y / TH
        s = 1.0 - 0.18 * t
        rot = 0.7 * t
        ring = []
        for k in range(n):
            a = 2 * math.pi * k / n
            x, z = math.cos(a) * 12.0 * s, math.sin(a) * 9.5 * s
            ring.append(Vector((x * math.cos(rot) - z * math.sin(rot), y, x * math.sin(rot) + z * math.cos(rot))))
        rings.append(ring)
    bm = bmesh.new()
    rows = [[bm.verts.new(p) for p in r] for r in rings]
    for i in range(lv):
        for k in range(n):
            bm.faces.new((rows[i][k], rows[i][(k + 1) % n], rows[i + 1][(k + 1) % n], rows[i + 1][k]))
    bm.faces.new(list(reversed(rows[0])))
    bm.faces.new(rows[-1])
    K.finish(bm, f"c_body_{tag}", "glass_gold", g, hi, smooth=True)
    lathe(f"c_crown_{tag}", [(0.0, 10.4), (1.4, 10.4), (6.0, 2.0), (7.0, 0.0)], (0, 0, 0), "gold", g, hi, L(hi, 16, 48)
          ).data.transform(K.trs((0, TH, 0), (0, 0, math.pi / 2)))
    tube(f"c_spire_{tag}", [(0, TH + 7.0, 0), (0, TH + 18.0, 0)], 0.35, "steel", g, hi, 1, L(hi, 6, 12))
    lobby("c", g, 22.0, 9.5, hi)
    if hi:
        for i in range(1, FLOORS):
            y = i * FLOOR_H
            t = y / TH
            s, rot = 1.0 - 0.18 * t, 0.7 * t
            pts = []
            for k in range(49):
                a = 2 * math.pi * k / 48
                x, z = math.cos(a) * (12.0 * s + 0.08), math.sin(a) * (9.5 * s + 0.08)
                pts.append(Vector((x * math.cos(rot) - z * math.sin(rot), y, x * math.sin(rot) + z * math.cos(rot))))
            tube(f"c_floor{i}", pts, 0.12, "white", g, True, 1, 4, False)


def build_sky_d(hi):
    """Violet glass slab with a sloped top and white vertical fins."""
    tag = "H" if hi else "L"
    g = "sky_d"
    w, d = 34.0, 15.0
    bm = bmesh.new()
    pts = [(-w / 2, 0), (w / 2, 0), (w / 2, TH - 8.0), (-w / 2, TH + 6.0)]
    fr = [bm.verts.new((x, y, d / 2)) for x, y in pts]
    bk = [bm.verts.new((x, y, -d / 2)) for x, y in pts]
    bm.faces.new(fr)
    bm.faces.new(list(reversed(bk)))
    for k in range(4):
        j = (k + 1) % 4
        bm.faces.new((fr[j], fr[k], bk[k], bk[j]))
    K.finish(bm, f"d_body_{tag}", "glass_violet", g, hi, smooth=False)
    for i in range(5):
        x = -w * 0.5 + 3.0 + i * (w - 6.0) / 4.0
        top = TH - 8.0 + (w / 2 - x) / w * 14.0
        for s in (-1, 1):
            bbox(f"d_fin{i}{s}_{tag}", (0.6, top + 1.0, 1.0), (x, (top + 1.0) * 0.5, s * (d * 0.5 + 0.4)), "white", g, hi,
                 L(hi, 0.0, 0.1))
    lobby("d", g, w, d * 0.5 + 0.9, hi)
    if hi:
        grid_lines("d_gf", g, -w / 2 + 0.3, w / 2 - 0.3, 6.0, TH - 8.5, d / 2 + 0.06, (0, 0, 1), 1.8, FLOOR_H)
        grid_lines("d_gb", g, -w / 2 + 0.3, w / 2 - 0.3, 6.0, TH - 8.5, d / 2 + 0.06, (0, 0, -1), 1.8, FLOOR_H)


def build_mall(v, hi):
    tag = "H" if hi else "L"
    g = "mall_a" if v == 0 else "mall_b"
    w, d, h = 64.0, 36.0, 16.0
    body = "white" if v == 0 else "pastel_yellow"
    accent = "red" if v == 0 else "purple"
    bbox(f"m{v}_body_{tag}", (w, h, d), (0, h * 0.5, 0), body, g, hi, L(hi, 0.0, 0.3))
    bbox(f"m{v}_front_{tag}", (w - 10.0, 11.0, 0.6), (0, 6.0, d * 0.5 + 0.2), "glass", g, hi, 0.0)
    bbox(f"m{v}_sign_{tag}", (w * 0.62, 3.6, 0.8), (0, h - 0.6, d * 0.5 + 0.5), accent, g, hi, L(hi, 0.0, 0.15))
    bbox(f"m{v}_doors_{tag}", (12.0, 5.0, 0.4), (0, 2.5, d * 0.5 + 0.6), "glass_dark", g, hi, 0.0)
    bbox(f"m{v}_canopy_{tag}", (16.0, 0.6, 6.0), (0, 5.6, d * 0.5 + 3.2), accent, g, hi, L(hi, 0.0, 0.1))
    for s in (-1, 1):
        tube(f"m{v}_pillar{s}_{tag}", [(s * 7.2, 0.0, d * 0.5 + 5.8), (s * 7.2, 5.4, d * 0.5 + 5.8)], 0.35, "white", g, hi,
             1, L(hi, 8, 16))
        bbox(f"m{v}_stripe{s}_{tag}", (0.6, h, d * 0.8), (s * (w * 0.5 + 0.25), h * 0.5, 0), accent, g, hi, 0.0)
    if v == 1:
        lathe(f"m{v}_rot_{tag}", [(0.0, 8.0), (h + 3.0, 8.0), (h + 3.0, 0.0)], (0, 0, 0), "glass", g, hi, L(hi, 16, 48)
              ).data.transform(K.trs((w * 0.5 - 6.0, 0, d * 0.5 - 2.0), (0, 0, math.pi / 2)))
        lathe(f"m{v}_rotcap_{tag}", [(0.0, 8.6), (0.8, 8.6), (0.8, 0.0)], (0, 0, 0), "white", g, hi, L(hi, 16, 48)
              ).data.transform(K.trs((w * 0.5 - 6.0, h + 2.8, d * 0.5 - 2.0), (0, 0, math.pi / 2)))
    for i in range(3):
        bbox(f"m{v}_unit{i}_{tag}", (5.0, 2.2, 4.0), (-16 + i * 16, h + 1.1, -6), "steel", g, hi, L(hi, 0.0, 0.08))
    if hi:
        grid_lines(f"m{v}_gl", g, -(w - 10.0) / 2 + 0.2, (w - 10.0) / 2 - 0.2, 0.6, 11.4, d * 0.5 + 0.56, (0, 0, 1), 2.4, 5.0,
                   "steel", 0.1)


def build_parking(hi):
    tag = "H" if hi else "L"
    g = "parking"
    bbox(f"p_lot_{tag}", (40.0, 0.14, 24.0), (0, 0.07, 0), "asphalt", g, hi, 0.0)
    for row in (-1, 1):
        for i in range(11):
            bbox(f"p_bay{row}{i}_{tag}", (0.18, 0.03, 5.2), (-17.5 + i * 3.5, 0.155, row * 8.6), "paint_white", g, hi, 0.0)
    bbox(f"p_mid_{tag}", (36.0, 0.03, 0.2), (0, 0.155, 0), "paint_yellow", g, hi, 0.0)
    tube(f"p_pole_{tag}", [(0, 0.0, 0), (0, 6.0, 0)], 0.1, "steel", g, hi, 1, L(hi, 6, 12))
    bbox(f"p_head_{tag}", (1.6, 0.25, 0.5), (0, 6.0, 0), "steel", g, hi, L(hi, 0.0, 0.05))


def build_car(g, body, hi, cab=False):
    tag = "H" if hi else "L"

    def body_def(p, n):
        return Vector((p.x, p.y * (1 - 0.25 * max(0.0, n.z) ** 2), p.z))
    superellipsoid(f"{g}_body_{tag}", (0.95, 0.4, 2.1), (0, 0.66, 0), body, g, hi, (0.35, 0.45), L(hi, (8, 6), (32, 16)),
                   deform=body_def)
    superellipsoid(f"{g}_cabin_{tag}", (0.8, 0.36, 1.15 if not cab else 1.25), (0, 1.3, -0.15 if not cab else 0.0),
                   "glass_dark", g, hi, (0.4, 0.5), L(hi, (8, 5), (28, 12)))
    if cab:
        superellipsoid(f"{g}_roof_{tag}", (0.82, 0.08, 1.2), (0, 1.66, 0.0), body, g, hi, (0.4, 0.5), L(hi, (8, 3), (24, 8)))
        bbox(f"{g}_sign_{tag}", (0.5, 0.18, 0.2), (0, 1.8, -0.3), "lamp_lens", g, hi, L(hi, 0.0, 0.03))
    for x in (-0.88, 0.88):
        for z in (-1.35, 1.35):
            lathe(f"{g}_wheel{x}{z}_{tag}", [(-0.15, 0.2), (-0.15, 0.36), (0.15, 0.36), (0.15, 0.2)], (x, 0.36, z), "tire",
                  g, hi, L(hi, 8, 24))
            lathe(f"{g}_hub{x}{z}_{tag}", [(0.0, 0.2), (0.0, 0.0)] if x > 0 else [(0.0, 0.0), (0.0, 0.2)],
                  (x + (0.151 if x > 0 else -0.151), 0.36, z), "chrome", g, hi, L(hi, 8, 24),
                  outward=lambda p, s=x: Vector((1.0 if s > 0 else -1.0, 0, 0)))
    for s in (-1, 1):
        ellipsoid(f"{g}_head{s}_{tag}", (0.16, 0.1, 0.05), (s * 0.6, 0.72, -2.08), "lamp_lens", g, hi, L(hi, (6, 4), (16, 8)))
        ellipsoid(f"{g}_tail{s}_{tag}", (0.16, 0.08, 0.05), (s * 0.62, 0.78, 2.08), "tail_lens", g, hi, L(hi, (6, 4), (16, 8)))


def build_billboard(hi):
    tag = "H" if hi else "L"
    g = "billboard"
    for x in (-3.0, 3.0):
        tube(f"bb_post{x}_{tag}", [(x, 0.0, 0), (x, 6.0, 0)], 0.22, "steel", g, hi, 1, L(hi, 8, 16))
    bbox(f"bb_frame_{tag}", (9.4, 4.4, 0.4), (0, 7.6, 0), "white", g, hi, L(hi, 0.0, 0.08))
    board = bbox(f"bb_board_{tag}", (8.8, 3.8, 0.2), (0, 7.6, 0.18), "turquoise", g, hi, 0.0)
    if hi:
        m = facing((0, 7.6, 0.285), (0, 0, 1))
        decal("bb_band", [(-4.4, -1.9), (4.4, -1.9), (4.4, -0.85), (-4.4, -0.85)], m, "paint_yellow", g, board, 0.003, 2)
        text_decal("bb_text", "BAKI", 1.6, m @ Matrix.Translation(Vector((1.0, 0.35, 0))), "white", g, board, 0.005)
        # Flame Towers logo.
        for k, (x, hgt) in enumerate(((-3.2, 2.4), (-2.6, 2.0), (-2.0, 1.8))):
            decal(f"bb_flame{k}", [(-0.3, 0), (0.3, 0), (0.05, hgt)], m @ Matrix.Translation(Vector((x, -1.4, 0))),
                  "glass", g, board, 0.004, 2)


def build_planter(hi):
    tag = "H" if hi else "L"
    g = "planter"
    bbox(f"pl_box_{tag}", (2.4, 0.6, 2.4), (0, 0.3, 0), "limestone", g, hi, L(hi, 0.0, 0.06))
    tube(f"pl_trunk_{tag}", [(0, 0.5, 0), (0, 2.8, 0)], 0.16, "trunk", g, hi, 1, L(hi, 6, 12))
    superellipsoid(f"pl_crown_{tag}", (1.3, 1.2, 1.3), (0, 3.3, 0), "leaf", g, hi, (1.0, 1.0), L(hi, (8, 6), (32, 20)))


BUILDERS = {"sky_a": build_sky_a, "sky_b": build_sky_b, "sky_c": build_sky_c, "sky_d": build_sky_d,
            "mall_a": lambda hi: build_mall(0, hi), "mall_b": lambda hi: build_mall(1, hi), "parking": build_parking,
            "car_a": lambda hi: build_car("car_a", "car_red", hi), "car_b": lambda hi: build_car("car_b", "car_blue", hi),
            "car_c": lambda hi: build_car("car_c", "cab_purple", hi, cab=True), "billboard": build_billboard,
            "planter": build_planter}
OFFSET = {g: Vector((i * 90.0, 0.0, 0.0)) for i, g in enumerate(GROUPS)}
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
K.CAGE, K.RAY, K.AO_DIST = 0.3, 0.6, 2.0
K.setup("downtown_props", "assets/models/downtown", PALETTE, PAINT_MAT, GROUPS, UV_SCALE, FAR_RATIO, stone_mats=STONE)
K.run(build)
