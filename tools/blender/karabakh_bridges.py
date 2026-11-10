"""The Xudafərin bridges over the Araz for the Qarabağ map (0.19.0 Blender models).

  blender --background --factory-startup --python tools/blender/karabakh_bridges.py -- --bake-res 4096 --tex-res 2048
Same pipeline as the other prop sets (kart_common.run). Both bridges are laid
out here too: assets/models/karabakh/bridges.json lists every module instance
[module, x, y, z, yaw] in Godot space (KarabakhDecor and karabakh_render.py
read it; the place comes from "bridges" and the Araz in data/tracks/karabakh.json).

The real bridges (Cəbrayıl, on the Araz), game-scaled to the 64 m river:
  * the 15-span bridge (13th c.): river-stone piers on rock outcrops with
    triangular cutwaters upstream and round ones downstream, pointed arches
    and parapets of baked brick, spans of different widths, sloping approaches.
  * the 11-span "Sınıq körpü" (11th-12th c.), ~800 m upstream: cut stone, only
    the three middle spans stand, the rest are ruined piers on their rocks.
Modules (x along the bridge, y up from the water level, z across; +z = upstream):
  kb_br_pier    pier of the 15-span bridge up to the springing, rock base
  kb_br_arch_w  wide span (6.4 m between pier centres) with deck and parapets
  kb_br_arch_n  narrow span (4.8 m)
  kb_br_ramp    9 m approach ramp from x = 0 down towards +x
  kb_br11_arch  span of the 11-span bridge (8 m between pier centres)
  kb_br11_pier  its pier (cutwaters on both sides)
  kb_br11_ruin_a  ruined pier with the stub of an arch
  kb_br11_ruin_b  low ruined pier, rubble
Stone / brick relief and the colour variation are procedural (cobbles: Voronoi,
bricks: brick texture), baked into the normal map and the albedo.
"""

import json
import math
import os
import random
import sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from kart_common import *  # noqa: F401,F403
import kart_common as K
import numpy as np
from mathutils import Vector, Matrix, noise

PALETTE = {
    "river_stone": ("B3A993", 0.9, 0.0),
    "brick": ("A9674A", 0.85, 0.0),
    "trim": ("B8AC92", 0.85, 0.0),
    "cut_stone": ("B9AB8C", 0.88, 0.0),
    "cut_dark": ("9C8F74", 0.9, 0.0),
    "rock": ("77705F", 0.95, 0.0),
    "glass": ("2F5F86", 0.08, 0.3),
}
PAINT_MAT = "glass"   # no glass here; mask stays 0
STONE = ["cut_stone", "cut_dark"]   # world-space coursing in prop_baked (the old cut-stone bridge)
GROUPS = ["kb_br_pier", "kb_br_arch_w", "kb_br_arch_n", "kb_br_ramp",
          "kb_br11_arch", "kb_br11_pier", "kb_br11_ruin_a", "kb_br11_ruin_b"]
UV_SCALE = {g: 1.0 for g in GROUPS}
FAR_RATIO = {g: 0.4 for g in GROUPS}

# 15-span bridge
HW = 1.8          # half width of the deck
SPRING = 2.4      # arch springing above the water
DECK = 6.5
PIER_W = 2.1
SPANS = {"W": (6.4, 2.2, 3.0), "N": (4.8, 1.4, 2.5)}   # pitch, half span, rise
PATTERN = "NWWNWNWWWNWNWWN"
RAMP = 9.0
RAMP_END = 3.0
# 11-span bridge
HW11 = 2.2
SPRING11 = 2.0
DECK11 = 6.9
P11, HALF11, RISE11 = 8.0, 2.7, 3.3
PIER11_W = 2.7
BED = -2.4        # pier foot under the water

COLOR_NODES = {}
_look = False


