"""Nizami street and the Nizami Museum of Literature for Yaska Racing
(0.17.2, owner: "mini Baku", from photos on Wikimedia Commons):

  blender --background --factory-startup --python tools/blender/nizami_props.py -- --bake-res 4096 --tex-res 2048
One shared 2048² set in assets/models/nizami/. Front = +Z, origin on the
ground in the middle of the footprint, depth 12 m for the street houses.
  lit_museum   Nizami Museum of Literature (north side of Fountain Square):
               cream-yellow front, ground floor of green-framed windows
               between pilasters, the deep loggia of tall pointed arches with
               blue tile spandrels and a white poet statue in every arch, an
               arcaded gallery with a balustrade and the raised centre on top
  nz_corner    four storeys of sandstone with a rounded corner (on +x): the
               corner stacks curved iron balconies and ends in a ribbed dome
               with a lantern; arched shop windows at street level
  nz_balcony   four storeys, a wrought-iron balcony on consoles in every bay,
               window surrounds with cornices, arched shop windows, heavy
               cornice and an attic balustrade
  nz_bay       three storeys, rusticated ground floor, a two-storey bay window
               (erker) in the middle under a pediment, side balconies
  nz_arcade    two storeys in the Taghiyev passage manner: tall round-arched
               windows between pilasters with capitals over square shop
               windows, a parapet with a raised attic
Every house has a plain window grid on its back so no blank wall shows.
orm alpha = glass (night glow), albedo alpha = stone.
"""

import math
import os
import sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from kart_common import *  # noqa: F401,F403
import kart_common as K
from mathutils import Vector, Matrix

PALETTE = {
    "sand": ("E1CDA6", 0.85, 0.0), "sand_trim": ("EEE0C2", 0.75, 0.0), "sand_dark": ("C7B089", 0.9, 0.0),
    "iron": ("25262B", 0.5, 0.6), "glass": ("3B6588", 0.08, 0.3), "shop": ("4D7898", 0.08, 0.3),
    "wood": ("6A3E22", 0.6, 0.0), "dome": ("8E989E", 0.5, 0.4),
    "museum": ("E4D38E", 0.8, 0.0), "museum_white": ("F3EFE2", 0.65, 0.0), "tile_blue": ("2D6CA6", 0.35, 0.0),
    "tile_white": ("F0F2F4", 0.4, 0.0), "statue": ("F5F2EA", 0.55, 0.0), "frame_green": ("3D7A58", 0.5, 0.0),
    "shadow": ("3A3A44", 0.9, 0.0),
}
PAINT_MAT = ["glass", "shop"]
STONE = ["sand", "sand_trim", "sand_dark", "museum", "museum_white"]
GROUPS = ["lit_museum", "nz_corner", "nz_balcony", "nz_bay", "nz_arcade"]
UV_SCALE = {g: 1.0 for g in GROUPS}
FAR_RATIO = {g: 0.4 for g in GROUPS}
UP = Matrix.Rotation(math.pi / 2, 4, "Z")  # lathe axis X -> Y
D = 12.0  # street house depth


def turned(name, profile, base, mat, g, hi, steps, cap=False):
    """Lathe around the vertical axis through `base`; profile = [(y, r)]."""
    yc = min(y for y, _ in profile) - 0.5
    ob = lathe(name, profile, (0, 0, 0), mat, g, hi, steps, False, cap,
               outward=lambda p: Vector((p.x - yc, p.y, p.z)))
    ob.data.transform(Matrix.Translation(Vector(base)) @ UP)
    return ob


def facing(normal, pos):
    n = Vector(normal).normalized()
    up = Vector((0, 1, 0))
    x = up.cross(n).normalized()
    m = Matrix((x, up, n)).transposed().to_4x4()
    m.translation = Vector(pos)
    return m


