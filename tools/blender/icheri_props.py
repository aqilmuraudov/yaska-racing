"""İçərişəhər landmarks for Yaska Racing (0.17.0, owner: "mini Baku", from
photos on Wikimedia Commons):

  blender --background --factory-startup --python tools/blender/icheri_props.py -- --bake-res 4096 --tex-res 2048
One shared 2048² set in assets/models/icheri/. Front = +Z, origin on the
ground in the middle of the footprint. Heights are game-fitted.
  shirvanshah   Palace of the Shirvanshahs on its terrace: two-storey palace
                block, the Shah mosque with the big stone dome (geometric star
                net) and the slender minaret (stalactite corbel, iron railing,
                upper drum, ribbed cap), the octagonal Divankhana with its
                carved portal, the domed mausoleum and the low bath domes
  juma_mosque   Juma Mosque: plain coursed hall, tall pointed portal, two rows
                of pointed windows, and the round minaret with a deep
                stalactite corbel under a pierced lattice parapet, upper drum
                and ribbed melon cap
  siniqqala     Muhammad Mosque (Sınıqqala, 1078): small hall with a toothed
                parapet and a pointed door, the tall plain round minaret with
                a stalactite band, lattice parapet and a short upper drum
  caravanserai  Multani / Bukhara caravanserai: low square of coursed stone
                round a courtyard (pointed cells inside), a tall pointed
                portal (pishtaq) with a wooden gate
orm alpha = glass / lit openings, albedo alpha = stone (world-space limestone
detail in prop_baked.gdshader).
"""

import math
import os
import sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from kart_common import *  # noqa: F401,F403
import kart_common as K
from mathutils import Vector, Matrix

PALETTE = {
    "limestone": ("D6BE94", 0.85, 0.0),
    "limestone_warm": ("D9B386", 0.85, 0.0),
    "stone_dark": ("A88E68", 0.9, 0.0),
    "trim": ("E6CFA4", 0.8, 0.0),
    "carved": ("C2A57A", 0.85, 0.0),
    "dome": ("CDB894", 0.8, 0.0),
    "wood": ("6E3A22", 0.6, 0.0),
    "iron": ("2E2B36", 0.5, 0.6),
    "slit": ("1E2A3A", 0.8, 0.0),
    "glass": ("2F5F86", 0.08, 0.3),
    "shadow": ("4A3C2E", 0.9, 0.0),
}
PAINT_MAT = ["glass"]
STONE = ["limestone", "limestone_warm", "stone_dark", "trim", "carved", "dome"]
GROUPS = ["shirvanshah", "juma_mosque", "siniqqala", "caravanserai"]
UV_SCALE = {g: 1.0 for g in GROUPS}
FAR_RATIO = {"shirvanshah": 0.35, "juma_mosque": 0.4, "siniqqala": 0.4, "caravanserai": 0.45}
UP = Matrix.Rotation(math.pi / 2, 4, "Z")  # lathe axis X -> Y
_bumped = False


def add_bump():
    """Coursed blocks with mortar grooves (Voronoi distance-to-edge), baked
    into the normal map."""
    for name in STONE:
        nt = K.MATS[name].node_tree
        bsdf = nt.nodes["Principled BSDF"]
        tc = nt.nodes.new("ShaderNodeTexCoord")
        mp = nt.nodes.new("ShaderNodeMapping")
        mp.inputs["Scale"].default_value = (1 / 1.0, 1 / 0.45, 1 / 1.0)
        vo = nt.nodes.new("ShaderNodeTexVoronoi")
        vo.feature = "DISTANCE_TO_EDGE"
        mr = nt.nodes.new("ShaderNodeMapRange")
        mr.inputs["From Max"].default_value = 0.07
        bump = nt.nodes.new("ShaderNodeBump")
        bump.inputs["Strength"].default_value = 0.7
        bump.inputs["Distance"].default_value = 0.035
        nt.links.new(tc.outputs["Object"], mp.inputs["Vector"])
        nt.links.new(mp.outputs["Vector"], vo.inputs["Vector"])
        nt.links.new(vo.outputs["Distance"], mr.inputs["Value"])
        nt.links.new(mr.outputs["Result"], bump.inputs["Height"])
        nt.links.new(bump.outputs["Normal"], bsdf.inputs["Normal"])


