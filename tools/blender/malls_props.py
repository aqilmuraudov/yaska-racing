"""Real Baku shopping malls for Yaska Racing (0.15.3, from photos on Wikimedia
Commons): 28 Mall, Port Baku Mall, Park Bulvar, Ganjlik Mall.

  blender --background --factory-startup --python tools/blender/malls_props.py -- --bake-res 4096 --tex-res 2048
Footprints stay within the old 64 x 36 m mall plot (DowntownDecor.MALLS, 38 m
reserved radius), front +Z, origin on the ground. Heights are game-fitted.
  mall_28      beige stone block, tall lit shop-window panels, left tower
               with the tall glowing "28" panel, glass top floor on V
               columns under a thin overhanging roof
  port_baku    round glass podium under a huge white disc roof on Y columns,
               two stepped beige residential towers behind
  park_bulvar  long Boulevard mall: silver barrel-vault roofs, glass dome at
               the left end, pointed stone "sails", blue glass bands
  ganjlik_mall glass box wrapped in wavy white horizontal bands (built from
               memory - no free photo was found)
orm alpha = glass (grid + lit shop windows at night), albedo alpha = stone.
"""

import math
import os
import sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from kart_common import *  # noqa: F401,F403
import kart_common as K
from mathutils import Vector, Matrix

PALETTE = {
    "stone_beige": ("CDB48E", 0.8, 0.0), "stone_light": ("E2CFAA", 0.75, 0.0), "white": ("F3F2EE", 0.45, 0.0),
    "glass": ("3C6F96", 0.08, 0.3), "glass_blue": ("2E8FC4", 0.08, 0.4), "shop": ("F2C46B", 0.2, 0.0),
    "panel_lit": ("FFF6DC", 0.2, 0.0), "steel": ("B9BEC5", 0.3, 0.6), "silver": ("C7CCD2", 0.28, 0.75),
    "dark": ("2A2E36", 0.5, 0.2), "balcony": ("7E8A96", 0.15, 0.4),
}
PAINT_MAT = ["glass", "glass_blue", "shop", "panel_lit"]
STONE = ["stone_beige", "stone_light"]
GROUPS = ["mall_28", "port_baku", "park_bulvar", "ganjlik_mall"]
UV_SCALE = {g: 1.0 for g in GROUPS}
FAR_RATIO = {g: 0.45 for g in GROUPS}
UP = Matrix.Rotation(math.pi / 2, 4, "Z")


def turned(name, profile, base, mat, g, hi, steps):
    ob = lathe(name, profile, (0, 0, 0), mat, g, hi, steps)
    ob.data.transform(Matrix.Translation(Vector(base)) @ UP)
    return ob


def build_mall_28(hi):
    tag = "H" if hi else "L"
    g = "mall_28"
    w, h, d = 58.0, 18.0, 32.0
    bbox(f"m28_body_{tag}", (w, h, d), (4.0, h * 0.5, 0), "stone_beige", g, hi, L(hi, 0.0, 0.2))
    fz = d * 0.5
    # Tall shop-window panels separated by stone piers with thin light strips.
    n = 7
    for k in range(n):
        x = 4.0 - w * 0.5 + 7.0 + k * (w - 10.0) / (n - 1) - 1.5
        bbox(f"m28_win{k}_{tag}", (4.4, 12.5, 0.3), (x, 7.6, fz + 0.1), "shop", g, hi, 0.0)
        bbox(f"m28_strip{k}_{tag}", (0.25, 15.0, 0.35), (x + 3.4, 8.5, fz + 0.15), "panel_lit", g, hi, 0.0)
    # Left tower with the tall glowing "28" panel.
    bbox(f"m28_tower_{tag}", (14.0, 26.0, 14.0), (-w * 0.5 - 3.0, 13.0, fz - 5.0), "stone_light", g, hi, L(hi, 0.0, 0.2))
    bbox(f"m28_panel_{tag}", (6.0, 15.0, 0.4), (-w * 0.5 - 3.0, 12.5, fz + 2.1), "panel_lit", g, hi, L(hi, 0.0, 0.05))
    bbox(f"m28_frame_{tag}", (7.4, 16.4, 0.3), (-w * 0.5 - 3.0, 12.5, fz + 1.95), "white", g, hi, L(hi, 0.0, 0.05))
    # Glass top floor on V columns, thin overhanging roof.
    bbox(f"m28_top_{tag}", (40.0, 5.5, 26.0), (10.0, h + 2.75, -1.0), "glass", g, hi, 0.0)
    bbox(f"m28_roof_{tag}", (46.0, 0.7, 32.0), (10.0, h + 6.1, 0.0), "white", g, hi, L(hi, 0.0, 0.1))
    for k in range(6):
        x = -10.0 + k * 8.0
        for s in (-1, 1):
            tube(f"m28_v{k}{s}_{tag}", [Vector((x, h, fz - 1.0)), Vector((x + s * 2.4, h + 5.8, fz - 1.0))], 0.22,
                 "steel", g, hi, 1, L(hi, 6, 10))
    bbox(f"m28_doors_{tag}", (10.0, 4.5, 0.4), (-12.0, 2.25, fz + 0.3), "dark", g, hi, 0.0)