def round_arch(w, h, n):
    hw = w * 0.5
    pts = [(-hw, 0.0), (hw, 0.0)]
    for k in range(n + 1):
        a = math.pi * k / n
        pts.append((math.cos(a) * hw, h - hw + math.sin(a) * hw))
    return pts


def ogee(w, h, n):
    """Tall pointed arch (the museum loggia)."""
    half = w * 0.5
    a = 1.25 * half
    t0 = math.acos((half - a) / a)
    spring = h - half * 1.3
    left = []
    for k in range(n + 1):
        t = math.pi - (math.pi - t0) * k / n
        left.append((-half + a + a * math.cos(t), spring + 1.3 * half * math.sin(t) / math.sin(t0)))
    right = [(-x, y) for (x, y) in reversed(left[:-1])]
    return [(-half, 0.0)] + left + right + [(half, 0.0)]


def rect(w, h):
    return [(-w * 0.5, 0.0), (w * 0.5, 0.0), (w * 0.5, h), (-w * 0.5, h)]


def window(name, pos, w, h, g, hi, shape="rect", fill="glass", frame="sand_trim", normal=(0, 0, 1), hood=True):
    """Window with a stone surround (and a small cornice over rect ones)."""
    m = facing(normal, pos)
    if shape == "round":
        out, fr = round_arch(w, h, L(hi, 4, 12)), round_arch(w + 0.4, h + 0.2, L(hi, 4, 12))
    elif shape == "ogee":
        out, fr = ogee(w, h, L(hi, 3, 8)), ogee(w + 0.5, h + 0.35, L(hi, 3, 8))
    else:
        out, fr = rect(w, h), [(-w * 0.5 - 0.2, -0.15), (w * 0.5 + 0.2, -0.15), (w * 0.5 + 0.2, h + 0.2),
                                (-w * 0.5 - 0.2, h + 0.2)]
    if frame:
        puffy(f"{name}_fr", fr, 0.14, 0.0, m, frame, g, hi)
    puffy(f"{name}_p", out, 0.22, 0.0, m, fill, g, hi)
    if shape == "rect" and hood and frame:
        rot = m.to_3x3().to_euler()
        bbox(f"{name}_hood", (w + 0.7, 0.22, 0.35), m @ Vector((0, h + 0.4, 0.14)), frame, g, hi, L(hi, 0.0, 0.03), rot=rot)


def balcony(name, x, y, z, w, g, hi, normal=(0, 0, 1), depth=0.9):
    """Stone slab on two consoles with a wrought-iron railing."""
    m = facing(normal, (x, y, z))
    rot = m.to_3x3().to_euler()
    bbox(f"{name}_slab", (w, 0.22, depth), m @ Vector((0, 0, depth * 0.5)), "sand_trim", g, hi, L(hi, 0.0, 0.04), rot=rot)
    for s in (-1, 1):
        bbox(f"{name}_con{s}", (0.25, 0.5, depth * 0.8), m @ Vector((s * (w * 0.5 - 0.3), -0.33, depth * 0.4)), "sand_dark",
             g, hi, L(hi, 0.0, 0.03), rot=rot)
    if hi:
        tube(f"{name}_rail", [m @ Vector((-w * 0.5, 1.0, 0.05)), m @ Vector((-w * 0.5, 1.0, depth - 0.05)),
                              m @ Vector((w * 0.5, 1.0, depth - 0.05)), m @ Vector((w * 0.5, 1.0, 0.05))],
             0.04, "iron", g, hi, 1, 4, False)
        n = int(w / 0.18)
        for k in range(n + 1):
            xx = -w * 0.5 + w * k / n
            tube(f"{name}_b{k}", [m @ Vector((xx, 0.11, depth - 0.05)), m @ Vector((xx, 1.0, depth - 0.05))], 0.018,
                 "iron", g, hi, 1, 3, False)
        for k in range(int(w / 0.6)):
            xx = -w * 0.5 + 0.3 + k * 0.6
            torus(f"{name}_s{k}", 0.2, 0.025, m @ Matrix.Translation(Vector((xx, 0.55, depth - 0.05))) @
                  Matrix.Rotation(math.pi / 2, 4, "X"), "iron", g, hi, (10, 4))
    else:
        bbox(f"{name}_ironf", (w, 0.9, 0.05), m @ Vector((0, 0.56, depth - 0.05)), "iron", g, hi, 0.0, rot=rot)
        for s in (-1, 1):
            bbox(f"{name}_irons{s}", (0.05, 0.9, depth), m @ Vector((s * w * 0.5, 0.56, depth * 0.5)), "iron", g, hi, 0.0,
                 rot=rot)