def turned(name, profile, base, mat, g, hi, steps, cap=False):
    """Lathe around the vertical axis through `base`; profile = [(y, r)]."""
    # Faces point away from the axis and up (horizontal caps would be
    # ambiguous with the default purely radial test).
    yc = min(y for y, _ in profile) - 0.5
    ob = lathe(name, profile, (0, 0, 0), mat, g, hi, steps, False, cap,
               outward=lambda p: Vector((p.x - yc, p.y, p.z)))
    ob.data.transform(Matrix.Translation(Vector(base)) @ UP)
    return ob


def pointed(half, spring, rise, n):
    """Pointed (two-centred) arch outline from (-half, 0) up over the apex to
    (half, 0): a closed panel outline."""
    a = 1.15 * half
    t0 = math.acos((half - a) / a)
    left = []
    for k in range(n + 1):
        t = math.pi - (math.pi - t0) * k / n
        left.append((-half + a + a * math.cos(t), spring + rise * math.sin(t) / math.sin(t0)))
    right = [(-x, y) for (x, y) in reversed(left[:-1])]
    return [(-half, 0.0)] + left + right + [(half, 0.0)]


def facing(normal, pos):
    n = Vector(normal).normalized()
    up = Vector((0, 1, 0))
    x = up.cross(n).normalized()
    m = Matrix((x, up, n)).transposed().to_4x4()
    m.translation = Vector(pos)
    return m


def opening(name, pos, w, h, fill, g, hi, normal=(0, 0, 1), frame="trim", depth=0.12):
    """Pointed-arch opening on a wall: filled panel plus a stone frame."""
    m = facing(normal, pos)
    half = w * 0.5
    spring = h - half * 1.05
    puffy(f"{name}_p", pointed(half, spring, half * 1.05, L(hi, 3, 8)), depth, 0.0, m, fill, g, hi)
    if frame:
        hw = half + 0.12
        path = [Vector(p + (0.05,)) for p in pointed(hw, spring, hw * 1.05, L(hi, 3, 8))]
        tube(f"{name}_f", [m @ p for p in path], 0.08, frame, g, hi, 1, L(hi, 3, 6), False)


def pishtaq(name, pos, w, h, depth, mat, g, hi, normal=(0, 0, 1), door_w=None, door_h=None):
    """Tall portal block standing out of a facade with a deep pointed recess
    and a wooden door inside."""
    m = facing(normal, pos)
    rot = m.to_3x3().to_euler()
    bbox(f"{name}_blk", (w, h, depth), m @ Vector((0, h * 0.5, depth * 0.5)), mat, g, hi, L(hi, 0.0, 0.06), rot=rot)
    rw, rh = w * 0.62, h * 0.78
    m2 = m @ Matrix.Translation(Vector((0, 0, depth + 0.02)))
    puffy(f"{name}_rec", pointed(rw * 0.5, rh - rw * 0.55, rw * 0.55, L(hi, 4, 10)), 0.06, 0.0, m2, "shadow", g, hi)
    hw = rw * 0.5 + 0.18
    path = [Vector(p + (0.06,)) for p in pointed(hw, rh - rw * 0.55, hw * 1.1, L(hi, 4, 10))]
    tube(f"{name}_fr", [m2 @ p for p in path], 0.16, "carved", g, hi, 1, L(hi, 3, 6), False)
    dw, dh = door_w or rw * 0.55, door_h or rh * 0.5
    m3 = m2 @ Matrix.Translation(Vector((0, 0, 0.05)))
    puffy(f"{name}_door", pointed(dw * 0.5, dh - dw * 0.5, dw * 0.5, L(hi, 3, 8)), 0.08, 0.0, m3, "wood", g, hi)
    if hi:
        # Carved band framing the portal (stalactite hood under the cornice).
        for k in range(7):
            x = -rw * 0.5 + rw * k / 6
            bbox(f"{name}_muq{k}", (rw / 7.5, 0.5, 0.25), m2 @ Vector((x, rh + 0.4, 0.1)), "carved", g, hi, 0.04, rot=rot)
    bbox(f"{name}_cap", (w + 0.3, 0.45, depth + 0.3), m @ Vector((0, h + 0.2, depth * 0.5)), "trim", g, hi,
         L(hi, 0.0, 0.05), rot=rot)


