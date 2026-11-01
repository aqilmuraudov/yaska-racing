"""Baku skyline for Yaska Racing (0.14.4 Blender models), after the owner's
reference photos: socar_tower (twisted flame-like glass tower), crown_tower
(square glass tower with a flared crown, lattice pyramid and spire),
stack_tower (stacked, rotated glass cubes with garden gaps), glass_slab (thin
glass slab with a sloped cut top), stalin_block (sandstone block with an
arcaded ground floor and white-domed corner turrets), resid_tower (cream
residential tower with a balcony grid).

  blender --background --factory-startup --python tools/blender/skyline_props.py -- --bake-res 4096 --tex-res 2048
Seen from 150-600 m, so the low models are light; floor lines, mullions,
arches and balconies come from the bake. Origin on the ground, front +Z.
orm alpha = glass (lit windows at night), albedo alpha = sandstone.
"""

import math
import os
import sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from kart_common import *  # noqa: F401,F403
import kart_common as K
from mathutils import Vector, Matrix, Euler, Quaternion

PALETTE = {
    "glass_blue": ("3D7FC4", 0.08, 0.6),
    "glass_teal": ("4A9BB0", 0.08, 0.6),
    "glass_grey": ("8FA6B8", 0.1, 0.6),
    "glass": ("2F5F86", 0.08, 0.3),
    "mullion": ("DDE3EA", 0.3, 0.7),
    "steel": ("9AA0A8", 0.35, 0.8),
    "white": ("F4F2EC", 0.6, 0.0),
    "sandstone": ("D9C29A", 0.85, 0.0),
    "sandstone_dark": ("B59A72", 0.85, 0.0),
    "cream": ("EBDCC0", 0.75, 0.0),
    "roof": ("8C7A62", 0.8, 0.0),
    "garden": ("4FA04A", 0.9, 0.0),
    "concrete": ("C9C4BA", 0.85, 0.0),
}
PAINT_MAT = "glass"
STONE = ["sandstone", "sandstone_dark"]
GROUPS = ["socar_tower", "crown_tower", "stack_tower", "glass_slab", "stalin_block", "resid_tower"]
UV_SCALE = {"socar_tower": 0.45, "crown_tower": 0.5, "stack_tower": 0.55, "glass_slab": 0.55, "stalin_block": 0.9,
            "resid_tower": 0.7}
FAR_RATIO = {g: 0.35 for g in GROUPS}


def loft(name, rings, mat, g, hi, cap=True):
    """Closed surface through rings of equal vertex count (bottom to top)."""
    bm = bmesh.new()
    rows = [[bm.verts.new(p) for p in r] for r in rings]
    n = len(rows[0])
    for i in range(len(rows) - 1):
        for k in range(n):
            bm.faces.new((rows[i][k], rows[i][(k + 1) % n], rows[i + 1][(k + 1) % n], rows[i + 1][k]))
    if cap:
        bm.faces.new(list(reversed(rows[0])))
        bm.faces.new(rows[-1])
    return K.finish(bm, name, mat, g, hi, smooth=True)


def superellipse_ring(a, b, e, n, y, rot=0.0, cx=0.0, cz=0.0):
    out = []
    for k in range(n):
        t = 2 * math.pi * k / n
        x = math.copysign(abs(math.cos(t)) ** e, math.cos(t)) * a
        z = math.copysign(abs(math.sin(t)) ** e, math.sin(t)) * b
        out.append(Vector((cx + x * math.cos(rot) - z * math.sin(rot), y, cz + x * math.sin(rot) + z * math.cos(rot))))
    return out


def floor_bands(prefix, g, levels, ring_fn, mat="mullion"):
    """High model: thin horizontal bands every floor (baked floor lines)."""
    for i, y in enumerate(levels):
        pts = ring_fn(y)
        tube(f"{prefix}{i}", pts + [pts[0]], 0.12, mat, g, True, 1, 4, False)