def back_grid(name, w, floors, fh, g, hi, y0=0.6):
    """Plain window rows on the back (-Z) so no blank wall shows."""
    n = max(2, int(w / 3.4))
    for f in range(floors):
        for k in range(n):
            x = -w * 0.5 + (k + 0.5) * w / n
            window(f"{name}{f}_{k}", (x, y0 + f * fh + 0.8, -D * 0.5 - 0.02), 1.3, 2.0, g, hi, normal=(0, 0, -1),
                   hood=False, frame="sand_trim" if hi else None)


def cornice(name, w, y, g, hi, depth=D, mat="sand_trim"):
    bbox(f"{name}_c1", (w + 0.6, 0.35, depth + 0.6), (0, y, 0), mat, g, hi, L(hi, 0.0, 0.05))
    bbox(f"{name}_c2", (w + 1.0, 0.3, depth + 1.0), (0, y + 0.32, 0), mat, g, hi, L(hi, 0.0, 0.05))


def balustrade(name, x0, x1, y, z, g, hi, mat="sand_trim"):
    bbox(f"{name}_base", (x1 - x0, 0.2, 0.5), ((x0 + x1) * 0.5, y + 0.1, z), mat, g, hi, 0.0)
    bbox(f"{name}_top", (x1 - x0, 0.2, 0.55), ((x0 + x1) * 0.5, y + 1.0, z), mat, g, hi, 0.0)
    if hi:
        n = int((x1 - x0) / 0.35)
        for k in range(n):
            x = x0 + (k + 0.5) * (x1 - x0) / n
            turned(f"{name}_b{k}", [(y + 0.2, 0.09), (y + 0.4, 0.14), (y + 0.7, 0.08), (y + 0.9, 0.1)], (x, 0, z), mat, g,
                   hi, 6)
    else:
        bbox(f"{name}_mid", (x1 - x0, 0.7, 0.25), ((x0 + x1) * 0.5, y + 0.55, z), mat, g, hi, 0.0)


def shopfront(name, x0, x1, n, g, hi, fz, h=4.2, shape="round"):
    for k in range(n):
        x = x0 + (k + 0.5) * (x1 - x0) / n
        window(f"{name}{k}", (x, 0.35, fz + 0.02), (x1 - x0) / n * 0.62, h, g, hi, shape=shape, fill="shop",
               frame="sand_dark", hood=False)


