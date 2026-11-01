"""Baku seafront buildings and the grandstand for Yaska Racing (0.14.4
Blender models): modern_a, modern_b, modern_c (Neftçilər avenue style
blocks) and grandstand.

  blender --background --factory-startup --python tools/blender/city_props.py -- --bake-res 4096 --tex-res 2048
Footprints, heights and the +Z front follow PropKit._modern / _grandstand so
placement, occluders and the AoMap stay valid. Window frames, rustication,
sills and mouldings exist only in the high model (shallow, baked into normal /
AO); the low model keeps the silhouette (balconies, cornices, roof) and flat
glass panels. orm alpha = window glass (night glow), albedo alpha = stone
(world-space limestone detail in prop_baked.gdshader).
"""

import math
import os
import sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from kart_common import *  # noqa: F401,F403
import kart_common as K
from mathutils import Vector, Matrix, Euler, Quaternion

PALETTE = {
    "plaster_cream": ("EBD9B4", 0.75, 0.0),
    "plaster_peach": ("F0C9A4", 0.75, 0.0),
    "plaster_white": ("F2ECE0", 0.75, 0.0),
    "limestone": ("D9C29A", 0.85, 0.0),
    "stone_dark": ("8C7A62", 0.85, 0.0),
    "trim_white": ("FAF6EE", 0.6, 0.0),
    "glass": ("2F5F86", 0.08, 0.3),
    "iron": ("2B2D33", 0.45, 0.55),
    "roof": ("6E5A4A", 0.8, 0.0),
    "awning_red": ("D7263D", 0.7, 0.0),
    "awning_teal": ("1FA3A0", 0.7, 0.0),
    "awning_orange": ("F07A2A", 0.7, 0.0),
    "concrete": ("B8B4AC", 0.9, 0.0),
    "seat_blue": ("2F74C9", 0.6, 0.0),
    "canopy_red": ("D7263D", 0.6, 0.0),
    "steel": ("9AA0A8", 0.4, 0.8),
    "skin": ("E8B892", 0.6, 0.0),
    "skin2": ("B9825A", 0.6, 0.0),
    "hair": ("3A2418", 0.6, 0.0),
    "shirt_red": ("E0344B", 0.7, 0.0), "shirt_blue": ("2F74C9", 0.7, 0.0), "shirt_yellow": ("FFC93C", 0.7, 0.0),
    "shirt_green": ("3FA35A", 0.7, 0.0), "shirt_white": ("F4F1EE", 0.7, 0.0), "shirt_purple": ("8B5CF6", 0.7, 0.0),
    "flag_blue": ("00B5E2", 0.6, 0.0), "flag_red": ("EF3340", 0.6, 0.0), "flag_green": ("509E2F", 0.6, 0.0),
}
PAINT_MAT = "glass"
STONE = ["limestone", "stone_dark"]
GROUPS = ["modern_a", "modern_b", "modern_c", "grandstand"]
UV_SCALE = {"modern_a": 1.0, "modern_b": 1.0, "modern_c": 1.0, "grandstand": 1.2}
FAR_RATIO = {"modern_a": 0.5, "modern_b": 0.5, "modern_c": 0.5, "grandstand": 0.35}

MOD_W = [16.0, 12.0, 20.0]
MOD_H = [18.0, 26.0, 14.0]
MOD_D = 12.0
MOD_BODY = ["plaster_cream", "plaster_peach", "plaster_white"]
MOD_AWNING = ["awning_red", "awning_teal", "awning_orange"]


def _wall_quad(name, w, h, center, normal, mat, g, hi):
    """Flat panel (glass) facing `normal`."""
    m = facing(center, normal)
    bm = bmesh.new()
    vs = [bm.verts.new((x * w * 0.5, y * h * 0.5, 0.0)) for x, y in ((-1, -1), (1, -1), (1, 1), (-1, 1))]
    bm.faces.new(vs)
    K.xform(bm, m)
    return K.finish(bm, name, mat, g, hi, keep=True, smooth=False)


