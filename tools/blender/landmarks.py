"""Baku landmarks for Yaska Racing (0.14.4 Blender models): government_house
(Hökumət Evi), carpet_museum (Xalça Muzeyi), crystal_hall, tv_tower,
crescent. Same local frames, sizes and origins as LandmarkKit / BakuExtras so
LANDMARK_SITES / EXTRA_SITES stay valid (front +Z, origin on the ground).

  blender --background --factory-startup --python tools/blender/landmarks.py -- --bake-res 4096 --tex-res 2048
Heydar Aliyev Center (smooth self-lit white shell) and the Flame Towers (LED
glass shader) stay LandmarkKit meshes; Flag Square keeps its waving flag.
orm alpha = glass (windows / Crystal Hall glow at night), albedo alpha = sandstone.
"""

import math
import os
import sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from kart_common import *  # noqa: F401,F403
import kart_common as K
from mathutils import Vector, Matrix, Euler, Quaternion

PALETTE = {
    "sand": ("D8C39A", 0.85, 0.0), "sand_light": ("EADCB8", 0.8, 0.0), "sand_shade": ("B49A70", 0.85, 0.0),
    "window_dark": ("2E3440", 0.15, 0.2), "glass": ("2F5F86", 0.08, 0.3), "glass_blue": ("3D7FC4", 0.08, 0.6),
    "steel": ("9AA0A8", 0.35, 0.8), "white": ("F4F2EC", 0.55, 0.0), "tv_red": ("D7263D", 0.5, 0.0),
    "concrete": ("C9C4BA", 0.85, 0.0), "limestone": ("D9C29A", 0.85, 0.0), "gold": ("E8B84A", 0.3, 1.0),
    "carpet_red": ("B3263A", 0.8, 0.0), "carpet_navy": ("23325E", 0.8, 0.0), "carpet_cream": ("F0DDB8", 0.8, 0.0),
    "carpet_gold": ("E0A33A", 0.8, 0.0), "carpet_green": ("2F7A5A", 0.8, 0.0), "flag_blue": ("00B5E2", 0.6, 0.0),
    "flag_red": ("EF3340", 0.6, 0.0), "flag_green": ("509E2F", 0.6, 0.0),
}
PAINT_MAT = ["glass", "glass_blue"]
STONE = ["sand", "sand_shade", "limestone"]
GROUPS = ["government_house", "carpet_museum", "crystal_hall", "tv_tower", "crescent"]
UV_SCALE = {"government_house": 1.0, "carpet_museum": 1.1, "crystal_hall": 0.8, "tv_tower": 0.7, "crescent": 0.7}
FAR_RATIO = {g: 0.4 for g in GROUPS}
UP = Matrix.Rotation(math.pi / 2, 4, "Z")  # lathe axis X -> Y


def turned(name, profile, base, mat, g, hi, steps):
    ob = lathe(name, profile, (0, 0, 0), mat, g, hi, steps)
    ob.data.transform(Matrix.Translation(Vector(base)) @ UP)
    return ob


def pointed_arch(w, h, n):
    """Outline of a pointed (Islamic) arch, base at y=0."""
    hw = w * 0.5
    spring = h - w * 0.75
    pts = [(-hw, 0.0), (hw, 0.0), (hw, spring)]
    for k in range(1, n):
        t = k / n
        pts.append((hw * (1 - t) ** 0.8, spring + (h - spring) * math.sin(t * math.pi / 2)))
    pts.append((0.0, h))
    for k in range(n - 1, 0, -1):
        t = k / n
        pts.append((-hw * (1 - t) ** 0.8, spring + (h - spring) * math.sin(t * math.pi / 2)))
    pts.append((-hw, spring))
    return pts


def recess(name, x, y, z, w, h, fill, g, hi, normal=(0, 0, 1), frame="sand_light"):
    """Pointed opening: dark panel flush on the wall; high model adds a frame."""
    n = Vector(normal)
    up = Vector((0, 1, 0))
    side = up.cross(n).normalized()
    m = Matrix((side, up, n)).transposed().to_4x4()
    m.translation = Vector((x, y, z)) + n * 0.05
    puffy(f"{name}_{'H' if hi else 'L'}", pointed_arch(w, h, L(hi, 3, 10)), 0.02, 0.0, m, fill, g, hi)
    if hi:
        ring = pointed_arch(w + 0.6, h + 0.4, 10)
        path = [m @ Vector((px, py, 0.08)) for px, py in ring[2:] + ring[:1]]
        tube(f"{name}_fr", path, 0.14, frame, g, True, 1, 4, False)