def build_corner(hi):
    tag = "H" if hi else "L"
    g = "nz_corner"
    w, fh, floors = 18.0, 3.9, 4
    h = fh * floors + 0.9
    fz = D * 0.5
    bbox(f"nc_body_{tag}", (w - 4.0, h, D), (-2.0, h * 0.5, 0), "sand", g, hi, L(hi, 0.0, 0.08))
    bbox(f"nc_rust_{tag}", (w - 3.8, 4.6, D + 0.2), (-2.0, 2.3, 0), "sand_dark", g, hi, L(hi, 0.0, 0.04))
    # Rounded corner on +x: a quarter-round mass, curved balconies, dome.
    cx, cz, r = w * 0.5 - 4.0, fz - 4.0, 4.0
    turned(f"nc_round_{tag}", [(0.0, r), (h, r), (h, 0.0)], (cx, 0, cz), "sand", g, hi, L(hi, 16, 40))
    bbox(f"nc_side_{tag}", (4.0, h, D - 4.0), (cx + 2.0, h * 0.5, -2.0), "sand", g, hi, L(hi, 0.0, 0.08))
    st = L(hi, 16, 40)
    for f in range(1, floors):
        y = 0.9 + f * fh
        turned(f"nc_rb{f}_{tag}", [(y - 0.25, r + 1.0), (y, r + 1.0), (y, 0.0)], (cx, 0, cz), "sand_trim", g, hi, st)
        if hi:
            ring = [Vector((cx + math.cos(a) * (r + 0.95), y + 1.0, cz + math.sin(a) * (r + 0.95)))
                    for a in [k * 2 * math.pi / 40 for k in range(41)]]
            tube(f"nc_rr{f}", ring, 0.04, "iron", g, hi, 1, 4, False)
            for k in range(60):
                a = 2 * math.pi * k / 60
                tube(f"nc_rp{f}_{k}", [Vector((cx + math.cos(a) * (r + 0.95), y, cz + math.sin(a) * (r + 0.95))),
                                       Vector((cx + math.cos(a) * (r + 0.95), y + 1.0, cz + math.sin(a) * (r + 0.95)))],
                     0.018, "iron", g, hi, 1, 3, False)
        else:
            turned(f"nc_rr{f}_{tag}", [(y, r + 0.95), (y + 1.0, r + 0.95)], (cx, 0, cz), "iron", g, hi, st)
        for k, a in enumerate((0.18, 0.5, 0.82)):  # front (+z) round to the side (+x)
            ang = a * math.pi * 0.5
            nrm = (math.sin(ang), 0, math.cos(ang))
            window(f"nc_rw{f}{k}_{tag}", (cx + nrm[0] * (r + 0.02), y + 0.25, cz + nrm[2] * (r + 0.02)), 1.2, 2.3, g, hi,
                   normal=nrm, hood=False)
    for k, a in enumerate((0.3, 0.72)):
        ang = a * math.pi * 0.5
        nrm = (math.sin(ang), 0, math.cos(ang))
        window(f"nc_rs{k}_{tag}", (cx + nrm[0] * (r + 0.02), 0.35, cz + nrm[2] * (r + 0.02)), 1.8, 4.0, g, hi,
               shape="round", fill="shop", frame="sand_dark", normal=nrm)
    cornice(f"nc_corn_{tag}", w - 4.0, h, g, hi)
    turned(f"nc_rc_{tag}", [(h - 0.1, r + 0.5), (h + 0.6, r + 0.7), (h + 0.6, 0.0)], (cx, 0, cz), "sand_trim", g, hi, st)
    # Drum, ribbed dome and lantern over the corner.
    turned(f"nc_drum_{tag}", [(h + 0.6, r * 0.8), (h + 2.2, r * 0.8), (h + 2.2, r * 0.85), (h + 2.5, r * 0.85)],
           (cx, 0, cz), "sand_trim", g, hi, st)
    prof = [(h + 2.5 + math.sin(math.pi * 0.5 * k / L(hi, 5, 12)) * 3.0,
             max(0.01, math.cos(math.pi * 0.5 * k / L(hi, 5, 12)) * r * 0.85)) for k in range(L(hi, 5, 12) + 1)]
    turned(f"nc_dome_{tag}", prof, (cx, 0, cz), "dome", g, hi, st)
    if hi:
        for k in range(12):
            a = 2 * math.pi * k / 12
            pts = [Vector((cx + math.cos(a) * math.cos(t) * (r * 0.85 + 0.05), h + 2.5 + math.sin(t) * 3.02,
                           cz + math.sin(a) * math.cos(t) * (r * 0.85 + 0.05))) for t in (0.0, 0.5, 1.0, 1.4)]
            tube(f"nc_rib{k}", pts, 0.07, "sand_trim", g, hi, 3, 4, False)
    turned(f"nc_lan_{tag}", [(h + 5.3, 0.6), (h + 6.3, 0.6), (h + 6.5, 0.8), (h + 7.3, 0.01)], (cx, 0, cz), "sand_trim",
           g, hi, L(hi, 8, 16))
    # Street front: shop arches, windows with balconies in every bay.
    shopfront(f"nc_shop_{tag}", -w * 0.5, w * 0.5 - 8.0, 3, g, hi, fz)
    for f in range(1, floors):
        y = 0.9 + f * fh
        for k in range(3):
            x = -w * 0.5 + (k + 0.5) * (w - 8.0) / 3
            window(f"nc_w{f}{k}_{tag}", (x, y + 0.25, fz + 0.02), 1.3, 2.4, g, hi)
            if (f + k) % 2 == 1:
                balcony(f"nc_b{f}{k}_{tag}", x, y, fz, 2.4, g, hi)
    back_grid(f"nc_back_{tag}", w - 2.0, floors, fh, g, hi)


