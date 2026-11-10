"""Şuşa landmarks for the Qarabağ map (0.19.1 Blender models; named by the owner 2026-11-10).

  blender --background --factory-startup --python tools/blender/karabakh_shusha.py -- --bake-res 4096 --tex-res 2048
Same pipeline as the other prop sets (kart_common.run). Frame: x along the
road / the wall run, y up, z towards the road (front), origin on the pad.
  kb_shusha_sign  the "ŞUŞA" sign at the entrance to the town (stone wall,
                  big letters) with the flag mast; the Azerbaijani flag is the
                  waving LandmarkKit flag added in Godot at SIGN_MAST_TOP.
  kb_mosque       Yuxarı Gövhər Ağa məscidi: grey stone prayer hall, the
                  arched front, two cylindrical brick minarets with
                  horizontal belts and balconies.
  kb_vagif        Molla Pənah Vaqif's mausoleum (1982, 18 m): a tall white
                  marble tower with lancet openings on a red marble podium
                  with steps.
  kb_wall_seg / kb_wall_tower / kb_wall_gate  the Şuşa fortress walls (rubble
                  limestone, battlements), 8 m modules laid along the rim of
                  the plateau above the Daşaltı gorge (lines.json); +z is the
                  outer (gorge) side.
Forms of the sign and the mausoleum's crown are approximations (no exact
references found); the owner reviews the renders.
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
    "limestone": ("CDBF9F", 0.9, 0.0),
    "limestone_dark": ("A8987A", 0.9, 0.0),
    "grey_stone": ("BDB7AA", 0.88, 0.0),
    "brick": ("B07452", 0.85, 0.0),
    "brick_light": ("D6B48E", 0.85, 0.0),
    "trim": ("E4DCC8", 0.8, 0.0),
    "roof": ("5E646B", 0.5, 0.4),
    "dome_tin": ("8E979F", 0.35, 0.7),
    "wood": ("6A4429", 0.7, 0.0),
    "dark": ("2A2622", 0.9, 0.0),
    "glass": ("39556E", 0.1, 0.3),
    "marble_white": ("EEEBE4", 0.35, 0.0),
    "marble_grey": ("B9B8B4", 0.4, 0.0),
    "marble_red": ("9C4A3C", 0.4, 0.0),
    "steel": ("B4BAC0", 0.3, 0.9),
    "letters": ("F4F1E8", 0.5, 0.0),
    "grass": ("5E8F3A", 0.95, 0.0),
    "flower_red": ("D23C3C", 0.8, 0.0),
    "paving": ("C6BFAF", 0.85, 0.0),
}
PAINT_MAT = "glass"
LOOK = {"limestone": "cobble", "limestone_dark": "cobble", "grey_stone": "cut", "brick": "brick",
        "brick_light": "brick", "trim": "plain", "marble_white": "plain", "marble_grey": "plain",
        "marble_red": "plain", "grass": "grass", "paving": "paving", "roof": "plain"}
GROUPS = ["kb_shusha_sign", "kb_mosque", "kb_vagif", "kb_wall_seg", "kb_wall_tower", "kb_wall_gate"]
UV_SCALE = {"kb_shusha_sign": 1.1, "kb_mosque": 1.0, "kb_vagif": 1.0, "kb_wall_seg": 1.2, "kb_wall_tower": 1.0,
            "kb_wall_gate": 1.1}
FAR_RATIO = {g: 0.4 for g in GROUPS}
F = S.FOUND
_looked = False

WALL_H = 8.0
WALL_T = 2.2
SEG = 8.0
DEEP = 4.0     # line modules reach this far under their origin (the rim is uneven)


# --- The "ŞUŞA" sign ---------------------------------------------------------------------------

def build_sign(hi):
    tag = "H" if hi else "L"
    g = "kb_shusha_sign"
    S.slab(f"{g}_plinth_{tag}", -7, 7, -F, 0.25, -3, 3, "paving", g, hi)
    S.slab(f"{g}_bed_{tag}", -4.2, 6.6, 0.25, 0.55, 0.6, 2.6, "grass", g, hi, bevel=0.0)
    for k in range(9):
        S.cylinder(f"{g}_fl{k}_{tag}", 0.45, 0.55, 0.85, (-3.6 + k * 1.25, 1.9), "flower_red", g, hi, seg=(5, 8))
    S.slab(f"{g}_wall_{tag}", -4.4, 6.6, 0.25, 2.6, -1.1, 0.4, "limestone", g, hi)
    S.slab(f"{g}_cap_{tag}", -4.6, 6.8, 2.6, 2.9, -1.3, 0.6, "trim", g, hi)
    S.text3d(f"{g}_name_{tag}", "ŞUŞA", 3.6, Matrix.Translation((1.1, 4.25, -0.2)), "letters", g, hi, depth=0.5)
    # the flag mast (the flag itself: Godot, waving)
    S.cylinder(f"{g}_mastbase_{tag}", 0.6, 0.25, 1.0, (-5.6, 0.0), "trim", g, hi, seg=(8, 16))
    S.cylinder(f"{g}_mast_{tag}", 0.12, 1.0, 10.7, (-5.6, 0.0), "steel", g, hi, seg=(6, 12), r_top=0.08)
    S.cylinder(f"{g}_finial_{tag}", 0.18, 10.7, 11.0, (-5.6, 0.0), "steel", g, hi, seg=(6, 10))


# --- Yuxarı Gövhər Ağa məscidi ------------------------------------------------------------------

def minaret(g, tag, hi, name, x, z, h=24.0):
    seg = (10, 24)
    S.slab(f"{g}_{name}_foot_{tag}", x - 1.9, x + 1.9, 0.3, 3.0, z - 1.9, z + 1.9, "grey_stone", g, hi)
    # shaft in belts of two brick patterns
    y = 3.0
    k = 0
    while y < h * 0.74:
        top = min(y + 1.6, h * 0.74)
        S.cylinder(f"{g}_{name}_b{k}_{tag}", 1.4, y, top, (x, z), "brick" if k % 2 == 0 else "brick_light", g, hi,
                   seg=seg, r_top=1.4 - 0.012 * (top - y))
        S.cylinder(f"{g}_{name}_ring{k}_{tag}", 1.47, top - 0.12, top + 0.06, (x, z), "trim", g, hi, seg=seg)
        y = top
        k += 1
    yb = h * 0.74
    # balcony (şərəfə) on corbels, with a parapet
    S.cylinder(f"{g}_{name}_corbel_{tag}", 1.4, yb, yb + 0.6, (x, z), "trim", g, hi, seg=seg, r_top=2.1)
    S.cylinder(f"{g}_{name}_balc_{tag}", 2.1, yb + 0.6, yb + 0.8, (x, z), "trim", g, hi, seg=seg)
    S.cylinder(f"{g}_{name}_rail_{tag}", 2.05, yb + 0.8, yb + 1.7, (x, z), "brick_light", g, hi, seg=seg)
    # upper shaft, cap
    S.cylinder(f"{g}_{name}_up_{tag}", 1.05, yb + 0.8, h - 1.2, (x, z), "brick", g, hi, seg=seg)
    S.cylinder(f"{g}_{name}_upring_{tag}", 1.2, h - 1.4, h - 1.1, (x, z), "trim", g, hi, seg=seg)
    S.dome(f"{g}_{name}_cap_{tag}", 1.2, h - 1.1, (x, z), "dome_tin", g, hi, rise=1.6, point=0.8)
    S.cylinder(f"{g}_{name}_spire_{tag}", 0.05, h + 1.6, h + 2.6, (x, z), "steel", g, hi, seg=(4, 6))


def build_mosque(hi):
    tag = "H" if hi else "L"
    g = "kb_mosque"
    W, D = 28.0, 32.0
    S.slab(f"{g}_plinth_{tag}", -W / 2, W / 2, -F, 0.3, -D / 2, D / 2, "grey_stone", g, hi, bevel=0.0)
    S.slab(f"{g}_court_{tag}", -W / 2 + 0.5, W / 2 - 0.5, 0.3, 0.4, -D / 2 + 0.5, D / 2 - 0.5, "paving", g, hi,
           bevel=0.0)
    # prayer hall: 22 x 20 m, 9 m walls, a low hipped roof
    hz0, hz1 = -15.0, 5.0
    S.slab(f"{g}_hall_{tag}", -11, 11, 0.4, 9.0, hz0, hz1, "grey_stone", g, hi)
    S.slab(f"{g}_cornice_{tag}", -11.3, 11.3, 9.0, 9.5, hz0 - 0.3, hz1 + 0.3, "trim", g, hi)
    S.prism(f"{g}_roof_{tag}", [(-11.3, hz0 - 0.3), (11.3, hz0 - 0.3), (11.3, hz1 + 0.3), (-11.3, hz1 + 0.3)],
            9.5, 9.6, "roof", g, hi, apex=(0.0, 13.0, (hz0 + hz1) / 2))
    # pointed double windows in two rows on the sides and back
    n = K.L(hi, 6, 12)
    for side in (-1, 1):
        for k in range(4):
            z = hz0 + 2.5 + k * 5.0
            for row, y0 in enumerate((2.0, 5.6)):
                outline = S.pointed(0.6, y0 + 1.6, 0.7, n)
                outline = [(-0.6, y0)] + outline + [(0.6, y0)]
                ob = S.extrude(f"{g}_win{side}{k}{row}_{tag}", list(reversed(outline)), 0.0, 0.1, "glass", g, hi)
                ob.data.transform(Matrix.Translation((side * 11.02, 0, z)) @ Matrix.Rotation(side * math.pi / 2, 4, "Y"))
    # the arched front (veranda) between the minarets: three pointed arches
    fz0, fz1 = hz1, hz1 + 5.0
    S.slab(f"{g}_ver_floor_{tag}", -8.6, 8.6, 0.4, 0.8, fz0, fz1, "grey_stone", g, hi)
    pitch = 5.4
    for k in range(3):
        cx = -pitch + k * pitch
        outline = S.pointed(2.0, 4.6, 2.2, n, cx=cx)
        poly = [(cx - pitch / 2, 0.8), (cx - 2.0, 0.8)] + outline + [(cx + 2.0, 0.8), (cx + pitch / 2, 0.8),
                                                                    (cx + pitch / 2, 9.0), (cx - pitch / 2, 9.0)]
        S.extrude(f"{g}_arch{k}_{tag}", list(reversed(poly)), fz1 - 1.0, fz1, "grey_stone", g, hi)
        S.extrude(f"{g}_archring{k}_{tag}", list(reversed(outline + [(p[0] * 1.0, p[1]) for p in
                                                                     reversed(S.pointed(2.35, 4.6, 2.55, n, cx=cx))])),
                  fz1 - 0.02, fz1 + 0.08, "brick", g, hi)
    S.slab(f"{g}_ver_top_{tag}", -8.6, 8.6, 9.0, 9.5, fz0, fz1 + 0.2, "trim", g, hi)
    S.slab(f"{g}_ver_roof_{tag}", -8.6, 8.6, 9.5, 9.7, fz0, fz1, "roof", g, hi, bevel=0.0)
    # inner front wall with the door and windows (seen through the arches)
    S.box(f"{g}_door_{tag}", (2.2, 3.6, 0.15), (0, 2.6, hz1 + 0.05), "wood", g, hi, bevel=0.0)
    for x in (-5.4, 5.4):
        S.box(f"{g}_fwin{x:.0f}_{tag}", (1.4, 2.4, 0.12), (x, 3.0, hz1 + 0.05), "glass", g, hi, bevel=0.0)
    # minarets at the front corners
    minaret(g, tag, hi, "mL", -10.3, fz1 - 1.5)
    minaret(g, tag, hi, "mR", 10.3, fz1 - 1.5)
    # steps down to the courtyard
    for k in range(2):
        S.slab(f"{g}_step{k}_{tag}", -6, 6, 0.4, 0.8 - k * 0.2, fz1, fz1 + 0.5 + k * 0.5, "grey_stone", g, hi,
               bevel=0.0)


# --- Vaqif's mausoleum --------------------------------------------------------------------------

def build_vagif(hi):
    tag = "H" if hi else "L"
    g = "kb_vagif"
    S.slab(f"{g}_plinth_{tag}", -9, 9, -F, 0.3, -9, 9, "paving", g, hi, bevel=0.0)
    for k, (h, r) in enumerate(((0.9, 7.6), (1.8, 6.2), (2.6, 4.9))):   # red marble podium, three levels
        S.slab(f"{g}_pod{k}_{tag}", -r, r, 0.3, h, -r, r, "marble_red", g, hi)
    for k in range(5):   # front stairs
        S.slab(f"{g}_st{k}_{tag}", -1.8, 1.8, 0.3, 0.3 + (k + 1) * 0.46, 4.9 + (4 - k) * 0.55, 4.9 + (5 - k) * 0.55,
               "marble_grey", g, hi, bevel=0.0)
    # the tower: four corner pylons, lancet openings 2.0 m wide, 18 m in all
    y0, top = 2.6, 16.2
    hw = 3.3
    for sx in (-1, 1):
        for sz in (-1, 1):
            S.slab(f"{g}_pyl{sx}{sz}_{tag}", sx * hw - 1.3 if sx > 0 else -hw, sx * hw if sx > 0 else -hw + 1.3,
                   y0, top, sz * hw - 1.3 if sz > 0 else -hw, sz * hw if sz > 0 else -hw + 1.3, "marble_white", g, hi)
    n = K.L(hi, 6, 14)
    for face in range(4):
        rot = Matrix.Rotation(face * math.pi / 2, 4, "Y")
        arch = S.pointed(1.0, 11.0, 2.8, n)
        poly = [(-2.0, 11.0), (-1.0, 11.0)] + arch[1:-1] + [(1.0, 11.0), (2.0, 11.0), (2.0, top), (-2.0, top)]
        ob = S.extrude(f"{g}_head{face}_{tag}", list(reversed(poly)), hw - 0.6, hw, "marble_white", g, hi)
        ob.data.transform(rot)
        # vertical ornament bands (aluminium) on the pylons, the lintel band
        for sx in (-1, 1):
            b = S.slab(f"{g}_orn{face}{sx}_{tag}", sx * 2.55 - 0.18, sx * 2.55 + 0.18, y0 + 0.6, top - 0.6, hw, hw + 0.06,
                       "steel", g, hi, bevel=0.0)
            b.data.transform(rot)
    S.slab(f"{g}_cenotaph_{tag}", -1.0, 1.0, y0, y0 + 1.0, -1.6, 1.6, "marble_grey", g, hi)
    # crown: cornice, a stepped drum and a low pointed cap
    S.slab(f"{g}_cornice_{tag}", -hw - 0.4, hw + 0.4, top, top + 0.5, -hw - 0.4, hw + 0.4, "marble_grey", g, hi)
    S.slab(f"{g}_drum_{tag}", -2.6, 2.6, top + 0.5, top + 1.3, -2.6, 2.6, "marble_white", g, hi)
    S.prism(f"{g}_cap_{tag}", [(-2.6, -2.6), (2.6, -2.6), (2.6, 2.6), (-2.6, 2.6)], top + 1.3, top + 1.35,
            "marble_grey", g, hi, apex=(0.0, 18.4 + 2.6, 0.0))


# --- Fortress walls -----------------------------------------------------------------------------

def battlements(g, tag, hi, name, x0, x1, y, z):
    k = 0
    x = x0 + 0.4
    while x + 1.2 <= x1 + 0.01:
        S.slab(f"{g}_{name}_m{k}_{tag}", x, x + 1.2, y, y + 1.3, z - 0.55, z + 0.55, "limestone", g, hi)
        x += 2.0
        k += 1


def build_wall_seg(hi):
    tag = "H" if hi else "L"
    g = "kb_wall_seg"
    S.slab(f"{g}_body_{tag}", -SEG / 2 - 0.05, SEG / 2 + 0.05, -DEEP, WALL_H, -WALL_T / 2, WALL_T / 2, "limestone",
           g, hi, bevel=0.0)
    S.slab(f"{g}_batter_{tag}", -SEG / 2 - 0.05, SEG / 2 + 0.05, -DEEP, 1.6, -WALL_T / 2 - 0.4, WALL_T / 2 + 0.6,
           "limestone_dark", g, hi, bevel=0.0)
    battlements(g, tag, hi, "bt", -SEG / 2, SEG / 2, WALL_H, WALL_T / 2 - 0.55)
    S.slab(f"{g}_parapet_{tag}", -SEG / 2, SEG / 2, WALL_H, WALL_H + 0.5, -WALL_T / 2, -WALL_T / 2 + 0.4,
           "limestone_dark", g, hi, bevel=0.0)
    for k, x in enumerate((-2.0, 2.0)):   # arrow slits on the outer face
        S.box(f"{g}_slit{k}_{tag}", (0.25, 1.1, 0.1), (x, 5.2, WALL_T / 2 + 0.02), "dark", g, hi, bevel=0.0)


def build_wall_tower(hi):
    tag = "H" if hi else "L"
    g = "kb_wall_tower"
    r = 3.4
    zc = 1.0
    S.cylinder(f"{g}_body_{tag}", r, -DEEP, WALL_H + 2.0, (0.0, zc), "limestone", g, hi, seg=(10, 24))
    S.cylinder(f"{g}_batter_{tag}", r + 0.6, -DEEP, 1.8, (0.0, zc), "limestone_dark", g, hi, seg=(10, 24), r_top=r)
    n = K.L(hi, 8, 12)
    for k in range(n):
        a = 2 * math.pi * (k + 0.5) / n
        x, z = math.cos(a) * (r - 0.45), zc + math.sin(a) * (r - 0.45)
        S.box(f"{g}_m{k}_{tag}", (1.1, 1.3, 0.9), (x, WALL_H + 2.65, z), "limestone", g, hi, rot=(0, -a, 0))
    for k, (a, y) in enumerate(((0.6, 4.5), (1.57, 7.0), (2.5, 4.5))):
        x, z = math.cos(a) * (r + 0.02), zc + math.sin(a) * (r + 0.02)
        S.box(f"{g}_slit{k}_{tag}", (0.25, 1.1, 0.1), (x, y, z), "dark", g, hi, rot=(0, math.pi / 2 - a, 0), bevel=0.0)


def build_wall_gate(hi):
    tag = "H" if hi else "L"
    g = "kb_wall_gate"
    n = K.L(hi, 8, 18)
    h = WALL_H + 2.5
    arch = S.pointed(1.8, 4.0, 2.2, n)
    poly = [(-SEG / 2, -DEEP), (-1.8, -DEEP), (-1.8, 0.0)] + arch + [(1.8, 0.0), (1.8, -DEEP), (SEG / 2, -DEEP),
                                                                   (SEG / 2, h), (-SEG / 2, h)]
    S.extrude(f"{g}_body_{tag}", list(reversed(poly)), -WALL_T / 2 - 0.4, WALL_T / 2 + 0.4, "limestone", g, hi)
    ring_o = S.pointed(2.3, 4.0, 2.7, n)
    S.extrude(f"{g}_ring_{tag}", list(reversed(arch + list(reversed(ring_o)))), WALL_T / 2 + 0.4, WALL_T / 2 + 0.55,
              "trim", g, hi)
    S.slab(f"{g}_floor_{tag}", -1.8, 1.8, -DEEP, 0.0, -WALL_T / 2 - 0.4, WALL_T / 2 + 0.4, "limestone_dark", g, hi,
           bevel=0.0)
    for s in (-1, 1):   # the two heavy wooden doors, opened
        S.box(f"{g}_door{s}_{tag}", (0.15, 4.6, 1.7), (s * 1.65, 2.3, -WALL_T / 2 - 0.4 - 0.85), "wood", g, hi,
              bevel=0.0)
    battlements(g, tag, hi, "bt", -SEG / 2, SEG / 2, h, WALL_T / 2)
    S.slab(f"{g}_panel_{tag}", -1.6, 1.6, 7.0, 8.4, WALL_T / 2 + 0.4, WALL_T / 2 + 0.5, "trim", g, hi, bevel=0.0)


def build(hi):
    global _looked
    if not _looked:
        S.add_looks(LOOK)
        _looked = True
    _build(hi)


_build = S.run_set(GROUPS, {"kb_shusha_sign": build_sign, "kb_mosque": build_mosque, "kb_vagif": build_vagif,
                            "kb_wall_seg": build_wall_seg, "kb_wall_tower": build_wall_tower,
                            "kb_wall_gate": build_wall_gate}, 60.0)
K.CAGE, K.RAY, K.AO_DIST = 0.08, 0.2, 2.0
K.setup("karabakh_shusha", "assets/models/karabakh_shusha", PALETTE, PAINT_MAT, GROUPS, UV_SCALE, FAR_RATIO,
        stone_mats=["__no_stone__"])
K.run(build)
