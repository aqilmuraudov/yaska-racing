"""Generic new 9-storey Baku residential blocks (0.15.3, owner: ordinary
buildings as the new 9-storey builds seen all over Baku). Placed unscaled by
TrackDecor's CityBlocks so windows keep their real proportions.

  blender --background --factory-startup --python tools/blender/blocks_props.py -- --bake-res 4096 --tex-res 2048
  block9_a  cream with white floor bands and glazed balcony strips
  block9_b  sandstone with stacked bay windows and a darker base
  block9_c  light grey with blue glass corners (newer towers)
All 30 m wide, 16 m deep, ground floor shops (4.5 m) + 9 floors of 3.1 m +
parapet; front +Z, origin on the ground. orm alpha = glass (lit at night).
"""

import math
import os
import sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from kart_common import *  # noqa: F401,F403
import kart_common as K
from mathutils import Vector, Matrix

PALETTE = {
    "cream": ("EADBC0", 0.8, 0.0), "white": ("F4F2EC", 0.6, 0.0), "sandstone": ("D6BC8E", 0.85, 0.0),
    "sand_dark": ("B39A72", 0.85, 0.0), "grey": ("C9CCCF", 0.7, 0.0), "glass": ("3B6E95", 0.08, 0.3),
    "glass_blue": ("2C86C0", 0.08, 0.45), "shop": ("F0C878", 0.2, 0.0), "frame": ("5D646E", 0.4, 0.5),
}
PAINT_MAT = ["glass", "glass_blue", "shop"]
STONE = ["sandstone", "sand_dark"]
GROUPS = ["block9_a", "block9_b", "block9_c"]
UV_SCALE = {g: 1.0 for g in GROUPS}
FAR_RATIO = {g: 0.45 for g in GROUPS}

W, D = 30.0, 16.0
G0 = 4.5
FH = 3.1
NF = 9
TOP = G0 + FH * NF


def windows(g, tag, hi, z, glass, spacing=2.6, w=1.5, h=1.9, skip=None):
    if not hi:
        return
    for f in range(NF):
        y = G0 + f * FH + 0.6
        for k in range(int(W / spacing)):
            x = -W / 2 + spacing / 2 + k * spacing
            if skip and skip(x):
                continue
            bbox(f"{g}_w{f}_{k}", (w, h, 0.05), (x, y + h / 2, z), glass, g, True, 0.0)


def side_windows(g, hi, glass):
    if not hi:
        return
    for f in range(NF):
        y = G0 + f * FH + 0.6
        for s in (-1, 1):
            for k in range(int(D / 3.0)):
                zz = -D / 2 + 1.5 + k * 3.0
                bbox(f"{g}_sw{f}{s}{k}", (0.05, 1.9, 1.4), (s * (W / 2 + 0.02), y + 0.95, zz), glass, g, True, 0.0)


def shops(g, tag, hi, z, base_mat):
    bbox(f"{g}_ground_{tag}", (W + 0.2, G0, D + 0.2), (0, G0 / 2, 0), base_mat, g, hi, L(hi, 0.0, 0.1))
    for k in range(5):
        x = -W / 2 + 3.0 + k * 6.0
        bbox(f"{g}_shop{k}_{tag}", (4.6, 3.2, 0.2), (x, 1.9, z + 0.1), "shop", g, hi, 0.0)
    bbox(f"{g}_awn_{tag}", (W + 0.6, 0.3, 1.4), (0, G0 - 0.2, z + 0.7), "frame", g, hi, 0.0)


def roof(g, tag, hi, mat):
    bbox(f"{g}_parapet_{tag}", (W + 0.4, 1.1, D + 0.4), (0, TOP + 0.55, 0), mat, g, hi, L(hi, 0.0, 0.08))
    bbox(f"{g}_stair_{tag}", (5.0, 3.0, 5.0), (W * 0.25, TOP + 1.5, -2.0), mat, g, hi, L(hi, 0.0, 0.1))


