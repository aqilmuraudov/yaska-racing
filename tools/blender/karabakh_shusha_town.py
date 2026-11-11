"""Old Şuşa town houses and Bülbül's house-museum (0.20.1 Blender models).

  blender --background --factory-startup --python tools/blender/karabakh_shusha_town.py -- --bake-res 4096 --tex-res 2048
Same pipeline as the other prop sets (kart_common.run). Frame: x along the
road, y up, z towards the road (front), origin on the pad.
The 18th-19th century Şuşa house (heritage listings): walls of rough limestone,
the upper floor opening onto a wooden gallery ("eyvan") on posts, windows with
"şəbəkə" lattices and coloured glass, a hipped tin roof.
  kb_sh_house_a  two storeys, a full-width wooden eyvan on the front, green tin roof
  kb_sh_house_b  two storeys of cut stone, arched şəbəkə windows, red tin roof
  kb_sh_house_c  one storey and a half, a corner eyvan on posts, grey tin roof,
                 a stone garden wall
  kb_bulbul      Bülbül's house-museum: a larger two-storey stone house with a
                 long carved wooden gallery upstairs, a courtyard wall and gate
                 (no lettering, no bust - not named by the owner)
Forms are approximations from the general type; the owner reviews the renders.
"""

import math
import os
import sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from kart_common import *  # noqa: F401,F403
import kart_common as K
from mathutils import Matrix
import kb_shapes as S

PALETTE = {
    "rubble": ("C2B394", 0.92, 0.0),
    "cut_stone": ("D3C6A6", 0.88, 0.0),
    "plinth": ("9C8F74", 0.9, 0.0),
    "wood": ("7A4F2E", 0.75, 0.0),
    "wood_light": ("A9744A", 0.75, 0.0),
    "glass": ("3C6A8A", 0.08, 0.3),
    "glass_red": ("B8343A", 0.1, 0.2),
    "glass_yellow": ("E2B23C", 0.1, 0.2),
    "roof_green": ("4E7458", 0.45, 0.5),
    "roof_red": ("9A3A2C", 0.45, 0.5),
    "roof_grey": ("7D848A", 0.4, 0.6),
    "door": ("5A3820", 0.7, 0.0),
    "grass": ("5E8F3A", 0.95, 0.0),
    "paving": ("BDB3A0", 0.9, 0.0),
    "flower": ("D6457A", 0.8, 0.0),
    "leaf": ("4C7A2E", 0.9, 0.0),
    "trunk": ("6B4A32", 0.9, 0.0),
}
PAINT_MAT = ["glass", "glass_red", "glass_yellow"]   # windows glow at night
LOOK = {"rubble": "cobble", "cut_stone": "cut", "plinth": "cut", "grass": "grass", "paving": "paving",
        "roof_green": "plain", "roof_red": "plain", "roof_grey": "plain", "wood": "plain", "wood_light": "plain"}
GROUPS = ["kb_sh_house_a", "kb_sh_house_b", "kb_sh_house_c", "kb_bulbul"]
UV_SCALE = {g: 1.0 for g in GROUPS}
FAR_RATIO = {g: 0.4 for g in GROUPS}
F = S.FOUND
_looked = False


def hip(g, tag, hi, name, x0, x1, z0, z1, y, rise, mat, over=0.6):
    S.prism(f"{g}_{name}_{tag}", [(x0 - over, z0 - over), (x1 + over, z0 - over), (x1 + over, z1 + over),
                                  (x0 - over, z1 + over)], y, y + 0.12, mat, g, hi,
            apex=((x0 + x1) / 2, y + rise, (z0 + z1) / 2))