def window(name, x, y, z, w, h, normal, g, hi, arched=False):
    """Glass panel; high model adds a shallow stone frame, sill and keystone."""
    n = Vector(normal)
    c = Vector((x, y, z)) + n * 0.012
    _wall_quad(f"{name}_glass", w, h, c, n, "glass", g, hi)
    if hi:
        up = Vector((0, 1, 0))
        side = up.cross(n).normalized()
        f = 0.12
        for sx in (-1, 1):
            bbox(f"{name}_jamb{sx}", (f, h + f, 0.018), c + side * sx * (w * 0.5 + f * 0.5) + n * 0.003, "trim_white",
                 g, True, 0.005, rot=Matrix((side, up, n)).transposed().to_euler())
        bbox(f"{name}_head", (w + 2 * f, f * 1.4, 0.02), c + up * (h * 0.5 + f * 0.7) + n * 0.004, "trim_white", g,
             True, 0.005, rot=Matrix((side, up, n)).transposed().to_euler())
        bbox(f"{name}_sill", (w + 2 * f + 0.1, 0.1, 0.022), c - up * (h * 0.5 + 0.05) + n * 0.005, "trim_white", g,
             True, 0.005, rot=Matrix((side, up, n)).transposed().to_euler())
        bbox(f"{name}_key", (0.18, 0.22, 0.02), c + up * (h * 0.5 + f * 1.2) + n * 0.006, "trim_white", g, True, 0.005,
             rot=Matrix((side, up, n)).transposed().to_euler())
        for k in range(1, 3):
            bbox(f"{name}_mull{k}", (0.04, h, 0.012), c + side * (w * (k / 3 - 0.5)) + n * 0.002, "trim_white", g,
                 True, 0.0, rot=Matrix((side, up, n)).transposed().to_euler())
        bbox(f"{name}_tr", (w, 0.04, 0.012), c + up * (h * 0.22) + n * 0.002, "trim_white", g, True, 0.0,
             rot=Matrix((side, up, n)).transposed().to_euler())


def balcony(name, x, y, z, w, g, hi):
    """Stone slab on corbels with a wrought-iron railing (front +Z)."""
    tag = "H" if hi else "L"
    bbox(f"{name}_slab_{tag}", (w, 0.16, 0.9), (x, y, z + 0.45), "limestone", g, hi, L(hi, 0.0, 0.04))
    for sx in (-1, 1):
        bbox(f"{name}_corbel{sx}_{tag}", (0.18, 0.35, 0.6), (x + sx * (w * 0.5 - 0.25), y - 0.25, z + 0.3), "limestone",
             g, hi, L(hi, 0.0, 0.03))
    rail_y = y + 0.08 + 0.5
    tube(f"{name}_rail_{tag}", [(x - w * 0.5, rail_y + 0.5, z + 0.88), (x + w * 0.5, rail_y + 0.5, z + 0.88)], 0.025,
         "iron", g, hi, 1, L(hi, 4, 8))
    for sx in (-1, 1):
        tube(f"{name}_side{sx}_{tag}", [(x + sx * w * 0.5, rail_y + 0.5, z + 0.05), (x + sx * w * 0.5, rail_y + 0.5, z + 0.88)],
             0.025, "iron", g, hi, 1, L(hi, 4, 8))
    if hi:
        n = int(w / 0.12)
        for k in range(n + 1):
            bx = x - w * 0.5 + k * w / n
            tube(f"{name}_bar{k}", [(bx, y + 0.08, z + 0.88), (bx, rail_y + 0.48, z + 0.88)], 0.011, "iron", g, True,
                 1, 4, False)
        for k in range(int(w / 0.5)):
            cx = x - w * 0.5 + 0.25 + k * 0.5
            torus(f"{name}_scroll{k}", 0.12, 0.012, Matrix.Translation(Vector((cx, rail_y + 0.2, z + 0.88)))
                  @ Matrix.Rotation(math.pi / 2, 4, "X"), "iron", g, True, (16, 4))
    else:
        bbox(f"{name}_grille_{tag}", (w, 0.9, 0.02), (x, rail_y + 0.05, z + 0.88), "iron", g, False, 0.0)