def minaret(name, x, z, y0, r0, r1, h, g, hi, style="lattice"):
    """Round tapering minaret: shaft, inscription band, stalactite corbel,
    a parapet (pierced stone lattice or iron railing), upper drum, cap."""
    st = L(hi, 14, 40)
    turned(f"{name}_shaft", [(y0, r0), (y0 + h, r1)], (x, 0, z), "limestone", g, hi, st)
    turned(f"{name}_band", [(y0 + h - 1.6, r1 + 0.05), (y0 + h - 0.6, r1 + 0.05)], (x, 0, z), "carved", g, hi, st)
    # Stalactite corbel flaring out under the gallery.
    c0 = y0 + h
    rb = r1 + 0.75
    turned(f"{name}_corbel", [(c0 - 0.6, r1 + 0.02), (c0, r1 + 0.2), (c0 + 0.6, r1 + 0.45), (c0 + 1.2, rb),
                              (c0 + 1.35, rb)], (x, 0, z), "carved", g, hi, st)
    if hi:
        for ring in range(3):
            n = 16 + ring * 4
            rr = r1 + 0.15 + ring * 0.22
            for k in range(n):
                a = 2 * math.pi * (k + 0.5 * ring) / n
                bbox(f"{name}_st{ring}_{k}", (0.32, 0.38, 0.22), (x + math.cos(a) * rr, c0 + ring * 0.42, z + math.sin(a) * rr),
                     "stone_dark", g, hi, 0.05, rot=(0, -a + math.pi / 2, 0))
    g0 = c0 + 1.35
    if style == "railing":
        turned(f"{name}_floor", [(g0, rb), (g0 + 0.15, rb), (g0 + 0.15, 0.0)], (x, 0, z), "trim", g, hi, st)
        rail = [Vector((x + math.cos(2 * math.pi * k / 24) * (rb - 0.05), g0 + 1.05, z + math.sin(2 * math.pi * k / 24) * (rb - 0.05)))
                for k in range(25)]
        tube(f"{name}_rail", rail, 0.05, "iron", g, hi, 1, L(hi, 3, 6), False)
        for k in range(L(hi, 8, 24)):
            a = 2 * math.pi * k / L(hi, 8, 24)
            tube(f"{name}_post{k}", [Vector((x + math.cos(a) * (rb - 0.05), g0, z + math.sin(a) * (rb - 0.05))),
                                     Vector((x + math.cos(a) * (rb - 0.05), g0 + 1.05, z + math.sin(a) * (rb - 0.05)))],
                 0.035, "iron", g, hi, 1, L(hi, 3, 4), False)
    else:
        turned(f"{name}_par", [(g0, rb), (g0 + 1.1, rb), (g0 + 1.1, rb - 0.2), (g0 + 0.2, rb - 0.2)], (x, 0, z),
               "trim", g, hi, st)
        if hi:
            for k in range(20):
                a = 2 * math.pi * k / 20
                bbox(f"{name}_lat{k}", (0.42, 0.55, 0.06), (x + math.cos(a) * (rb + 0.01), g0 + 0.55, z + math.sin(a) * (rb + 0.01)),
                     "shadow", g, hi, 0.0, rot=(0, -a + math.pi / 2, 0))
    rd = r1 * 0.78
    dh = 3.0 if style == "railing" else 2.6
    turned(f"{name}_drum", [(g0, rd), (g0 + dh, rd * 0.97), (g0 + dh + 0.25, rd + 0.1), (g0 + dh + 0.45, rd + 0.1)],
           (x, 0, z), "limestone", g, hi, st)
    # Cap: low ribbed melon dome.
    prof = [(g0 + dh + 0.45, rd + 0.05)]
    n = L(hi, 4, 10)
    for k in range(1, n + 1):
        a = math.pi * 0.5 * k / n
        prof.append((g0 + dh + 0.45 + math.sin(a) * rd * 0.75, max(0.01, math.cos(a) * (rd + 0.05))))
    cap = turned(f"{name}_cap", prof, (x, 0, z), "dome", g, hi, L(hi, 12, 32))
    if hi:
        for k in range(12):
            a = 2 * math.pi * k / 12
            pts = [Vector((x + math.cos(a) * math.cos(t) * (rd + 0.08), g0 + dh + 0.45 + math.sin(t) * rd * 0.78,
                           z + math.sin(a) * math.cos(t) * (rd + 0.08))) for t in (0.0, 0.5, 1.0, 1.4)]
            tube(f"{name}_rib{k}", pts, 0.07, "dome", g, hi, 3, 5, False)
    return cap