def build_port_baku(hi):
    tag = "H" if hi else "L"
    g = "port_baku"
    steps = L(hi, 24, 72)
    # Round glass podium with floor bands.
    turned(f"pb_pod_{tag}", [(0.0, 21.0), (12.0, 21.0), (12.0, 0.0)], (0, 0, 4.0), "glass", g, hi, steps)
    for k, y in enumerate((4.2, 8.2)):
        turned(f"pb_band{k}_{tag}", [(y, 21.3), (y + 0.5, 21.3), (y + 0.5, 20.9), (y, 20.9)], (0, 0, 4.0), "white", g, hi,
               steps)
    # Huge white disc roof, slightly thicker at the rim.
    turned(f"pb_disc_{tag}", [(12.4, 0.0), (12.4, 29.0), (13.2, 29.5), (14.2, 29.0), (14.2, 0.0)], (0, 0, 4.0), "white",
           g, hi, steps)
    # Y columns around the podium.
    for k in range(7):
        a = math.pi * (0.1 + 0.8 * k / 6)
        x, z = math.cos(a) * 25.5, 4.0 + math.sin(a) * 25.5
        tube(f"pb_col{k}_{tag}", [Vector((x, 0, z)), Vector((x, 7.0, z))], 0.45, "white", g, hi, 1, L(hi, 6, 12))
        for s in (-1, 1):
            t = Vector((-math.sin(a), 0, math.cos(a))) * s * 2.6
            tube(f"pb_y{k}{s}_{tag}", [Vector((x, 7.0, z)), Vector((x + t.x, 12.4, z + t.z))], 0.32, "white", g, hi, 1,
                 L(hi, 6, 12))
    # Two stepped residential towers behind (balcony bands).
    for i, (x, z, hgt, wid) in enumerate(((-13.0, -12.0, 34.0, 16.0), (12.0, -14.0, 40.0, 18.0))):
        y = 0.0
        tiers = 3
        for t in range(tiers):
            th = hgt / tiers
            ww = wid - t * 2.0
            bbox(f"pb_t{i}{t}_{tag}", (ww, th, 14.0 - t * 1.5), (x, y + th * 0.5, z), "stone_light", g, hi,
                 L(hi, 0.0, 0.2))
            for f in range(int(th / 3.0)):
                bbox(f"pb_bal{i}{t}{f}_{tag}", (ww + 0.8, 0.25, 15.0 - t * 1.5), (x, y + 1.5 + f * 3.0, z), "balcony", g,
                     hi, 0.0)
                bbox(f"pb_glz{i}{t}{f}_{tag}", (ww - 1.0, 1.8, 14.2 - t * 1.5), (x, y + 2.6 + f * 3.0, z), "glass", g,
                     hi, 0.0)
            y += th
    # Round glass pavilion on the right.
    turned(f"pb_pav_{tag}", [(0.0, 7.0), (9.0, 7.0), (9.0, 0.0)], (27.0, 0, -6.0), "glass", g, hi, L(hi, 16, 40))
    turned(f"pb_pavr_{tag}", [(9.0, 8.2), (10.0, 8.2), (10.0, 0.0)], (27.0, 0, -6.0), "white", g, hi, L(hi, 16, 40))


def vault(name, x, w, d, y0, rise, g, hi):
    """Barrel vault roof (axis along z) over x-w/2..x+w/2, rising `rise`."""
    n = L(hi, 6, 20)
    bm = bmesh.new()
    rows = []
    for zz in (-d * 0.5, d * 0.5):
        row = []
        for k in range(n + 1):
            t = k / n
            a = math.pi * t
            row.append(bm.verts.new((x - w * 0.5 + w * t, y0 + rise * math.sin(a), zz)))
        rows.append(row)
    for k in range(n):
        bm.faces.new((rows[0][k], rows[0][k + 1], rows[1][k + 1], rows[1][k]))
    # end caps (glass gable)
    K.finish(bm, f"{name}_shell", "silver", g, hi, outward=lambda p: Vector((p.x - x, p.y - y0 + 0.01, 0.0)))
    for s in (-1, 1):
        outline = [(-w * 0.5 + w * k / n, rise * math.sin(math.pi * k / n)) for k in range(n + 1)]
        m = Matrix.Translation(Vector((x, y0, s * d * 0.5))) @ Matrix.Rotation(0.0 if s > 0 else math.pi, 4, "Y")
        puffy(f"{name}_gable{s}", outline, 0.2, 0.0, m, "glass_blue", g, hi)