def build_government_house(hi):
    tag = "H" if hi else "L"
    g = "government_house"
    Lm, D, H = 176.0, 28.0, 31.0
    fz = D * 0.5
    bbox(f"gh_body_{tag}", (Lm, H, D), (0, H * 0.5, 0), "sand", g, hi, L(hi, 0.0, 0.3))
    bbox(f"gh_cornice_{tag}", (Lm + 1.6, 1.4, D + 1.6), (0, H + 0.2, 0), "sand_light", g, hi, L(hi, 0.0, 0.3))
    bbox(f"gh_plinth_{tag}", (Lm + 2.0, 2.2, D + 2.0), (0, 1.1, 0), "sand_shade", g, hi, L(hi, 0.0, 0.2))
    bbox(f"gh_band_{tag}", (Lm + 0.6, 0.8, D + 0.6), (0, 12.6, 0), "sand_light", g, hi, L(hi, 0.0, 0.15))
    # Ground-floor pointed arcade and tall double-height windows above.
    arc_w = 4.6
    nar = int((Lm - 64.0) / arc_w)
    for k in range(nar):
        x = (k - (nar - 1) * 0.5) * arc_w
        if abs(x) < 23.0:
            continue
        recess(f"gh_arc{k}", x, 2.2, fz, 3.2, 9.6, "window_dark", g, hi)
        recess(f"gh_win{k}", x, 14.0, fz, 2.2, 7.5, "glass", g, hi)
        recess(f"gh_top{k}", x, 23.5, fz, 1.8, 5.0, "glass", g, hi)
        if hi:
            bbox(f"gh_pil{k}", (0.6, H - 14.0, 0.25), (x + arc_w * 0.5, 13.0 + (H - 14.0) * 0.5, fz + 0.12), "sand_light",
                 g, True, 0.05)
    # 0.15.3 (from photos): square towers with two storeys of tall arched
    # loggias, a toothed parapet and needle pinnacles - corner towers on the
    # projecting wings, the tallest in the centre, small ones in between. The
    # whole roof edge carries the same small teeth.
    def teeth(name, x0, x1, y, z, step=2.4):
        n = max(int((x1 - x0) / step), 1)
        for k in range(n + 1):
            bbox(f"{name}{k}_{tag}", (0.7, 1.2, 0.5), (x0 + k * (x1 - x0) / n, y + 0.6, z), "sand_light", g, hi, 0.0)

    def needle(name, x, y, z, hgt):
        turned(f"{name}_{tag}", [(0.0, 0.45), (0.6, 0.45), (0.8, 0.3), (hgt, 0.04), (hgt, 0.0)], (x, y, z), "sand_light",
               g, hi, L(hi, 6, 12))
        ellipsoid(f"{name}b_{tag}", (0.28, 0.28, 0.28), (x, y + hgt * 0.45, z), "sand_light", g, hi, L(hi, (6, 4), (10, 6)))

    def tower(name, cx, cz, w, d, y0, levels, lh, arches, needles_h):
        y = y0
        for lv in range(levels):
            bbox(f"{name}_lv{lv}_{tag}", (w, lh, d), (cx, y + lh * 0.5, cz), "sand", g, hi, L(hi, 0.0, 0.2))
            for s in (-1, 1):
                for k in range(arches):
                    xx = cx + (k - (arches - 1) * 0.5) * (w / arches)
                    recess(f"{name}_a{lv}{k}{s}", xx, y + 0.8, cz + s * d * 0.5, w / arches * 0.55, lh - 1.6,
                           "window_dark", g, hi, normal=(0, 0, s))
                for k in range(max(arches - 1, 1)):
                    zz = cz + (k - (max(arches - 1, 1) - 1) * 0.5) * (d / max(arches - 1, 1))
                    recess(f"{name}_s{lv}{k}{s}", cx + s * w * 0.5, y + 0.8, zz, d / max(arches - 1, 1) * 0.5, lh - 1.6,
                           "window_dark", g, hi, normal=(s, 0, 0))
            bbox(f"{name}_cor{lv}_{tag}", (w + 0.8, 0.5, d + 0.8), (cx, y + lh, cz), "sand_light", g, hi, L(hi, 0.0, 0.1))
            y += lh
        for s in (-1, 1):
            teeth(f"{name}_tf{s}", cx - w * 0.5, cx + w * 0.5, y + 0.25, cz + s * d * 0.5)
            nz = max(int(d / 2.4), 1)
            for k in range(nz + 1):
                bbox(f"{name}_ts{s}{k}_{tag}", (0.5, 1.2, 0.7), (cx + s * w * 0.5, y + 0.85, cz - d * 0.5 + k * d / nz),
                     "sand_light", g, hi, 0.0)
        for sx in (-1, 1):
            for sz in (-1, 1):
                needle(f"{name}_n{sx}{sz}", cx + sx * w * 0.5, y + 0.3, cz + sz * d * 0.5, needles_h)
        needle(f"{name}_nc", cx, y + 0.3, cz + d * 0.5, needles_h * 1.25)
        return y

    # Roof-edge teeth along the main body.
    for s in (-1, 1):
        teeth(f"gh_roof{s}", -Lm * 0.5, Lm * 0.5, H + 0.9, s * fz)
    # Wings: corner towers (project forward).
    for s in (-1, 1):
        wx = s * (Lm * 0.5 - 12.0)
        bbox(f"gh_wing{s}_{tag}", (24.0, H, 10.0), (wx, H * 0.5, fz + 5.0), "sand", g, hi, L(hi, 0.0, 0.3))
        for k in range(4):
            recess(f"gh_wwin{s}{k}", wx - 7.5 + k * 5.0, 3.0, fz + 10.0, 2.6, 8.0, "window_dark", g, hi)
            recess(f"gh_wwin2{s}{k}", wx - 7.5 + k * 5.0, 15.0, fz + 10.0, 2.2, 9.0, "glass", g, hi)
        tower(f"gh_ct{s}", wx, fz + 2.0, 22.0, 14.0, H, 2, 8.0, 3, 5.0)
        # Small towers between the corners and the centre.
        tower(f"gh_mt{s}", s * Lm * 0.26, 0.0, 12.0, 10.0, H, 1, 7.0, 2, 3.5)
    # Centre: projecting block, giant portal between paired columns, main tower.
    bbox(f"gh_centre_{tag}", (46.0, H + 4.0, 6.0), (0, (H + 4.0) * 0.5, fz + 3.0), "sand", g, hi, L(hi, 0.0, 0.3))
    recess("gh_portal", 0.0, 2.2, fz + 6.0, 12.0, 24.0, "window_dark", g, hi)
    for s in (-1, 1):
        for c in (8.5, 10.5):
            turned(f"gh_col{s}{c}_{tag}", [(0.0, 0.9), (0.6, 0.75), (24.0, 0.7), (24.6, 0.95)], (s * c, 2.2, fz + 6.8),
                   "sand_light", g, hi, L(hi, 6, 16))
        for k in range(3):
            recess(f"gh_cwin{s}{k}", s * (14.0 + k * 3.6), 14.0, fz + 6.0, 2.0, 7.0, "glass", g, hi)
    tower("gh_main", 0.0, 2.0, 26.0, 20.0, H + 4.0, 2, 10.0, 3, 6.0)