def dome(name, cx, cy, cz, r, rise, g, hi, net=False):
    """Stone dome on a short drum; the Shah mosque's carries a star net."""
    turned(f"{name}_drum", [(cy, r + 0.2), (cy + 0.8, r + 0.2), (cy + 0.8, r)], (cx, 0, cz), "trim", g, hi, L(hi, 16, 48))
    prof = []
    n = L(hi, 6, 16)
    for k in range(n + 1):
        a = math.pi * 0.5 * k / n
        prof.append((cy + 0.8 + math.sin(a) * rise, max(0.01, math.cos(a) * r)))
    turned(f"{name}_shell", prof, (cx, 0, cz), "dome", g, hi, L(hi, 16, 48))
    if hi and net:
        # Geometric star net: two families of spiral ribs crossing.
        for fam in (-1, 1):
            for k in range(12):
                pts = []
                for i in range(9):
                    t = i / 8 * 0.95
                    a = 2 * math.pi * k / 12 + fam * t * 1.1
                    el = t * math.pi * 0.5
                    pts.append(Vector((cx + math.cos(a) * math.cos(el) * (r + 0.04), cy + 0.8 + math.sin(el) * rise,
                                       cz + math.sin(a) * math.cos(el) * (r + 0.04))))
                tube(f"{name}_net{fam}{k}", pts, 0.06, "stone_dark", g, hi, 2, 4, False)


def parapet(name, size, center, g, hi, mat="trim"):
    w, d = size
    cx, y, cz = center
    for s in (-1, 1):
        bbox(f"{name}_x{s}", (w + 0.3, 0.6, 0.35), (cx, y + 0.3, cz + s * d * 0.5), mat, g, hi, L(hi, 0.0, 0.04))
        bbox(f"{name}_z{s}", (0.35, 0.6, d), (cx + s * w * 0.5, y + 0.3, cz), mat, g, hi, L(hi, 0.0, 0.04))