def add_look():
    """Procedural colour + relief per material (object space, y up)."""
    for name, m in K.MATS.items():
        if name == "glass":
            continue
        nt = m.node_tree
        bsdf = nt.nodes["Principled BSDF"]
        base = tuple(m["yaska"][:3])
        tc = nt.nodes.new("ShaderNodeTexCoord")
        sep = nt.nodes.new("ShaderNodeSeparateXYZ")
        nt.links.new(tc.outputs["Object"], sep.inputs["Vector"])
        if name == "brick":
            br = nt.nodes.new("ShaderNodeTexBrick")
            br.inputs["Scale"].default_value = 1.0
            br.inputs["Brick Width"].default_value = 0.46
            br.inputs["Row Height"].default_value = 0.13
            br.inputs["Mortar Size"].default_value = 0.014
            br.inputs["Mortar Smooth"].default_value = 0.3
            br.inputs["Bias"].default_value = 0.1
            br.inputs["Color1"].default_value = (*(c * 1.12 for c in base), 1.0)
            br.inputs["Color2"].default_value = (*(c * 0.78 for c in base), 1.0)
            br.inputs["Mortar"].default_value = (*K.hex_lin("B9AD98"), 1.0)
            nt.links.new(tc.outputs["Object"], br.inputs["Vector"])
            colour = br.outputs["Color"]
            inv = nt.nodes.new("ShaderNodeMath")
            inv.operation = "SUBTRACT"
            inv.inputs[0].default_value = 1.0
            nt.links.new(br.outputs["Fac"], inv.inputs[1])
            height = inv.outputs[0]
            strength, dist = 0.8, 0.02
        elif name == "rock":
            no = nt.nodes.new("ShaderNodeTexNoise")
            no.inputs["Scale"].default_value = 1.6
            no.inputs["Detail"].default_value = 6.0
            nt.links.new(tc.outputs["Object"], no.inputs["Vector"])
            mr = nt.nodes.new("ShaderNodeMapRange")
            mr.inputs["From Min"].default_value = 0.3
            mr.inputs["From Max"].default_value = 0.7
            mr.inputs["To Min"].default_value = 0.72
            mr.inputs["To Max"].default_value = 1.2
            nt.links.new(no.outputs["Fac"], mr.inputs["Value"])
            mul = nt.nodes.new("ShaderNodeVectorMath")
            mul.operation = "SCALE"
            mul.inputs[0].default_value = base
            nt.links.new(mr.outputs["Result"], mul.inputs["Scale"])
            colour = mul.outputs["Vector"]
            height = no.outputs["Fac"]
            strength, dist = 0.9, 0.12
        else:
            mp = nt.nodes.new("ShaderNodeMapping")
            cut = name in STONE or name == "trim"
            # cobbles ~0.4 m; cut blocks ~1.0 x 0.45 m
            mp.inputs["Scale"].default_value = (1 / 1.0, 1 / 0.45, 1 / 1.0) if cut else (2.4, 2.9, 2.4)
            nt.links.new(tc.outputs["Object"], mp.inputs["Vector"])
            vo = nt.nodes.new("ShaderNodeTexVoronoi")
            vo.feature = "DISTANCE_TO_EDGE"
            vo.inputs["Scale"].default_value = 1.0
            nt.links.new(mp.outputs["Vector"], vo.inputs["Vector"])
            vc = nt.nodes.new("ShaderNodeTexVoronoi")
            vc.inputs["Scale"].default_value = 1.0
            nt.links.new(mp.outputs["Vector"], vc.inputs["Vector"])
            sc = nt.nodes.new("ShaderNodeSeparateColor")
            nt.links.new(vc.outputs["Color"], sc.inputs["Color"])
            tint = nt.nodes.new("ShaderNodeMapRange")       # per-stone tone
            tint.inputs["To Min"].default_value = 0.86 if cut else 0.7
            tint.inputs["To Max"].default_value = 1.1 if cut else 1.22
            nt.links.new(sc.outputs["Red"], tint.inputs["Value"])
            joint = nt.nodes.new("ShaderNodeMapRange")      # dark joints
            joint.inputs["From Max"].default_value = 0.05 if cut else 0.09
            joint.inputs["To Min"].default_value = 0.72
            nt.links.new(vo.outputs["Distance"], joint.inputs["Value"])
            k = nt.nodes.new("ShaderNodeMath")
            k.operation = "MULTIPLY"
            nt.links.new(tint.outputs["Result"], k.inputs[0])
            nt.links.new(joint.outputs["Result"], k.inputs[1])
            mul = nt.nodes.new("ShaderNodeVectorMath")
            mul.operation = "SCALE"
            mul.inputs[0].default_value = base
            nt.links.new(k.outputs[0], mul.inputs["Scale"])
            colour = mul.outputs["Vector"]
            hr = nt.nodes.new("ShaderNodeMapRange")
            hr.inputs["From Max"].default_value = 0.07 if cut else 0.22
            nt.links.new(vo.outputs["Distance"], hr.inputs["Value"])
            height = hr.outputs["Result"]
            strength, dist = (0.75, 0.04) if cut else (0.9, 0.07)
        # Wet, darker masonry just above the water line.
        wet = nt.nodes.new("ShaderNodeMapRange")
        wet.inputs["From Min"].default_value = -0.4
        wet.inputs["From Max"].default_value = 1.3
        wet.inputs["To Min"].default_value = 0.68
        wet.inputs["To Max"].default_value = 1.0
        nt.links.new(sep.outputs["Y"], wet.inputs["Value"])
        wmul = nt.nodes.new("ShaderNodeVectorMath")
        wmul.operation = "SCALE"
        nt.links.new(colour, wmul.inputs[0])
        nt.links.new(wet.outputs["Result"], wmul.inputs["Scale"])
        COLOR_NODES[name] = wmul.outputs["Vector"]
        bump = nt.nodes.new("ShaderNodeBump")
        bump.inputs["Strength"].default_value = strength
        bump.inputs["Distance"].default_value = dist
        nt.links.new(height, bump.inputs["Height"])
        nt.links.new(bump.outputs["Normal"], bsdf.inputs["Normal"])


