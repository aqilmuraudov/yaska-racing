"""Name boards of the Qarabağ sights and Laçın's Bayraq meydanı (0.20.1 Blender models).

Owner (2026-11-11): "the names of the main known buildings / objects in capital
letters, big, on all of them - LaCinema, Lachin Resort & SPA, Bayraq meydanı...;
Laçın has the famous Bayraq meydanı, make it too".

  blender --background --factory-startup --python tools/blender/karabakh_names.py -- --bake-res 2048 --tex-res 1024
Same pipeline as the other prop sets (kart_common.run).
  kb_name_<sight>  a dark granite board on a limestone plinth with the name in
                   white letters 2.4-2.8 m high (one or two lines), like the
                   town entry signs; set beside the road in front of its sight,
                   turned to the oncoming karts (tools/karabakh_maps_layout.py).
  kb_flag_square   Bayraq meydanı: a round granite square (r 15) with a star of
                   paving, a stepped round podium and a 40 m flag mast; lawns,
                   lamps and benches round it. The flag is the waving LandmarkKit
                   flag (Godot: KarabakhDecor.FLAG_SQUARE_TOP), as on the signs.
                   An approximation (no photo): the owner reviews the render.
Frame: x across, y up, +z the front (to the road), origin on the pad.
Writes assets/models/karabakh_names/sizes.json: each board's footprint (w, d)
for the layout.
"""

import json
import math
import os
import sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from kart_common import *  # noqa: F401,F403
import kart_common as K
from mathutils import Matrix
import kb_shapes as S

PALETTE = {
    "limestone": ("D3C4A2", 0.9, 0.0),
    "granite": ("8E8A82", 0.8, 0.0),
    "granite_red": ("9B5A4A", 0.7, 0.0),
    "board": ("2B2F36", 0.6, 0.0),
    "trim": ("ECE5D3", 0.8, 0.0),
    "letters": ("FBFAF6", 0.45, 0.0),
    "steel": ("B9BFC5", 0.3, 0.9),
    "grass": ("5E8F3A", 0.95, 0.0),
    "flower_red": ("D23C3C", 0.8, 0.0),
    "flower_yellow": ("F2C230", 0.8, 0.0),
    "paving": ("CFC8B8", 0.85, 0.0),
    "paving_dark": ("8D8A84", 0.85, 0.0),
    "frame": ("33373D", 0.4, 0.6),
    "lamp": ("F4EFD8", 0.4, 0.0),
    "wood": ("8A5A36", 0.7, 0.0),
    "glass": ("2F5F86", 0.08, 0.3),
}
PAINT_MAT = "glass"
LOOK = {"limestone": "cobble", "granite": "cut", "granite_red": "cut", "trim": "plain", "grass": "grass",
        "paving": "paving", "paving_dark": "paving"}
# id -> lines of the name (capitals, Azerbaijani spelling; the hotel's own name in English)
NAMES = {
    "kb_name_cinema": ["LACINEMA"],
    "kb_name_hotel": ["LACHIN", "RESORT & SPA"],
    "kb_name_flag": ["BAYRAQ MEYDANI"],
    "kb_name_mosque": ["YUXARI GÖVHƏR AĞA", "MƏSCİDİ"],
    "kb_name_vagif": ["VAQİF TÜRBƏSİ"],
    "kb_name_bulbul": ["BÜLBÜLÜN", "EV-MUZEYİ"],
    "kb_name_fortress": ["ŞUŞA QALASI"],
    "kb_name_victory": ["ZƏFƏR MEYDANI"],
    "kb_name_university": ["QARABAĞ", "UNİVERSİTETİ"],
    "kb_name_stadium": ["XANKƏNDİ", "STADİONU"],
    "kb_name_mountains": ["BİZ VƏ", "BİZİM DAĞLAR"],
    "kb_name_bridges": ["XUDAFƏRİN", "KÖRPÜLƏRİ"],
}
# 0.20.1 (owner): the name on Hoçaz itself, big white letters standing on the slope (as some
# countries write a name on a hill). One model per letter: the terrain stands each on the ground.
HOCAZ = {"kb_hl_h": "H", "kb_hl_o": "O", "kb_hl_c": "Ç", "kb_hl_a": "A", "kb_hl_z": "Z"}
HL_SIZE = 30.0                   # em size: capitals ~21 m high
GROUPS = list(NAMES) + ["kb_flag_square"] + list(HOCAZ)
UV_SCALE = {g: 1.0 for g in GROUPS}
FAR_RATIO = {g: 0.45 for g in GROUPS}
F = S.FOUND
SIZE1, SIZE2 = 1.3, 1.1          # letter size: one line / two lines (owner: small - the sight must show)
MAST_TOP = 40.0                  # = KarabakhDecor.FLAG_SQUARE_TOP.y
SIZES = {}
_looked = False


