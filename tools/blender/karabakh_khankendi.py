"""Xankəndi landmarks for the Qarabağ map (0.19.1 Blender models; named by the owner 2026-11-10).

  blender --background --factory-startup --python tools/blender/karabakh_khankendi.py -- --bake-res 4096 --tex-res 2048
Same pipeline as the other prop sets (kart_common.run). Frame: x along the
road, y up, z towards the road (front), origin at the footprint centre on its
pad (tools/karabakh_layout.py footprints w x d).
  kb_victory_square  Zəfər meydanı with the Victory Arch (the owner: "ən əsası";
                     after the owner's photo), 70 x 64 m: the 30 m white arch
                     at the top of a broad stair, cypress rows, red flowers,
                     arm lamps, a low white building beyond. No flag mast
                     (not named by the owner).
  kb_university      Qarabağ Universiteti, 46 x 24 m: four-storey teaching
                     building, glazed entrance hall, the name in letters.
  kb_stadium         Xankəndi stadium, 100 x 74 m: pitch, running track,
                     covered main stand at the back, low stands, four
                     floodlight masts.
  kb_our_mountains   "Biz və bizim dağlar": the grandfather and grandmother
                     carved in red tuff (~7 m) on a stone platform.
Night: the building glass (orm alpha) glows in cells (prop_baked "windows").
"""

import math
import os
import random
import sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from kart_common import *  # noqa: F401,F403
import kart_common as K
from mathutils import Vector, Matrix
import kb_shapes as S

PALETTE = {
    "granite": ("C9C3B6", 0.8, 0.0),
    "granite_dark": ("8E8A82", 0.8, 0.0),
    "cream": ("E6D9BE", 0.85, 0.0),
    "cream_shade": ("C9B898", 0.85, 0.0),
    "white": ("F1EEE6", 0.7, 0.0),
    "roof": ("6F7378", 0.6, 0.2),
    "glass": ("365C7E", 0.08, 0.3),
    "frame": ("3A3F46", 0.4, 0.6),
    "water": ("5FA8C4", 0.05, 0.0),
    "grass": ("5E8F3A", 0.95, 0.0),
    "flower_red": ("D23C3C", 0.8, 0.0),
    "flower_yellow": ("F2C230", 0.8, 0.0),
    "leaf": ("4C7A2E", 0.9, 0.0),
    "trunk": ("6B4A32", 0.9, 0.0),
    "steel": ("A9AFB6", 0.35, 0.8),
    "lamp_head": ("F4EFD8", 0.4, 0.0),
    "seat_blue": ("2D6CB5", 0.6, 0.0),
    "seat_white": ("E9ECEF", 0.6, 0.0),
    "track_red": ("B24A3A", 0.9, 0.0),
    "concrete": ("BDB8AE", 0.9, 0.0),
    "tuff": ("A85A40", 0.95, 0.0),
    "tuff_dark": ("74382A", 0.95, 0.0),
    "letters": ("D9B45A", 0.35, 0.8),
    "arch_white": ("F4F3EF", 0.5, 0.0),
    "stair": ("4E5156", 0.35, 0.0),
    "cypress": ("2F4A24", 0.9, 0.0),
}
PAINT_MAT = "glass"
STONE = []
LOOK = {"granite": "paving", "granite_dark": "cut", "cream": "cut", "cream_shade": "cut", "white": "plain",
        "concrete": "plain", "grass": "grass", "tuff": "rock", "tuff_dark": "rock", "track_red": "plain",
        "leaf": "grass", "roof": "plain", "arch_white": "plain", "stair": "tile",
        "cypress": "grass"}
GROUPS = ["kb_victory_square", "kb_university", "kb_stadium", "kb_our_mountains"]
UV_SCALE = {"kb_victory_square": 1.0, "kb_university": 1.0, "kb_stadium": 0.8, "kb_our_mountains": 1.2}
FAR_RATIO = {g: 0.35 for g in GROUPS}
F = S.FOUND
_looked = False
# side profiles drawn as (z, y), extruded along x
SWAP_XZ = Matrix(((0, 0, 1, 0), (0, 1, 0, 0), (1, 0, 0, 0), (0, 0, 0, 1)))