def build_shirvanshah(hi):
    tag = "H" if hi else "L"
    g = "shirvanshah"
    # Terrace on the hilltop (the complex stands on three levels).
    bbox(f"ss_terrace_{tag}", (46.0, 1.6, 38.0), (0, 0.8, 0), "stone_dark", g, hi, L(hi, 0.0, 0.1))
    b = 1.6
    # Two-storey palace block (back left): plain walls, small windows.
    bbox(f"ss_palace_{tag}", (16.0, 11.0, 14.0), (-13.0, b + 5.5, -9.0), "limestone", g, hi, L(hi, 0.0, 0.1))
    parapet(f"ss_ppar_{tag}", (16.0, 14.0), (-13.0, b + 11.0, -9.0), g, hi)
    for row, y in enumerate((b + 2.2, b + 6.6)):
        for k in range(5):
            x = -19.0 + k * 3.0
            bbox(f"ss_pw{row}{k}_{tag}", (1.0, 1.6 if row else 1.3, 0.2), (x, y + 0.8, -1.95), "slit", g, hi, 0.0)
    opening(f"ss_pdoor_{tag}", (-8.0, b, -1.95), 1.8, 3.0, "wood", g, hi)
    # Shah mosque (right) with the big star-net dome and the minaret.
    bbox(f"ss_mosque_{tag}", (16.0, 8.0, 14.0), (11.5, b + 4.0, -7.0), "limestone", g, hi, L(hi, 0.0, 0.1))
    parapet(f"ss_mpar_{tag}", (16.0, 14.0), (11.5, b + 8.0, -7.0), g, hi)
    dome(f"ss_mdome_{tag}", 11.5, b + 8.0, -7.0, 5.4, 4.6, g, hi, net=True)
    opening(f"ss_mwin_{tag}", (11.5, b + 2.0, 0.05), 1.4, 2.4, "slit", g, hi)
    minaret(f"ss_min_{tag}", 19.5, -0.5, b, 1.45, 1.3, 17.0, g, hi, style="railing")
    # Divankhana: octagonal pavilion with an octagonal dome, behind a
    # courtyard wall with the carved portal.
    turned(f"ss_div_{tag}", [(b, 3.6), (b + 7.0, 3.6), (b + 7.0, 0.0)], (-0.5, 0, -12.5), "limestone_warm", g, hi, 8)
    turned(f"ss_divd_{tag}", [(b + 7.0, 3.9), (b + 7.4, 3.9), (b + 9.6, 1.9), (b + 10.5, 0.01)], (-0.5, 0, -12.5),
           "dome", g, hi, 8)
    # Mausoleum (front left) and bath-house domes (front right, low).
    bbox(f"ss_maus_{tag}", (9.0, 6.0, 8.0), (-14.0, b + 3.0, 9.5), "limestone_warm", g, hi, L(hi, 0.0, 0.1))
    dome(f"ss_mausd_{tag}", -14.0, b + 6.0, 9.5, 3.0, 2.6, g, hi)
    pishtaq(f"ss_mausp_{tag}", (-14.0, b, 13.5), 4.5, 7.0, 0.6, "limestone_warm", g, hi)
    bbox(f"ss_bath_{tag}", (14.0, 2.4, 9.0), (12.0, b + 1.2, 9.5), "stone_dark", g, hi, L(hi, 0.0, 0.1))
    for k, (x, z, r) in enumerate(((8.0, 8.0, 2.2), (12.5, 11.0, 1.8), (16.0, 8.0, 2.0), (10.5, 12.5, 1.3))):
        dome(f"ss_bd{k}_{tag}", x, b + 2.4, z, r, r * 0.8, g, hi)
    # Courtyard wall in front with the Divankhana portal (carved pishtaq).
    bbox(f"ss_cwall_{tag}", (18.0, 4.5, 1.0), (-1.0, b + 2.25, 4.0), "limestone", g, hi, L(hi, 0.0, 0.06))
    pishtaq(f"ss_port_{tag}", (-1.0, b, 4.5), 5.5, 9.0, 0.9, "limestone_warm", g, hi)
    # Stair up to the terrace.
    for k in range(4):
        bbox(f"ss_step{k}_{tag}", (8.0, 0.4 * (k + 1), 0.6), (-1.0, 0.2 * (k + 1), 19.3 + (3 - k) * 0.6), "stone_dark",
             g, hi, 0.0)