def build_park_bulvar(hi):
    tag = "H" if hi else "L"
    g = "park_bulvar"
    w, h, d = 60.0, 10.0, 30.0
    bbox(f"pbv_body_{tag}", (w, h, d), (2.0, h * 0.5, 0), "stone_light", g, hi, L(hi, 0.0, 0.2))
    bbox(f"pbv_glass_{tag}", (w - 6.0, 6.0, 0.4), (2.0, 4.0, d * 0.5 + 0.1), "glass_blue", g, hi, 0.0)
    # Silver barrel vaults, rising towards the middle.
    for k, (x, ww, rise) in enumerate(((-14.0, 20.0, 6.5), (6.0, 20.0, 8.0), (24.0, 14.0, 5.0))):
        vault(f"pbv_v{k}_{tag}", x, ww, d - 2.0, h, rise, g, hi)
    # Glass dome at the left end.
    ellipsoid(f"pbv_dome_{tag}", (10.5, 13.0, 10.5), (-26.5, 4.0, 2.0), "glass_blue", g, hi, L(hi, (14, 8), (40, 20)))
    turned(f"pbv_ring_{tag}", [(3.6, 11.4), (4.4, 11.4), (4.4, 10.8), (3.6, 10.8)], (-26.5, 0, 2.0), "white", g, hi,
           L(hi, 16, 40))
    # Pointed stone "sails" between the vaults (front side).
    for k, x in enumerate((-4.0, 17.0)):
        m = Matrix.Translation(Vector((x, h - 0.5, d * 0.5 - 2.0))) @ Matrix.Rotation(math.pi / 2, 4, "Y")
        puffy(f"pbv_sail{k}_{tag}", [(-4.0, 0.0), (5.0, 0.0), (3.0, 13.0)], 1.6, 0.0, m, "stone_beige", g, hi)
    bbox(f"pbv_canopy_{tag}", (18.0, 0.5, 5.0), (2.0, 7.6, d * 0.5 + 2.4), "white", g, hi, L(hi, 0.0, 0.08))


def wave_band(name, w, y, thick, depth, zf, amp, phase, g, hi):
    """White horizontal band whose front edge waves in plan."""
    n = L(hi, 16, 64)
    bm = bmesh.new()
    top, bot = [], []
    for k in range(n + 1):
        x = -w * 0.5 + w * k / n
        z = zf + amp * math.sin(x * 0.11 + phase)
        top.append((bm.verts.new((x, y + thick * 0.5, z)), bm.verts.new((x, y + thick * 0.5, z - depth))))
        bot.append((bm.verts.new((x, y - thick * 0.5, z)), bm.verts.new((x, y - thick * 0.5, z - depth))))
    for k in range(n):
        for (a, b) in ((top, top), (bot, bot)):
            pass
        bm.faces.new((top[k][0], top[k + 1][0], top[k + 1][1], top[k][1]))
        bm.faces.new((bot[k][1], bot[k + 1][1], bot[k + 1][0], bot[k][0]))
        bm.faces.new((bot[k][0], bot[k + 1][0], top[k + 1][0], top[k][0]))
    bm.faces.new((top[0][0], top[0][1], bot[0][1], bot[0][0]))
    bm.faces.new((bot[n][0], bot[n][1], top[n][1], top[n][0]))
    K.finish(bm, name, "white", g, hi, smooth=True)


def build_ganjlik(hi):
    tag = "H" if hi else "L"
    g = "ganjlik_mall"
    w, h, d = 62.0, 17.0, 32.0
    bbox(f"gm_box_{tag}", (w - 2.0, h, d), (0, h * 0.5, 0), "glass", g, hi, 0.0)
    for k, y in enumerate((0.6, 4.8, 9.0, 13.2, 17.0)):
        wave_band(f"gm_band{k}_{tag}", w, y, 1.0 if k else 1.2, 4.0, d * 0.5 + 1.8, 1.4, k * 0.6, g, hi)
    bbox(f"gm_entry_{tag}", (14.0, 8.0, 1.0), (0, 4.0, d * 0.5 + 2.0), "glass_blue", g, hi, 0.0)
    bbox(f"gm_roof_{tag}", (w - 2.0, 0.6, d), (0, h + 0.3, 0), "white", g, hi, 0.0)


OFFSET = {g: Vector((i * 120.0, 0.0, 0.0)) for i, g in enumerate(GROUPS)}


def _built(fn):
    before = set(K.COLL.objects)
    fn()
    for o in set(K.COLL.objects) - before:
        o.data.transform(Matrix.Translation(OFFSET[o["group"]]))


def build(hi):
    _built(lambda: build_mall_28(hi))
    _built(lambda: build_port_baku(hi))
    _built(lambda: build_park_bulvar(hi))
    _built(lambda: build_ganjlik(hi))


def _home(groups):
    for o in groups:
        o.data.transform(Matrix.Translation(-OFFSET[o.name]))


K.PRE_EXPORT.append(_home)

K.setup("malls_props", "assets/models/malls", PALETTE, PAINT_MAT, GROUPS, UV_SCALE, FAR_RATIO, stone_mats=STONE)
K.run(build)