def build_balcony(hi):
    tag = "H" if hi else "L"
    g = "nz_balcony"
    w, fh, floors = 16.0, 3.8, 4
    h = fh * floors + 0.9
    fz = D * 0.5
    bbox(f"nb_body_{tag}", (w, h, D), (0, h * 0.5, 0), "sand", g, hi, L(hi, 0.0, 0.08))
    bbox(f"nb_rust_{tag}", (w + 0.2, 4.6, D + 0.2), (0, 2.3, 0), "sand_dark", g, hi, L(hi, 0.0, 0.04))
    for k in range(5):
        bbox(f"nb_pil{k}_{tag}", (0.5, h - 4.8, 0.3), (-w * 0.5 + 0.4 + k * (w - 0.8) / 4, 4.6 + (h - 4.8) * 0.5, fz + 0.1),
             "sand_trim", g, hi, L(hi, 0.0, 0.03))
    shopfront(f"nb_shop_{tag}", -w * 0.5, w * 0.5, 4, g, hi, fz)
    for f in range(1, floors):
        y = 0.9 + f * fh
        bbox(f"nb_band{f}_{tag}", (w + 0.3, 0.25, D + 0.3), (0, y - 0.15, 0), "sand_trim", g, hi, 0.0)
        for k in range(4):
            x = -w * 0.5 + (k + 0.5) * w / 4
            window(f"nb_w{f}{k}_{tag}", (x, y + 0.2, fz + 0.02), 1.3, 2.5, g, hi)
            balcony(f"nb_b{f}{k}_{tag}", x, y, fz, 2.6, g, hi, depth=0.8 if f < 3 else 1.1)
    cornice(f"nb_corn_{tag}", w, h, g, hi)
    balustrade(f"nb_attic_{tag}", -w * 0.5, w * 0.5, h + 0.62, fz - 0.1, g, hi)
    back_grid(f"nb_back_{tag}", w, floors, fh, g, hi)