def build_modern(v, hi):
    tag = "H" if hi else "L"
    g = GROUPS[v]
    w, h, d = MOD_W[v], MOD_H[v], MOD_D
    body = MOD_BODY[v]
    fz = d * 0.5
    bbox(f"{g}_body_{tag}", (w, h, d), (0, h * 0.5, 0), body, g, hi, L(hi, 0.0, 0.08))
    # Rusticated stone ground floor, tall arched shop fronts with awnings.
    bbox(f"{g}_base_{tag}", (w + 0.16, 4.2, d + 0.16), (0, 2.1, 0), "limestone", g, hi, L(hi, 0.0, 0.05))
    bbox(f"{g}_band_{tag}", (w + 0.4, 0.35, d + 0.4), (0, 4.3, 0), "trim_white", g, hi, L(hi, 0.0, 0.06))
    shops = max(2, int(w / 4.0))
    for i in range(shops):
        x = -w * 0.5 + (i + 0.5) * w / shops
        window(f"{g}_shop{i}", x, 2.0, fz + 0.08, w / shops * 0.62, 2.8, (0, 0, 1), g, hi)
        aw = w / shops * 0.7
        bbox(f"{g}_awning{i}_{tag}", (aw, 0.08, 1.2), (x, 3.65, fz + 0.65), MOD_AWNING[v], g, hi, L(hi, 0.0, 0.02),
             rot=(0.35, 0, 0))
    # Upper floors: framed windows, balconies on alternate floors.
    floors = int((h - 5.0) / 3.2)
    cols = max(3, int(w / 2.6))
    for f in range(floors):
        y = 5.6 + f * 3.2
        for i in range(cols):
            x = -w * 0.5 + (i + 0.5) * w / cols
            window(f"{g}_w{f}_{i}", x, y + 0.9, fz, 1.1, 1.8, (0, 0, 1), g, hi)
        if f % 2 == 0:
            for i in range(cols):
                if i % 2 == 1 or cols <= 3:
                    x = -w * 0.5 + (i + 0.5) * w / cols
                    balcony(f"{g}_bal{f}_{i}", x, y - 0.05, fz, 1.9, g, hi)
        # Side windows (streets see the sides).
        for s in (-1, 1):
            for i in range(max(2, int(d / 3.0))):
                zz = -d * 0.5 + (i + 0.5) * d / max(2, int(d / 3.0))
                window(f"{g}_sw{f}_{s}_{i}", s * w * 0.5, y + 0.9, zz, 1.0, 1.7, (s, 0, 0), g, hi)
        if hi:
            bbox(f"{g}_floorband{f}", (w + 0.04, 0.12, 0.02), (0, y - 0.2, fz + 0.012), "trim_white", g, True, 0.0)
    # Cornice, attic and roof details.
    bbox(f"{g}_cornice_{tag}", (w + 0.7, 0.45, d + 0.7), (0, h + 0.1, 0), "trim_white", g, hi, L(hi, 0.0, 0.12))
    bbox(f"{g}_attic_{tag}", (w, 0.9, 0.3), (0, h + 0.75, fz - 0.15), body, g, hi, L(hi, 0.0, 0.05))
    if v == 1:
        superellipsoid(f"{g}_dome_{tag}", (2.4, 2.2, 2.4), (w * 0.3, h + 1.2, fz - 2.8), "roof", g, hi, (0.8, 1.0),
                       L(hi, (12, 8), (40, 24)))
        lathe(f"{g}_drum_{tag}", [(0.0, 2.5), (1.2, 2.5)], (0, 0, 0), body, g, hi, L(hi, 12, 40)).data.transform(
            K.trs((w * 0.3, h + 0.2, fz - 2.8), (0, 0, math.pi / 2)))
    else:
        for s in (-1, 1):
            bbox(f"{g}_rooftop{s}_{tag}", (3.0, 2.0, 3.0), (s * w * 0.25, h + 1.2, -1.5), "plaster_white", g, hi,
                 L(hi, 0.0, 0.06))
    if hi:
        # Pediment over the centre bay and pilasters between bays.
        puffy(f"{g}_pediment", [(-2.6, 0), (2.6, 0), (0, 1.3)], 0.02, 0.0, K.trs((0, h - 0.9, fz + 0.012)),
              "trim_white", g, True)
        for i in range(cols + 1):
            x = -w * 0.5 + i * w / cols
            bbox(f"{g}_pilaster{i}", (0.3, h - 5.0, 0.02), (x, 4.5 + (h - 5.0) * 0.5, fz + 0.012), "trim_white", g,
                 True, 0.0)


