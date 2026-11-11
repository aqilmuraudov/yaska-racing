"""Laçın landmarks for the Qarabağ map (0.19.1 Blender models; named by the owner 2026-11-10).

  blender --background --factory-startup --python tools/blender/karabakh_lachin.py -- --bake-res 4096 --tex-res 2048
Same pipeline as the other prop sets (kart_common.run). Frame: x along the
road / the run, y up, z towards the road (front), origin on the pad.
  kb_cinema       LaCinema (after the owner's photo): a white marble hall
                  with a portico of tall columns and a deep cornice, diamond
                  wall panels, a lower side wing.
  kb_hotel        Lachin Resort & Spa (after the owner's photo, game-scaled
                  80 x 46 m): white neoclassical blocks with grey roofs,
                  forward wings with glass penthouses, end pavilions, the
                  conservatory and the pool on the front terrace.
  kb_garden_cafe  the garden-style café / restaurant on the Həkəri boulevard:
                  pavilion, pergola terrace, tables under umbrellas, planters.
  kb_house_a/b/c  the new town houses: two storeys, light walls, red / brown
                  tiled roofs with solar panels (the rebuilt Laçın).
  kb_blvd_seg     10 m of the Həkəri boulevard (lines.json): paving, the
                  river wall and railing (+z = the river), lamp, bench, tree.
Hoçaz is not a model: it is the terrain's peak (karabakh_terrain.py, owner's photo).
The café's form is an approximation (no reference); the owner reviews the renders.
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
    "wall_white": ("EFEBE2", 0.85, 0.0),
    "wall_cream": ("E8D9B8", 0.85, 0.0),
    "wall_sand": ("D9C3A0", 0.85, 0.0),
    "stone": ("B9AE98", 0.9, 0.0),
    "roof_red": ("A8452F", 0.7, 0.0),
    "roof_brown": ("6E4A36", 0.7, 0.0),
    "roof_grey": ("5C6268", 0.5, 0.3),
    "solar": ("1F3354", 0.15, 0.4),
    "glass": ("3E6A8E", 0.08, 0.3),
    "frame": ("33373D", 0.4, 0.6),
    "wood": ("8A5A36", 0.7, 0.0),
    "red": ("C8202F", 0.5, 0.0),
    "letters": ("F6F4EE", 0.5, 0.0),
    "paving": ("C8C1B2", 0.85, 0.0),
    "grass": ("5E8F3A", 0.95, 0.0),
    "leaf": ("4C7A2E", 0.9, 0.0),
    "trunk": ("6B4A32", 0.9, 0.0),
    "umbrella": ("F2EAD8", 0.8, 0.0),
    "lamp_head": ("F4EFD8", 0.4, 0.0),
    "steel": ("A9AFB6", 0.35, 0.8),
    "flower": ("D6457A", 0.8, 0.0),
    "marble": ("F2F0EA", 0.45, 0.0),
    "marble_grey": ("C9C7C2", 0.5, 0.0),
    "panel": ("ECEAE4", 0.5, 0.0),
    "gold": ("C9A55A", 0.35, 0.8),
    "pool": ("3FC1CF", 0.05, 0.0),
}
PAINT_MAT = "glass"
LOOK = {"wall_white": "plain", "wall_cream": "plain", "wall_sand": "plain", "stone": "cobble", "roof_red": "tile",
        "roof_brown": "tile", "paving": "paving", "grass": "grass", "leaf": "grass", "wood": "plain",
        "marble": "plain", "marble_grey": "cut", "panel": "diamond", "roof_grey": "plain"}
GROUPS = ["kb_cinema", "kb_hotel", "kb_garden_cafe", "kb_house_a", "kb_house_b", "kb_house_c", "kb_blvd_seg"]
UV_SCALE = {g: 1.0 for g in GROUPS}
FAR_RATIO = {g: 0.4 for g in GROUPS}
F = S.FOUND
_looked = False
SWAP_XZ = Matrix(((0, 0, 1, 0), (0, 1, 0, 0), (1, 0, 0, 0), (0, 0, 0, 1)))


def windows(g, tag, hi, x0, x1, y, z, w=1.4, h=1.6, pitch=3.0, skip=None, rot=None):
    n = max(1, int((x1 - x0) // pitch))
    start = (x0 + x1) / 2 - (n - 1) * pitch / 2
    for i in range(n):
        x = start + i * pitch
        if skip and skip[0] < x < skip[1]:
            continue
        ob = S.box(f"{g}_w{i}_{y:.0f}_{z:.0f}_{tag}", (w, h, 0.12), (x, y, z), "glass", g, hi, bevel=0.0)
        if rot is not None:
            ob.data.transform(rot)


def gable(g, tag, hi, name, x0, x1, z0, z1, y, rise, mat, over=0.5):
    """Gable roof, ridge along x."""
    zc = (z0 + z1) / 2
    prof = [(z0 - over, y - 0.15), (zc, y + rise), (z1 + over, y - 0.15), (z1 + over, y + 0.1), (zc, y + rise + 0.25),
            (z0 - over, y + 0.1)]
    S.extrude(f"{g}_{name}_{tag}", [(z, yy) for z, yy in prof], x0 - over, x1 + over, mat, g, hi, matrix=SWAP_XZ)
    return zc


def hip(g, tag, hi, name, x0, x1, z0, z1, y, rise, mat, over=0.5):
    S.prism(f"{g}_{name}_{tag}", [(x0 - over, z0 - over), (x1 + over, z0 - over), (x1 + over, z1 + over),
                                  (x0 - over, z1 + over)], y, y + 0.1, mat, g, hi,
            apex=((x0 + x1) / 2, y + rise, (z0 + z1) / 2))


def solar(g, tag, hi, name, x0, x1, zc, z1, y, rise, over=0.5):
    """Panels on the front slope of a gable() roof (ridge at zc, eave at z1 + over)."""
    def top(z):
        return y + rise + 0.25 - (rise + 0.15) * (z - zc) / (z1 + over - zc)
    za, zb = zc + 0.5, z1 - 0.2
    prof = [(za, top(za) + 0.06), (zb, top(zb) + 0.06), (zb, top(zb) + 0.16), (za, top(za) + 0.16)]
    S.extrude(f"{g}_{name}_{tag}", [(z, y) for z, y in prof], x0, x1, "solar", g, hi, matrix=SWAP_XZ)


# --- LaCinema -----------------------------------------------------------------------------------

def column(g, tag, hi, name, x, z, y0, y1, r=0.55):
    S.slab(f"{g}_{name}_base_{tag}", x - r - 0.25, x + r + 0.25, y0, y0 + 0.9, z - r - 0.25, z + r + 0.25, "marble",
           g, hi)
    S.cylinder(f"{g}_{name}_shaft_{tag}", r, y0 + 0.9, y1 - 0.6, (x, z), "marble", g, hi, seg=(8, 16), r_top=r * 0.9)
    S.slab(f"{g}_{name}_cap_{tag}", x - r - 0.2, x + r + 0.2, y1 - 0.6, y1, z - r - 0.2, z + r + 0.2, "marble", g, hi)


def cornice(g, tag, hi, name, x0, x1, z0, z1, y, dentils=True):
    """Deep classical cornice with a row of modillions (as on LaCinema)."""
    S.slab(f"{g}_{name}_frieze_{tag}", x0, x1, y, y + 0.9, z0, z1, "marble", g, hi)
    S.slab(f"{g}_{name}_corona_{tag}", x0 - 0.9, x1 + 0.9, y + 1.25, y + 1.7, z0 - 0.9, z1 + 0.9, "marble", g, hi)
    S.slab(f"{g}_{name}_bed_{tag}", x0 - 0.45, x1 + 0.45, y + 0.9, y + 1.25, z0 - 0.45, z1 + 0.45, "marble", g, hi)
    if dentils and hi:
        k = 0
        x = x0 - 0.3
        while x < x1 + 0.3:      # front and back rows
            for z in (z0 - 0.6, z1 + 0.6):
                S.box(f"{g}_{name}_d{k}_{tag}", (0.3, 0.3, 0.5), (x, y + 1.05, z), "marble", g, hi, bevel=0.0)
                k += 1
            x += 0.9
        z = z0 - 0.3
        while z < z1 + 0.3:      # the sides
            for x in (x0 - 0.6, x1 + 0.6):
                S.box(f"{g}_{name}_d{k}_{tag}", (0.5, 0.3, 0.3), (x, y + 1.05, z), "marble", g, hi, bevel=0.0)
                k += 1
            z += 0.9


def build_cinema(hi):
    """LaCinema after the owner's photo (2026-11-10): a white marble temple-like
    hall with a deep modillion cornice and a portico of tall columns on the
    front, diamond-patterned wall panels, a podium with steps, and a lower
    side wing with pilasters, a wooden glazed door and its own steps."""
    tag = "H" if hi else "L"
    g = "kb_cinema"
    W, D = 32.0, 28.0
    S.slab(f"{g}_plinth_{tag}", -W / 2, W / 2, -F, 0.2, -D / 2, D / 2, "paving", g, hi, bevel=0.0)
    # podium (grey marble) under the hall and the portico
    hx0, hx1 = -15.0, 4.0
    hz0, hz1 = -13.0, 6.5
    S.slab(f"{g}_podium_{tag}", hx0 - 0.5, hx1 + 0.5, 0.2, 1.2, hz0 - 0.5, hz1 + 6.0, "marble_grey", g, hi)
    for k in range(4):
        S.slab(f"{g}_pstep{k}_{tag}", hx0 + 2.0, hx1 - 2.0, 0.2, 1.2 - k * 0.25, hz1 + 6.0, hz1 + 6.4 + k * 0.4,
               "marble", g, hi, bevel=0.0)
    # the hall: 19 x 19.5 m, 12 m walls with diamond panels
    S.slab(f"{g}_hall_{tag}", hx0, hx1, 1.2, 12.5, hz0, hz1, "panel", g, hi)
    S.slab(f"{g}_socle_{tag}", hx0 - 0.1, hx1 + 0.1, 1.2, 2.4, hz0 - 0.1, hz1 + 0.1, "marble", g, hi)
    for x in (hx0, hx1):   # corner pilasters
        for z in (hz0, hz1):
            S.slab(f"{g}_pil{x:.0f}{z:.0f}_{tag}", x - 0.6, x + 0.6, 1.2, 12.5, z - 0.6, z + 0.6, "marble", g, hi)
    # the portico: 4 columns on the front, 2 behind at the sides, a flat deep roof
    pz = hz1 + 4.6
    for k, x in enumerate((hx0 + 0.9, hx0 + 6.5, hx1 - 6.5, hx1 - 0.9)):
        column(g, tag, hi, f"c{k}", x, pz, 1.2, 12.5)
    for k, x in enumerate((hx0 + 0.9, hx1 - 0.9)):
        column(g, tag, hi, f"cb{k}", x, hz1 + 1.4, 1.2, 12.5)
    S.slab(f"{g}_portroof_{tag}", hx0, hx1, 12.5, 12.8, hz1, pz + 0.8, "marble", g, hi)
    cornice(g, tag, hi, "corn", hx0, hx1, hz0, pz + 0.8, 12.8)
    S.slab(f"{g}_roof_{tag}", hx0 + 0.5, hx1 - 0.5, 14.5, 14.8, hz0 + 0.5, pz, "marble_grey", g, hi, bevel=0.0)
    S.box(f"{g}_bigdoor_{tag}", (3.2, 4.6, 0.12), ((hx0 + hx1) / 2, 3.5, hz1 + 0.06), "wood", g, hi, bevel=0.0)
    S.box(f"{g}_bigdoorglass_{tag}", (2.6, 4.0, 0.04), ((hx0 + hx1) / 2, 3.5, hz1 + 0.13), "glass", g, hi, bevel=0.0)
    # no lettering: the owner's photo shows a plain frieze
    # the side wing (one storey, pilasters, a deep cornice, its own steps)
    wx0, wx1 = hx1, 14.5
    wz0, wz1 = hz0 + 2.0, hz1 - 1.0
    S.slab(f"{g}_wpod_{tag}", wx0, wx1 + 0.5, 0.2, 1.2, wz0, wz1 + 1.0, "marble_grey", g, hi)
    S.slab(f"{g}_wing_{tag}", wx0, wx1, 1.2, 6.2, wz0, wz1, "panel", g, hi)
    for k, x in enumerate((wx0 + 1.0, wx0 + 4.5, wx1 - 4.5, wx1 - 0.6)):
        S.slab(f"{g}_wpil{k}_{tag}", x - 0.45, x + 0.45, 1.2, 6.2, wz1 - 0.1, wz1 + 0.5, "marble", g, hi)
    S.slab(f"{g}_wcorn_{tag}", wx0, wx1 + 0.6, 6.2, 7.0, wz0 - 0.4, wz1 + 0.9, "marble", g, hi)
    S.box(f"{g}_wdoor_{tag}", (2.0, 3.0, 0.12), (wx0 + 7.0, 2.7, wz1 + 0.06), "wood", g, hi, bevel=0.0)
    S.box(f"{g}_wdoorglass_{tag}", (1.6, 2.6, 0.04), (wx0 + 7.0, 2.7, wz1 + 0.13), "glass", g, hi, bevel=0.0)
    for k in range(4):
        S.slab(f"{g}_wstep{k}_{tag}", wx0 + 4.5, wx1 + 0.4, 0.2, 1.2 - k * 0.25, wz1 + 1.0, wz1 + 1.4 + k * 0.45,
               "marble", g, hi, bevel=0.0)
    # wooden fence by the wing, two poplars
    S.slab(f"{g}_fence_{tag}", wx1 + 0.6, wx1 + 0.75, 1.2, 2.2, wz0, wz1, "wood", g, hi, bevel=0.0)
    for k, z in enumerate((hz0 + 1.0, hz0 + 5.0)):
        S.cylinder(f"{g}_pt{k}_{tag}", 0.2, 0.2, 3.0, (14.0, z), "trunk", g, hi, seg=(5, 8))
        S.cylinder(f"{g}_pc{k}_{tag}", 1.1, 2.5, 10.0, (14.0, z), "leaf", g, hi, seg=(6, 10), r_top=0.4)


# --- Lachin Resort & Spa --------------------------------------------------------------------------

def hip_box(g, tag, hi, name, x0, x1, z0, z1, y, rise, mat="roof_grey", over=0.4):
    hip(g, tag, hi, name, x0, x1, z0, z1, y, rise, mat, over=over)


def floors(g, tag, hi, name, x0, x1, z_face, y0, n, pitch=2.6, arched_top=True, face=1):
    """Window rows on a facade plane (face = +1 front / -1 back on z, 2 / -2 on x)."""
    for f in range(n):
        y = y0 + 1.6 + f * 3.2
        top = arched_top and f == n - 1
        h = 2.2 if top else 1.7
        cnt = max(1, int((x1 - x0) // pitch))
        start = (x0 + x1) / 2 - (cnt - 1) * pitch / 2
        for i in range(cnt):
            c = start + i * pitch
            if abs(face) == 1:
                S.box(f"{g}_{name}_w{f}_{i}_{tag}", (1.1, h, 0.12), (c, y, z_face + 0.06 * face), "glass", g, hi,
                      bevel=0.0)
                if top:
                    S.cylinder(f"{g}_{name}_a{f}_{i}_{tag}", 0.55, 0.0, 0.12, (0, 0), "glass", g, hi, seg=(6, 10)).data.transform(
                        Matrix.Translation((c, y + h / 2, z_face + 0.06 * face)) @ Matrix.Rotation(math.pi / 2, 4, "X"))
            else:
                S.box(f"{g}_{name}_w{f}_{i}_{tag}", (0.12, h, 1.1), (z_face + 0.06 * face / 2, y, c), "glass", g, hi,
                      bevel=0.0)


def build_hotel(hi):
    """Lachin Resort & Spa after the owner's photo (2026-11-10), game-scaled: a
    white neoclassical complex - the central block (four storeys, arched top
    windows, grey mansard roof), two wings coming forward with glass rooftop
    pavilions, low arcaded pavilions at both ends, a glass conservatory and
    the long turquoise pool on the front terrace, lawns and paths."""
    tag = "H" if hi else "L"
    g = "kb_hotel"
    W, D = 80.0, 46.0
    S.slab(f"{g}_plinth_{tag}", -W / 2, W / 2, -F, 0.2, -D / 2, D / 2, "paving", g, hi, bevel=0.0)
    S.slab(f"{g}_terrace_{tag}", -15, 15, 0.2, 0.5, -10, 14, "marble", g, hi, bevel=0.0)
    for sx in (-1, 1):
        S.slab(f"{g}_lawn{sx}_{tag}", min(sx * 15, sx * 39), max(sx * 15, sx * 39), 0.2, 0.35, 8, 21, "grass", g, hi,
               bevel=0.0)
    # central block
    cz0, cz1 = -21.0, -10.0
    S.slab(f"{g}_c_body_{tag}", -15, 15, 0.5, 13.5, cz0, cz1, "wall_white", g, hi)
    S.slab(f"{g}_c_corn_{tag}", -15.4, 15.4, 13.5, 14.1, cz0 - 0.4, cz1 + 0.4, "marble", g, hi)
    hip_box(g, tag, hi, "c_roof", -15, 15, cz0, cz1, 14.1, 4.5)
    floors(g, tag, hi, "c", -14, 14, cz1, 0.5, 4, 2.4)
    # glass conservatory on the terrace in front of the central block
    S.slab(f"{g}_cons_{tag}", -10, 10, 0.5, 4.5, cz1, cz1 + 5.0, "glass", g, hi, bevel=0.0)
    S.slab(f"{g}_cons_roof_{tag}", -10.2, 10.2, 4.5, 4.8, cz1 - 0.2, cz1 + 5.2, "frame", g, hi, bevel=0.0)
    for k in range(9):
        x = -10 + k * 2.5
        S.slab(f"{g}_cons_m{k}_{tag}", x - 0.07, x + 0.07, 0.5, 4.5, cz1 + 5.0, cz1 + 5.1, "frame", g, hi, bevel=0.0)
    # the pool with an infinity edge
    S.slab(f"{g}_pool_rim_{tag}", -6.5, 6.5, 0.2, 0.6, 1.0, 13.0, "marble", g, hi, bevel=0.0)
    S.slab(f"{g}_pool_{tag}", -6.0, 6.0, 0.6, 0.62, 1.5, 12.5, "pool", g, hi, bevel=0.0)
    S.slab(f"{g}_pool_low_{tag}", -4.0, 4.0, 0.2, 0.32, 13.0, 15.5, "pool", g, hi, bevel=0.0)
    for sx in (-1, 1):
        # the wing: three storeys + a glass penthouse, coming forward
        x0, x1 = min(sx * 15, sx * 26), max(sx * 15, sx * 26)
        S.slab(f"{g}_w{sx}_body_{tag}", x0, x1, 0.5, 10.3, -19.0, 6.0, "wall_white", g, hi)
        S.slab(f"{g}_w{sx}_corn_{tag}", x0 - 0.3, x1 + 0.3, 10.3, 10.8, -19.3, 6.3, "marble", g, hi)
        floors(g, tag, hi, f"w{sx}f", x0 + 0.8, x1 - 0.8, 6.0, 0.5, 3, 2.4, arched_top=False)
        floors(g, tag, hi, f"w{sx}s", -18.0, 5.0, x1 if sx > 0 else x0, 0.5, 3, 2.6, arched_top=False,
               face=2 * sx)
        S.slab(f"{g}_w{sx}_pent_{tag}", x0 + 1.5, x1 - 1.5, 10.8, 13.6, -6.0, 3.0, "glass", g, hi, bevel=0.0)
        S.slab(f"{g}_w{sx}_pentroof_{tag}", x0 + 1.2, x1 - 1.2, 13.6, 13.9, -6.3, 3.3, "frame", g, hi, bevel=0.0)
        hip_box(g, tag, hi, f"w{sx}_roof", x0, x1, -19.0, -7.0, 10.8, 3.5)
        # the low pavilion at the end with arched windows
        p0, p1 = min(sx * 26, sx * 39), max(sx * 26, sx * 39)
        S.slab(f"{g}_p{sx}_body_{tag}", p0, p1, 0.5, 5.6, -16.0, 1.0, "wall_white", g, hi)
        hip_box(g, tag, hi, f"p{sx}_roof", p0, p1, -16.0, 1.0, 5.6, 3.6)
        for k in range(4):
            x = p0 + 1.8 + k * 3.1
            S.box(f"{g}_p{sx}_w{k}_{tag}", (1.6, 2.6, 0.12), (x, 2.4, 1.06), "glass", g, hi, bevel=0.0)
            S.cylinder(f"{g}_p{sx}_a{k}_{tag}", 0.8, 0.0, 0.12, (0, 0), "glass", g, hi, seg=(6, 10)).data.transform(
                Matrix.Translation((x, 3.7, 1.06)) @ Matrix.Rotation(math.pi / 2, 4, "X"))
    # paths and young trees on the front lawns
    for sx in (-1, 1):
        S.slab(f"{g}_path{sx}_{tag}", min(sx * 15, sx * 39), max(sx * 15, sx * 39), 0.35, 0.4, 19.0, 20.6, "paving", g,
               hi, bevel=0.0)
        for k in range(5):
            x = sx * (18.0 + k * 4.5)
            S.cylinder(f"{g}_tt{sx}{k}_{tag}", 0.15, 0.35, 2.0, (x, 15.0), "trunk", g, hi, seg=(5, 8))
            S.tree_ball(f"{g}_tc{sx}{k}_{tag}", (x, 2.9, 15.0), 1.2, "leaf", g, hi, k + sx)


# --- The garden café on the boulevard ------------------------------------------------------------

def build_cafe(hi):
    tag = "H" if hi else "L"
    g = "kb_garden_cafe"
    W, D = 22.0, 16.0
    rnd = random.Random(3)
    S.slab(f"{g}_deck_{tag}", -W / 2, W / 2, -F, 0.35, -D / 2, D / 2, "wood", g, hi, bevel=0.0)
    # pavilion (kitchen / bar) at the back
    S.slab(f"{g}_pav_{tag}", -9, -1, 0.35, 3.6, -D / 2 + 0.5, -D / 2 + 6.0, "wall_white", g, hi)
    hip(g, tag, hi, "pavroof", -9, -1, -D / 2 + 0.5, -D / 2 + 6.0, 3.6, 2.2, "roof_red", over=0.6)
    windows(g, tag, hi, -8.5, -1.5, 2.0, -D / 2 + 6.06, w=1.6, h=1.6, pitch=2.2)
    # pergola over the terrace
    for x in (-1.0, 4.0, 9.0):
        for z in (-6.0, 0.0, 6.0):
            S.slab(f"{g}_post{x:.0f}{z:.0f}_{tag}", x - 0.15, x + 0.15, 0.35, 3.2, z - 0.15, z + 0.15, "wood", g, hi,
                   bevel=0.0)
    for z in (-6.0, 0.0, 6.0):
        S.slab(f"{g}_beam{z:.0f}_{tag}", -1.2, 9.2, 3.2, 3.45, z - 0.12, z + 0.12, "wood", g, hi, bevel=0.0)
    for k in range(9):
        x = -1.0 + k * 1.25
        S.slab(f"{g}_rafter{k}_{tag}", x - 0.06, x + 0.06, 3.45, 3.6, -6.3, 6.3, "wood", g, hi, bevel=0.0)
    # 0.20.1: the leaf mat in the high model too - the bake rays hit leaves everywhere (no black patches)
    S.slab(f"{g}_vine_{tag}", -1.2, 9.2, 3.6, 3.75, -6.3, 6.3, "leaf", g, hi, bevel=0.0)
    if hi:
        for k in range(14):   # vine leaves on the pergola
            S.tree_ball(f"{g}_vine{k}_{tag}", (rnd.uniform(-1, 9), 3.75, rnd.uniform(-6, 6)), 0.9, "leaf", g, hi,
                        k * 0.7)
    # tables with umbrellas on the open part, chairs
    for k, (x, z) in enumerate(((-7.5, 2.5), (-4.0, 4.5), (-7.5, 6.3), (2.0, -3.0), (6.5, -3.0), (2.0, 3.0),
                                (6.5, 3.0))):
        S.cylinder(f"{g}_tab{k}_{tag}", 0.6, 1.05, 1.12, (x, z), "wall_white", g, hi, seg=(8, 12))
        S.cylinder(f"{g}_leg{k}_{tag}", 0.06, 0.35, 1.05, (x, z), "frame", g, hi, seg=(4, 6))
        for c in range(2):
            S.box(f"{g}_ch{k}{c}_{tag}", (0.45, 0.9, 0.45), (x + (1 if c else -1) * 0.95, 0.8, z), "wood", g, hi)
        if x < -1:
            S.cylinder(f"{g}_upole{k}_{tag}", 0.04, 1.1, 2.6, (x, z), "frame", g, hi, seg=(4, 6))
            S.cone(f"{g}_umb{k}_{tag}", 1.4, 2.4, 3.0, (x, z), "umbrella", g, hi, seg=(6, 10))
    # planters with flowers round the deck
    for k, x in enumerate((-10.0, -6.0, -2.0, 2.0, 6.0, 10.0)):
        S.slab(f"{g}_pl{k}_{tag}", x - 0.9, x + 0.9, 0.35, 1.0, D / 2 - 0.9, D / 2 - 0.1, "wood", g, hi, bevel=0.0)
        S.tree_ball(f"{g}_fl{k}_{tag}", (x, 1.25, D / 2 - 0.5), 0.55, "flower", g, hi, k)


# --- Town houses ----------------------------------------------------------------------------------

def house_base(g, tag, hi, wall, w=9.0, d=7.5, floors=2):
    S.slab(f"{g}_plinth_{tag}", -6, 6, -F, 0.3, -5.5, 5.5, "paving", g, hi, bevel=0.0)
    S.slab(f"{g}_garden_{tag}", -5.8, 5.8, 0.3, 0.35, -5.3, 5.3, "grass", g, hi, bevel=0.0)
    z0, z1 = -5.0, -5.0 + d
    h = 0.35 + floors * 3.0
    S.slab(f"{g}_socle_{tag}", -w / 2, w / 2, 0.3, 0.9, z0, z1, "stone", g, hi)
    S.slab(f"{g}_body_{tag}", -w / 2, w / 2, 0.9, h, z0, z1, wall, g, hi)
    for f in range(floors):
        windows(g, tag, hi, -w / 2 + 0.6, w / 2 - 0.6, 2.2 + f * 3.0, z1 + 0.06, w=1.2, h=1.4, pitch=2.4,
                skip=(-0.8, 0.8) if f == 0 else None)
    S.box(f"{g}_door_{tag}", (1.2, 2.2, 0.12), (0.0, 1.95, z1 + 0.06), "wood", g, hi, bevel=0.0)
    # garden fence on the front
    S.slab(f"{g}_fence_{tag}", -5.8, 5.8, 0.35, 1.1, 5.1, 5.25, "wood", g, hi, bevel=0.0)
    return z0, z1, h


def build_house_a(hi):
    tag = "H" if hi else "L"
    g = "kb_house_a"
    z0, z1, h = house_base(g, tag, hi, "wall_white")
    hip(g, tag, hi, "roof", -4.5, 4.5, z0, z1, h, 2.6, "roof_red", over=0.5)
    # solar panels on the front slope
    # panels on the front slope of the hip roof (rise 2.6 over 4.25 m)
    def top(z):
        return h + 0.1 + 2.6 * (z1 + 0.5 - z) / (z1 + 0.5 - (z0 + z1) / 2)
    za, zb = (z0 + z1) / 2 + 1.0, z1 - 0.1
    prof = [(za, top(za) + 0.06), (zb, top(zb) + 0.06), (zb, top(zb) + 0.16), (za, top(za) + 0.16)]
    S.extrude(f"{g}_solar_{tag}", [(z, y) for z, y in prof], -1.8, 1.8, "solar", g, hi, matrix=SWAP_XZ)


def build_house_b(hi):
    tag = "H" if hi else "L"
    g = "kb_house_b"
    z0, z1, h = house_base(g, tag, hi, "wall_cream", w=10.0, d=7.0)
    zc = gable(g, tag, hi, "roof", -5.0, 5.0, z0, z1, h, 2.4, "roof_brown", over=0.5)
    solar(g, tag, hi, "solar", -3.6, 3.6, zc, z1, h, 2.4)
    S.slab(f"{g}_balc_{tag}", -2.0, 2.0, 3.2, 3.4, z1, z1 + 1.1, "wall_white", g, hi, bevel=0.0)
    S.slab(f"{g}_brail_{tag}", -2.0, 2.0, 3.4, 4.2, z1 + 1.0, z1 + 1.1, "wood", g, hi, bevel=0.0)


def build_house_c(hi):
    tag = "H" if hi else "L"
    g = "kb_house_c"
    z0, z1, h = house_base(g, tag, hi, "wall_sand", w=8.5, d=8.0)
    zc = gable(g, tag, hi, "roof", -4.25, 4.25, z0, z1, h, 2.8, "roof_red", over=0.5)
    solar(g, tag, hi, "solar", -3.2, 3.2, zc, z1, h, 2.8)
    S.slab(f"{g}_chimney_{tag}", 2.2, 2.9, h, h + 3.6, z0 + 1.0, z0 + 1.7, "stone", g, hi)


# --- Həkəri boulevard segment ---------------------------------------------------------------------

BLVD = 10.0


def build_blvd(hi):
    tag = "H" if hi else "L"
    g = "kb_blvd_seg"
    L2 = BLVD / 2 + 0.05
    S.slab(f"{g}_base_{tag}", -L2, L2, -2.6, 0.15, -4.5, 4.5, "stone", g, hi, bevel=0.0)
    S.slab(f"{g}_paving_{tag}", -L2, L2, 0.15, 0.25, -3.0, 4.2, "paving", g, hi, bevel=0.0)
    S.slab(f"{g}_lawn_{tag}", -L2, L2, 0.15, 0.3, -4.5, -3.0, "grass", g, hi, bevel=0.0)
    # river wall + railing (+z = the river)
    S.slab(f"{g}_wall_{tag}", -L2, L2, -3.2, 0.7, 4.2, 4.7, "stone", g, hi, bevel=0.0)
    S.slab(f"{g}_rail_{tag}", -L2, L2, 1.55, 1.65, 4.35, 4.55, "steel", g, hi, bevel=0.0)
    for k in range(3):
        x = -BLVD / 2 + 1.6 + k * 3.4
        S.slab(f"{g}_rp{k}_{tag}", x - 0.05, x + 0.05, 0.7, 1.6, 4.4, 4.5, "steel", g, hi, bevel=0.0)
    # lamp, bench, a tree on the land side
    S.cylinder(f"{g}_lamp_{tag}", 0.09, 0.25, 4.6, (0.0, 3.7), "frame", g, hi, seg=(5, 8))
    S.cylinder(f"{g}_lamphead_{tag}", 0.32, 4.6, 5.0, (0.0, 3.7), "lamp_head", g, hi, seg=(6, 10))
    S.box(f"{g}_bench_{tag}", (2.0, 0.12, 0.5), (2.6, 0.7, 3.2), "wood", g, hi)
    S.box(f"{g}_benchback_{tag}", (2.0, 0.5, 0.1), (2.6, 1.0, 2.95), "wood", g, hi)
    for sx in (-1, 1):
        S.box(f"{g}_benchleg{sx}_{tag}", (0.1, 0.45, 0.45), (2.6 + sx * 0.85, 0.47, 3.2), "frame", g, hi, bevel=0.0)
    # 0.19.2: no tree on the land side - the river must be seen from the road
    S.slab(f"{g}_planter_{tag}", -3.3, -1.7, 0.25, 0.75, -4.3, -3.2, "stone", g, hi)
    S.tree_ball(f"{g}_shrub_{tag}", (-2.5, 1.1, -3.75), 0.7, "flower", g, hi, 1.0)


def build(hi):
    global _looked
    if not _looked:
        S.add_looks(LOOK)
        _looked = True
    _build(hi)


_build = S.run_set(GROUPS, {"kb_cinema": build_cinema, "kb_hotel": build_hotel, "kb_garden_cafe": build_cafe,
                            "kb_house_a": build_house_a, "kb_house_b": build_house_b, "kb_house_c": build_house_c,
                            "kb_blvd_seg": build_blvd}, 70.0)
K.CAGE, K.RAY, K.AO_DIST = 0.08, 0.2, 2.0
K.setup("karabakh_lachin", "assets/models/karabakh_lachin", PALETTE, PAINT_MAT, GROUPS, UV_SCALE, FAR_RATIO,
        stone_mats=["__no_stone__"])
K.run(build)
