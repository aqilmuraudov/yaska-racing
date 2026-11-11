"""Laçın town fill (0.20.1 Blender models, after the owner's two aerial photos of the town).

  blender --background --factory-startup --python tools/blender/karabakh_lachin_town.py -- --bake-res 2048 --tex-res 1024
Same pipeline as the other prop sets (kart_common.run). Frame: x along the
street, y up, +z towards the street (front), origin on the pad.
The rebuilt Laçın from the air: white rendered houses with terracotta hipped
roofs (a few dark grey ones), two and three storeys, some with solar panels,
long white four-storey blocks, gardens and cypresses between the houses.
  kb_lc_house_1  one storey, porch on posts, front garden wall      plot 12 x 10
  kb_lc_house_2  two storeys, a balcony over the door                plot 12 x 11
  kb_lc_house_3  two storeys and a lower wing, dark grey roof, solar plot 13 x 11
  kb_lc_house_4  three storeys, narrow and tall (the white towers)   plot 12 x 13
  kb_lc_block    four-storey block of flats, balconies              plot 28 x 14
  kb_lc_round    roundabout island: kerb, lawn, flowers, a cypress  d 13
  kb_cypress     a cypress (the dark spires between the houses)
Many instances (MultiMesh): every model stays low-poly.
"""

import math
import os
import sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from kart_common import *  # noqa: F401,F403
import kart_common as K
import bmesh
from mathutils import Matrix
import kb_shapes as S

PALETTE = {
    "wall_white": ("F1EEE6", 0.85, 0.0),
    "wall_cream": ("ECE2CC", 0.85, 0.0),
    "plinth": ("A9A193", 0.9, 0.0),
    "roof_tile": ("CC5A2C", 0.7, 0.0),
    "roof_dark": ("4B5059", 0.55, 0.2),
    "solar": ("1F3354", 0.15, 0.4),
    "glass": ("3E6A8E", 0.08, 0.3),
    "frame": ("3A3D42", 0.4, 0.6),
    "wood": ("8A5A36", 0.7, 0.0),
    "paving": ("C8C1B2", 0.85, 0.0),
    "grass": ("5E8F3A", 0.95, 0.0),
    "leaf": ("4C7A2E", 0.9, 0.0),
    "cypress": ("2F4D27", 0.9, 0.0),
    "trunk": ("6B4A32", 0.9, 0.0),
    "flower": ("D6457A", 0.8, 0.0),
    "kerb": ("D9D6CF", 0.8, 0.0),
    "rail": ("E9E7E1", 0.5, 0.0),
}
PAINT_MAT = "glass"
LOOK = {"wall_white": "plain", "wall_cream": "plain", "plinth": "cut", "roof_tile": "tile", "roof_dark": "plain",
        "paving": "paving", "grass": "grass", "leaf": "grass", "cypress": "grass", "wood": "plain"}
GROUPS = ["kb_lc_house_1", "kb_lc_house_2", "kb_lc_house_3", "kb_lc_house_4", "kb_lc_block", "kb_lc_round",
          "kb_cypress"]
UV_SCALE = {g: 1.0 for g in GROUPS}
FAR_RATIO = {g: 0.4 for g in GROUPS}
F = S.FOUND
_looked = False


def hip_roof(g, tag, hi, name, x0, x1, z0, z1, y, rise, mat, over=0.55):
    """Hipped roof with a ridge along the longer side (a pyramid on a square plan)."""
    x0, x1, z0, z1 = x0 - over, x1 + over, z0 - over, z1 + over
    bm = bmesh.new()
    t = 0.14
    if (x1 - x0) >= (z1 - z0):
        r = (z1 - z0) / 2
        a, b = (x0 + r, y + rise, (z0 + z1) / 2), (x1 - r, y + rise, (z0 + z1) / 2)
    else:
        r = (x1 - x0) / 2
        a, b = ((x0 + x1) / 2, y + rise, z1 - r), ((x0 + x1) / 2, y + rise, z0 + r)
    e = [bm.verts.new(p) for p in ((x0, y, z0), (x1, y, z0), (x1, y, z1), (x0, y, z1))]
    lo = [bm.verts.new((p.co.x, p.co.y - t, p.co.z)) for p in e]
    va, vb = bm.verts.new(a), bm.verts.new(b)
    if (x1 - x0) >= (z1 - z0):
        faces = [(e[0], va, vb, e[1]), (e[1], vb, e[2]), (e[2], vb, va, e[3]), (e[3], va, e[0])]
    else:
        faces = [(e[0], vb, e[1]), (e[1], vb, va, e[2]), (e[2], va, e[3]), (e[3], va, vb, e[0])]
    for f in faces:
        bm.faces.new(f)
    for i in range(4):          # the eave edge and the soffit
        j = (i + 1) % 4
        bm.faces.new((e[i], e[j], lo[j], lo[i]))
    bm.faces.new(list(reversed(lo)))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return K.finish(bm, f"{g}_{name}_{tag}", mat, g, hi, smooth=False)


