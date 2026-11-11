"""Xankəndi town fill (0.20.2 Blender models, after modern photos of the town, 2024-2026).

  blender --background --factory-startup --python tools/blender/karabakh_khankendi_town.py -- --bake-res 4096 --tex-res 2048
Same pipeline as the other prop sets (kart_common.run). Frame: x along the
street, y up, +z towards the street (front), origin on the pad.
Xankəndi today (Wikimedia Commons, "Xankəndi, August 2024", "Streets in
Khankendi", 2026): a town of five-storey Soviet blocks in beige tuff with
balcony stacks, a few nine-storey towers, the new four-storey buildings of the
main avenue (cream walls, an arcade of arches on the ground floor, a dark
slate roof, an orange bay), white classical buildings with dark hipped roofs,
and old one / two storey stone houses with red and rust metal roofs behind
garden walls. Shown rebuilt and tidy (a children's game).
  kb_xk_block5   five-storey block of flats, tuff, balcony stacks, 3 doors   plot 34 x 15
  kb_xk_tower9   nine-storey tower, flat roof, two balcony stacks           plot 18 x 16
  kb_xk_new4     new four-storey avenue building, arcade, slate roof         plot 32 x 15
  kb_xk_villa    white two-storey classical house, portico, dark roof        plot 16 x 13
  kb_xk_house_1  old two-storey stone house, maroon gable roof, balcony      plot 12 x 11
  kb_xk_house_2  one-storey grey block house, rust hipped roof, garage       plot 12 x 10
Many instances (MultiMesh, full model at every distance): the windows of the
tall buildings are baked into the texture (high-poly only), the low-poly
keeps the walls, balconies and roofs.
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

SWAP_XZ = Matrix(((0, 0, 1, 0), (0, 1, 0, 0), (1, 0, 0, 0), (0, 0, 0, 1)))

PALETTE = {
    "tuff": ("C8AC84", 0.9, 0.0),          # the beige / ochre tuff of the Soviet blocks
    "tuff_light": ("DCC7A3", 0.9, 0.0),
    "panel": ("D6C6A6", 0.85, 0.0),        # the nine-storey towers
    "balc": ("BBA88A", 0.85, 0.0),
    "cream": ("EFE8DA", 0.85, 0.0),        # the new avenue buildings
    "accent": ("D8893A", 0.8, 0.0),        # their orange bay
    "white": ("F2F0EA", 0.8, 0.0),
    "plaster": ("D8C6B5", 0.9, 0.0),       # old houses: pinkish plaster
    "block_grey": ("ABA79D", 0.9, 0.0),    # old houses: grey concrete blocks
    "plinth": ("9C968A", 0.9, 0.0),
    "slate": ("41454C", 0.55, 0.2),        # dark roofs
    "roof_red": ("8C2E2A", 0.6, 0.3),      # maroon metal roofs
    "roof_rust": ("B0602E", 0.7, 0.2),     # rust metal roofs
    "flat_roof": ("6E6A64", 0.95, 0.0),
    "glass": ("3E6A8E", 0.08, 0.3),
    "shadow": ("2B2A28", 0.9, 0.0),        # deep arcade openings
    "frame": ("33363B", 0.4, 0.6),
    "wood": ("7E5232", 0.7, 0.0),
    "gate": ("6B2A26", 0.5, 0.5),
    "paving": ("C4BDAE", 0.85, 0.0),
    "grass": ("5E8F3A", 0.95, 0.0),
    "rail": ("E9E7E1", 0.5, 0.0),
}
PAINT_MAT = "glass"
LOOK = {"tuff": "plain", "tuff_light": "plain", "panel": "plain", "cream": "plain", "white": "plain",
        "plaster": "plain", "block_grey": "cut", "plinth": "cut", "paving": "paving", "grass": "grass",
        "roof_red": "plain", "roof_rust": "plain", "slate": "plain", "wood": "plain"}
GROUPS = ["kb_xk_block5", "kb_xk_tower9", "kb_xk_new4", "kb_xk_villa", "kb_xk_house_1", "kb_xk_house_2"]
UV_SCALE = {g: 1.0 for g in GROUPS}
FAR_RATIO = {g: 0.4 for g in GROUPS}
F = S.FOUND
FLOOR = 2.9
_looked = False


# --- Parts -----------------------------------------------------------------------------------

def hip_roof(g, tag, hi, name, x0, x1, z0, z1, y, rise, mat, over=0.55):
    """Hipped roof, the ridge along the longer side."""
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
    for i in range(4):
        j = (i + 1) % 4
        bm.faces.new((e[i], e[j], lo[j], lo[i]))
    bm.faces.new(list(reversed(lo)))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return K.finish(bm, f"{g}_{name}_{tag}", mat, g, hi, smooth=False)


def gable_roof(g, tag, hi, name, x0, x1, z0, z1, y, rise, mat, wall, over=0.45):
    """Gable roof, the ridge along x; the gable triangles in the wall material."""
    zm = (z0 + z1) / 2
    S.extrude(f"{g}_{name}_gab_{tag}", [(z0, y), (z1, y), (zm, y + rise)], x0, x1, wall, g, hi,
              matrix=SWAP_XZ)
    xa, xb, za, zb = x0 - over, x1 + over, z0 - over, z1 + over
    k = rise / ((z1 - z0) / 2)
    t = 0.12
    for sgn, ze in ((-1, za), (1, zb)):
        ye = y - k * (abs(ze - zm) - (z1 - z0) / 2)
        prof = [(ze, ye), (zm, y + rise), (zm, y + rise + t), (ze, ye + t)]
        if sgn < 0:
            prof = [prof[1], prof[0], prof[3], prof[2]]
        S.extrude(f"{g}_{name}_s{sgn}_{tag}", prof, xa, xb, mat, g, hi,
                  matrix=SWAP_XZ)


def windows(g, tag, hi, x0, x1, y, z, w=1.3, h=1.5, pitch=2.6, skip=None, depth=0.1):
    n = max(1, int((x1 - x0) // pitch))
    start = (x0 + x1) / 2 - (n - 1) * pitch / 2
    for i in range(n):
        x = start + i * pitch
        if skip and any(a < x < b for a, b in skip):
            continue
        S.box(f"{g}_w{i}_{y:.0f}_{z:.0f}_{tag}", (w, h, depth), (x, y, z), "glass", g, hi, bevel=0.0)


def side_windows(g, tag, hi, x, z0, z1, y, pitch=2.8, w=1.2, depth=0.1):
    n = max(1, int((z1 - z0) // pitch))
    for i in range(n):
        z = (z0 + z1) / 2 - (n - 1) * pitch / 2 + i * pitch
        S.box(f"{g}_sw{x:.0f}_{i}_{y:.0f}_{tag}", (depth, 1.4, w), (x, y, z), "glass", g, hi, bevel=0.0)


# Baked-only windows (the tall buildings): flush with the wall, well inside the bake cage (0.08 m),
# or the cage rays start inside the pane and the bake comes out as noise.
BW = 0.03


def pad(g, tag, hi, w, d, lawn=None):
    S.slab(f"{g}_pad_{tag}", -w / 2, w / 2, -F, 0.25, -d / 2, d / 2, "paving", g, hi, bevel=0.0)
    if lawn:
        S.slab(f"{g}_lawn_{tag}", lawn[0], lawn[1], 0.25, 0.3, lawn[2], lawn[3], "grass", g, hi, bevel=0.0)


def balcony(g, tag, hi, name, x, y, z, w, deep=1.1, mat="balc", glazed=False):
    """A projecting balcony on the front (+z) at floor level y: slab and a solid parapet."""
    S.slab(f"{g}_{name}_f_{tag}", x - w / 2, x + w / 2, y - 0.15, y + 0.05, z, z + deep, mat, g, hi, bevel=0.0)
    S.slab(f"{g}_{name}_p_{tag}", x - w / 2, x + w / 2, y + 0.05, y + 1.0, z + deep - 0.12, z + deep, mat, g, hi,
           bevel=0.0)
    if glazed and hi:
        S.box(f"{g}_{name}_g_{tag}", (w - 0.3, 1.2, 0.06), (x, y + 1.7, z + deep - 0.06), "glass", g, hi, bevel=0.0)


def flat_roof(g, tag, hi, x0, x1, z0, z1, y, wall):
    S.slab(f"{g}_roof_{tag}", x0, x1, y, y + 0.15, z0, z1, "flat_roof", g, hi, bevel=0.0)
    for name, a, b, c, d in (("pf", x0, x1, z1 - 0.25, z1), ("pb", x0, x1, z0, z0 + 0.25),
                             ("pl", x0, x0 + 0.25, z0, z1), ("pr", x1 - 0.25, x1, z0, z1)):
        S.slab(f"{g}_{name}_{tag}", a, b, y, y + 0.7, c, d, wall, g, hi, bevel=0.0)


# --- Buildings -------------------------------------------------------------------------------

def build_block5(hi):
    """Five-storey Soviet block (ref: "Street in Xankəndi, August 2024"): beige tuff, three stair
    entrances with canopies, balcony stacks on the street side, a flat roof with a parapet."""
    tag = "H" if hi else "L"
    g = "kb_xk_block5"
    pad(g, tag, hi, 34.0, 15.0, lawn=(-16.6, 16.6, 4.9, 7.1))
    x0, x1, z0, z1 = -15.5, 15.5, -6.5, 4.5
    top = 0.3 + 0.6 + 5 * FLOOR
    S.slab(f"{g}_socle_{tag}", x0 - 0.05, x1 + 0.05, 0.3, 0.9, z0 - 0.05, z1 + 0.05, "plinth", g, hi)
    S.slab(f"{g}_body_{tag}", x0, x1, 0.9, top, z0, z1, "tuff", g, hi)
    flat_roof(g, tag, hi, x0 - 0.1, x1 + 0.1, z0 - 0.1, z1 + 0.1, top, "tuff_light")
    doors = (-10.3, 0.0, 10.3)
    bays = (-13.2, -6.6, 6.6, 13.2, -3.4, 3.4)
    for f in range(5):
        yy = 0.9 + 1.5 + f * FLOOR
        if hi:
            windows(g, tag, hi, x0 + 0.6, x1 - 0.6, yy, z1 + BW / 2, depth=BW, pitch=2.55,
                    skip=[(d - 0.9, d + 0.9) for d in doors] if f == 0 else None)
            windows(g, tag, hi, x0 + 0.6, x1 - 0.6, yy, z0 - BW / 2, depth=BW, pitch=2.55)
        for d in doors:       # stair windows over each door, between the floors
            if f > 0 and hi:
                S.box(f"{g}_st{d:.0f}_{f}_{tag}", (0.9, 1.0, BW), (d, yy - 1.0, z1 + BW / 2), "glass", g, hi, bevel=0.0)
    for f in range(1, 5):
        y = 0.9 + f * FLOOR
        for k, bx in enumerate(bays):
            balcony(g, tag, hi, f"b{f}_{k}", bx, y, z1, 2.6, glazed=(k + f) % 3 == 0)
    for d in doors:
        S.box(f"{g}_door{d:.0f}_{tag}", (1.3, 2.2, 0.12), (d, 0.9 + 1.1, z1 + 0.06), "wood", g, hi, bevel=0.0)
        S.slab(f"{g}_can{d:.0f}_{tag}", d - 1.3, d + 1.3, 3.2, 3.4, z1, z1 + 1.4, "tuff_light", g, hi, bevel=0.0)
        S.slab(f"{g}_step{d:.0f}_{tag}", d - 1.3, d + 1.3, 0.25, 0.6, z1, z1 + 1.4, "plinth", g, hi, bevel=0.0)


def build_tower9(hi):
    """Nine-storey tower (ref: "Buildings in Xankəndi, August 2024"): light beige panels, two
    balcony stacks, the lift room on the flat roof."""
    tag = "H" if hi else "L"
    g = "kb_xk_tower9"
    pad(g, tag, hi, 18.0, 16.0, lawn=(-8.6, 8.6, 5.6, 7.6))
    x0, x1, z0, z1 = -7.5, 7.5, -7.0, 5.2
    top = 0.3 + 0.6 + 9 * FLOOR
    S.slab(f"{g}_socle_{tag}", x0 - 0.05, x1 + 0.05, 0.3, 0.9, z0 - 0.05, z1 + 0.05, "plinth", g, hi)
    S.slab(f"{g}_body_{tag}", x0, x1, 0.9, top, z0, z1, "panel", g, hi)
    flat_roof(g, tag, hi, x0 - 0.1, x1 + 0.1, z0 - 0.1, z1 + 0.1, top, "panel")
    S.slab(f"{g}_lift_{tag}", -2.0, 2.0, top, top + 2.6, -2.5, 0.5, "panel", g, hi)
    for f in range(9):
        yy = 0.9 + 1.5 + f * FLOOR
        if hi:
            windows(g, tag, hi, x0 + 0.5, x1 - 0.5, yy, z1 + BW / 2, depth=BW, pitch=2.5, skip=[(-1.0, 1.0)] if f == 0 else None)
            windows(g, tag, hi, x0 + 0.5, x1 - 0.5, yy, z0 - BW / 2, depth=BW, pitch=2.5)
            side_windows(g, tag, hi, x0 - BW / 2, z0 + 0.6, z1 - 0.6, yy, pitch=3.0, depth=BW)
            side_windows(g, tag, hi, x1 + BW / 2, z0 + 0.6, z1 - 0.6, yy, pitch=3.0, depth=BW)
    for f in range(1, 9):
        y = 0.9 + f * FLOOR
        for k, bx in enumerate((-4.6, 4.6)):
            balcony(g, tag, hi, f"b{f}_{k}", bx, y, z1, 3.4, mat="balc" if (f + k) % 2 else "tuff_light",
                    glazed=(f + k) % 2 == 0)
    S.box(f"{g}_door_{tag}", (1.6, 2.3, 0.12), (0.0, 0.9 + 1.15, z1 + 0.06), "frame", g, hi, bevel=0.0)
    S.slab(f"{g}_can_{tag}", -1.8, 1.8, 3.3, 3.5, z1, z1 + 1.6, "panel", g, hi, bevel=0.0)


def build_new4(hi):
    """The new avenue buildings (ref: "Streets in Khankendi (1)", 2026): cream walls, a ground-floor
    arcade of round arches, black balconies, an orange bay, a dark slate hipped roof."""
    tag = "H" if hi else "L"
    g = "kb_xk_new4"
    pad(g, tag, hi, 32.0, 15.0)
    x0, x1, z0, z1 = -15.0, 15.0, -6.0, 4.2
    h0 = 0.3 + 4.2            # the arcade floor is taller
    top = h0 + 3 * 3.2
    S.slab(f"{g}_socle_{tag}", x0 - 0.05, x1 + 0.05, 0.3, 0.8, z0 - 0.05, z1 + 0.05, "plinth", g, hi)
    S.slab(f"{g}_body_{tag}", x0, x1, 0.8, top, z0, z1, "cream", g, hi)
    S.slab(f"{g}_band_{tag}", x0 - 0.12, x1 + 0.12, h0 - 0.3, h0, z0 - 0.12, z1 + 0.12, "white", g, hi, bevel=0.0)
    S.slab(f"{g}_cornice_{tag}", x0 - 0.25, x1 + 0.25, top - 0.45, top, z0 - 0.25, z1 + 0.25, "white", g, hi,
           bevel=0.0)
    # the arcade: nine round-arched openings on the front, glass shop fronts deep inside
    n_arch = 9
    pitch = (x1 - x0) / n_arch
    for k in range(n_arch):
        cx = x0 + pitch * (k + 0.5)
        half = pitch * 0.32
        outline = [(cx - half, 0.8)] + S.round_arch(half, 3.1, K.L(hi, 4, 8), cx) + [(cx + half, 0.8)]
        S.extrude(f"{g}_arch{k}_{tag}", outline, z1, z1 + 0.06, "shadow", g, hi)
    # the orange bay (two windows wide) from the first floor up
    S.slab(f"{g}_bay_{tag}", 3.0, 7.4, h0, top - 0.45, z1, z1 + 0.35, "accent", g, hi)
    for f in range(3):
        yy = h0 + 1.6 + f * 3.2
        if hi:
            windows(g, tag, hi, x0 + 0.6, x1 - 0.6, yy, z1 + BW / 2, depth=BW, w=1.2, h=1.8, pitch=2.6, skip=[(3.0, 7.4)])
            windows(g, tag, hi, 3.2, 7.2, yy, z1 + 0.35 + BW / 2, depth=BW, w=1.4, h=1.9, pitch=2.2)
            windows(g, tag, hi, x0 + 0.6, x1 - 0.6, yy, z0 - BW / 2, depth=BW, w=1.2, h=1.8, pitch=2.6)
            side_windows(g, tag, hi, x0 - BW / 2, z0 + 0.6, z1 - 0.6, yy, depth=BW)
            side_windows(g, tag, hi, x1 + BW / 2, z0 + 0.6, z1 - 0.6, yy, depth=BW)
        if f > 0:
            for k, bx in enumerate((-12.4, -7.2, -2.0, 11.6)):   # black French balconies
                S.slab(f"{g}_fb{f}_{k}_{tag}", bx - 1.0, bx + 1.0, yy - 1.0, yy - 0.2, z1 + 0.4, z1 + 0.5, "frame", g,
                       hi, bevel=0.0)
                S.slab(f"{g}_fs{f}_{k}_{tag}", bx - 1.0, bx + 1.0, yy - 1.15, yy - 1.0, z1, z1 + 0.5, "frame", g, hi,
                       bevel=0.0)
    hip_roof(g, tag, hi, "roof", x0, x1, z0, z1, top, 3.2, "slate", over=0.3)
    for k, cx in enumerate((-9.0, 0.0, 9.0)):     # dormers on the slate roof
        S.slab(f"{g}_dorm{k}_{tag}", cx - 0.8, cx + 0.8, top + 0.4, top + 1.9, z1 - 1.6, z1 - 0.6, "cream", g, hi,
               bevel=0.0)
        if hi:
            S.box(f"{g}_dw{k}_{tag}", (1.0, 0.9, 0.06), (cx, top + 1.1, z1 - 0.57), "glass", g, hi, bevel=0.0)


def build_villa(hi):
    """White classical two-storey building with a dark hipped roof and a portico (ref: "View of
    Xankəndi, August 2024": the white buildings round the stadium)."""
    tag = "H" if hi else "L"
    g = "kb_xk_villa"
    pad(g, tag, hi, 16.0, 13.0, lawn=(-7.6, 7.6, 3.3, 6.1))
    x0, x1, z0, z1 = -6.8, 6.8, -5.8, 2.6
    top = 0.3 + 0.7 + 2 * 3.4
    S.slab(f"{g}_socle_{tag}", x0 - 0.05, x1 + 0.05, 0.3, 1.0, z0 - 0.05, z1 + 0.05, "plinth", g, hi)
    S.slab(f"{g}_body_{tag}", x0, x1, 1.0, top, z0, z1, "white", g, hi)
    S.slab(f"{g}_cornice_{tag}", x0 - 0.2, x1 + 0.2, top - 0.35, top, z0 - 0.2, z1 + 0.2, "white", g, hi, bevel=0.0)
    for f in range(2):
        yy = 1.0 + 1.7 + f * 3.4
        windows(g, tag, hi, x0 + 0.6, x1 - 0.6, yy, z1 + 0.05, w=1.1, h=1.9, pitch=2.3,
                skip=[(-2.4, 2.4)] if f == 0 else None)
        windows(g, tag, hi, x0 + 0.6, x1 - 0.6, yy, z0 - 0.05, w=1.1, h=1.9, pitch=2.3)
        side_windows(g, tag, hi, x0 - 0.05, z0 + 0.6, z1 - 0.6, yy, pitch=2.6)
        side_windows(g, tag, hi, x1 + 0.05, z0 + 0.6, z1 - 0.6, yy, pitch=2.6)
    # the portico: four columns, the balcony on top, steps
    S.slab(f"{g}_steps_{tag}", -2.8, 2.8, 0.25, 1.0, z1, z1 + 2.6, "plinth", g, hi, bevel=0.0)
    for k, cx in enumerate((-2.2, -0.75, 0.75, 2.2)):
        S.cylinder(f"{g}_col{k}_{tag}", 0.22, 1.0, 4.2, (cx, z1 + 2.1), "white", g, hi, seg=(6, 12))
    S.slab(f"{g}_portroof_{tag}", -2.7, 2.7, 4.2, 4.55, z1, z1 + 2.5, "white", g, hi, bevel=0.0)
    S.slab(f"{g}_portrail_{tag}", -2.7, 2.7, 4.55, 5.4, z1 + 2.38, z1 + 2.5, "white", g, hi, bevel=0.0)
    S.box(f"{g}_door_{tag}", (1.4, 2.5, 0.12), (0.0, 1.0 + 1.25, z1 + 0.06), "wood", g, hi, bevel=0.0)
    hip_roof(g, tag, hi, "roof", x0, x1, z0, z1, top, 2.6, "slate", over=0.4)


def garden_wall(g, tag, hi, w, d, mat, gate_w=3.0, h=1.8):
    """A solid wall on the street side with a metal gate (the old Xankəndi yards)."""
    z = d / 2 - 0.35
    for sx in (-1, 1):
        a, b = sorted((sx * gate_w / 2, sx * (w / 2 - 0.2)))
        S.slab(f"{g}_gw{sx}_{tag}", a, b, 0.25, h, z - 0.15, z + 0.15, mat, g, hi, bevel=0.0)
    S.box(f"{g}_gate_{tag}", (gate_w, h - 0.15, 0.08), (0.0, 0.25 + (h - 0.15) / 2, z), "gate", g, hi, bevel=0.0)


def build_house_1(hi):
    """Old two-storey stone house (ref: "Streets in Khankendi (3)"): pinkish plaster, a maroon
    metal gable roof, a balcony on posts, the yard wall with a gate."""
    tag = "H" if hi else "L"
    g = "kb_xk_house_1"
    pad(g, tag, hi, 12.0, 11.0, lawn=(-5.8, 5.8, 1.0, 5.0))
    garden_wall(g, tag, hi, 12.0, 11.0, "block_grey")
    x0, x1, z0, z1 = -4.8, 4.8, -5.0, 1.2
    top = 0.3 + 0.5 + 2 * 3.0
    S.slab(f"{g}_socle_{tag}", x0 - 0.05, x1 + 0.05, 0.3, 0.8, z0 - 0.05, z1 + 0.05, "plinth", g, hi)
    S.slab(f"{g}_body_{tag}", x0, x1, 0.8, top, z0, z1, "plaster", g, hi)
    for f in range(2):
        yy = 0.8 + 1.6 + f * 3.0
        windows(g, tag, hi, x0 + 0.5, x1 - 0.5, yy, z1 + 0.05, w=1.1, pitch=2.5, skip=[(-0.9, 0.9)] if f == 0 else None)
        windows(g, tag, hi, x0 + 0.5, x1 - 0.5, yy, z0 - 0.05, w=1.1, pitch=2.5)
        side_windows(g, tag, hi, x1 + 0.05, z0 + 0.5, z1 - 0.5, yy)
    S.box(f"{g}_door_{tag}", (1.1, 2.1, 0.12), (0.0, 0.8 + 1.05, z1 + 0.06), "wood", g, hi, bevel=0.0)
    gable_roof(g, tag, hi, "roof", x0, x1, z0, z1, top, 2.0, "roof_red", "plaster")
    # the balcony on the first floor, on two posts
    S.slab(f"{g}_balc_{tag}", -3.2, 3.2, 3.6, 3.8, z1, z1 + 1.5, "wood", g, hi, bevel=0.0)
    S.slab(f"{g}_brail_{tag}", -3.2, 3.2, 3.8, 4.7, z1 + 1.4, z1 + 1.5, "frame", g, hi, bevel=0.0)
    for sx in (-1, 1):
        S.slab(f"{g}_post{sx}_{tag}", sx * 3.0 - 0.1, sx * 3.0 + 0.1, 0.3, 3.6, z1 + 1.3, z1 + 1.5, "frame", g, hi,
               bevel=0.0)


def build_house_2(hi):
    """One-storey house of grey concrete blocks (ref: "Streets in Khankendi (2)"): a rust metal
    hipped roof, a garage with a metal gate beside it."""
    tag = "H" if hi else "L"
    g = "kb_xk_house_2"
    pad(g, tag, hi, 12.0, 10.0, lawn=(-5.8, 0.5, 1.5, 4.8))
    x0, x1, z0, z1 = -5.2, 1.6, -4.6, 1.4
    top = 0.3 + 0.5 + 3.2
    S.slab(f"{g}_socle_{tag}", x0 - 0.05, x1 + 0.05, 0.3, 0.8, z0 - 0.05, z1 + 0.05, "plinth", g, hi)
    S.slab(f"{g}_body_{tag}", x0, x1, 0.8, top, z0, z1, "block_grey", g, hi)
    windows(g, tag, hi, x0 + 0.5, x1 - 0.5, 2.5, z1 + 0.05, w=1.3, pitch=2.4, skip=[(-2.4, -1.0)])
    windows(g, tag, hi, x0 + 0.5, x1 - 0.5, 2.5, z0 - 0.05, w=1.3, pitch=2.4)
    side_windows(g, tag, hi, x0 - 0.05, z0 + 0.5, z1 - 0.5, 2.5)
    S.box(f"{g}_door_{tag}", (1.1, 2.1, 0.12), (-1.7, 0.8 + 1.05, z1 + 0.06), "wood", g, hi, bevel=0.0)
    hip_roof(g, tag, hi, "roof", x0, x1, z0, z1, top, 1.9, "roof_rust")
    # the garage (flat roof) and its gate, the yard wall
    S.slab(f"{g}_gar_{tag}", 2.0, 5.8, 0.3, 3.0, -3.6, 3.6, "block_grey", g, hi)
    S.slab(f"{g}_garroof_{tag}", 1.8, 6.0, 3.0, 3.2, -3.8, 3.9, "roof_rust", g, hi, bevel=0.0)
    S.box(f"{g}_gargate_{tag}", (3.0, 2.4, 0.08), (3.9, 1.55, 3.62), "gate", g, hi, bevel=0.0)
    S.slab(f"{g}_wall_{tag}", -5.8, 1.8, 0.25, 1.2, 4.6, 4.85, "block_grey", g, hi, bevel=0.0)


def build(hi):
    global _looked
    if not _looked:
        S.add_looks(LOOK)
        _looked = True
    _build(hi)


_build = S.run_set(GROUPS, {"kb_xk_block5": build_block5, "kb_xk_tower9": build_tower9, "kb_xk_new4": build_new4,
                            "kb_xk_villa": build_villa, "kb_xk_house_1": build_house_1,
                            "kb_xk_house_2": build_house_2}, 60.0)
K.CAGE, K.RAY, K.AO_DIST = 0.08, 0.2, 2.0
K.setup("karabakh_khankendi_town", "assets/models/karabakh_khankendi_town", PALETTE, PAINT_MAT, GROUPS, UV_SCALE,
        FAR_RATIO, stone_mats=["__no_stone__"])
K.run(build)