def build_carpet_museum(hi):
    tag = "H" if hi else "L"
    g = "carpet_museum"
    W = 18.0
    # A carpet lying on the ground that rolls up at the +x end (rolled carpet).
    def profile(t):
        if t < 0.55:
            # Lying part rises gently into the roll.
            k = t / 0.55
            return Vector((-40.0 + k * 62.0, 3.6 + 2.4 * k * k))
        a = (t - 0.55) / 0.45 * 1.3 * math.pi
        rr = 6.0 - (t - 0.55) / 0.45 * 1.2
        return Vector((22.0 + rr * math.sin(a), 12.0 - rr * math.cos(a)))
    n = L(hi, 28, 120)
    bm = bmesh.new()
    top, bot = [], []
    for i in range(n + 1):
        p = profile(i / n)
        top.append([bm.verts.new((p.x, p.y, z)) for z in (-W / 2, W / 2)])
        bot.append([bm.verts.new((p.x, p.y - 0.6, z)) for z in (-W / 2, W / 2)])
    for i in range(n):
        bm.faces.new((top[i][0], top[i][1], top[i + 1][1], top[i + 1][0]))
        bm.faces.new((bot[i][1], bot[i][0], bot[i + 1][0], bot[i + 1][1]))
        for s in (0, 1):
            q = (top[i][s], top[i + 1][s], bot[i + 1][s], bot[i][s])
            bm.faces.new(q if s == 0 else tuple(reversed(q)))
    carpet = K.finish(bm, f"cm_carpet_{tag}", "carpet_red", g, hi, smooth=True)
    bbox(f"cm_hall_{tag}", (36.0, 3.4, W - 2.0), (-14.0, 1.7, 0), "glass", g, hi, L(hi, 0.0, 0.2))
    bbox(f"cm_hall2_{tag}", (12.0, 5.6, W - 2.0), (15.0, 2.8, 0), "glass", g, hi, L(hi, 0.0, 0.2))
    for s in (-1, 1):
        turned(f"cm_cap{s}_{tag}", [(0.0, 6.2), (0.4, 6.2), (0.4, 0.0)], (0, 0, 0), "carpet_navy", g, hi, L(hi, 16, 48)
               ).data.transform(Matrix.Translation(Vector((22.0, 12.0, s * (W * 0.5 - 0.2)))) @ Matrix.Rotation(math.pi / 2, 4, "X") @ UP.inverted())
    bbox(f"cm_plaza_{tag}", (80.0, 0.4, W + 12.0), (-4.0, 0.2, 2.0), "limestone", g, hi, L(hi, 0.0, 0.1))
    if hi:
        # Carpet ornament on the top surface: borders, medallions, diamonds.
        for z in (-W / 2 + 1.0, W / 2 - 1.0):
            for x0 in range(-40, 12, 4):
                decal(f"cm_border{z}{x0}", [(-2.0, -0.45), (2.0, -0.45), (2.0, 0.45), (-2.0, 0.45)],
                      facing((x0 + 2.0, 6.0, z), (0, 1, 0), up=(1, 0, 0)), "carpet_navy", g, carpet, 0.01, 2)
                decal(f"cm_bd{z}{x0}", [(-0.5, 0), (0, 0.35), (0.5, 0), (0, -0.35)],
                      facing((x0 + 2.0, 6.0, z), (0, 1, 0), up=(1, 0, 0)), "carpet_gold", g, carpet, 0.02, 1)
        for i, x in enumerate((-30.0, -15.0, 0.0)):
            decal(f"cm_med{i}", [(math.cos(a) * 5.5 * (1 if k % 2 else 0.7), math.sin(a) * 5.5 * (1 if k % 2 else 0.7))
                                 for k, a in enumerate([2 * math.pi * j / 16 for j in range(16)])],
                  facing((x, 6.0, 0), (0, 1, 0), up=(1, 0, 0)), "carpet_navy", g, carpet, 0.01, 3)
            decal(f"cm_medin{i}", circle_outline(3.0, 3.0, 20), facing((x, 6.0, 0), (0, 1, 0), up=(1, 0, 0)),
                  "carpet_cream", g, carpet, 0.02, 2)
            decal(f"cm_medc{i}", [(-1.6, 0), (0, 1.6), (1.6, 0), (0, -1.6)], facing((x, 6.0, 0), (0, 1, 0), up=(1, 0, 0)),
                  "carpet_green", g, carpet, 0.03, 1)
        for i in range(10):
            x = -38.0 + i * 5.0
            for z in (-4.5, 4.5):
                decal(f"cm_dia{i}{z}", [(-0.9, 0), (0, 0.9), (0.9, 0), (0, -0.9)],
                      facing((x, 6.0, z), (0, 1, 0), up=(1, 0, 0)), "carpet_gold", g, carpet, 0.015, 1)
        # Mullions on the glass halls.
        for k in range(18):
            x = -31.5 + k * 2.0
            bbox(f"cm_mull{k}", (0.12, 6.0, 0.1), (x, 3.0, (W - 2.0) * 0.5 + 0.03), "steel", g, True, 0.0)