_orig_emit = K.set_emit


def _set_emit(mode):
    """The albedo pass bakes the procedural colour, the mask passes flat values."""
    _orig_emit(mode)
    for name, m in K.MATS.items():
        nt = m.node_tree
        sock = nt.nodes["Principled BSDF"].inputs["Emission Color"]
        for link in list(sock.links):
            nt.links.remove(link)
        if mode == "albedo" and name in COLOR_NODES:
            nt.links.new(COLOR_NODES[name], sock)


K.set_emit = _set_emit


# --- Shapes ------------------------------------------------------------------------------

def pointed(half, spring, rise, n, cx=0.0):
    """Pointed (two-centred) arch from (cx - half, spring) over the apex to (cx + half, spring)."""
    a = 1.15 * half
    t0 = math.acos((half - a) / a)
    left = []
    for k in range(n + 1):
        t = math.pi - (math.pi - t0) * k / n
        left.append((-half + a + a * math.cos(t), spring + rise * math.sin(t) / math.sin(t0)))
    right = [(-x, y) for (x, y) in reversed(left[:-1])]
    return [(x + cx, y) for (x, y) in left + right]


def extrude(name, outline, z0, z1, mat, g, hi):
    """Simple polygon (local XY, may be concave) extruded from z0 to z1."""
    from mathutils.geometry import tessellate_polygon
    bm = bmesh.new()
    front = [bm.verts.new((x, y, z1)) for x, y in outline]
    back = [bm.verts.new((x, y, z0)) for x, y in outline]
    for tri in tessellate_polygon([[Vector((x, y, 0.0)) for x, y in outline]]):
        bm.faces.new([front[i] for i in tri])
        bm.faces.new([back[i] for i in reversed(tri)])
    n = len(outline)
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((front[j], front[i], back[i], back[j]))
    return K.finish(bm, name, mat, g, hi, smooth=False)