def shebeke(g, tag, hi, name, x, y, z, w=1.2, h=1.7, arched=False):
    """Lattice window: a wooden frame, coloured glass panes in a grid."""
    S.box(f"{g}_{name}_frame_{tag}", (w + 0.2, h + 0.2, 0.14), (x, y, z), "wood", g, hi, bevel=0.0)
    cols, rows = (3, 4) if hi else (1, 1)
    cw, ch = w / cols, h / rows
    mats = ["glass", "glass_red", "glass_yellow", "glass"]
    for i in range(cols):
        for j in range(rows):
            S.box(f"{g}_{name}_p{i}{j}_{tag}", (cw - 0.08, ch - 0.08, 0.06),
                  (x - w / 2 + cw * (i + 0.5), y - h / 2 + ch * (j + 0.5), z + 0.06),
                  mats[(i + j) % 4] if hi else "glass", g, hi, bevel=0.0)
    if arched:   # a half-round fan of yellow glass in a wooden ring over the window
        n = K.L(hi, 6, 12)
        r = w / 2 + 0.1
        outer = [(x + r * math.cos(math.pi * k / n), y + h / 2 + r * math.sin(math.pi * k / n)) for k in range(n + 1)]
        ri = r - 0.12
        inner = [(x + ri * math.cos(math.pi * k / n), y + h / 2 + 0.06 + ri * math.sin(math.pi * k / n))
                 for k in range(n, -1, -1)]
        S.extrude(f"{g}_{name}_ring_{tag}", outer + inner, z - 0.07, z + 0.07, "wood", g, hi)
        S.extrude(f"{g}_{name}_fan_{tag}", list(reversed(inner)), z - 0.03, z + 0.03, "glass_yellow", g, hi)


def eyvan(g, tag, hi, name, x0, x1, z_face, y_floor, depth, posts):
    """Wooden gallery on posts in front of the upper floor, with a carved railing."""
    S.slab(f"{g}_{name}_floor_{tag}", x0, x1, y_floor - 0.25, y_floor, z_face, z_face + depth, "wood", g, hi)
    for k in range(posts):
        x = x0 + 0.2 + (x1 - x0 - 0.4) * k / (posts - 1)
        S.slab(f"{g}_{name}_post{k}_{tag}", x - 0.13, x + 0.13, 0.3, y_floor + 2.9, z_face + depth - 0.3,
               z_face + depth - 0.04, "wood", g, hi, bevel=0.0)
    S.slab(f"{g}_{name}_rail_{tag}", x0, x1, y_floor + 0.85, y_floor + 1.0, z_face + depth - 0.25, z_face + depth,
           "wood_light", g, hi, bevel=0.0)
    n = int((x1 - x0) / 0.45)
    for k in range(n if hi else 0):     # balusters
        x = x0 + 0.25 + k * 0.45
        S.slab(f"{g}_{name}_bal{k}_{tag}", x - 0.05, x + 0.05, y_floor, y_floor + 0.85, z_face + depth - 0.2,
               z_face + depth - 0.1, "wood_light", g, hi, bevel=0.0)
    S.slab(f"{g}_{name}_beam_{tag}", x0, x1, y_floor + 2.9, y_floor + 3.15, z_face, z_face + depth, "wood", g, hi,
           bevel=0.0)


def base(g, tag, hi, w=12.0, d=11.0):
    S.slab(f"{g}_plinth_{tag}", -w / 2, w / 2, -F, 0.3, -d / 2, d / 2, "paving", g, hi, bevel=0.0)


def build_house_a(hi):
    tag = "H" if hi else "L"
    g = "kb_sh_house_a"
    base(g, tag, hi)
    z0, z1 = -5.0, 1.5
    S.slab(f"{g}_socle_{tag}", -5, 5, 0.3, 1.0, z0, z1, "plinth", g, hi)
    S.slab(f"{g}_body_{tag}", -5, 5, 1.0, 7.0, z0, z1, "rubble", g, hi)
    for x in (-3.0, 0.0, 3.0):
        shebeke(g, tag, hi, f"w1{x:.0f}", x, 2.6, z1 + 0.02, 1.0, 1.4)
        shebeke(g, tag, hi, f"w2{x:.0f}", x, 5.4, z1 + 0.02, 1.2, 1.8)
    S.box(f"{g}_door_{tag}", (1.2, 2.2, 0.12), (-1.5, 1.4, z1 + 0.04), "door", g, hi, bevel=0.0)
    eyvan(g, tag, hi, "ey", -5.0, 5.0, z1, 4.0, 1.8, 5)
    hip(g, tag, hi, "roof", -5, 5, z0, z1 + 1.8, 7.0, 2.6, "roof_green")
    S.slab(f"{g}_yard_{tag}", -5.8, 5.8, 0.3, 0.35, z1 + 2.0, 5.3, "grass", g, hi, bevel=0.0)