def text_width(obj):
    xs = [v.co.x for v in obj.data.vertices]
    return max(xs) - min(xs)


def build_board(g, hi):
    tag = "H" if hi else "L"
    lines = NAMES[g]
    size = SIZE1 if len(lines) == 1 else SIZE2
    gap = size * 1.25
    y0 = 0.8                                   # top of the plinth
    height = len(lines) * gap + 0.5
    widths = []
    for k, ln in enumerate(lines):
        y = y0 + 0.25 + gap * (len(lines) - k - 0.5)
        ob = S.text3d(f"{g}_t{k}_{tag}", ln, size, Matrix.Translation((0.0, y, 0.25)), "letters", g, hi, depth=0.4)
        widths.append(text_width(ob))
    W = max(widths) + 1.2
    S.slab(f"{g}_plinth_{tag}", -W / 2 - 0.3, W / 2 + 0.3, -F, 0.3, -1.0, 1.0, "granite", g, hi)
    S.slab(f"{g}_base_{tag}", -W / 2, W / 2, 0.3, y0, -0.8, 0.6, "limestone", g, hi)
    S.slab(f"{g}_board_{tag}", -W / 2 + 0.1, W / 2 - 0.1, y0, y0 + height, -0.6, 0.05, "board", g, hi)
    S.slab(f"{g}_cap_{tag}", -W / 2 - 0.1, W / 2 + 0.1, y0 + height, y0 + height + 0.3, -0.75, 0.2, "trim", g, hi)
    S.slab(f"{g}_bed_{tag}", -W / 2, W / 2, 0.3, 0.45, 0.6, 1.0, "grass", g, hi, bevel=0.0)
    n = int(W // 1.0)
    for k in range(n):
        x = -W / 2 + 0.5 + k * 1.0
        S.cylinder(f"{g}_fl{k}_{tag}", 0.3, 0.45, 0.7, (x, 0.8), "flower_red" if k % 2 else "flower_yellow", g, hi,
                   seg=(5, 8))
    SIZES[g] = [round(W + 0.6, 2), 2.0, round(y0 + height + 0.3, 2)]


def build_flag_square(hi):
    tag = "H" if hi else "L"
    g = "kb_flag_square"
    R = 15.0
    seg = (24, 48)
    S.slab(f"{g}_pad_{tag}", -20, 20, -F, 0.25, -17, 17, "grass", g, hi, bevel=0.0)
    S.cylinder(f"{g}_square_{tag}", R, -0.2, 0.35, (0.0, 0.0), "paving", g, hi, seg=seg)
    S.cylinder(f"{g}_ring_{tag}", R + 0.5, -0.2, 0.3, (0.0, 0.0), "granite", g, hi, seg=seg)
    # an eight-pointed star of dark paving round the podium
    pts = []
    for k in range(16):
        a = math.pi * k / 8
        r = 11.0 if k % 2 == 0 else 6.5
        pts.append((r * math.cos(a), r * math.sin(a)))
    S.prism(f"{g}_star_{tag}", pts, 0.35, 0.4, "paving_dark", g, hi)
    for k, (r, h) in enumerate(((5.0, 0.9), (4.0, 1.45), (3.0, 2.0))):     # the stepped podium
        S.cylinder(f"{g}_step{k}_{tag}", r, 0.35, h, (0.0, 0.0), "granite_red" if k == 2 else "granite", g, hi,
                   seg=(16, 32))
    S.cylinder(f"{g}_mast_{tag}", 0.45, 2.0, MAST_TOP, (0.0, 0.0), "steel", g, hi, seg=(8, 16), r_top=0.22)
    S.cylinder(f"{g}_finial_{tag}", 0.45, MAST_TOP, MAST_TOP + 0.9, (0.0, 0.0), "steel", g, hi, seg=(8, 12))
    # lawns at the corners, lamps and benches on the ring
    for sx in (-1, 1):
        for sz in (-1,):          # back corners only: the front stays open to the road (the name board)
            S.cylinder(f"{g}_tree{sx}{sz}_{tag}", 0.2, 0.25, 2.6, (sx * 17.5, sz * 14.5), "wood", g, hi, seg=(5, 8))
            S.tree_ball(f"{g}_crown{sx}{sz}_{tag}", (sx * 17.5, 3.8, sz * 14.5), 1.8, "grass", g, hi, sx + sz * 2)
    for k in range(8):
        a = math.pi / 8 + k * math.pi / 4
        x, z = (R - 1.2) * math.cos(a), (R - 1.2) * math.sin(a)
        S.cylinder(f"{g}_lp{k}_{tag}", 0.1, 0.35, 5.2, (x, z), "frame", g, hi, seg=(5, 8))
        S.cylinder(f"{g}_lh{k}_{tag}", 0.35, 5.2, 5.7, (x, z), "lamp", g, hi, seg=(6, 10))
        bx, bz = (R - 2.6) * math.cos(a + math.pi / 8), (R - 2.6) * math.sin(a + math.pi / 8)
        S.box(f"{g}_bench{k}_{tag}", (1.8, 0.45, 0.5), (bx, 0.6, bz), "wood", g, hi,
              rot=(0.0, -(a + math.pi / 8) + math.pi / 2, 0.0))


def build_hocaz_letter(g, hi):
    """A letter (front +z, its foot at y 0) that lies on the mountain face: the terrain tilts it
    back onto the slope (lines.json pitch), a thick slab so the face never shows through."""
    tag = "H" if hi else "L"
    ob = S.text3d(f"{g}_t_{tag}", HOCAZ[g], HL_SIZE, Matrix.Identity(4), "letters", g, hi, depth=1.6)
    ys = [v.co.y for v in ob.data.vertices]
    xs = [v.co.x for v in ob.data.vertices]
    ob.data.transform(Matrix.Translation((0.0, -min(ys), 0.0)))
    h = max(ys) - min(ys)
    SIZES[g] = [round(max(xs) - min(xs), 2), 3.0, round(h, 2)]


def build(hi):
    global _looked
    if not _looked:
        S.add_looks(LOOK)
        _looked = True
    _build(hi)
    out = os.path.join(K.ROOT, "assets", "models", "karabakh_names")
    os.makedirs(out, exist_ok=True)
    json.dump({"doc": "board footprint: w (across), d (deep), height (m)", "sizes": SIZES},
              open(os.path.join(out, "sizes.json"), "w", encoding="utf-8"), ensure_ascii=False, indent=1)


fns = {g: (lambda hi, g=g: build_board(g, hi)) for g in NAMES}
fns["kb_flag_square"] = build_flag_square
for _g in HOCAZ:
    fns[_g] = (lambda hi, g=_g: build_hocaz_letter(g, hi))
_build = S.run_set(GROUPS, fns, 60.0)
K.CAGE, K.RAY, K.AO_DIST = 0.08, 0.2, 2.0
K.setup("karabakh_names", "assets/models/karabakh_names", PALETTE, PAINT_MAT, GROUPS, UV_SCALE, FAR_RATIO,
        stone_mats=["__no_stone__"])
K.run(build)