def build_juma(hi):
    tag = "H" if hi else "L"
    g = "juma_mosque"
    w, h, d = 22.0, 9.0, 16.0
    bbox(f"jm_hall_{tag}", (w, h, d), (1.5, h * 0.5, -1.0), "limestone", g, hi, L(hi, 0.0, 0.1))
    parapet(f"jm_par_{tag}", (w, d), (1.5, h, -1.0), g, hi)
    fz = d * 0.5 - 1.0
    for row, y in enumerate((1.2, 5.0)):
        for k, x in enumerate((-7.0, -4.0, 6.5, 9.5)):
            opening(f"jm_w{row}{k}_{tag}", (x, y, fz + 0.02), 1.5, 2.6, "glass", g, hi)
    pishtaq(f"jm_portal_{tag}", (1.5, 0.0, fz), 7.0, 12.5, 1.6, "limestone_warm", g, hi)
    minaret(f"jm_min_{tag}", -11.5, 5.0, 0.0, 2.1, 1.8, 18.5, g, hi, style="lattice")
    # Side windows.
    for k in range(3):
        opening(f"jm_sw{k}_{tag}", (w * 0.5 + 1.52, 4.2, -6.0 + k * 5.0), 1.4, 2.4, "glass", g, hi, normal=(1, 0, 0))


def teeth(name, x0, x1, y, z, g, hi, normal=(0, 0, 1), size=0.7):
    """Toothed (saw) parapet along a wall top: local x from x0 to x1 along the
    wall, placed `z` out along `normal` at height y."""
    from mathutils.geometry import tessellate_polygon
    n = max(2, int((x1 - x0) / size))
    pts = [(x0, 0.0), (x1, 0.0)]
    for k in range(n, 0, -1):
        xa = x0 + (x1 - x0) * k / n
        xm = x0 + (x1 - x0) * (k - 0.5) / n
        pts += [(xa, 0.15), (xm, 0.15 + size * 0.8)]
    pts.append((x0, 0.15))
    m = facing(normal, (0, y, 0)) @ Matrix.Translation(Vector((0, 0, z)))
    bm = bmesh.new()
    fr = [bm.verts.new(m @ Vector((x, yy, 0.2))) for x, yy in pts]
    bk = [bm.verts.new(m @ Vector((x, yy, -0.2))) for x, yy in pts]
    for tri in tessellate_polygon([[Vector((x, yy, 0.0)) for x, yy in pts]]):
        bm.faces.new([fr[i] for i in tri])
        bm.faces.new([bk[i] for i in reversed(tri)])
    for i in range(len(pts)):
        j = (i + 1) % len(pts)
        bm.faces.new((fr[j], fr[i], bk[i], bk[j]))
    return K.finish(bm, name, "limestone_warm", g, hi, smooth=False)


def build_siniqqala(hi):
    tag = "H" if hi else "L"
    g = "siniqqala"
    w, h, d = 12.0, 7.0, 9.0
    bbox(f"sq_hall_{tag}", (w, h, d), (-1.0, h * 0.5, 0.0), "limestone_warm", g, hi, L(hi, 0.0, 0.1))
    teeth(f"sq_teeth_f_{tag}", -7.0, 5.0, h, d * 0.5 - 0.2, g, hi)
    teeth(f"sq_teeth_b_{tag}", -5.0, 7.0, h, d * 0.5 - 0.2, g, hi, normal=(0, 0, -1))
    teeth(f"sq_teeth_l_{tag}", -4.5, 4.5, h, 6.8, g, hi, normal=(-1, 0, 0))
    opening(f"sq_door_{tag}", (-3.0, 0.0, d * 0.5 + 0.02), 2.0, 3.6, "wood", g, hi, frame="carved")
    bbox(f"sq_plaque_{tag}", (1.2, 0.8, 0.1), (-0.5, 4.2, d * 0.5 + 0.05), "slit", g, hi, 0.0)
    # Buttress-like mass the minaret stands on (right).
    bbox(f"sq_base_{tag}", (5.0, 7.5, 6.0), (6.5, 3.75, -1.0), "limestone_warm", g, hi, L(hi, 0.0, 0.1))
    teeth(f"sq_teeth_r_{tag}", 4.0, 9.0, 7.5, 2.0, g, hi)
    minaret(f"sq_min_{tag}", 6.5, -1.0, 7.5, 1.9, 1.55, 13.5, g, hi, style="lattice")