def prism(name, poly_xz, y0, y1, apex, mat, g, hi):
    """Polygon in plan (x, z) from y0 to y1, closed by a pyramid to `apex`."""
    bm = bmesh.new()
    bot = [bm.verts.new((x, y0, z)) for x, z in poly_xz]
    top = [bm.verts.new((x, y1, z)) for x, z in poly_xz]
    n = len(poly_xz)
    bm.faces.new(bot)
    a = bm.verts.new(apex)
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((bot[i], bot[j], top[j], top[i]))
        bm.faces.new((top[i], top[j], a))
    return K.finish(bm, name, mat, g, hi, smooth=False)


def rock(name, radii, center, seed, g, hi, sub=3):
    """Faceted river rock (same mesh low / high: the bake rays stay short)."""
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=sub, radius=1.0)
    for v in bm.verts:
        k = 1.0 + 0.3 * noise.noise(v.co * 1.6 + Vector((seed * 7.3, seed * 1.9, 0.0)))
        v.co = Vector((v.co.x * radii[0] * k + center[0], v.co.y * radii[1] * k + center[1],
                       v.co.z * radii[2] * k + center[2]))
    return K.finish(bm, name, "rock", g, hi, smooth=False)


def box(name, size, center, mat, g, hi, rot=(0, 0, 0), bevel=0.03):
    return bbox(name, size, center, mat, g, hi, L(hi, 0.0, bevel), rot=rot)


def cutwaters(g, tag, hi, pw, hw, top, mat, both_tri):
    """Triangular breakwater upstream (+z); downstream round (15-span) or triangular."""
    h = pw * 0.5
    prism(f"{g}_cut_up_{tag}", [(-h, hw - 0.05), (h, hw - 0.05), (0.0, hw + pw * 0.85)], BED, top,
          (0.0, top + 1.0, hw - 0.05), mat, g, hi)
    if both_tri:
        prism(f"{g}_cut_dn_{tag}", [(h, -hw + 0.05), (-h, -hw + 0.05), (0.0, -hw - pw * 0.85)], BED, top,
              (0.0, top + 1.0, -hw + 0.05), mat, g, hi)
    else:
        n = 6
        arc = [(h * math.cos(math.pi * k / n), -hw + 0.05 - h * math.sin(math.pi * k / n)) for k in range(n + 1)]
        prism(f"{g}_cut_dn_{tag}", arc, BED, top, (0.0, top + 0.8, -hw + 0.05), mat, g, hi)


def arch_module(g, tag, hi, pitch, half, spring, rise, deck, hw, ring, wall, ring_mat):
    n = L(hi, 12, 18)
    ci = pointed(half, spring, rise, n)
    co = pointed(half + ring, spring, rise + ring * 1.15, n)
    outline = [(-pitch / 2, spring)] + co + [(pitch / 2, spring), (pitch / 2, deck), (-pitch / 2, deck)]
    extrude(f"{g}_wall_{tag}", list(reversed(outline)), -hw, hw, wall, g, hi)
    extrude(f"{g}_ring_{tag}", ci + list(reversed(co)), -hw - 0.06, hw + 0.06, ring_mat, g, hi)


# --- 15-span bridge ----------------------------------------------------------------------

def build_pier(hi):
    tag = "H" if hi else "L"
    g = "kb_br_pier"
    box(f"{g}_shaft_{tag}", (PIER_W, SPRING - BED, HW * 2), (0, (SPRING + BED) / 2, 0), "river_stone", g, hi)
    cutwaters(g, tag, hi, PIER_W, HW, SPRING + 0.9, "river_stone", False)
    rock(f"{g}_rock_{tag}", (2.3, 1.7, 4.6), (0.1, BED + 1.5, 0.5), 1.0, g, hi)
    rock(f"{g}_rock2_{tag}", (1.2, 0.9, 1.3), (1.5, BED + 2.2, -2.6), 2.0, g, hi, 2)