def build_bay(hi):
    tag = "H" if hi else "L"
    g = "nz_bay"
    w, fh, floors = 14.0, 4.0, 3
    h = fh * floors + 0.9
    fz = D * 0.5
    bbox(f"ny_body_{tag}", (w, h, D), (0, h * 0.5, 0), "sand", g, hi, L(hi, 0.0, 0.08))
    bbox(f"ny_rust_{tag}", (w + 0.2, 4.8, D + 0.2), (0, 2.4, 0), "sand_dark", g, hi, L(hi, 0.0, 0.04))
    if hi:
        for k in range(10):
            bbox(f"ny_rl{k}", (w + 0.25, 0.06, 0.06), (0, 0.45 + k * 0.45, fz + 0.12), "sand", g, hi, 0.0)
    shopfront(f"ny_shop_{tag}", -w * 0.5, w * 0.5, 3, g, hi, fz, shape="round")
    # Two-storey bay window (erker) in the middle under a pediment.
    bw = 4.6
    bbox(f"ny_bay_{tag}", (bw, fh * 2 - 0.4, 1.2), (0, 0.9 + fh + fh - 0.2, fz + 0.6), "sand_trim", g, hi, L(hi, 0.0, 0.06))
    bbox(f"ny_bayc_{tag}", (bw + 0.5, 0.6, 1.6), (0, 0.9 + fh - 0.4, fz + 0.7), "sand_dark", g, hi, L(hi, 0.0, 0.05))
    for f in (1, 2):
        y = 0.9 + f * fh
        for k in (-1, 0, 1):
            window(f"ny_bw{f}{k}_{tag}", (k * 1.45, y + 0.3, fz + 1.22), 1.0, 2.4, g, hi, hood=False)
        for s in (-1, 1):
            x = s * (w * 0.5 - 2.4)
            window(f"ny_w{f}{s}_{tag}", (x, y + 0.3, fz + 0.02), 1.4, 2.6, g, hi)
            if f == 1:
                balcony(f"ny_b{s}_{tag}", x, y, fz, 2.6, g, hi)
    m = facing((0, 0, 1), (0, h - 0.2, fz + 0.3))
    puffy(f"ny_ped_{tag}", [(-bw * 0.5 - 0.6, 0.0), (bw * 0.5 + 0.6, 0.0), (0.0, 1.6)], 0.5, 0.0, m, "sand_trim", g, hi)
    cornice(f"ny_corn_{tag}", w, h, g, hi)
    back_grid(f"ny_back_{tag}", w, floors, fh, g, hi)


def build_arcade(hi):
    tag = "H" if hi else "L"
    g = "nz_arcade"
    w, h = 20.0, 11.0
    fz = D * 0.5
    bbox(f"na_body_{tag}", (w, h, D), (0, h * 0.5, 0), "sand", g, hi, L(hi, 0.0, 0.08))
    n = 5
    for k in range(n + 1):
        x = -w * 0.5 + 0.3 + k * (w - 0.6) / n
        bbox(f"na_pil{k}_{tag}", (0.7, h - 1.0, 0.45), (x, (h - 1.0) * 0.5, fz + 0.15), "sand_trim", g, hi, L(hi, 0.0, 0.04))
        bbox(f"na_cap{k}_{tag}", (1.1, 0.5, 0.65), (x, h - 1.2, fz + 0.2), "sand_trim", g, hi, L(hi, 0.0, 0.05))
        bbox(f"na_capl{k}_{tag}", (1.0, 0.4, 0.6), (x, 4.4, fz + 0.2), "sand_trim", g, hi, L(hi, 0.0, 0.05))
    for k in range(n):
        x = -w * 0.5 + 0.3 + (k + 0.5) * (w - 0.6) / n
        window(f"na_shop{k}_{tag}", (x, 0.3, fz + 0.02), 2.6, 3.6, g, hi, fill="shop", frame="sand_dark", hood=False)
        window(f"na_arch{k}_{tag}", (x, 5.1, fz + 0.02), 2.4, 4.6, g, hi, shape="round")
    bbox(f"na_band_{tag}", (w + 0.3, 0.35, D + 0.3), (0, 4.6, 0), "sand_trim", g, hi, 0.0)
    cornice(f"na_corn_{tag}", w, h, g, hi)
    bbox(f"na_par_{tag}", (w, 1.0, 0.5), (0, h + 1.1, fz - 0.1), "sand", g, hi, L(hi, 0.0, 0.04))
    bbox(f"na_attic_{tag}", (6.0, 2.2, 0.8), (0, h + 1.7, fz - 0.2), "sand_trim", g, hi, L(hi, 0.0, 0.05))
    m = facing((0, 0, 1), (0, h + 2.8, fz - 0.2))
    puffy(f"na_atticp_{tag}", round_arch(6.0, 1.4, L(hi, 4, 10)), 0.8, 0.0, m, "sand_trim", g, hi)
    back_grid(f"na_back_{tag}", w, 2, 4.8, g, hi)


