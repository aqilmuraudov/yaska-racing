"""Town entry signs for the Qarabağ map (0.19.2 Blender models; owner 2026-11-11:
"hər şəhərin girişində plakat kimi şəhərin adını yazaq üzərində bayraq ilə,
görünən ölçüdə").

  blender --background --factory-startup --python tools/blender/karabakh_signs.py -- --bake-res 4096 --tex-res 2048
Same pipeline as the other prop sets (kart_common.run). One model per town:
  kb_sign_khankendi  XANKƏNDİ
  kb_sign_shusha     ŞUŞA
  kb_sign_lachin     LAÇIN
A limestone wall (22-26 m) on a granite plinth, the name in 4 m white letters
standing on it, a flower bed in front and a 16 m flag mast at the left end. The
Azerbaijani flag is the waving LandmarkKit flag, added in Godot at SIGN_MAST_TOP
(KarabakhDecor), flying to the right over the letters. Frame: x across, y up,
+z the front (it faces the oncoming karts, tools/karabakh_layout.py), origin
at the footprint centre on its pad.
"""

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
    "board": ("2B2F36", 0.6, 0.0),
    "trim": ("ECE5D3", 0.8, 0.0),
    "letters": ("FBFAF6", 0.45, 0.0),
    "steel": ("B9BFC5", 0.3, 0.9),
    "grass": ("5E8F3A", 0.95, 0.0),
    "flower_red": ("D23C3C", 0.8, 0.0),
    "flower_yellow": ("F2C230", 0.8, 0.0),
    "glass": ("2F5F86", 0.08, 0.3),
}
PAINT_MAT = "glass"
LOOK = {"limestone": "cobble", "granite": "cut", "trim": "plain", "grass": "grass"}
NAMES = {"kb_sign_khankendi": "XANKƏNDİ", "kb_sign_shusha": "ŞUŞA", "kb_sign_lachin": "LAÇIN"}
GROUPS = list(NAMES)
UV_SCALE = {g: 1.0 for g in GROUPS}
FAR_RATIO = {g: 0.45 for g in GROUPS}
F = S.FOUND
W = 22.0            # wall width (all three: one footprint in the layout)
MAST_X = -W / 2 - 1.6
MAST_TOP = 17.0     # = KarabakhDecor.SIGN_MAST_TOP.y
_looked = False


def build_sign(g, hi):
    tag = "H" if hi else "L"
    name = NAMES[g]
    S.slab(f"{g}_plinth_{tag}", -W / 2 - 3.0, W / 2 + 0.5, -F, 0.3, -2.0, 2.0, "granite", g, hi)
    S.slab(f"{g}_wall_{tag}", -W / 2, W / 2, 0.3, 3.4, -0.9, 0.6, "limestone", g, hi)
    S.slab(f"{g}_cap_{tag}", -W / 2 - 0.25, W / 2 + 0.25, 3.4, 3.75, -1.1, 0.8, "trim", g, hi)
    # the name: 4 m letters standing on the wall, facing the karts
    size = 6.5 if len(name) <= 5 else 5.4
    top = 3.75 + size * 1.05 + 0.6
    # dark granite board behind the letters (white on dark reads from far away)
    S.slab(f"{g}_board_{tag}", -W / 2 + 0.3, W / 2 - 0.3, 3.75, top, -0.85, -0.45, "board", g, hi)
    S.slab(f"{g}_boardcap_{tag}", -W / 2 + 0.1, W / 2 - 0.1, top, top + 0.3, -1.0, -0.3, "trim", g, hi)
    S.text3d(f"{g}_name_{tag}", name, size, Matrix.Translation((0.0, 3.75 + 0.35 + size * 0.5, -0.2)), "letters", g,
             hi, depth=0.5)
    # flower bed in front
    S.slab(f"{g}_bed_{tag}", -W / 2, W / 2, 0.3, 0.55, 0.6, 1.9, "grass", g, hi, bevel=0.0)
    n = int(W // 1.4)
    for k in range(n):
        x = -W / 2 + 0.7 + k * 1.4
        S.cylinder(f"{g}_fl{k}_{tag}", 0.5, 0.55, 0.95, (x, 1.25), "flower_red" if k % 2 else "flower_yellow", g, hi,
                   seg=(5, 8))
    # the flag mast at the left end
    S.cylinder(f"{g}_mastbase_{tag}", 0.75, 0.3, 1.2, (MAST_X, 0.0), "trim", g, hi, seg=(8, 16))
    S.cylinder(f"{g}_mast_{tag}", 0.17, 1.2, MAST_TOP + 0.1, (MAST_X, 0.0), "steel", g, hi, seg=(6, 12), r_top=0.11)
    S.cylinder(f"{g}_finial_{tag}", 0.24, MAST_TOP + 0.1, MAST_TOP + 0.45, (MAST_X, 0.0), "steel", g, hi, seg=(6, 10))


def build(hi):
    global _looked
    if not _looked:
        S.add_looks(LOOK)
        _looked = True
    _build(hi)


_build = S.run_set(GROUPS, {g: (lambda hi, g=g: build_sign(g, hi)) for g in GROUPS}, 60.0)
K.CAGE, K.RAY, K.AO_DIST = 0.08, 0.2, 2.0
K.setup("karabakh_signs", "assets/models/karabakh_signs", PALETTE, PAINT_MAT, GROUPS, UV_SCALE, FAR_RATIO,
        stone_mats=["__no_stone__"])
K.run(build)