def build_arch(kind, g, hi):
    tag = "H" if hi else "L"
    pitch, half, rise = SPANS[kind]
    arch_module(g, tag, hi, pitch, half, SPRING, rise, DECK, HW, 0.36, "river_stone", "brick")
    box(f"{g}_course_{tag}", (pitch, 0.22, HW * 2 + 0.24), (0, DECK, 0), "trim", g, hi)
    for s in (-1, 1):
        box(f"{g}_parapet{s}_{tag}", (pitch, 0.85, 0.34), (0, DECK + 0.11 + 0.425, s * (HW - 0.2)), "brick", g, hi)
        box(f"{g}_coping{s}_{tag}", (pitch, 0.1, 0.44), (0, DECK + 0.11 + 0.9, s * (HW - 0.2)), "trim", g, hi)


def build_ramp(hi):
    tag = "H" if hi else "L"
    g = "kb_br_ramp"
    extrude(f"{g}_body_{tag}", [(0, BED + 0.9), (RAMP, BED + 0.9), (RAMP, RAMP_END), (0, DECK + 0.11)], -HW, HW,
            "river_stone", g, hi)
    for s in (-1, 1):
        z = s * (HW - 0.2)
        extrude(f"{g}_parapet{s}_{tag}", [(0, DECK + 0.11), (RAMP, RAMP_END), (RAMP, RAMP_END + 0.85), (0, DECK + 0.96)],
                z - 0.17, z + 0.17, "brick", g, hi)
        extrude(f"{g}_coping{s}_{tag}", [(0, DECK + 0.96), (RAMP, RAMP_END + 0.85), (RAMP, RAMP_END + 0.95), (0, DECK + 1.06)],
                z - 0.22, z + 0.22, "trim", g, hi)
        box(f"{g}_post{s}_{tag}", (0.5, 1.2, 0.5), (RAMP - 0.25, RAMP_END + 0.5, z), "trim", g, hi)


# --- 11-span bridge ----------------------------------------------------------------------

def build_arch11(hi):
    tag = "H" if hi else "L"
    g = "kb_br11_arch"
    arch_module(g, tag, hi, P11, HALF11, SPRING11, RISE11, DECK11, HW11, 0.45, "cut_stone", "cut_dark")
    for s in (-1, 1):
        box(f"{g}_kerb{s}_{tag}", (P11, 0.4, 0.45), (0, DECK11 + 0.2, s * (HW11 - 0.23)), "cut_dark", g, hi, bevel=0.05)


def build_pier11(hi):
    tag = "H" if hi else "L"
    g = "kb_br11_pier"
    box(f"{g}_shaft_{tag}", (PIER11_W, SPRING11 - BED, HW11 * 2), (0, (SPRING11 + BED) / 2, 0), "cut_stone", g, hi)
    cutwaters(g, tag, hi, PIER11_W, HW11, SPRING11 + 0.6, "cut_dark", True)
    rock(f"{g}_rock_{tag}", (3.0, 1.8, 5.6), (-0.2, BED + 1.5, 0.2), 3.0, g, hi)


def rubble(g, tag, hi, rnd, count, area, y):
    for i in range(count):
        s = (rnd.uniform(0.5, 1.1), rnd.uniform(0.3, 0.6), rnd.uniform(0.4, 0.9))
        box(f"{g}_rubble{i}_{tag}", s, (rnd.uniform(-area[0], area[0]), y + s[1] * 0.4, rnd.uniform(-area[1], area[1])),
            "cut_stone" if i % 2 else "cut_dark", g, hi, rot=(rnd.uniform(-0.3, 0.3), rnd.uniform(0, 3.1), rnd.uniform(-0.3, 0.3)))