def build_socar(hi):
    tag = "H" if hi else "L"
    g = "socar_tower"
    H = 150.0
    lv = L(hi, 18, 60)
    n = L(hi, 14, 40)

    def ring(y):
        t = y / H
        s = 1.0 - 0.42 * t ** 1.6
        return superellipse_ring(20.0 * s, 13.0 * s * (1 - 0.2 * t), 0.75, n, y, rot=0.9 * t)
    rings = [ring(H * i / lv) for i in range(lv + 1)]
    # Pointed flame tip.
    tip = [Vector((p.x * 0.15, H + 10.0, p.z * 0.15)) for p in rings[-1]]
    rings.append(tip)
    loft(f"socar_body_{tag}", rings, "glass_blue", g, hi)
    bbox(f"socar_podium_{tag}", (60.0, 8.0, 40.0), (0, 4.0, 0), "glass_grey", g, hi, L(hi, 0.0, 0.6))
    if hi:
        floor_bands("socar_band", g, [4.0 * k for k in range(3, int(H / 4.0))], ring)


def build_crown(hi):
    tag = "H" if hi else "L"
    g = "crown_tower"
    H = 100.0
    bbox(f"crown_shaft_{tag}", (22.0, H, 22.0), (0, H * 0.5, 0), "glass_grey", g, hi, L(hi, 0.0, 0.5))
    for s in (-1, 1):
        bbox(f"crown_fin{s}_{tag}", (1.2, H, 26.0), (s * 11.6, H * 0.5, 0), "white", g, hi, L(hi, 0.0, 0.2))
    # Flared crown: an inverted frustum, its lip, a lattice pyramid and the spire.
    lathe(f"crown_lip_{tag}", [(0.0, 15.0), (6.0, 22.0), (8.0, 22.0), (8.0, 18.0)], (0, 0, 0), "white", g, hi,
          L(hi, 4, 4), False, True).data.transform(K.trs((0, H, 0), (0, math.pi / 4, math.pi / 2)))
    lathe(f"crown_pyr_{tag}", [(0.0, 16.0), (16.0, 0.6)], (0, 0, 0), "steel", g, hi, L(hi, 4, 4), False, True
          ).data.transform(K.trs((0, H + 8.0, 0), (0, math.pi / 4, math.pi / 2)))
    tube(f"crown_spire_{tag}", [(0, H + 20.0, 0), (0, H + 42.0, 0)], 0.6, "steel", g, hi, 1, L(hi, 6, 12))
    if hi:
        for k in range(8):
            a = math.pi / 4 + k * math.pi / 2
            tube(f"crown_rib{k}", [(math.cos(a) * 15.5, H + 8.5, math.sin(a) * 15.5), (0, H + 24.0, 0)], 0.35, "steel",
                 g, True, 1, 6)
        floor_bands("crown_band", g, [4.0 * k for k in range(2, int(H / 4.0))],
                    lambda y: [Vector((x, y, z)) for x, z in ((-11.05, -11.05), (11.05, -11.05), (11.05, 11.05),
                                                                (-11.05, 11.05))])


def build_stack(hi):
    tag = "H" if hi else "L"
    g = "stack_tower"
    bbox(f"stack_base_{tag}", (40.0, 7.0, 26.0), (0, 3.5, 0), "glass_teal", g, hi, L(hi, 0.0, 2.0))
    y = 9.0
    for i in range(6):
        h = 15.0
        rot = (0.08 * (1 if i % 2 else -1), 0.25 * i, 0.05 * (1 if i % 3 else -1))
        bbox(f"stack_cube{i}_{tag}", (22.0, h, 22.0), (0, y + h * 0.5, 0), "glass_teal" if i % 2 else "glass_blue",
             g, hi, L(hi, 0.0, 1.2), rot=rot)
        bbox(f"stack_garden{i}_{tag}", (14.0, 2.0, 14.0), (0, y + h + 1.0, 0), "garden", g, hi, L(hi, 0.0, 0.4))
        if hi:
            for s in range(4):
                a = 0.25 * i + s * math.pi / 2
                for k in range(1, 4):
                    yy = y + k * h / 4
                    tube(f"stack_line{i}{s}{k}", [(math.cos(a) * 11.0 - math.sin(a) * 11.0, yy,
                                                   math.sin(a) * 11.0 + math.cos(a) * 11.0),
                                                  (math.cos(a) * 11.0 + math.sin(a) * 11.0, yy,
                                                   math.sin(a) * 11.0 - math.cos(a) * 11.0)], 0.15, "mullion", g,
                         True, 1, 4, False)
        y += h + 2.0