def build_museum(hi):
    tag = "H" if hi else "L"
    g = "lit_museum"
    w, d = 44.0, 14.0
    fz = d * 0.5
    h1, h2 = 5.0, 13.0
    bbox(f"lm_body_{tag}", (w, h1, d), (0, h1 * 0.5, 0), "museum", g, hi, L(hi, 0.0, 0.1))
    # Upper body set back behind the loggia (the poets stand in its depth).
    bbox(f"lm_upper_{tag}", (w, h2 - h1, d - 3.4), (0, h1 + (h2 - h1) * 0.5, -1.7), "museum", g, hi, L(hi, 0.0, 0.1))
    for s in (-1, 1):
        bbox(f"lm_end{s}_{tag}", (4.0, h2 - h1, 3.4), (s * (w * 0.5 - 2.0), h1 + (h2 - h1) * 0.5, fz - 1.7), "museum", g,
             hi, L(hi, 0.0, 0.06))
    bbox(f"lm_plinth_{tag}", (w + 0.4, 0.8, d + 0.4), (0, 0.4, 0), "museum_white", g, hi, 0.0)
    # Ground floor: green-framed windows between white pilasters.
    n = 11
    for k in range(n + 1):
        x = -w * 0.5 + 0.4 + k * (w - 0.8) / n
        bbox(f"lm_gp{k}_{tag}", (0.7, h1, 0.35), (x, h1 * 0.5, fz + 0.1), "museum_white", g, hi, L(hi, 0.0, 0.03))
    for k in range(n):
        x = -w * 0.5 + 0.4 + (k + 0.5) * (w - 0.8) / n
        window(f"lm_gw{k}_{tag}", (x, 1.1, fz + 0.02), 1.7, 2.8, g, hi, fill="glass", frame="frame_green", hood=False)
        if hi:
            bbox(f"lm_gt{k}", (1.9, 0.6, 0.06), (x, 4.3, fz + 0.04), "tile_blue", g, hi, 0.0)
    bbox(f"lm_band_{tag}", (w + 0.5, 0.45, d + 0.5), (0, h1, 0), "museum_white", g, hi, L(hi, 0.0, 0.04))
    # Loggia of tall pointed arches, blue tile spandrels, a poet in every arch.
    na = 9
    lw = w - 8.0
    bbox(f"lm_loggia_{tag}", (lw, h2 - h1 - 1.0, 2.0), (0, h1 + (h2 - h1 - 1.0) * 0.5 + 0.2, fz - 2.4), "shadow", g, hi, 0.0)
    for k in range(na + 1):
        x = -lw * 0.5 + k * lw / na
        bbox(f"lm_lp{k}_{tag}", (0.9, h2 - h1, 1.0), (x, h1 + (h2 - h1) * 0.5, fz + 0.2), "museum_white", g, hi,
             L(hi, 0.0, 0.04))
    for k in range(na):
        x = -lw * 0.5 + (k + 0.5) * lw / na
        aw = lw / na - 0.9
        m = facing((0, 0, 1), (x, h1 + 0.3, fz + 0.45))
        # spandrel panel with the arch cut (blue tile) + white arch rim
        if hi:
            puffy(f"lm_sp{k}", [(-aw * 0.5, 5.2), (aw * 0.5, 5.2), (aw * 0.5, 7.4), (-aw * 0.5, 7.4)], 0.08, 0.0, m,
                  "tile_blue", g, hi)
            rim = [m @ Vector(p + (0.1,)) for p in ogee(aw - 0.1, 7.0, 8)[1:-1]]
            tube(f"lm_rim{k}", rim, 0.1, "tile_white", g, hi, 1, 4, False)
        else:
            puffy(f"lm_sp{k}_{tag}", [(-aw * 0.5, 5.6), (aw * 0.5, 5.6), (aw * 0.5, 7.4), (-aw * 0.5, 7.4)], 0.08, 0.0, m,
                  "tile_blue", g, hi)
        # poet on a pedestal
        bbox(f"lm_ped{k}_{tag}", (0.8, 1.0, 0.8), (x, h1 + 0.8, fz - 0.3), "museum_white", g, hi, L(hi, 0.0, 0.03))
        capsule(f"lm_body{k}_{tag}", (x, h1 + 1.4, fz - 0.3), (x, h1 + 2.9, fz - 0.3), 0.33, "statue", g, hi,
                L(hi, (6, 4), (12, 8)), r_end=0.25)
        ellipsoid(f"lm_head{k}_{tag}", (0.2, 0.25, 0.2), (x, h1 + 3.35, fz - 0.3), "statue", g, hi, L(hi, (6, 4), (12, 8)))
    bbox(f"lm_band2_{tag}", (w + 0.5, 0.5, d + 0.5), (0, h2, 0), "museum_white", g, hi, L(hi, 0.0, 0.04))
    # Side bays with windows.
    for s in (-1, 1):
        x = s * (w * 0.5 - 2.0)
        window(f"lm_sw{s}_{tag}", (x, h1 + 1.5, fz + 0.02), 1.6, 3.4, g, hi, shape="ogee", frame="museum_white")
    # Top: arcaded gallery with a balustrade, raised centre.
    gw = w - 6.0
    bbox(f"lm_gal_{tag}", (gw, 3.0, d - 3.0), (0, h2 + 1.5, -1.0), "museum", g, hi, L(hi, 0.0, 0.06))
    for k in range(15):
        x = -gw * 0.5 + (k + 0.5) * gw / 15
        window(f"lm_ga{k}_{tag}", (x, h2 + 0.4, fz - 2.48), 1.1, 2.3, g, hi, shape="round", fill="shadow",
               frame="museum_white")
    balustrade(f"lm_bal_{tag}", -w * 0.5, w * 0.5, h2 + 0.25, fz - 0.2, g, hi, mat="museum_white")
    bbox(f"lm_top_{tag}", (14.0, 3.0, 8.0), (0, h2 + 4.5, -1.5), "museum", g, hi, L(hi, 0.0, 0.06))
    for k in range(5):
        window(f"lm_ta{k}_{tag}", (-5.6 + k * 2.8, h2 + 3.3, 2.52), 1.0, 2.0, g, hi, shape="round", fill="shadow",
               frame="museum_white")
    balustrade(f"lm_tbal_{tag}", -7.0, 7.0, h2 + 6.0, 2.3, g, hi, mat="museum_white")
    bbox(f"lm_door_{tag}", (2.6, 3.4, 0.3), (0, 1.7, fz + 0.2), "wood", g, hi, 0.0)


OFFSET = {g: Vector((i * 80.0, 0.0, 0.0)) for i, g in enumerate(GROUPS)}


def _built(fn, g):
    before = set(K.COLL.objects)
    fn()
    for o in set(K.COLL.objects) - before:
        o.data.transform(Matrix.Translation(OFFSET[g]))


def build(hi):
    _built(lambda: build_museum(hi), "lit_museum")
    _built(lambda: build_corner(hi), "nz_corner")
    _built(lambda: build_balcony(hi), "nz_balcony")
    _built(lambda: build_bay(hi), "nz_bay")
    _built(lambda: build_arcade(hi), "nz_arcade")


def _home(groups):
    for o in groups:
        o.data.transform(Matrix.Translation(-OFFSET[o.name]))


K.PRE_EXPORT.append(_home)

K.setup("nizami_props", "assets/models/nizami", PALETTE, PAINT_MAT, GROUPS, UV_SCALE, FAR_RATIO, stone_mats=STONE)
K.run(build)