def build_ruin_a(hi):
    """A pier still carrying the stub of its arch towards +x."""
    tag = "H" if hi else "L"
    g = "kb_br11_ruin_a"
    rnd = random.Random(11)
    box(f"{g}_shaft_{tag}", (PIER11_W, SPRING11 - BED, HW11 * 2), (0, (SPRING11 + BED) / 2, 0), "cut_stone", g, hi)
    cutwaters(g, tag, hi, PIER11_W, HW11, SPRING11 - 0.4, "cut_dark", True)
    n = L(hi, 12, 18)
    curve = pointed(HALF11, SPRING11, RISE11, n, cx=P11 / 2)
    stub = curve[:int(n * 0.55) + 1]
    lx, ly = stub[-1]
    poly = stub + [(lx - 0.25, ly + 0.75), (lx - 0.9, ly + 0.5), (0.7, ly + 1.0), (0.1, ly + 0.3), (-0.6, ly + 0.9),
                   (-PIER11_W / 2, ly - 0.2), (-PIER11_W / 2, SPRING11)]
    extrude(f"{g}_stub_{tag}", list(reversed(poly)), -HW11, HW11, "cut_stone", g, hi)
    for i in range(4):   # broken courses on the top
        s = (rnd.uniform(0.6, 1.2), rnd.uniform(0.35, 0.8), rnd.uniform(0.8, 1.6))
        box(f"{g}_top{i}_{tag}", s, (rnd.uniform(-1.0, 0.2), ly + 0.6 + s[1] * 0.3, rnd.uniform(-1.5, 1.5)),
            "cut_dark" if i % 2 else "cut_stone", g, hi, rot=(0, rnd.uniform(-0.25, 0.25), rnd.uniform(-0.12, 0.12)))
    rock(f"{g}_rock_{tag}", (3.1, 1.8, 5.4), (0.3, BED + 1.5, -0.3), 4.0, g, hi)
    rubble(g, tag, hi, rnd, 4, (2.6, 3.8), BED + 2.8)


def build_ruin_b(hi):
    """A low stump of a pier among its fallen stones."""
    tag = "H" if hi else "L"
    g = "kb_br11_ruin_b"
    rnd = random.Random(23)
    top = 0.9
    box(f"{g}_shaft_{tag}", (PIER11_W, top - BED, HW11 * 2 - 0.4), (0, (top + BED) / 2, 0), "cut_stone", g, hi)
    cutwaters(g, tag, hi, PIER11_W, HW11 - 0.2, top - 0.9, "cut_dark", True)
    for i in range(5):
        s = (rnd.uniform(0.7, 1.3), rnd.uniform(0.3, 1.1), rnd.uniform(0.8, 1.5))
        box(f"{g}_top{i}_{tag}", s, (rnd.uniform(-0.7, 0.7), top + s[1] * 0.35, rnd.uniform(-1.5, 1.5)),
            "cut_dark" if i % 2 else "cut_stone", g, hi, rot=(0, rnd.uniform(-0.3, 0.3), rnd.uniform(-0.1, 0.1)))
    rock(f"{g}_rock_{tag}", (3.2, 1.7, 5.0), (0.0, BED + 1.4, 0.4), 5.0, g, hi)
    rubble(g, tag, hi, rnd, 6, (2.8, 4.0), BED + 2.7)


OFFSET = {g: Vector((i * 40.0, 0.0, 0.0)) for i, g in enumerate(GROUPS)}


def _built(fn, g):
    before = set(K.COLL.objects)
    fn()
    for o in set(K.COLL.objects) - before:
        o.data.transform(Matrix.Translation(OFFSET[g]))


def build(hi):
    global _look
    if not _look:
        add_look()
        _look = True
    _built(lambda: build_pier(hi), "kb_br_pier")
    _built(lambda: build_arch("W", "kb_br_arch_w", hi), "kb_br_arch_w")
    _built(lambda: build_arch("N", "kb_br_arch_n", hi), "kb_br_arch_n")
    _built(lambda: build_ramp(hi), "kb_br_ramp")
    _built(lambda: build_arch11(hi), "kb_br11_arch")
    _built(lambda: build_pier11(hi), "kb_br11_pier")
    _built(lambda: build_ruin_a(hi), "kb_br11_ruin_a")
    _built(lambda: build_ruin_b(hi), "kb_br11_ruin_b")


def _home(groups):
    for o in groups:
        o.data.transform(Matrix.Translation(-OFFSET[o.name]))