def build_crystal_hall(hi):
    tag = "H" if hi else "L"
    g = "crystal_hall"
    turned(f"ch_podium_{tag}", [(0.0, 44.0), (3.0, 44.0), (3.0, 0.0)], (0, 0, 0), "concrete", g, hi, L(hi, 24, 72))
    n = 18
    r0, r1 = 38.0, 30.0
    bm = bmesh.new()
    ring_b, ring_t = [], []
    for i in range(n):
        a = 2 * math.pi * i / n
        h = 20.0 + 5.0 * (i % 3)
        ring_b.append(bm.verts.new((math.cos(a) * r0, 3.0, math.sin(a) * r0)))
        ring_t.append(bm.verts.new((math.cos(a) * r1, 3.0 + h, math.sin(a) * r1)))
    centre = bm.verts.new((0, 30.0, 0))
    for i in range(n):
        j = (i + 1) % n
        a = 2 * math.pi * (i + 0.5) / n
        mid = bm.verts.new(((ring_b[i].co + ring_b[j].co + ring_t[i].co + ring_t[j].co) * 0.25
                            + Vector((math.cos(a), 0, math.sin(a))) * 2.5))
        for tri in ((ring_b[i], mid, ring_b[j]), (ring_b[i], ring_t[i], mid), (ring_t[i], ring_t[j], mid),
                    (ring_b[j], mid, ring_t[j])):
            bm.faces.new(tri)
        bm.faces.new((ring_t[i], centre, ring_t[j]))
    K.finish(bm, f"ch_shell_{tag}", "glass_blue", g, hi, outward=lambda p: Vector((p.x, p.y - 8.0, p.z)), smooth=False)
    if hi:
        for i in range(n):
            j = (i + 1) % n
            a = 2 * math.pi * i / n
            h = 20.0 + 5.0 * (i % 3)
            b = Vector((math.cos(a) * r0, 3.0, math.sin(a) * r0))
            t = Vector((math.cos(a) * r1, 3.0 + h, math.sin(a) * r1))
            tube(f"ch_edge{i}", [b, t], 0.25, "steel", g, True, 1, 6, False)
            for k in range(1, 6):
                y = 3.0 + h * k / 6
                p0 = b.lerp(t, k / 6)
                a1 = 2 * math.pi * j / n
                h1 = 20.0 + 5.0 * (j % 3)
                q0 = Vector((math.cos(a1) * r0, 3.0, math.sin(a1) * r0)).lerp(
                    Vector((math.cos(a1) * r1, 3.0 + h1, math.sin(a1) * r1)), k / 6)
                tube(f"ch_band{i}{k}", [p0 + (p0 - Vector((0, p0.y, 0))).normalized() * 0.4,
                                        q0 + (q0 - Vector((0, q0.y, 0))).normalized() * 0.4], 0.12, "steel", g, True,
                     1, 4, False)