def build_house_b(hi):
    tag = "H" if hi else "L"
    g = "kb_sh_house_b"
    base(g, tag, hi)
    z0, z1 = -5.0, 2.5
    S.slab(f"{g}_socle_{tag}", -5.2, 5.2, 0.3, 1.1, z0, z1, "plinth", g, hi)
    S.slab(f"{g}_body_{tag}", -5, 5, 1.1, 7.6, z0, z1, "cut_stone", g, hi)
    S.slab(f"{g}_band_{tag}", -5.1, 5.1, 4.2, 4.45, z0 - 0.1, z1 + 0.1, "plinth", g, hi, bevel=0.0)
    S.slab(f"{g}_cornice_{tag}", -5.3, 5.3, 7.6, 7.9, z0 - 0.3, z1 + 0.3, "plinth", g, hi)
    for x in (-3.2, 0.0, 3.2):
        if x != 0.0:      # the door is in the middle of the ground floor
            shebeke(g, tag, hi, f"w1{x:.0f}", x, 2.5, z1 + 0.02, 1.0, 1.5, arched=True)
        shebeke(g, tag, hi, f"w2{x:.0f}", x, 5.6, z1 + 0.02, 1.2, 1.8, arched=True)
    S.box(f"{g}_door_{tag}", (1.4, 2.4, 0.12), (0.0, 1.5, z1 + 0.04), "door", g, hi, bevel=0.0)
    hip(g, tag, hi, "roof", -5, 5, z0, z1, 7.9, 2.4, "roof_red")
    S.slab(f"{g}_steps_{tag}", -1.2, 1.2, 0.3, 0.75, z1, z1 + 0.9, "plinth", g, hi, bevel=0.0)


def build_house_c(hi):
    tag = "H" if hi else "L"
    g = "kb_sh_house_c"
    base(g, tag, hi)
    z0, z1 = -5.0, 1.0
    S.slab(f"{g}_body_{tag}", -4.5, 3.0, 0.3, 4.6, z0, z1, "rubble", g, hi)
    S.slab(f"{g}_upper_{tag}", -4.5, 0.0, 4.6, 6.8, z0, z1, "rubble", g, hi)
    for x in (-3.0, 1.6):
        shebeke(g, tag, hi, f"w1{x:.0f}", x, 2.4, z1 + 0.02, 1.0, 1.4)
    shebeke(g, tag, hi, "w2", -2.2, 5.6, z1 + 0.02, 1.2, 1.4)
    S.box(f"{g}_door_{tag}", (1.1, 2.1, 0.12), (-0.6, 1.35, z1 + 0.04), "door", g, hi, bevel=0.0)
    # corner eyvan on posts over the lower wing
    eyvan(g, tag, hi, "ey", 0.0, 3.0, z0, 4.6, z1 - z0, 3)
    hip(g, tag, hi, "roof_hi", -4.5, 0.0, z0, z1, 6.8, 2.0, "roof_grey")
    S.slab(f"{g}_eyroof_{tag}", -0.2, 3.4, 7.7, 7.85, z0 - 0.3, z1 + 0.4, "roof_grey", g, hi, bevel=0.0)
    # stone garden wall and a tree
    S.slab(f"{g}_gwall_{tag}", -5.8, 5.8, 0.3, 1.4, 4.8, 5.3, "rubble", g, hi)
    S.slab(f"{g}_garden_{tag}", -5.8, 5.8, 0.3, 0.35, z1 + 0.2, 4.8, "grass", g, hi, bevel=0.0)
    S.cylinder(f"{g}_tt_{tag}", 0.18, 0.3, 2.6, (4.2, 3.0), "trunk", g, hi, seg=(5, 8))
    S.tree_ball(f"{g}_tc_{tag}", (4.2, 3.9, 3.0), 1.6, "leaf", g, hi, 2.0)