# --- Layout ------------------------------------------------------------------------------

def layout():
    """Both bridges across the Araz (north - south), as module instances."""
    track = json.load(open(os.path.join(K.ROOT, "data", "tracks", "karabakh.json"), encoding="utf-8"))
    road = json.load(open(os.path.join(K.ROOT, "tools", "blender", "out", "karabakh_road.json"), encoding="utf-8"))
    araz = next(r for r in track["rivers"] if r["id"] == "araz")
    pts = np.array(araz["points"], dtype=np.float64)
    for _ in range(3):   # the same corner cutting as karabakh_terrain.py
        q = [pts[0]]
        for a, b in zip(pts[:-1], pts[1:]):
            q.append(a * 0.75 + b * 0.25)
            q.append(a * 0.25 + b * 0.75)
        q.append(pts[-1])
        pts = np.array(q)
    level = float(araz["level"])
    south = -math.pi / 2    # Basis(UP, yaw): local +x -> world +z
    out = []
    info = {}
    for br in track["bridges"]:
        x = float(br["x"])
        zc = float(np.interp(x, pts[:, 0], pts[:, 1]))
        if br["kind"] == "khudafarin15":
            total = sum(SPANS[k][0] for k in PATTERN)
            z = zc - total / 2
            z_north = z
            out.append(["kb_br_ramp", x, level, z, -south])
            out.append(["kb_br_pier", x, level, z, south])
            for k in PATTERN:
                pitch = SPANS[k][0]
                out.append(["kb_br_arch_w" if k == "W" else "kb_br_arch_n", x, level, z + pitch / 2, south])
                z += pitch
                out.append(["kb_br_pier", x, level, z, south])
            out.append(["kb_br_ramp", x, level, z, south])
            ends = (z_north - RAMP, z + RAMP)
        else:
            z = zc - P11 * 11 / 2
            ends = (z, z + P11 * 11)
            for i in range(12):
                if 4 <= i <= 7:
                    out.append(["kb_br11_pier", x, level, z, south])
                elif i == 3:
                    out.append(["kb_br11_ruin_a", x, level, z, south])       # stub towards the standing spans
                elif i == 8:
                    out.append(["kb_br11_ruin_a", x, level, z, -south])
                else:
                    out.append(["kb_br11_ruin_a" if i in (1, 10) else "kb_br11_ruin_b", x, level, z,
                                south if i % 2 else -south])
                if 4 <= i <= 6:
                    out.append(["kb_br11_arch", x, level, z + P11 / 2, south])
                z += P11
        gap = min(math.hypot(p[0] - x, p[2] - ends[0]) - hw - road["offroad_width"]
                  for p, hw in zip(road["points"], road["half_widths"]))
        info[br["kind"]] = {"x": x, "z_north": round(ends[0], 2), "z_south": round(ends[1], 2), "river_z": round(zc, 2),
                            "gap_to_runoff": round(gap, 2)}
        print(f"BRIDGE {br['kind']}: x {x:.0f}, z {ends[0]:.1f} .. {ends[1]:.1f}, {gap:.1f} m behind the run-off")
        assert gap > 2.0, "the bridge reaches the road"
    out = [[m, round(x, 2), round(y, 2), round(z, 2), round(yaw, 4)] for m, x, y, z, yaw in out]
    path = os.path.join(K.ROOT, "assets", "models", "karabakh", "bridges.json")
    json.dump({"doc": "module, x, y, z, yaw (Godot space; y = the Araz water level)", "bridges": info, "instances": out},
              open(path, "w", encoding="utf-8", newline="\n"))
    print("WROTE", path, len(out), "instances")


K.PRE_EXPORT.append(_home)
layout()
if "--layout-only" not in K.ARGV:
    K.setup("karabakh_bridges", "assets/models/karabakh_bridges", PALETTE, PAINT_MAT, GROUPS, UV_SCALE, FAR_RATIO,
            stone_mats=STONE)
    K.run(build)