def lamp(g, tag, hi, x, z, h=5.0):
    S.cylinder(f"{g}_lp{x:.0f}_{z:.0f}_{tag}", 0.12, 0.0, h, (x, z), "frame", g, hi, seg=(5, 10))
    S.box(f"{g}_lh{x:.0f}_{z:.0f}_{tag}", (0.55, 0.7, 0.55), (x, h + 0.3, z), "lamp_head", g, hi)
    S.box(f"{g}_lc{x:.0f}_{z:.0f}_{tag}", (0.7, 0.12, 0.7), (x, h + 0.7, z), "frame", g, hi)


def park_tree(g, tag, hi, x, z, r=2.2, h=3.0, seed=0.0):
    S.cylinder(f"{g}_tt{x:.0f}_{z:.0f}_{tag}", 0.2, 0.0, h, (x, z), "trunk", g, hi, seg=(5, 8))
    S.tree_ball(f"{g}_tc{x:.0f}_{z:.0f}_{tag}", (x, h + r * 0.7, z), r, "leaf", g, hi, seed)


def windows_row(g, tag, hi, x0, x1, y, z, w=1.6, h=2.0, pitch=3.2, skip=None):
    """Glass panes on a facade plane (z = face), proud by 0.06 m."""
    n = int((x1 - x0) // pitch)
    start = (x0 + x1) / 2 - (n - 1) * pitch / 2
    for i in range(n):
        x = start + i * pitch
        if skip and skip[0] < x < skip[1]:
            continue
        S.box(f"{g}_w{i}_{y:.0f}_{z:.0f}_{tag}", (w, h, 0.12), (x, y, z), "glass", g, hi, bevel=0.0)


# --- Zəfər meydanı ---------------------------------------------------------------------------

def cypress(g, tag, hi, x, z, y0=0.0, h=5.5):
    S.cylinder(f"{g}_cyt{x:.0f}_{z:.0f}_{tag}", 0.15, y0, y0 + 0.6, (x, z), "trunk", g, hi, seg=(4, 6))
    S.cylinder(f"{g}_cyc{x:.0f}_{z:.0f}_{tag}", 0.75, y0 + 0.5, y0 + h * 0.75, (x, z), "cypress", g, hi, seg=(6, 10),
               r_top=0.6)
    S.cone(f"{g}_cyp{x:.0f}_{z:.0f}_{tag}", 0.6, y0 + h * 0.75, y0 + h, (x, z), "cypress", g, hi, seg=(6, 10))


def arm_lamp(g, tag, hi, x, z, y0, side):
    """Black pole with a curved arm and a flat round head (as on the square)."""
    S.cylinder(f"{g}_alp{x:.0f}_{z:.0f}_{tag}", 0.1, y0, y0 + 5.2, (x, z), "frame", g, hi, seg=(5, 8))
    S.box(f"{g}_ala{x:.0f}_{z:.0f}_{tag}", (1.3, 0.1, 0.1), (x + side * 0.6, y0 + 5.15, z), "frame", g, hi, bevel=0.0)
    S.cylinder(f"{g}_alh{x:.0f}_{z:.0f}_{tag}", 0.38, y0 + 4.9, y0 + 5.1, (x + side * 1.2, z), "lamp_head", g, hi,
               seg=(6, 12))


def build_square(hi):
    """Zəfər meydanı after the owner's photo (2026-11-10): the Victory Arch -
    a huge white portal (legs with a sloping inner face, a deep lintel) at the
    top of a broad stair (two dark granite flights, a white middle strip, white
    cheek walls), cypress rows, red flower beds and black arm lamps on the
    lawns beside it, wet-looking light granite paving, a low white building
    beyond the arch. Front (+z) to the road."""
    tag = "H" if hi else "L"
    g = "kb_victory_square"
    W, D = 70.0, 64.0
    TOP = 4.0                       # the upper terrace
    zs0, zs1 = 6.0, 20.0            # the stair (bottom at zs1, top at zs0)
    S.slab(f"{g}_plinth_{tag}", -W / 2, W / 2, -F, 0.15, -D / 2, D / 2, "granite_dark", g, hi, bevel=0.0)
    # front plaza
    S.slab(f"{g}_plaza_{tag}", -W / 2 + 1, W / 2 - 1, 0.15, 0.3, zs1, D / 2 - 1, "granite", g, hi, bevel=0.0)
    # upper terrace (a solid block under it), arch court paving
    S.slab(f"{g}_terrace_{tag}", -W / 2 + 1, W / 2 - 1, 0.15, TOP, -D / 2 + 1, zs0, "granite_dark", g, hi, bevel=0.0)
    S.slab(f"{g}_court_{tag}", -15, 15, TOP, TOP + 0.1, -D / 2 + 9, zs0, "granite", g, hi, bevel=0.0)
    # the stair: two dark flights, the white middle strip, white cheek walls
    steps = K.L(hi, 8, 16)
    for k in range(steps):
        z0 = zs1 - (zs1 - zs0) * (k + 1) / steps
        y = 0.3 + (TOP - 0.3) * (k + 1) / steps
        for sx in (-1, 1):
            S.slab(f"{g}_st{sx}{k}_{tag}", min(sx * 3.0, sx * 12.0), max(sx * 3.0, sx * 12.0), 0.15, y, z0,
                   z0 + (zs1 - zs0) / steps, "stair", g, hi, bevel=0.0)
    ramp = [(zs1, 0.3), (zs0, TOP), (zs0, 0.15), (zs1, 0.15)]
    S.extrude(f"{g}_strip_{tag}", [(z, y) for z, y in ramp], -3.0, 3.0, "white", g, hi,
              matrix=SWAP_XZ)
    for sx in (-1, 1):
        cheek = [(zs1 + 1.0, 0.3), (zs1 + 1.0, 1.2), (zs0, TOP + 0.9), (zs0 - 0.01, 0.15), (zs1 + 1.0, 0.15)]
        S.extrude(f"{g}_cheek{sx}_{tag}", [(z, y) for z, y in cheek], sx * 12.0 - 0.6, sx * 12.0 + 0.6, "white", g, hi,
                  matrix=SWAP_XZ)
    # the Victory Arch: 26 m wide, 30 m high, 7 m deep
    az0, az1 = -9.5, -2.5
    y0 = TOP + 0.1
    yl, yt = y0 + 21.0, y0 + 30.0
    for sx in (-1, 1):
        leg = [(sx * 13.0, y0), (sx * 7.6, y0), (sx * 5.6, yl), (sx * 5.6, yt), (sx * 13.0, yt)]
        if sx < 0:
            leg = list(reversed(leg))
        S.extrude(f"{g}_leg{sx}_{tag}", leg, az0, az1, "arch_white", g, hi)
    S.slab(f"{g}_lintel_{tag}", -5.65, 5.65, yl, yt, az0, az1, "arch_white", g, hi, bevel=0.0)
    S.slab(f"{g}_lintel_under_{tag}", -5.6, 5.6, yl - 0.02, yl, az0 + 0.05, az1 - 0.05, "white", g, hi, bevel=0.0)
    for sx in (-1, 1):       # the two roof lights on top
        S.box(f"{g}_rl{sx}_{tag}", (2.2, 0.3, 1.2), (sx * 8.5, yt + 0.15, (az0 + az1) / 2), "lamp_head", g, hi)
    # lawns beside the stair and the terrace: red flower rows, cypresses, lamps
    for sx in (-1, 1):
        x0, x1 = sx * 13.0, sx * 34.0
        lo, hi_x = min(x0, x1), max(x0, x1)
        S.slab(f"{g}_lawn_low{sx}_{tag}", lo, hi_x, 0.15, 0.45, zs1, D / 2 - 6.0, "grass", g, hi, bevel=0.0)
        slope = [(D / 2 - 6.0, 0.45), (zs0, TOP + 0.3), (zs0 - 0.01, 0.15), (D / 2 - 6.0, 0.15)]
        S.extrude(f"{g}_lawn_slope{sx}_{tag}", [(z, y) for z, y in slope], lo, hi_x, "grass", g, hi,
                  matrix=SWAP_XZ)
        S.slab(f"{g}_lawn_top{sx}_{tag}", lo, hi_x, TOP, TOP + 0.3, -D / 2 + 9, zs0, "grass", g, hi, bevel=0.0)
        for k in range(3):   # rows of round red shrubs along the stair
            xr = sx * (14.6 + k * 2.2)
            nb = 9
            for j in range(nb):
                zc = D / 2 - 7.0 - j * (D / 2 - 7.0 - zs0 - 0.8) / (nb - 1)
                t = min(max((D / 2 - 6.0 - zc) / (D / 2 - 6.0 - zs0), 0.0), 1.0)
                yb = 0.45 + (TOP + 0.3 - 0.45) * t
                S.cylinder(f"{g}_fl{sx}{k}{j}_{tag}", 0.6, yb, yb + 0.55, (xr, zc), "flower_red", g, hi, seg=(6, 10))
                S.dome(f"{g}_flt{sx}{k}{j}_{tag}", 0.6, yb + 0.55, (xr, zc), "flower_red", g, hi, rise=0.6,
                       seg=(6, 10), rings=(2, 4))
        for k in range(7):   # cypress rows
            zc = D / 2 - 8.0 - k * 3.6
            t = min(max((D / 2 - 6.0 - zc) / (D / 2 - 6.0 - zs0), 0.0), 1.0)
            yb = 0.45 + (TOP + 0.3 - 0.45) * t
            for xr in (sx * 22.5, sx * 25.0):
                cypress(g, tag, hi, xr, zc, yb, 5.5 + (k % 2) * 0.6)
        for k in range(5):
            zc = -D / 2 + 11.0 + k * 4.0
            cypress(g, tag, hi, sx * 22.5, zc, TOP + 0.3, 6.0)
            cypress(g, tag, hi, sx * 25.0, zc, TOP + 0.3, 6.4)
        for k in range(5):   # arm lamps along the stair cheeks
            zc = zs1 + 4.0 - k * 4.2
            t = min(max((zs1 - zc) / (zs1 - zs0), 0.0), 1.0)
            arm_lamp(g, tag, hi, sx * 13.4, zc, 0.3 + (TOP - 0.3) * t + 0.9, -sx)
    # the low white building beyond the arch
    bz0, bz1 = -D / 2 + 1.0, -D / 2 + 8.0
    S.slab(f"{g}_bld_{tag}", -24, 24, TOP, TOP + 8.0, bz0, bz1, "white", g, hi)
    S.slab(f"{g}_bld_roof_{tag}", -24.5, 24.5, TOP + 8.0, TOP + 8.6, bz0 - 0.3, bz1 + 0.5, "roof", g, hi)
    windows_row(g, tag, hi, -23.0, 23.0, TOP + 2.2, bz1 + 0.06, w=1.4, h=2.0, pitch=2.6, skip=(-3.0, 3.0))
    windows_row(g, tag, hi, -23.0, 23.0, TOP + 5.6, bz1 + 0.06, w=1.4, h=2.0, pitch=2.6)
    S.box(f"{g}_bdoor_{tag}", (4.0, 3.0, 0.12), (0.0, TOP + 1.5, bz1 + 0.06), "glass", g, hi, bevel=0.0)
    # the name stone at the front corner of the plaza
    S.slab(f"{g}_stone_{tag}", -33.0, -15.0, 0.3, 2.6, D / 2 - 3.0, D / 2 - 1.4, "granite_dark", g, hi)
    S.text3d(f"{g}_name_{tag}", "ZƏFƏR MEYDANI", 1.9, Matrix.Translation((-24.0, 1.5, D / 2 - 1.36)), "letters", g,
             hi, depth=0.12)


# --- Qarabağ Universiteti ------------------------------------------------------------------

def build_university(hi):
    tag = "H" if hi else "L"
    g = "kb_university"
    W, D = 46.0, 24.0
    S.slab(f"{g}_plinth_{tag}", -W / 2, W / 2, -F, 0.2, -D / 2, D / 2, "granite_dark", g, hi, bevel=0.0)
    S.slab(f"{g}_court_{tag}", -W / 2 + 0.5, W / 2 - 0.5, 0.2, 0.3, -D / 2 + 0.5, D / 2 - 0.5, "granite", g, hi,
           bevel=0.0)
    z0, z1 = -D / 2 + 1.0, -D / 2 + 15.0
    S.slab(f"{g}_body_{tag}", -21, 21, 0.3, 15.5, z0, z1, "white", g, hi)
    S.slab(f"{g}_roof_{tag}", -21.3, 21.3, 15.5, 16.1, z0 - 0.3, z1 + 0.3, "concrete", g, hi)
    for k in range(4):
        y = 2.2 + k * 3.5
        windows_row(g, tag, hi, -20.5, 20.5, y, z1 + 0.06, w=2.2, h=2.2, pitch=3.0, skip=(-6.5, 6.5))
    for k in range(13):   # vertical fins
        x = -20.0 + k * 3.33
        if -6.5 < x < 6.5:
            continue
        S.slab(f"{g}_fin{k}_{tag}", x - 0.15, x + 0.15, 0.3, 15.5, z1, z1 + 0.6, "cream", g, hi, bevel=0.0)
    # glazed entrance hall, canopy, name
    S.slab(f"{g}_hall_{tag}", -6, 6, 0.3, 15.5, z1 - 0.2, z1 + 2.2, "glass", g, hi, bevel=0.0)
    for k in range(7):
        x = -6 + k * 2.0
        S.slab(f"{g}_mul{k}_{tag}", x - 0.08, x + 0.08, 0.3, 15.5, z1 + 2.2, z1 + 2.35, "frame", g, hi, bevel=0.0)
    for k in range(4):
        S.slab(f"{g}_tr{k}_{tag}", -6, 6, 3.8 + k * 3.5, 3.95 + k * 3.5, z1 + 2.2, z1 + 2.35, "frame", g, hi,
               bevel=0.0)
    S.slab(f"{g}_canopy_{tag}", -8, 8, 3.6, 3.9, z1 + 2.2, z1 + 6.5, "white", g, hi)
    for sx in (-1, 1):
        S.cylinder(f"{g}_cp{sx}_{tag}", 0.2, 0.3, 3.6, (sx * 7.3, z1 + 6.0), "steel", g, hi, seg=(6, 10))
    S.slab(f"{g}_band_{tag}", -20, 20, 16.1, 19.1, z1 - 1.0, z1 - 0.4, "white", g, hi)
    S.text3d(f"{g}_name_{tag}", "QARABAĞ UNİVERSİTETİ", 2.1, Matrix.Translation((0, 17.6, z1 - 0.36)),
             "frame", g, hi, depth=0.12)
    for x in (-18, -12, 12, 18):
        park_tree(g, tag, hi, x, D / 2 - 3.0, 1.8, 2.6, x * 0.1)


# --- Stadium ----------------------------------------------------------------------------------

def build_stadium(hi):
    tag = "H" if hi else "L"
    g = "kb_stadium"
    W, D = 100.0, 74.0
    S.slab(f"{g}_plinth_{tag}", -W / 2, W / 2, -F, 0.2, -D / 2, D / 2, "concrete", g, hi, bevel=0.0)
    S.slab(f"{g}_track_{tag}", -42, 42, 0.2, 0.3, -28, 28, "track_red", g, hi, bevel=0.0)
    S.slab(f"{g}_pitch_{tag}", -36, 36, 0.3, 0.35, -23, 23, "grass", g, hi, bevel=0.0)
    for k in range(8):   # mowing stripes
        x = -36 + k * 9.0
        if k % 2:
            S.slab(f"{g}_mow{k}_{tag}", x, x + 9.0, 0.35, 0.37, -23, 23, "leaf", g, hi, bevel=0.0)
    S.slab(f"{g}_mid_{tag}", -0.08, 0.08, 0.37, 0.39, -23, 23, "white", g, hi, bevel=0.0)
    for sz in (-23, 23):
        S.slab(f"{g}_side{sz}_{tag}", -36, 36, 0.37, 0.39, sz - 0.08, sz + 0.08, "white", g, hi, bevel=0.0)
    for sx in (-36, 36):
        S.slab(f"{g}_goal_line{sx}_{tag}", sx - 0.08, sx + 0.08, 0.37, 0.39, -23, 23, "white", g, hi, bevel=0.0)
        for zz in (-3.66, 3.66):
            S.cylinder(f"{g}_post{sx}{zz:.0f}_{tag}", 0.08, 0.35, 2.8, (sx, zz), "white", g, hi, seg=(5, 8))
        S.slab(f"{g}_bar{sx}_{tag}", sx - 0.08, sx + 0.08, 2.7, 2.86, -3.7, 3.7, "white", g, hi, bevel=0.0)
    S.cylinder(f"{g}_circle_{tag}", 9.15, 0.37, 0.385, (0, 0), "white", g, hi, seg=(16, 40))
    S.cylinder(f"{g}_circle_in_{tag}", 9.0, 0.37, 0.39, (0, 0), "grass", g, hi, seg=(16, 40))
    # main stand at the back (away from the road): 14 rows, roof on masts
    sb = []
    rows = K.L(hi, 7, 14)
    for r in range(rows):
        z0 = -29.0 - r * (8.0 / rows)
        y = 0.3 + (r + 1) * (9.0 / rows)
        sb.append(S.slab(f"{g}_mb{r}_{tag}", -40, 40, 0.3, y, z0 - 8.0 / rows, z0,
                         "seat_blue" if (r % 4) else "seat_white", g, hi, bevel=0.0))
    S.slab(f"{g}_mb_back_{tag}", -40.5, 40.5, 0.3, 11.0, -37.6, -37.0, "concrete", g, hi, bevel=0.0)
    S.slab(f"{g}_roof_{tag}", -41, 41, 15.0, 15.5, -38.5, -26.0, "white", g, hi, bevel=0.0)
    for k in range(6):
        x = -40 + k * 16.0
        S.slab(f"{g}_mast{k}_{tag}", x - 0.3, x + 0.3, 9.0, 15.0, -37.6, -37.0, "steel", g, hi, bevel=0.0)
    # low stands on the road side and both ends (the player looks in over them)
    rows2 = K.L(hi, 4, 8)
    for r in range(rows2):
        y = 0.3 + (r + 1) * (4.0 / rows2)
        z0 = 29.0 + r * (5.0 / rows2)
        S.slab(f"{g}_fs{r}_{tag}", -40, 40, 0.3, y, z0, z0 + 5.0 / rows2, "seat_blue" if r % 3 else "seat_white",
               g, hi, bevel=0.0)
        for sx in (-1, 1):
            x0 = sx * (43.0 + r * (5.0 / rows2))
            S.slab(f"{g}_es{sx}{r}_{tag}", min(x0, x0 + sx * 5.0 / rows2), max(x0, x0 + sx * 5.0 / rows2), 0.3, y,
                   -28, 28, "seat_blue" if r % 3 else "seat_white", g, hi, bevel=0.0)
    # floodlight masts at the four corners
    for sx in (-1, 1):
        for sz in (-1, 1):
            x, z = sx * 47.0, sz * 34.0
            S.cylinder(f"{g}_fm{sx}{sz}_{tag}", 0.45, 0.2, 28.0, (x, z), "steel", g, hi, seg=(6, 12), r_top=0.3)
            S.box(f"{g}_fp{sx}{sz}_{tag}", (5.0, 3.0, 0.5), (x, 29.5, z), "lamp_head", g, hi,
                  rot=(0.3 * sz, math.atan2(-x, -z), 0.0))


# --- Biz və bizim dağlar ---------------------------------------------------------------------

def head(g, tag, hi, name, cx, h, woman):
    """Stylised carved head (the grandfather / the grandmother): a massive,
    flat-faced block of tuff; deep brows, a long nose, sunken eyes; his long
    beard, her headscarf framing the face."""
    S_ = K.superellipsoid
    seg = K.L(hi, (10, 8), (24, 16))
    yc = h / 2 + 1.2
    if woman:
        S_(f"{g}_{name}_scarf_{tag}", (1.75, h / 2, 1.45), (cx, yc, -0.1), "tuff_dark", g, hi, e=(0.3, 0.4), seg=seg)
        S_(f"{g}_{name}_face_{tag}", (1.05, h * 0.3, 0.6), (cx, yc + h * 0.05, 1.0), "tuff", g, hi, e=(0.4, 0.5),
           seg=seg)
        fz, fw = 1.55, 0.8
    else:
        S_(f"{g}_{name}_head_{tag}", (1.6, h / 2, 1.4), (cx, yc, 0.0), "tuff", g, hi, e=(0.3, 0.4), seg=seg)
        S_(f"{g}_{name}_beard_{tag}", (1.45, h * 0.3, 0.75), (cx, 1.2 + h * 0.28, 1.25), "tuff_dark", g, hi,
           e=(0.45, 0.5), seg=seg)
        S.slab(f"{g}_{name}_mous_{tag}", cx - 0.9, cx + 0.9, 1.2 + h * 0.5, 1.2 + h * 0.56, 1.25, 1.75, "tuff_dark",
               g, hi)
        fz, fw = 1.45, 1.0
    yb = 1.2 + h * (0.7 if not woman else 0.66)
    S.slab(f"{g}_{name}_brow_{tag}", cx - fw, cx + fw, yb, yb + 0.35, fz - 0.4, fz + 0.2, "tuff", g, hi)
    S.prism(f"{g}_{name}_nose_{tag}", [(cx - 0.3, fz - 0.2), (cx + 0.3, fz - 0.2), (cx, fz + 0.45)],
            yb - h * 0.2, yb, "tuff", g, hi)
    for sx in (-1, 1):
        S.slab(f"{g}_{name}_eye{sx}_{tag}", cx + sx * fw * 0.55 - 0.25, cx + sx * fw * 0.55 + 0.25, yb - 0.45,
               yb - 0.08, fz - 0.45, fz - 0.15, "tuff_dark", g, hi, bevel=0.0)


def build_our_mountains(hi):
    tag = "H" if hi else "L"
    g = "kb_our_mountains"
    W, D = 16.0, 12.0
    S.slab(f"{g}_plinth_{tag}", -W / 2, W / 2, -F, 0.3, -D / 2, D / 2, "granite_dark", g, hi)
    S.slab(f"{g}_terrace_{tag}", -W / 2 + 1, W / 2 - 1, 0.3, 0.6, -D / 2 + 1, D / 2 - 1, "granite", g, hi)
    S.slab(f"{g}_base_{tag}", -4.4, 4.4, 0.6, 1.2, -2.2, 2.2, "tuff_dark", g, hi)
    head(g, tag, hi, "man", -2.0, 6.6, False)
    head(g, tag, hi, "woman", 2.0, 5.9, True)


def build(hi):
    global _looked
    if not _looked:
        S.add_looks(LOOK)
        _looked = True
    _build(hi)


_build = S.run_set(GROUPS, {"kb_victory_square": build_square, "kb_university": build_university,
                            "kb_stadium": build_stadium, "kb_our_mountains": build_our_mountains})
K.CAGE, K.RAY, K.AO_DIST = 0.08, 0.2, 2.5
K.setup("karabakh_khankendi", "assets/models/karabakh_khankendi", PALETTE, PAINT_MAT, GROUPS, UV_SCALE, FAR_RATIO,
        stone_mats=["__no_stone__"])
K.run(build)