def build_grandstand(hi):
    tag = "H" if hi else "L"
    g = "grandstand"
    w = 30.0
    for i in range(5):
        bbox(f"gs_tier{i}_{tag}", (w, 0.6, 1.4), (0, 0.3 + i * 0.6, -i * 1.3), "concrete", g, hi, L(hi, 0.0, 0.04))
        bbox(f"gs_seat{i}_{tag}", (w - 0.4, 0.12, 0.5), (0, 0.66 + i * 0.6, -i * 1.3 + 0.2), "seat_blue", g, hi,
             L(hi, 0.0, 0.03))
    shirts = ["shirt_red", "shirt_blue", "shirt_yellow", "shirt_green", "shirt_white", "shirt_purple"]
    for i in range(5):
        for k in range(18):
            x = -w * 0.5 + 1.0 + k * (w - 2.0) / 17.0 + (0.3 if i % 2 == 0 else 0.0)
            seed = (k * 7 + i * 3)
            y0 = 0.7 + i * 0.6
            zz = -i * 1.3 - 0.05
            shirt = shirts[seed % len(shirts)]
            skin = "skin" if seed % 3 else "skin2"
            superellipsoid(f"gs_body{i}_{k}_{tag}", (0.24, 0.32, 0.18), (x, y0 + 0.35, zz), shirt, g, hi, (0.7, 0.8),
                           L(hi, (4, 6), (12, 16)))
            ellipsoid(f"gs_head{i}_{k}_{tag}", (0.14, 0.15, 0.14), (x, y0 + 0.8, zz), skin, g, hi, L(hi, (5, 4), (16, 10)))
            if hi:
                ellipsoid(f"gs_hair{i}_{k}", (0.145, 0.08, 0.14), (x, y0 + 0.88, zz + 0.02), "hair", g, True, (16, 8))
            if seed % 4 == 0:
                # Cheering: both arms up; every eighth waves a flag.
                for s in (-1, 1):
                    capsule(f"gs_arm{i}_{k}{s}_{tag}", (x + s * 0.2, y0 + 0.55, zz), (x + s * 0.32, y0 + 1.05, zz - 0.05),
                            0.05, shirt, g, hi, L(hi, (4, 3), (10, 6)))
                if seed % 8 == 0:
                    tube(f"gs_pole{i}_{k}_{tag}", [(x + 0.32, y0 + 1.0, zz - 0.05), (x + 0.36, y0 + 1.7, zz - 0.05)],
                         0.015, "steel", g, hi, 1, L(hi, 3, 6))
                    for j, col in enumerate(("flag_blue", "flag_red", "flag_green")):
                        bbox(f"gs_flag{i}_{k}{j}_{tag}", (0.5, 0.11, 0.015), (x + 0.6, y0 + 1.62 - j * 0.11, zz - 0.05),
                             col, g, hi, 0.0)
    for x in (-w * 0.5, 0.0, w * 0.5):
        tube(f"gs_post{x}_{tag}", [(x, 0.0, -6.0), (x, 6.6, -6.0)], 0.15, "steel", g, hi, 1, L(hi, 6, 16))
        tube(f"gs_brace{x}_{tag}", [(x, 6.2, -6.0), (x, 6.9, -1.0)], 0.08, "steel", g, hi, 1, L(hi, 5, 12))
    bbox(f"gs_roof_{tag}", (w + 2.0, 0.25, 8.0), (0, 6.6, -3.0), "canopy_red", g, hi, L(hi, 0.0, 0.08), rot=(0.12, 0, 0))
    if hi:
        for k in range(8):
            bbox(f"gs_rib{k}", (0.12, 0.05, 8.0), (-w * 0.5 + k * w / 7, 6.46, -3.0), "steel", g, True, 0.01,
                 rot=(0.12, 0, 0))
        text_decal("gs_name", "BAKI", 0.9, facing((0, 6.65, 1.02), (0, 0.12, 1)), "trim_white", g, None)


OFFSET = {g: Vector((i * 40.0, 0.0, 0.0)) for i, g in enumerate(GROUPS)}


def build(hi):
    for v, g in enumerate(GROUPS):
        before = set(K.COLL.objects)
        if g == "grandstand":
            build_grandstand(hi)
        else:
            build_modern(v, hi)
        for o in set(K.COLL.objects) - before:
            o.data.transform(Matrix.Translation(OFFSET[g]))


def _home(groups):
    for o in groups:
        o.data.transform(Matrix.Translation(-OFFSET[o.name]))


K.PRE_EXPORT.append(_home)
K.setup("city_props", "assets/models/city", PALETTE, PAINT_MAT, GROUPS, UV_SCALE, FAR_RATIO, stone_mats=STONE)
K.run(build)