def build_bulbul(hi):
    tag = "H" if hi else "L"
    g = "kb_bulbul"
    W, D = 18.0, 13.0
    S.slab(f"{g}_plinth_{tag}", -W / 2, W / 2, -F, 0.3, -D / 2, D / 2, "paving", g, hi, bevel=0.0)
    z0, z1 = -6.0, 0.5
    S.slab(f"{g}_socle_{tag}", -7.2, 7.2, 0.3, 1.0, z0, z1, "plinth", g, hi)
    S.slab(f"{g}_body_{tag}", -7, 7, 1.0, 7.4, z0, z1, "rubble", g, hi)
    for x in (-5.0, -2.5, 2.5, 5.0):
        shebeke(g, tag, hi, f"w1{x:.0f}", x, 2.7, z1 + 0.02, 1.1, 1.5)
    for x in (-5.2, -2.6, 0.0, 2.6, 5.2):
        shebeke(g, tag, hi, f"w2{x:.0f}", x, 5.6, z1 + 0.02, 1.3, 1.9)
    S.box(f"{g}_door_{tag}", (1.6, 2.5, 0.12), (0.0, 1.55, z1 + 0.04), "door", g, hi, bevel=0.0)
    eyvan(g, tag, hi, "ey", -7.0, 7.0, z1, 4.2, 2.2, 7)
    hip(g, tag, hi, "roof", -7, 7, z0, z1 + 2.2, 7.4, 2.8, "roof_green")
    # courtyard: a low stone wall with a gate in front, paving, flower beds, two trees
    S.slab(f"{g}_court_{tag}", -8.6, 8.6, 0.3, 0.38, z1 + 2.4, D / 2 - 0.3, "paving", g, hi, bevel=0.0)
    for sx in (-1, 1):
        S.slab(f"{g}_cwall{sx}_{tag}", min(sx * 1.6, sx * 8.8), max(sx * 1.6, sx * 8.8), 0.3, 1.6, D / 2 - 0.5,
               D / 2, "rubble", g, hi)
        S.slab(f"{g}_gpost{sx}_{tag}", sx * 1.6 - 0.35, sx * 1.6 + 0.35, 0.3, 2.6, D / 2 - 0.6, D / 2 + 0.1,
               "cut_stone", g, hi)
        S.slab(f"{g}_bed{sx}_{tag}", sx * 5.0 - 2.0, sx * 5.0 + 2.0, 0.38, 0.6, z1 + 3.0, z1 + 4.6, "grass", g, hi,
               bevel=0.0)
        S.tree_ball(f"{g}_fl{sx}_{tag}", (sx * 5.0, 0.95, z1 + 3.8), 0.7, "flower", g, hi, sx)
        S.cylinder(f"{g}_tt{sx}_{tag}", 0.2, 0.3, 3.0, (sx * 7.8, z1 + 3.5), "trunk", g, hi, seg=(5, 8))
        S.tree_ball(f"{g}_tc{sx}_{tag}", (sx * 7.8, 4.4, z1 + 3.5), 1.9, "leaf", g, hi, sx * 2)
    S.slab(f"{g}_lintel_{tag}", -1.95, 1.95, 2.6, 3.0, D / 2 - 0.6, D / 2 + 0.1, "cut_stone", g, hi)


def build(hi):
    global _looked
    if not _looked:
        S.add_looks(LOOK)
        _looked = True
    _build(hi)


_build = S.run_set(GROUPS, {"kb_sh_house_a": build_house_a, "kb_sh_house_b": build_house_b,
                            "kb_sh_house_c": build_house_c, "kb_bulbul": build_bulbul}, 60.0)
K.CAGE, K.RAY, K.AO_DIST = 0.08, 0.2, 2.0
K.setup("karabakh_shusha_town", "assets/models/karabakh_shusha_town", PALETTE, PAINT_MAT, GROUPS, UV_SCALE, FAR_RATIO,
        stone_mats=["__no_stone__"])
K.run(build)