def build_tv_tower(hi):
    tag = "H" if hi else "L"
    g = "tv_tower"
    st = L(hi, 10, 32)
    turned(f"tv_base_{tag}", [(0.0, 9.0), (8.0, 6.0)], (0, 0, 0), "white", g, hi, st)
    turned(f"tv_shaft_{tag}", [(0.0, 5.2), (100.0, 2.6)], (0, 8.0, 0), "white", g, hi, st)
    turned(f"tv_pod_low_{tag}", [(0.0, 3.0), (5.0, 9.5)], (0, 101.5, 0), "white", g, hi, st)
    turned(f"tv_pod_glass_{tag}", [(0.0, 9.0), (4.5, 9.0)], (0, 106.5, 0), "glass", g, hi, st)
    turned(f"tv_pod_top_{tag}", [(0.0, 9.8), (4.0, 4.0)], (0, 111.0, 0), "white", g, hi, st)
    turned(f"tv_neck_{tag}", [(0.0, 2.2), (8.0, 2.2)], (0, 115.0, 0), "white", g, hi, L(hi, 8, 24))
    for i in range(8):
        turned(f"tv_ant{i}_{tag}", [(0.0, 1.4 - i * 0.12), (5.0, 1.3 - i * 0.12)], (0, 123.0 + i * 5.0, 0),
               "tv_red" if i % 2 == 0 else "white", g, hi, L(hi, 6, 16))
    if hi:
        for k in range(6):
            a = 2 * math.pi * k / 6
            tube(f"tv_rib{k}", [(math.cos(a) * 5.3, 8.0, math.sin(a) * 5.3), (math.cos(a) * 2.7, 107.0, math.sin(a) * 2.7)],
                 0.25, "white", g, True, 4, 6, False)
        for k in range(24):
            a = 2 * math.pi * k / 24
            bbox(f"tv_podmull{k}", (0.15, 4.5, 0.15), (math.cos(a) * 9.05, 108.75, math.sin(a) * 9.05), "steel", g, True,
                 0.0)


