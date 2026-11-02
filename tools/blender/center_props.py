"""Baku city-centre landmarks for "Göydələnlər" (0.17.0, owner: "mini Baku",
from photos on Wikimedia Commons):

  blender --background --factory-startup --python tools/blender/center_props.py -- --bake-res 4096 --tex-res 2048
One shared 2048² set in assets/models/center/. Front = +Z, origin on the
ground in the middle of the footprint. Heights are game-fitted.
  philharmonic     Muslim Magomayev Philharmonic: ochre-yellow hall with white
                   trim, two slender towers with two open belvederes and gold
                   finials, central ribbed dome, round corner rotunda with
                   oval windows and a low dome
  city_hall        Baku City Hall (İcra Hakimiyyəti): sandstone block with red
                   panels between the windows, rusticated ground floor, slate
                   mansard roofs and corner pavilions, central clock tower
                   over a tall arch with a blue cupola and a flag
  ismailiyya       Ismailiyya Palace: Venetian Gothic, cream stone; corner
                   risalits with stepped gables and pinnacles, round-arched
                   ground floor, lancet windows with rose windows above, a
                   crest of small pinnacles
  fountain_tiered  Fountain Square: round stepped fountain in a low basin
  fountain_spheres Fountain Square: square basin, three steel spheres
  fountain_plaza   Fountain Square paving: grey with white wave bands
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
    "ochre": ("E2B44A", 0.75, 0.0), "white": ("F3EEE0", 0.6, 0.0), "dome_grey": ("98A6A2", 0.5, 0.3),
    "bronze": ("8C7A5C", 0.5, 0.4), "gold": ("D9A93A", 0.3, 0.9),
    "sand": ("D8C59F", 0.85, 0.0), "sand_dark": ("B9A47E", 0.9, 0.0), "red": ("A44A3B", 0.8, 0.0),
    "slate": ("6A6F76", 0.6, 0.15), "cupola": ("5A86AD", 0.4, 0.4), "clock": ("F8F4E8", 0.4, 0.0),
    "cream": ("E8D19C", 0.8, 0.0), "cream_trim": ("F2E3BC", 0.7, 0.0),
    "glass": ("3B6588", 0.08, 0.3), "dark": ("2A2E36", 0.6, 0.1), "wood": ("6A3E22", 0.6, 0.0),
    "steel": ("CDD2DA", 0.12, 1.0), "water": ("8FD0EA", 0.05, 0.0), "spray": ("E8F6FC", 0.3, 0.0),
    "paving": ("8E8F94", 0.85, 0.0), "paving_white": ("E4E2DC", 0.8, 0.0),
}
PAINT_MAT = ["glass"]
STONE = ["sand", "sand_dark", "cream", "cream_trim", "white"]
GROUPS = ["philharmonic", "city_hall", "ismailiyya", "fountain_tiered", "fountain_spheres", "fountain_plaza"]
UV_SCALE = {"philharmonic": 1.0, "city_hall": 1.0, "ismailiyya": 1.0, "fountain_tiered": 1.0,
            "fountain_spheres": 1.0, "fountain_plaza": 0.5}
FAR_RATIO = {"philharmonic": 0.4, "city_hall": 0.4, "ismailiyya": 0.4, "fountain_tiered": 0.5,
             "fountain_spheres": 0.5, "fountain_plaza": 0.9}
UP = Matrix.Rotation(math.pi / 2, 4, "Z")  # lathe axis X -> Y


def turned(name, profile, base, mat, g, hi, steps, cap=False):
    """Lathe around the vertical axis through `base`; profile = [(y, r)]."""
    # Faces point away from the axis and up (horizontal caps would be
    # ambiguous with the default purely radial test).
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


def lancet(w, h, n):
    half = w * 0.5
    a = 1.4 * half
    t0 = math.acos((half - a) / a)
    spring = h - half * 1.5
    left = []
    for k in range(n + 1):
        t = math.pi - (math.pi - t0) * k / n
        left.append((-half + a + a * math.cos(t), spring + 1.5 * half * math.sin(t) / math.sin(t0)))
    right = [(-x, y) for (x, y) in reversed(left[:-1])]
    return [(-half, 0.0)] + left + right + [(half, 0.0)]


def window(name, pos, w, h, g, hi, shape="round", fill="glass", frame="white", normal=(0, 0, 1)):
    m = facing(normal, pos)
    if shape == "round":
        out = round_arch(w, h, L(hi, 4, 12))
        fr = round_arch(w + 0.3, h + 0.15, L(hi, 4, 12))
    elif shape == "lancet":
        out = lancet(w, h, L(hi, 3, 8))
        fr = lancet(w + 0.3, h + 0.2, L(hi, 3, 8))
    elif shape == "oval":
        out = [(math.cos(2 * math.pi * k / L(hi, 8, 20)) * w * 0.5, h * 0.5 + math.sin(2 * math.pi * k / L(hi, 8, 20)) * h * 0.5)
               for k in range(L(hi, 8, 20))]
        fr = [(x * 1.25, h * 0.5 + (y - h * 0.5) * 1.2) for x, y in out]
    else:  # rect
        out = [(-w * 0.5, 0.0), (w * 0.5, 0.0), (w * 0.5, h), (-w * 0.5, h)]
        fr = [(-w * 0.5 - 0.15, -0.1), (w * 0.5 + 0.15, -0.1), (w * 0.5 + 0.15, h + 0.25), (-w * 0.5 - 0.15, h + 0.25)]
    if frame:
        puffy(f"{name}_fr", fr, 0.12, 0.0, m, frame, g, hi)
    puffy(f"{name}_p", out, 0.2, 0.0, m, fill, g, hi)


def row(name, x0, x1, n, y, z, w, h, g, hi, **kw):
    for k in range(n):
        x = x0 + (x1 - x0) * (k + 0.5) / n
        window(f"{name}{k}", (x, y, z), w, h, g, hi, **kw)


def finial(name, x, y, z, g, hi, s=1.0):
    ellipsoid(f"{name}_ball", (0.35 * s, 0.35 * s, 0.35 * s), (x, y + 0.35 * s, z), "gold", g, hi, L(hi, (8, 6), (16, 10)))
    turned(f"{name}_spike", [(y + 0.6 * s, 0.12 * s), (y + 1.6 * s, 0.01)], (x, 0, z), "gold", g, hi, L(hi, 6, 12))


def ribbed_dome(name, cx, cy, cz, r, rise, mat, g, hi, ribs=12, rib_mat="white"):
    prof = []
    n = L(hi, 5, 14)
    for k in range(n + 1):
        a = math.pi * 0.5 * k / n
        prof.append((cy + math.sin(a) * rise, max(0.01, math.cos(a) * r)))
    turned(f"{name}_shell", prof, (cx, 0, cz), mat, g, hi, L(hi, 16, 48))
    if hi:
        for k in range(ribs):
            a = 2 * math.pi * k / ribs
            pts = [Vector((cx + math.cos(a) * math.cos(t) * (r + 0.05), cy + math.sin(t) * rise * 1.01,
                           cz + math.sin(a) * math.cos(t) * (r + 0.05))) for t in (0.0, 0.45, 0.9, 1.3)]
            tube(f"{name}_rib{k}", pts, 0.09, rib_mat, g, hi, 3, 5, False)


def belvedere(name, x, y, z, side, h, g, hi):
    """Open square lantern: four white columns, slab, cornice."""
    d = side * 0.5 - 0.2
    for i, (sx, sz) in enumerate(((-1, -1), (1, -1), (1, 1), (-1, 1))):
        tube(f"{name}_c{i}", [Vector((x + sx * d, y, z + sz * d)), Vector((x + sx * d, y + h, z + sz * d))], 0.16,
             "white", g, hi, 1, L(hi, 6, 10))
    bbox(f"{name}_slab", (side + 0.3, 0.35, side + 0.3), (x, y + h + 0.17, z), "white", g, hi, L(hi, 0.0, 0.05))
    bbox(f"{name}_rail", (side + 0.1, 0.6, side + 0.1), (x, y + 0.3, z), "white", g, hi, L(hi, 0.0, 0.03))


def build_philharmonic(hi):
    tag = "H" if hi else "L"
    g = "philharmonic"
    # Main hall.
    bbox(f"ph_body_{tag}", (30.0, 11.0, 20.0), (0, 5.5, -2.0), "ochre", g, hi, L(hi, 0.0, 0.1))
    bbox(f"ph_plinth_{tag}", (30.4, 1.0, 20.4), (0, 0.5, -2.0), "white", g, hi, L(hi, 0.0, 0.05))
    bbox(f"ph_band_{tag}", (30.4, 0.4, 20.4), (0, 5.2, -2.0), "white", g, hi, 0.0)
    bbox(f"ph_corn_{tag}", (31.0, 0.7, 21.0), (0, 11.2, -2.0), "white", g, hi, L(hi, 0.0, 0.06))
    row(f"ph_g_{tag}", -15.0, -6.5, 3, 1.1, 8.02, 1.8, 3.3, g, hi)
    row(f"ph_g2_{tag}", 6.5, 15.0, 3, 1.1, 8.02, 1.8, 3.3, g, hi)
    row(f"ph_u_{tag}", -15.0, -6.5, 3, 6.4, 8.02, 1.6, 2.8, g, hi, shape="rect")
    row(f"ph_u2_{tag}", 6.5, 15.0, 3, 6.4, 8.02, 1.6, 2.8, g, hi, shape="rect")
    # Central risalit with the entrance and the two towers.
    bbox(f"ph_ris_{tag}", (13.0, 13.0, 2.4), (0, 6.5, 9.0), "ochre", g, hi, L(hi, 0.0, 0.08))
    bbox(f"ph_risc_{tag}", (13.6, 0.7, 2.9), (0, 13.2, 9.0), "white", g, hi, L(hi, 0.0, 0.05))
    window(f"ph_door_{tag}", (0, 0.4, 10.22), 3.6, 6.0, g, hi, fill="wood")
    window(f"ph_bigw_{tag}", (0, 7.2, 10.22), 4.2, 4.6, g, hi)
    for s in (-1, 1):
        x = s * 5.2
        bbox(f"ph_tw{s}_{tag}", (2.6, 7.0, 2.6), (x, 13.5 + 3.5, 9.0), "ochre", g, hi, L(hi, 0.0, 0.06))
        window(f"ph_tww{s}_{tag}", (x, 15.0, 10.32), 1.0, 2.2, g, hi)
        belvedere(f"ph_b1{s}_{tag}", x, 20.5, 9.0, 2.6, 3.0, g, hi)
        belvedere(f"ph_b2{s}_{tag}", x, 23.9, 9.0, 1.8, 2.2, g, hi)
        turned(f"ph_tcap{s}_{tag}", [(26.4, 1.0), (27.0, 0.6), (27.2, 0.01)], (x, 0, 9.0), "white", g, hi, L(hi, 8, 16))
        finial(f"ph_fin{s}_{tag}", x, 27.1, 9.0, g, hi)
    # Central dome on a drum.
    turned(f"ph_drum_{tag}", [(11.0, 6.2), (12.6, 6.2), (12.6, 6.6), (12.9, 6.6)], (0, 0, -3.0), "ochre", g, hi,
           L(hi, 16, 48))
    ribbed_dome(f"ph_dome_{tag}", 0, 12.9, -3.0, 6.4, 4.4, "dome_grey", g, hi, 16)
    belvedere(f"ph_lant_{tag}", 0, 17.2, -3.0, 1.6, 1.5, g, hi)
    finial(f"ph_lfin_{tag}", 0, 19.1, -3.0, g, hi, 0.8)
    # Round corner rotunda (front left) with oval windows and a low dome.
    turned(f"ph_rot_{tag}", [(0.0, 5.6), (8.5, 5.6), (8.5, 0.0)], (-19.0, 0, 5.0), "white", g, hi, L(hi, 16, 40))
    turned(f"ph_rotc_{tag}", [(8.5, 5.9), (9.2, 5.9), (9.2, 5.5)], (-19.0, 0, 5.0), "white", g, hi, L(hi, 16, 40))
    for k in range(5):
        a = math.pi * (0.45 + 0.6 * k / 4)  # front round to the left side
        nrm = (math.cos(a), 0, math.sin(a))
        p = (-19.0 + nrm[0] * 5.62, 0.6, 5.0 + nrm[2] * 5.62)
        window(f"ph_rd{k}_{tag}", p, 1.6, 4.4, g, hi, shape="rect", fill="wood", frame="ochre", normal=nrm)
        window(f"ph_ro{k}_{tag}", (p[0], 5.8, p[2]), 1.3, 0.9, g, hi, shape="oval", frame="ochre", normal=nrm)
    ribbed_dome(f"ph_rdome_{tag}", -19.0, 9.2, 5.0, 5.6, 2.6, "bronze", g, hi, 12, "gold")
    turned(f"ph_rlant_{tag}", [(11.6, 1.0), (13.0, 1.0), (13.2, 0.01)], (-19.0, 0, 5.0), "white", g, hi, L(hi, 8, 16))
    # Lower right wing.
    bbox(f"ph_wing_{tag}", (10.0, 8.0, 16.0), (20.0, 4.0, -3.0), "ochre", g, hi, L(hi, 0.0, 0.08))
    bbox(f"ph_wingc_{tag}", (10.6, 0.6, 16.6), (20.0, 8.2, -3.0), "white", g, hi, 0.0)
    row(f"ph_ww_{tag}", 15.5, 24.5, 3, 1.2, 5.02, 1.6, 3.6, g, hi)


def prism(name, x0, x1, profile, mat, g, hi):
    """Prism along x from x0 to x1 with a (z, y) profile (convex)."""
    bm = bmesh.new()
    a = [bm.verts.new((x0, y, z)) for z, y in profile]
    b = [bm.verts.new((x1, y, z)) for z, y in profile]
    n = len(profile)
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((a[i], a[j], b[j], b[i]))
    bm.faces.new(a)
    bm.faces.new(list(reversed(b)))
    return K.finish(bm, name, mat, g, hi, smooth=False)


def build_city_hall(hi):
    tag = "H" if hi else "L"
    g = "city_hall"
    w, h, d = 44.0, 15.0, 18.0
    fz = d * 0.5
    bbox(f"ch_body_{tag}", (w, h, d), (0, h * 0.5, 0), "sand", g, hi, L(hi, 0.0, 0.1))
    bbox(f"ch_rust_{tag}", (w + 0.3, 4.6, d + 0.3), (0, 2.3, 0), "sand_dark", g, hi, L(hi, 0.0, 0.05))
    bbox(f"ch_corn_{tag}", (w + 0.8, 0.8, d + 0.8), (0, h + 0.1, 0), "cream_trim", g, hi, L(hi, 0.0, 0.06))
    bbox(f"ch_mid_{tag}", (w + 0.4, 0.35, d + 0.4), (0, 9.7, 0), "cream_trim", g, hi, 0.0)
    # Windows: ground floor arched, upper floors with red panels between.
    for side in (-1, 1):
        x0, x1 = (-w * 0.5 + 6.0, -5.5) if side < 0 else (5.5, w * 0.5 - 6.0)
        row(f"ch_g{side}_{tag}", x0, x1, 4, 0.8, fz + 0.16, 1.7, 3.2, g, hi, frame="cream_trim")
        row(f"ch_1{side}_{tag}", x0, x1, 4, 5.6, fz + 0.16, 1.6, 3.0, g, hi, shape="rect", frame="cream_trim")
        row(f"ch_2{side}_{tag}", x0, x1, 4, 10.6, fz + 0.16, 1.5, 2.7, g, hi, shape="rect", frame="cream_trim")
        for k in range(5):
            x = x0 + (x1 - x0) * k / 4
            bbox(f"ch_red{side}{k}_{tag}", (2.0, 8.8, 0.1), (x, 9.6, fz + 0.06), "red", g, hi, 0.0)
    # Slate mansard roof and corner pavilions.
    prism(f"ch_roof_{tag}", -w * 0.5 + 6.0, w * 0.5 - 6.0, [(-d * 0.5, h + 0.5), (d * 0.5, h + 0.5), (d * 0.5 - 2.5, h + 4.0),
                                                           (-d * 0.5 + 2.5, h + 4.0)], "slate", g, hi)
    for s in (-1, 1):
        x = s * (w * 0.5 - 3.0)
        bbox(f"ch_pav{s}_{tag}", (6.6, h + 1.5, d + 1.2), (x, (h + 1.5) * 0.5, 0), "sand", g, hi, L(hi, 0.0, 0.08))
        prism(f"ch_pavr{s}_{tag}", x - 3.3, x + 3.3, [(-d * 0.5 - 0.6, h + 1.5), (d * 0.5 + 0.6, h + 1.5),
                                                       (d * 0.5 - 2.0, h + 6.0), (-d * 0.5 + 2.0, h + 6.0)], "slate", g, hi)
        window(f"ch_pw{s}_{tag}", (x, 6.0, fz + 0.76), 2.0, 5.0, g, hi, frame="cream_trim")
    # Clock tower over a tall arch (front centre).
    tz = fz + 1.6
    bbox(f"ch_tbase_{tag}", (10.0, h + 2.0, 4.0), (0, (h + 2.0) * 0.5, tz - 1.0), "sand", g, hi, L(hi, 0.0, 0.08))
    window(f"ch_arch_{tag}", (0, 0.0, tz + 1.02), 5.0, 9.0, g, hi, fill="dark", frame="cream_trim")
    bbox(f"ch_balc_{tag}", (6.0, 0.4, 1.2), (0, 10.4, tz + 1.4), "cream_trim", g, hi, L(hi, 0.0, 0.04))
    window(f"ch_tw_{tag}", (0, 10.8, tz + 1.02), 2.6, 4.2, g, hi, frame="cream_trim")
    bbox(f"ch_shaft_{tag}", (6.4, 6.0, 6.4), (0, h + 2.0 + 3.0, tz - 1.0), "sand", g, hi, L(hi, 0.0, 0.06))
    for k, nrm in enumerate(((0, 0, 1), (1, 0, 0), (-1, 0, 0))):
        c = Vector((0, h + 5.2, tz - 1.0)) + Vector(nrm) * 3.22
        m = facing(nrm, c)
        puffy(f"ch_clk{k}_{tag}", [(math.cos(2 * math.pi * i / L(hi, 12, 24)) * 1.4, math.sin(2 * math.pi * i / L(hi, 12, 24)) * 1.4)
                                   for i in range(L(hi, 12, 24))], 0.12, 0.0, m, "clock", g, hi)
        bbox(f"ch_hand{k}a_{tag}", (0.12, 1.1, 0.05), m @ Vector((0, 0.45, 0.1)), "dark", g, hi, 0.0,
             rot=m.to_3x3().to_euler())
        bbox(f"ch_hand{k}b_{tag}", (0.8, 0.12, 0.05), m @ Vector((0.3, 0, 0.1)), "dark", g, hi, 0.0,
             rot=m.to_3x3().to_euler())
    bbox(f"ch_tcorn_{tag}", (7.2, 0.6, 7.2), (0, h + 8.3, tz - 1.0), "cream_trim", g, hi, L(hi, 0.0, 0.05))
    bbox(f"ch_upper_{tag}", (4.6, 3.6, 4.6), (0, h + 10.4, tz - 1.0), "sand", g, hi, L(hi, 0.0, 0.05))
    for k, nrm in enumerate(((0, 0, 1), (1, 0, 0), (-1, 0, 0), (0, 0, -1))):
        c = Vector((0, h + 9.0, tz - 1.0)) + Vector(nrm) * 2.32
        window(f"ch_uo{k}_{tag}", tuple(c), 1.4, 2.6, g, hi, fill="dark", frame="cream_trim", normal=nrm)
    # Blue bulb cupola, lantern, flag pole.
    prof = [(h + 12.2, 2.6), (h + 13.0, 2.9), (h + 14.2, 2.5), (h + 15.3, 1.4), (h + 15.9, 0.45), (h + 16.2, 0.01)]
    turned(f"ch_cup_{tag}", prof, (0, 0, tz - 1.0), "cupola", g, hi, L(hi, 12, 32))
    turned(f"ch_lan_{tag}", [(h + 15.9, 0.5), (h + 17.0, 0.5), (h + 17.4, 0.01)], (0, 0, tz - 1.0), "cream_trim", g, hi,
           L(hi, 8, 16))
    tube(f"ch_pole_{tag}", [Vector((0, h + 17.2, tz - 1.0)), Vector((0, h + 21.5, tz - 1.0))], 0.07, "dark", g, hi, 1, 6)


def gable(name, x, y, z, w, h, g, hi):
    """Stepped Gothic gable (front +z) with pinnacles at the steps and apex."""
    from mathutils.geometry import tessellate_polygon
    hw = w * 0.5
    pts = [(-hw, 0.0), (hw, 0.0), (hw, h * 0.3), (hw * 0.55, h * 0.45), (hw * 0.55, h * 0.65), (0.0, h),
           (-hw * 0.55, h * 0.65), (-hw * 0.55, h * 0.45), (-hw, h * 0.3)]
    bm = bmesh.new()
    fr = [bm.verts.new((x + px, y + py, z + 0.35)) for px, py in pts]
    bk = [bm.verts.new((x + px, y + py, z - 0.35)) for px, py in pts]
    for tri in tessellate_polygon([[Vector((px, py, 0.0)) for px, py in pts]]):
        bm.faces.new([fr[i] for i in tri])
        bm.faces.new([bk[i] for i in reversed(tri)])
    for i in range(len(pts)):
        j = (i + 1) % len(pts)
        bm.faces.new((fr[j], fr[i], bk[i], bk[j]))
    K.finish(bm, name, "cream", g, hi, smooth=False)
    for k, (px, py) in enumerate(((hw, h * 0.3), (-hw, h * 0.3), (hw * 0.55, h * 0.65), (-hw * 0.55, h * 0.65), (0.0, h))):
        turned(f"{name}_pin{k}", [(y + py, 0.32), (y + py + 0.5, 0.32), (y + py + 2.4, 0.01)], (x + px, 0, z),
               "cream_trim", g, hi, L(hi, 4, 8))
    window(f"{name}_rose", (x, y + h * 0.28, z + 0.36), 1.6, 1.6, g, hi, shape="oval", frame="cream_trim")


def build_ismailiyya(hi):
    tag = "H" if hi else "L"
    g = "ismailiyya"
    w, h, d = 30.0, 16.0, 14.0
    fz = d * 0.5
    bbox(f"is_body_{tag}", (w, h, d), (0, h * 0.5, 0), "cream", g, hi, L(hi, 0.0, 0.1))
    bbox(f"is_plinth_{tag}", (w + 0.3, 0.9, d + 0.3), (0, 0.45, 0), "sand_dark", g, hi, 0.0)
    bbox(f"is_band_{tag}", (w + 0.3, 0.4, d + 0.3), (0, 6.0, 0), "cream_trim", g, hi, 0.0)
    bbox(f"is_corn_{tag}", (w + 0.6, 0.6, d + 0.6), (0, h, 0), "cream_trim", g, hi, L(hi, 0.0, 0.05))
    # Ground floor round arches, lancets above, rose windows over them.
    row(f"is_g_{tag}", -w * 0.5, -2.5, 3, 1.0, fz + 0.12, 2.3, 4.2, g, hi, frame="cream_trim")
    row(f"is_g2_{tag}", 2.5, w * 0.5, 3, 1.0, fz + 0.12, 2.3, 4.2, g, hi, frame="cream_trim")
    window(f"is_door_{tag}", (0, 0.9, fz + 0.12), 2.8, 4.8, g, hi, fill="wood", frame="cream_trim")
    row(f"is_l_{tag}", -w * 0.5 + 0.5, w * 0.5 - 0.5, 9, 6.8, fz + 0.12, 1.5, 4.6, g, hi, shape="lancet",
        frame="cream_trim")
    row(f"is_r_{tag}", -w * 0.5 + 0.5, w * 0.5 - 0.5, 9, 12.4, fz + 0.12, 1.3, 1.3, g, hi, shape="oval",
        frame="cream_trim")
    # Crest of small pinnacles.
    n = L(hi, 10, 20)
    for k in range(n):
        x = -w * 0.5 + 1.0 + (w - 2.0) * k / (n - 1)
        turned(f"is_cr{k}_{tag}", [(h + 0.3, 0.22), (h + 0.8, 0.22), (h + 1.9, 0.01)], (x, 0, fz - 0.1), "cream_trim",
               g, hi, 4)
    # Corner risalits with stepped gables.
    for s in (-1, 1):
        x = s * (w * 0.5 + 3.0)
        bbox(f"is_ris{s}_{tag}", (7.0, h + 2.5, d + 1.6), (x, (h + 2.5) * 0.5, 0), "cream", g, hi, L(hi, 0.0, 0.08))
        bbox(f"is_risb{s}_{tag}", (7.3, 0.4, d + 1.9), (x, 6.0, 0), "cream_trim", g, hi, 0.0)
        window(f"is_rg{s}_{tag}", (x, 1.0, fz + 0.92), 3.0, 4.4, g, hi, frame="cream_trim")
        window(f"is_rl{s}_{tag}", (x, 7.0, fz + 0.92), 2.2, 6.0, g, hi, shape="lancet", frame="cream_trim")
        window(f"is_rr{s}_{tag}", (x, 14.2, fz + 0.92), 1.6, 1.6, g, hi, shape="oval", frame="cream_trim")
        gable(f"is_gab{s}_{tag}", x, h + 2.5, fz + 0.5, 7.0, 5.0, g, hi)
        turned(f"is_tur{s}_{tag}", [(0.0, 0.55), (h + 4.0, 0.55), (h + 6.5, 0.01)], (x + s * 3.5, 0, fz + 0.8),
               "cream_trim", g, hi, L(hi, 6, 12))


def build_fountain_tiered(hi):
    tag = "H" if hi else "L"
    g = "fountain_tiered"
    st = L(hi, 20, 48)
    turned(f"ft_rim_{tag}", [(0.0, 7.4), (0.55, 7.4), (0.55, 6.8), (0.2, 6.8)], (0, 0, 0), "sand", g, hi, st)
    turned(f"ft_water_{tag}", [(0.2, 6.85), (0.36, 6.85), (0.36, 0.01)], (0, 0, 0), "water", g, hi, st)
    y = 0.3
    r = 5.0
    k = 0
    while r > 0.8:
        turned(f"ft_t{k}_{tag}", [(y, r), (y + 0.38, r), (y + 0.38, 0.01)], (0, 0, 0), "sand" if k % 2 else "sand_dark",
               g, hi, st)
        y += 0.38
        r -= 0.62
        k += 1
    turned(f"ft_jet_{tag}", [(y, 0.25), (y + 0.9, 0.12), (y + 1.4, 0.01)], (0, 0, 0), "spray", g, hi, L(hi, 8, 16))
    for i in range(8):
        a = 2 * math.pi * i / 8
        turned(f"ft_sj{i}_{tag}", [(0.35, 0.12), (1.0, 0.06), (1.3, 0.01)], (math.cos(a) * 5.8, 0, math.sin(a) * 5.8),
               "spray", g, hi, 6)


def build_fountain_spheres(hi):
    tag = "H" if hi else "L"
    g = "fountain_spheres"
    bbox(f"fs_rim_{tag}", (12.0, 0.6, 12.0), (0, 0.3, 0), "sand", g, hi, L(hi, 0.0, 0.06))
    bbox(f"fs_water_{tag}", (11.0, 0.1, 11.0), (0, 0.62, 0), "water", g, hi, 0.0)
    turned(f"fs_ped_{tag}", [(0.6, 2.6), (1.2, 2.4), (1.8, 2.8), (2.1, 2.8), (2.1, 0.01)], (0, 0, 0), "sand_dark", g, hi,
           8)
    for k, x in enumerate((-1.9, 0.0, 1.9)):
        ellipsoid(f"fs_ball{k}_{tag}", (1.15, 1.15, 1.15), (x, 3.2, 0.0), "steel", g, hi, L(hi, (14, 10), (36, 22)))
    for i in range(12):
        a = 2 * math.pi * i / 12
        turned(f"fs_j{i}_{tag}", [(0.65, 0.1), (1.6, 0.05), (2.0, 0.01)], (math.cos(a) * 4.3, 0, math.sin(a) * 4.3),
               "spray", g, hi, 6)


def build_fountain_plaza(hi):
    tag = "H" if hi else "L"
    g = "fountain_plaza"
    w, d = 56.0, 40.0
    bbox(f"fp_slab_{tag}", (w, 0.12, d), (0, 0.06, 0), "paving", g, hi, 0.0)
    if hi:
        # White wave bands across the grey paving (the square's pattern).
        for k in range(9):
            z0 = -d * 0.5 + 2.5 + k * 4.4
            pts = [Vector((-w * 0.5 + 0.5 + i * (w - 1.0) / 24, 0.13, z0 + 1.2 * math.sin(i / 24 * math.pi * 4 + k)))
                   for i in range(25)]
            tube(f"fp_wave{k}", pts, 0.28, "paving_white", g, hi, 2, 4, False)
        for k in range(4):
            bbox(f"fp_edge{k}", (w if k < 2 else 0.6, 0.06, 0.6 if k < 2 else d),
                 (0 if k < 2 else (k * 2 - 5) * (w * 0.5 - 0.3), 0.13, (k * 2 - 1) * (d * 0.5 - 0.3) if k < 2 else 0),
                 "paving_white", g, hi, 0.0)


OFFSET = {g: Vector((i * 90.0, 0.0, 0.0)) for i, g in enumerate(GROUPS)}


def _built(fn, g):
    before = set(K.COLL.objects)
    fn()
    for o in set(K.COLL.objects) - before:
        o.data.transform(Matrix.Translation(OFFSET[g]))


def build(hi):
    _built(lambda: build_philharmonic(hi), "philharmonic")
    _built(lambda: build_city_hall(hi), "city_hall")
    _built(lambda: build_ismailiyya(hi), "ismailiyya")
    _built(lambda: build_fountain_tiered(hi), "fountain_tiered")
    _built(lambda: build_fountain_spheres(hi), "fountain_spheres")
    _built(lambda: build_fountain_plaza(hi), "fountain_plaza")


def _home(groups):
    for o in groups:
        o.data.transform(Matrix.Translation(-OFFSET[o.name]))


K.PRE_EXPORT.append(_home)

K.setup("center_props", "assets/models/center", PALETTE, PAINT_MAT, GROUPS, UV_SCALE, FAR_RATIO, stone_mats=STONE)
K.run(build)