def build_caravanserai(hi):
    tag = "H" if hi else "L"
    g = "caravanserai"
    s, h, t = 26.0, 6.5, 4.0
    for k, (cx, cz, sx, sz) in enumerate(((0, s * 0.5 - t * 0.5, s, t), (0, -s * 0.5 + t * 0.5, s, t),
                                          (s * 0.5 - t * 0.5, 0, t, s - 2 * t), (-s * 0.5 + t * 0.5, 0, t, s - 2 * t))):
        bbox(f"cs_wall{k}_{tag}", (sx, h, sz), (cx, h * 0.5, cz), "limestone", g, hi, L(hi, 0.0, 0.08))
    bbox(f"cs_yard_{tag}", (s - 2 * t, 0.1, s - 2 * t), (0, 0.05, 0), "stone_dark", g, hi, 0.0)
    bbox(f"cs_cornice_{tag}", (s + 0.3, 0.35, s + 0.3), (0, h + 0.1, 0), "trim", g, hi, 0.0)
    # Pointed cells round the courtyard (inner faces).
    inner = s * 0.5 - t
    for side, nrm in ((0, (0, 0, -1)), (1, (0, 0, 1)), (2, (-1, 0, 0)), (3, (1, 0, 0))):
        for k in range(4):
            u = -inner + (k + 0.5) * (2 * inner) / 4
            if side == 0:
                pos = (u, 0.1, inner - 0.02)
            elif side == 1:
                pos = (u, 0.1, -inner + 0.02)
            elif side == 2:
                pos = (inner - 0.02, 0.1, u)
            else:
                pos = (-inner + 0.02, 0.1, u)
            if side == 0 and k in (1, 2):
                continue  # the gate passage
            opening(f"cs_cell{side}{k}_{tag}", pos, 2.6, 4.2, "shadow", g, hi, normal=nrm)
    # Gate: tall projecting portal on the street front.
    pishtaq(f"cs_gate_{tag}", (0.0, 0.0, s * 0.5), 9.0, 9.0, 1.4, "limestone_warm", g, hi, door_w=3.4, door_h=4.6)
    # Small windows / slits on the outer walls.
    for k in range(4):
        bbox(f"cs_slit{k}_{tag}", (0.5, 0.9, 0.2), (-10.0 + k * 6.6 if k < 2 else 3.4 + (k - 2) * 6.6, 4.4, s * 0.5 + 0.05),
             "slit", g, hi, 0.0)


OFFSET = {g: Vector((i * 80.0, 0.0, 0.0)) for i, g in enumerate(GROUPS)}


def _built(fn, g):
    before = set(K.COLL.objects)
    fn()
    for o in set(K.COLL.objects) - before:
        o.data.transform(Matrix.Translation(OFFSET[g]))


def build(hi):
    global _bumped
    if hi and not _bumped:
        add_bump()
        _bumped = True
    _built(lambda: build_shirvanshah(hi), "shirvanshah")
    _built(lambda: build_juma(hi), "juma_mosque")
    _built(lambda: build_siniqqala(hi), "siniqqala")
    _built(lambda: build_caravanserai(hi), "caravanserai")


def _home(groups):
    for o in groups:
        o.data.transform(Matrix.Translation(-OFFSET[o.name]))


K.PRE_EXPORT.append(_home)

K.setup("icheri_props", "assets/models/icheri", PALETTE, PAINT_MAT, GROUPS, UV_SCALE, FAR_RATIO, stone_mats=STONE)
K.run(build)