def roof_slope_y(y, rise, z_eave, z_ridge, z):
    return y + rise * (z_eave - z) / (z_eave - z_ridge)


def solar_panel(g, tag, hi, name, x0, x1, y, rise, z_eave, z_ridge):
    """A panel row lying on a front roof slope (eave at z_eave, ridge at z_ridge)."""
    za, zb = z_ridge + 1.0, z_eave - 0.6
    ya, yb = roof_slope_y(y, rise, z_eave, z_ridge, za), roof_slope_y(y, rise, z_eave, z_ridge, zb)
    prof = [(za, ya + 0.08), (zb, yb + 0.08), (zb, yb + 0.2), (za, ya + 0.2)]
    S.extrude(f"{g}_{name}_{tag}", prof, x0, x1, "solar", g, hi,
              matrix=Matrix(((0, 0, 1, 0), (0, 1, 0, 0), (1, 0, 0, 0), (0, 0, 0, 1))))


def windows(g, tag, hi, x0, x1, y, z, w=1.3, h=1.5, pitch=2.6, skip=None):
    n = max(1, int((x1 - x0) // pitch))
    start = (x0 + x1) / 2 - (n - 1) * pitch / 2
    for i in range(n):
        x = start + i * pitch
        if skip and skip[0] < x < skip[1]:
            continue
        S.box(f"{g}_w{i}_{y:.0f}_{z:.0f}_{tag}", (w, h, 0.1), (x, y, z), "glass", g, hi, bevel=0.0)


def side_windows(g, tag, hi, x, z0, z1, y, pitch=2.8):
    n = max(1, int((z1 - z0) // pitch))
    for i in range(n):
        z = (z0 + z1) / 2 - (n - 1) * pitch / 2 + i * pitch
        S.box(f"{g}_sw{x:.0f}_{i}_{y:.0f}_{tag}", (0.1, 1.4, 1.2), (x, y, z), "glass", g, hi, bevel=0.0)


def plot(g, tag, hi, w, d, wall=True):
    S.slab(f"{g}_plinth_{tag}", -w / 2, w / 2, -F, 0.25, -d / 2, d / 2, "paving", g, hi, bevel=0.0)
    S.slab(f"{g}_garden_{tag}", -w / 2 + 0.2, w / 2 - 0.2, 0.25, 0.3, -d / 2 + 0.2, d / 2 - 0.2, "grass", g, hi,
           bevel=0.0)
    if wall:     # low white garden wall on the street side, a gap for the gate
        for sx in (-1, 1):
            S.slab(f"{g}_gw{sx}_{tag}", min(sx * 1.0, sx * (w / 2 - 0.2)), max(sx * 1.0, sx * (w / 2 - 0.2)), 0.3,
                   1.0, d / 2 - 0.45, d / 2 - 0.2, "rail", g, hi, bevel=0.0)


def body(g, tag, hi, x0, x1, z0, z1, floors, wall="wall_white", y0=0.3):
    h = y0 + 0.6 + floors * 3.0
    S.slab(f"{g}_socle_{tag}", x0 - 0.05, x1 + 0.05, y0, y0 + 0.6, z0 - 0.05, z1 + 0.05, "plinth", g, hi)
    S.slab(f"{g}_body_{tag}", x0, x1, y0 + 0.6, h, z0, z1, wall, g, hi)
    for f in range(floors):
        yy = y0 + 0.6 + 1.6 + f * 3.0
        windows(g, tag, hi, x0 + 0.5, x1 - 0.5, yy, z1 + 0.05, skip=(-0.9, 0.9) if f == 0 else None)
        windows(g, tag, hi, x0 + 0.5, x1 - 0.5, yy, z0 - 0.05)
        side_windows(g, tag, hi, x0 - 0.05, z0 + 0.5, z1 - 0.5, yy)
        side_windows(g, tag, hi, x1 + 0.05, z0 + 0.5, z1 - 0.5, yy)
    S.box(f"{g}_door_{tag}", (1.2, 2.2, 0.12), (0.0, y0 + 0.6 + 1.1, z1 + 0.06), "wood", g, hi, bevel=0.0)
    return h


def build_house_1(hi):
    tag = "H" if hi else "L"
    g = "kb_lc_house_1"
    plot(g, tag, hi, 12.0, 10.0)
    x0, x1, z0, z1 = -4.5, 4.5, -4.5, 1.5
    h = body(g, tag, hi, x0, x1, z0, z1, 1)
    hip_roof(g, tag, hi, "roof", x0, x1, z0, z1 + 1.6, h, 2.3, "roof_tile")
    S.slab(f"{g}_porch_{tag}", -3.0, 3.0, 0.3, 0.5, z1, z1 + 1.6, "paving", g, hi, bevel=0.0)
    for sx in (-1, 1):
        S.slab(f"{g}_post{sx}_{tag}", sx * 2.7 - 0.12, sx * 2.7 + 0.12, 0.5, h, z1 + 1.3, z1 + 1.55, "rail", g, hi,
               bevel=0.0)


def build_house_2(hi):
    tag = "H" if hi else "L"
    g = "kb_lc_house_2"
    plot(g, tag, hi, 12.0, 11.0)
    x0, x1, z0, z1 = -4.8, 4.8, -5.0, 2.2
    h = body(g, tag, hi, x0, x1, z0, z1, 2)
    hip_roof(g, tag, hi, "roof", x0, x1, z0, z1, h, 2.6, "roof_tile")
    S.slab(f"{g}_balc_{tag}", -2.2, 2.2, 3.7, 3.9, z1, z1 + 1.2, "wall_white", g, hi, bevel=0.0)
    S.slab(f"{g}_brail_{tag}", -2.2, 2.2, 3.9, 4.8, z1 + 1.1, z1 + 1.2, "rail", g, hi, bevel=0.0)


def build_house_3(hi):
    tag = "H" if hi else "L"
    g = "kb_lc_house_3"
    plot(g, tag, hi, 13.0, 11.0)
    x0, x1, z0, z1 = -5.5, 2.0, -5.0, 2.0
    h = body(g, tag, hi, x0, x1, z0, z1, 2, wall="wall_cream")
    hip_roof(g, tag, hi, "roof", x0, x1, z0, z1, h, 2.4, "roof_dark")
    solar_panel(g, tag, hi, "solar", x0 + 2.4, x1 - 2.4, h, 2.4, z1 + 0.55, (z0 + z1) / 2)
    # the lower wing (garage / kitchen) with a flat-ish roof
    S.slab(f"{g}_wing_{tag}", 2.0, 5.6, 0.3, 3.4, -3.5, 1.5, "wall_white", g, hi)
    hip_roof(g, tag, hi, "wingroof", 2.0, 5.6, -3.5, 1.5, 3.4, 1.0, "roof_dark", over=0.35)
    S.box(f"{g}_gate_{tag}", (2.6, 2.3, 0.1), (3.8, 1.5, 1.56), "frame", g, hi, bevel=0.0)


def build_house_4(hi):
    tag = "H" if hi else "L"
    g = "kb_lc_house_4"
    plot(g, tag, hi, 12.0, 13.0, wall=False)
    x0, x1, z0, z1 = -4.5, 4.5, -5.8, 3.2
    h = body(g, tag, hi, x0, x1, z0, z1, 3)
    hip_roof(g, tag, hi, "roof", x0, x1, z0, z1, h, 2.8, "roof_tile")
    S.slab(f"{g}_band_{tag}", x0 - 0.08, x1 + 0.08, h - 0.35, h, z0 - 0.08, z1 + 0.08, "plinth", g, hi, bevel=0.0)


def build_block(hi):
    tag = "H" if hi else "L"
    g = "kb_lc_block"
    S.slab(f"{g}_plinth_{tag}", -14, 14, -F, 0.25, -7, 7, "paving", g, hi, bevel=0.0)
    S.slab(f"{g}_lawn_{tag}", -13.6, 13.6, 0.25, 0.3, 3.4, 6.6, "grass", g, hi, bevel=0.0)
    x0, x1, z0, z1 = -12.5, 12.5, -5.0, 3.0
    h = body(g, tag, hi, x0, x1, z0, z1, 4)
    hip_roof(g, tag, hi, "roof", x0, x1, z0, z1, h, 2.8, "roof_tile")
    for f in range(1, 4):           # balconies on the front, two bays per side of the stair
        y = 0.9 + f * 3.0
        for bx in (-8.5, -3.8, 3.8, 8.5):
            S.slab(f"{g}_b{f}{bx:.0f}_{tag}", bx - 1.7, bx + 1.7, y - 0.15, y + 0.05, z1, z1 + 1.1, "wall_white", g, hi,
                   bevel=0.0)
            S.slab(f"{g}_br{f}{bx:.0f}_{tag}", bx - 1.7, bx + 1.7, y + 0.05, y + 1.0, z1 + 1.0, z1 + 1.1, "rail", g,
                   hi, bevel=0.0)
    S.slab(f"{g}_canopy_{tag}", -1.6, 1.6, 3.0, 3.2, z1, z1 + 1.4, "frame", g, hi, bevel=0.0)


def cypress(g, tag, hi, name, x, z, height, r):
    S.cylinder(f"{g}_{name}t_{tag}", 0.14, 0.0, 0.8, (x, z), "trunk", g, hi, seg=(4, 6))
    S.cylinder(f"{g}_{name}c_{tag}", r, 0.6, height * 0.55, (x, z), "cypress", g, hi, seg=(5, 8), r_top=r * 0.92)
    S.cone(f"{g}_{name}k_{tag}", r * 0.92, height * 0.55, height, (x, z), "cypress", g, hi, seg=(5, 8))


def build_round(hi):
    tag = "H" if hi else "L"
    g = "kb_lc_round"
    S.cylinder(f"{g}_kerb_{tag}", 6.5, -F, 0.35, (0.0, 0.0), "kerb", g, hi, seg=(16, 32))
    S.cylinder(f"{g}_lawn_{tag}", 6.1, 0.35, 0.45, (0.0, 0.0), "grass", g, hi, seg=(16, 32))
    S.cylinder(f"{g}_bed_{tag}", 3.0, 0.45, 0.7, (0.0, 0.0), "flower", g, hi, seg=(10, 20))
    cypress(g, tag, hi, "c0", 0.0, 0.0, 7.5, 0.9)
    for k in range(4):
        a = math.pi / 4 + k * math.pi / 2
        S.tree_ball(f"{g}_sh{k}_{tag}", (4.4 * math.cos(a), 0.9, 4.4 * math.sin(a)), 0.7, "leaf", g, hi, k)


def build_cypress(hi):
    tag = "H" if hi else "L"
    cypress("kb_cypress", tag, hi, "c", 0.0, 0.0, 9.0, 0.95)


def build(hi):
    global _looked
    if not _looked:
        S.add_looks(LOOK)
        _looked = True
    _build(hi)


_build = S.run_set(GROUPS, {"kb_lc_house_1": build_house_1, "kb_lc_house_2": build_house_2,
                            "kb_lc_house_3": build_house_3, "kb_lc_house_4": build_house_4,
                            "kb_lc_block": build_block, "kb_lc_round": build_round, "kb_cypress": build_cypress}, 50.0)
K.CAGE, K.RAY, K.AO_DIST = 0.08, 0.2, 2.0
K.setup("karabakh_lachin_town", "assets/models/karabakh_lachin_town", PALETTE, PAINT_MAT, GROUPS, UV_SCALE, FAR_RATIO,
        stone_mats=["__no_stone__"])
K.run(build)