def build_slab(hi):
    tag = "H" if hi else "L"
    g = "glass_slab"
    W, D, H = 36.0, 14.0, 80.0
    bm = bmesh.new()
    pts = [(-W / 2, 0), (W / 2, 0), (W / 2, H - 22.0), (-W / 2, H)]  # sloped cut top
    front = [bm.verts.new((x, y, D / 2)) for x, y in pts]
    back = [bm.verts.new((x, y, -D / 2)) for x, y in pts]
    bm.faces.new(front)
    bm.faces.new(list(reversed(back)))
    for k in range(4):
        j = (k + 1) % 4
        bm.faces.new((front[j], front[k], back[k], back[j]))
    K.finish(bm, f"slab_body_{tag}", "glass_blue", g, hi, smooth=False)
    bbox(f"slab_podium_{tag}", (W + 10.0, 6.0, D + 12.0), (0, 3.0, 0), "white", g, hi, L(hi, 0.0, 0.5))
    if hi:
        for k in range(2, int(H / 3.5)):
            yy = 3.5 * k
            top = H - 22.0 + 22.0 * 0.0
            x_end = W / 2 if yy < H - 22.0 else W / 2 - (yy - (H - 22.0)) / 22.0 * W
            tube(f"slab_line{k}", [(-W / 2, yy, D / 2 + 0.05), (x_end, yy, D / 2 + 0.05)], 0.1, "mullion", g, True, 1,
                 4, False)
        for k in range(1, 12):
            x = -W / 2 + k * W / 12
            h_top = H - 22.0 + (W / 2 - x) / W * 22.0 if x > -W / 2 else H
            tube(f"slab_mull{k}", [(x, 6.0, D / 2 + 0.05), (x, min(h_top, H) - 0.5, D / 2 + 0.05)], 0.12, "mullion", g,
                 True, 1, 4, False)


def build_stalin(hi):
    tag = "H" if hi else "L"
    g = "stalin_block"
    W, D, H = 40.0, 22.0, 26.0
    bbox(f"st_body_{tag}", (W, H, D), (0, H * 0.5, 0), "sandstone", g, hi, L(hi, 0.0, 0.3))
    bbox(f"st_base_{tag}", (W + 0.4, 6.0, D + 0.4), (0, 3.0, 0), "sandstone_dark", g, hi, L(hi, 0.0, 0.2))
    bbox(f"st_cornice_{tag}", (W + 1.2, 0.8, D + 1.2), (0, H + 0.2, 0), "white", g, hi, L(hi, 0.0, 0.3))
    for sx in (-1, 1):
        cx = sx * (W / 2 - 3.0)
        bbox(f"st_turret{sx}_{tag}", (6.5, 6.0, 6.5), (cx, H + 3.0, D / 2 - 3.0), "sandstone", g, hi, L(hi, 0.0, 0.2))
        superellipsoid(f"st_dome{sx}_{tag}", (3.2, 3.6, 3.2), (cx, H + 6.0, D / 2 - 3.0), "white", g, hi, (0.8, 1.0),
                       L(hi, (8, 6), (32, 20)), deform=lambda p, n: Vector((p.x, max(p.y, 0.0), p.z)))
        tube(f"st_finial{sx}_{tag}", [(cx, H + 9.4, D / 2 - 3.0), (cx, H + 11.0, D / 2 - 3.0)], 0.15, "steel", g, hi,
             1, L(hi, 4, 8))
    for k in range(int(W / 4.0)):
        x = -W / 2 + 2.0 + k * 4.0
        bm = bmesh.new()
        vs = [bm.verts.new((x + dx, y, D / 2 + 0.25)) for dx, y in ((-1.4, 0.0), (1.4, 0.0), (1.4, 4.6), (-1.4, 4.6))]
        bm.faces.new(vs)
        K.finish(bm, f"st_arch{k}_{tag}", "glass", g, hi, keep=True, smooth=False)
    if hi:
        for f in range(int((H - 7.0) / 3.4)):
            y = 7.5 + f * 3.4
            for k in range(int(W / 2.6)):
                x = -W / 2 + 1.3 + k * 2.6
                bbox(f"st_win{f}_{k}", (1.2, 1.9, 0.05), (x, y + 1.0, D / 2 + 0.02), "glass", g, True, 0.0)
                bbox(f"st_frame{f}_{k}", (1.5, 0.15, 0.08), (x, y + 2.05, D / 2 + 0.03), "white", g, True, 0.0)
            for s in (-1, 1):
                for k in range(int(D / 2.6)):
                    z = -D / 2 + 1.3 + k * 2.6
                    bbox(f"st_sw{f}_{s}_{k}", (0.05, 1.9, 1.2), (s * (W / 2 + 0.02), y + 1.0, z), "glass", g, True, 0.0)
        for k in range(int(W / 4.0)):
            x = -W / 2 + 2.0 + k * 4.0
            torus(f"st_archring{k}", 1.4, 0.18, K.trs((x, 4.6, D / 2 + 0.22), (math.pi / 2, 0, 0)), "white", g, True,
                  (24, 4))