def build_a(hi):
    tag = "H" if hi else "L"
    g = "block9_a"
    bbox(f"{g}_body_{tag}", (W, TOP - G0, D), (0, (TOP + G0) / 2, 0), "cream", g, hi, L(hi, 0.0, 0.2))
    shops(g, tag, hi, D / 2, "sand_dark")
    for f in range(NF + 1):
        bbox(f"{g}_band{f}_{tag}", (W + 0.3, 0.3, D + 0.3), (0, G0 + f * FH, 0), "white", g, hi, 0.0)
    # Glazed balcony strips at both ends of the front.
    for s in (-1, 1):
        bbox(f"{g}_bal{s}_{tag}", (7.0, TOP - G0 - 0.4, 1.4), (s * 10.0, (TOP + G0) / 2, D / 2 + 0.7), "glass", g, hi, 0.0)
        if hi:
            for f in range(NF):
                bbox(f"{g}_balrail{s}{f}", (7.2, 0.9, 0.08), (s * 10.0, G0 + f * FH + 0.45, D / 2 + 1.42), "white", g,
                     True, 0.0)
    windows(g, tag, hi, D / 2 + 0.02, "glass", skip=lambda x: abs(abs(x) - 10.0) < 3.6)
    side_windows(g, hi, "glass")
    roof(g, tag, hi, "white")


def build_b(hi):
    tag = "H" if hi else "L"
    g = "block9_b"
    bbox(f"{g}_body_{tag}", (W, TOP - G0, D), (0, (TOP + G0) / 2, 0), "sandstone", g, hi, L(hi, 0.0, 0.2))
    shops(g, tag, hi, D / 2, "sand_dark")
    # Stacked bay windows (erkers) - three columns.
    for k, x in enumerate((-9.0, 0.0, 9.0)):
        bbox(f"{g}_bay{k}_{tag}", (4.6, TOP - G0 - 3.1, 1.2), (x, (TOP + G0 - 3.1) / 2 + 1.5, D / 2 + 0.6), "sandstone",
             g, hi, L(hi, 0.0, 0.1))
        if hi:
            for f in range(NF - 1):
                bbox(f"{g}_bayw{k}{f}", (3.4, 2.0, 0.05), (x, G0 + f * FH + 1.55, D / 2 + 1.22), "glass", g, True, 0.0)
    windows(g, tag, hi, D / 2 + 0.02, "glass", spacing=3.0, skip=lambda x: min(abs(x + 9.0), abs(x), abs(x - 9.0)) < 2.6)
    side_windows(g, hi, "glass")
    bbox(f"{g}_cornice_{tag}", (W + 1.0, 0.6, D + 1.0), (0, TOP, 0), "white", g, hi, L(hi, 0.0, 0.15))
    roof(g, tag, hi, "sandstone")


def build_c(hi):
    tag = "H" if hi else "L"
    g = "block9_c"
    bbox(f"{g}_body_{tag}", (W - 6.0, TOP - G0, D), (-3.0, (TOP + G0) / 2, 0), "grey", g, hi, L(hi, 0.0, 0.2))
    # Blue glass corner volume, full height.
    bbox(f"{g}_corner_{tag}", (6.0, TOP - G0 + 2.0, D), (W / 2 - 3.0, (TOP + G0 + 2.0) / 2, 0), "glass_blue", g, hi, 0.0)
    shops(g, tag, hi, D / 2, "frame")
    for f in range(NF + 1):
        bbox(f"{g}_slab{f}_{tag}", (W - 6.0 + 0.3, 0.25, D + 0.3), (-3.0, G0 + f * FH, 0), "white", g, hi, 0.0)
    windows(g, tag, hi, D / 2 + 0.02, "glass", spacing=2.2, w=1.7, skip=lambda x: x > W / 2 - 6.4)
    side_windows(g, hi, "glass")
    roof(g, tag, hi, "grey")


OFFSET = {g: Vector((i * 60.0, 0.0, 0.0)) for i, g in enumerate(GROUPS)}


def _built(fn):
    before = set(K.COLL.objects)
    fn()
    for o in set(K.COLL.objects) - before:
        o.data.transform(Matrix.Translation(OFFSET[o["group"]]))


def build(hi):
    _built(lambda: build_a(hi))
    _built(lambda: build_b(hi))
    _built(lambda: build_c(hi))


def _home(groups):
    for o in groups:
        o.data.transform(Matrix.Translation(-OFFSET[o.name]))


K.PRE_EXPORT.append(_home)

K.setup("blocks_props", "assets/models/blocks", PALETTE, PAINT_MAT, GROUPS, UV_SCALE, FAR_RATIO, stone_mats=STONE)
K.run(build)