def _arc(c, rad, a0, a1, toward, n):
    """Arc of the circle (c, rad) from angle a0 to a1, going the way whose
    middle points to the angle `toward`."""
    da = (a1 - a0) % (2 * math.pi)
    ccw_mid = a0 + da * 0.5
    cw_mid = ccw_mid + math.pi
    def gap(a):
        return abs((a - toward + math.pi) % (2 * math.pi) - math.pi)
    if gap(ccw_mid) > gap(cw_mid):
        da = da - 2 * math.pi
    return [c + Vector((math.cos(a0 + da * k / n), math.sin(a0 + da * k / n))) * rad for k in range(n + 1)]


def build_crescent(hi):
    """Crescent moon standing on its outer rim (LandmarkKit._crescent frame):
    outer circle R 46 touching y = 0, inner circle r 39 cut out up-left."""
    tag = "H" if hi else "L"
    g = "crescent"
    R, r = 46.0, 39.0
    oc, ic = Vector((0.0, R)), Vector((-15.0, R + 12.0))
    d = (ic - oc).length
    a = (R * R - r * r + d * d) / (2 * d)
    h = math.sqrt(max(R * R - a * a, 0.0))
    dvec = (ic - oc) / d
    mid = oc + dvec * a
    perp = Vector((-dvec.y, dvec.x))
    t1, t2 = mid + perp * h, mid - perp * h
    n = L(hi, 18, 64)
    away = math.atan2((oc - ic).y, (oc - ic).x)
    outer = _arc(oc, R, math.atan2((t1 - oc).y, (t1 - oc).x), math.atan2((t2 - oc).y, (t2 - oc).x), away, n)
    inner = _arc(ic, r, math.atan2((t2 - ic).y, (t2 - ic).x), math.atan2((t1 - ic).y, (t1 - ic).x), away, n)
    outline = [(p.x, p.y) for p in outer] + [(p.x, p.y) for p in inner[1:-1]]
    bm = bmesh.new()
    fr = [bm.verts.new((x, y, 8.0)) for x, y in outline]
    bk = [bm.verts.new((x, y, -8.0)) for x, y in outline]
    f1 = bm.faces.new(fr)
    f2 = bm.faces.new(list(reversed(bk)))
    bmesh.ops.triangulate(bm, faces=[f1, f2])
    m = len(outline)
    for i in range(m):
        j = (i + 1) % m
        bm.faces.new((fr[j], fr[i], bk[i], bk[j]))
    K.finish(bm, f"cr_body_{tag}", "glass_blue", g, hi, smooth=False)
    turned(f"cr_base_{tag}", [(-3.5, 41.0), (0.0, 41.0), (0.0, 0.0)], (0, 0, 0), "white", g, hi, L(hi, 24, 64))
    if hi:
        poly = outline
        for k in range(1, 26):
            y = k * 3.6
            xs = []
            for i in range(len(poly)):
                (x0, y0), (x1, y1) = poly[i], poly[(i + 1) % len(poly)]
                if (y0 - y) * (y1 - y) < 0:
                    xs.append(x0 + (y - y0) / (y1 - y0) * (x1 - x0))
            xs.sort()
            for q in range(0, len(xs) - 1, 2):
                for sgn in (-1, 1):
                    tube(f"cr_floor{k}_{q}{sgn}", [(xs[q], y, sgn * 8.05), (xs[q + 1], y, sgn * 8.05)], 0.1, "white", g,
                         True, 1, 4, False)


BUILDERS = {"government_house": build_government_house, "carpet_museum": build_carpet_museum,
            "crystal_hall": build_crystal_hall, "tv_tower": build_tv_tower, "crescent": build_crescent}
OFFSET = {g: Vector((i * 260.0, 0.0, 0.0)) for i, g in enumerate(GROUPS)}


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
K.CAGE, K.RAY, K.AO_DIST = 0.35, 0.7, 3.0
K.setup("landmarks", "assets/models/landmarks", PALETTE, PAINT_MAT, GROUPS, UV_SCALE, FAR_RATIO, stone_mats=STONE)
K.run(build)