def build_resid(hi):
    tag = "H" if hi else "L"
    g = "resid_tower"
    W, D, H = 24.0, 20.0, 60.0
    bbox(f"rt_body_{tag}", (W, H, D), (0, H * 0.5, 0), "cream", g, hi, L(hi, 0.0, 0.3))
    bbox(f"rt_crown_{tag}", (W - 6.0, 4.0, D - 6.0), (0, H + 2.0, 0), "cream", g, hi, L(hi, 0.0, 0.3))
    bbox(f"rt_cap_{tag}", (W + 0.8, 0.6, D + 0.8), (0, H, 0), "white", g, hi, L(hi, 0.0, 0.2))
    # Projecting balcony bays (silhouette) on the front.
    for s in (-1, 1):
        bbox(f"rt_bay{s}_{tag}", (6.0, H - 6.0, 1.6), (s * 6.5, (H - 6.0) * 0.5 + 6.0, D / 2 + 0.8), "white", g, hi,
             L(hi, 0.0, 0.2))
    if hi:
        for f in range(2, int(H / 3.2)):
            y = f * 3.2
            for k in range(int(W / 2.4)):
                x = -W / 2 + 1.2 + k * 2.4
                bbox(f"rt_win{f}_{k}", (1.4, 1.8, 0.05), (x, y + 1.0, D / 2 + (1.62 if abs(abs(x) - 6.5) < 3.0 else 0.03)),
                     "glass", g, True, 0.0)
            for s in (-1, 1):
                bbox(f"rt_slab{f}{s}", (6.2, 0.18, 0.05), (s * 6.5, y, D / 2 + 1.62), "steel", g, True, 0.0)
                for k in range(int(D / 2.4)):
                    z = -D / 2 + 1.2 + k * 2.4
                    bbox(f"rt_sw{f}_{s}_{k}", (0.05, 1.8, 1.4), (s * (W / 2 + 0.03), y + 1.0, z), "glass", g, True, 0.0)


BUILDERS = {"socar_tower": build_socar, "crown_tower": build_crown, "stack_tower": build_stack,
            "glass_slab": build_slab, "stalin_block": build_stalin, "resid_tower": build_resid}
OFFSET = {g: Vector((i * 120.0, 0.0, 0.0)) for i, g in enumerate(GROUPS)}


def build(hi):
    for g in GROUPS:
        before = set(K.COLL.objects)
        BUILDERS[g](hi)
        for o in set(K.COLL.objects) - before:
            o.data.transform(Matrix.Translation(OFFSET[g]))


def _home(groups):
    for o in groups:
        o.data.transform(Matrix.Translation(-OFFSET[o.name]))


K.PRE_EXPORT.append(_home)
K.CAGE, K.RAY, K.AO_DIST = 0.45, 0.9, 4.0
K.setup("skyline_props", "assets/models/skyline", PALETTE, PAINT_MAT, GROUPS, UV_SCALE, FAR_RATIO, stone_mats=STONE)
K.run(build)
