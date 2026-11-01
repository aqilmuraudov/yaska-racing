"""Qoşa Qala gate and İçərişəhər walls for Yaska Racing (0.15.x Blender models).

  blender --background --factory-startup --python tools/blender/gate_props.py -- --bake-res 4096 --tex-res 2048
Same pipeline as the other prop sets (kart_common.run). Modules, assembled in
LandmarkKit.qosa_qala / city_wall:
  gate_arch   wall over the road with a pointed arch, built for a 22 m span
              (x across the road, centred; scaled in x to the real span)
  gate_tower  round gate tower at the origin with the blind side gate on +x
              (the left tower is the same mesh turned 180°)
  wall_seg    4 m of crenellated wall along +x from x = 0
  wall_tower  half-round wall tower at x = 0 on the outer (-z) face
  wall_end    free-standing round tower closing a wall run
Coursed limestone relief is a Voronoi bump baked into the normal map; albedo
alpha marks stone for the world-space limestone detail in prop_baked.gdshader.
"""

import math
import os
import sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from kart_common import *  # noqa: F401,F403
import kart_common as K
from mathutils import Vector, Matrix

PALETTE = {
    "limestone": ("D9C29A", 0.85, 0.0),
    "limestone_warm": ("E0B98A", 0.85, 0.0),
    "stone_dark": ("A88E68", 0.9, 0.0),
    "trim": ("EBD3A8", 0.8, 0.0),
    "wood": ("7A4A2A", 0.6, 0.0),
    "iron": ("2E2B36", 0.5, 0.6),
    "slit": ("1E2A3A", 0.8, 0.0),
    "glass": ("2F5F86", 0.08, 0.3),
}
PAINT_MAT = "glass"   # no glass here; mask stays 0
STONE = ["limestone", "limestone_warm", "stone_dark", "trim"]
GROUPS = ["gate_arch", "gate_tower", "wall_seg", "wall_tower", "wall_end"]
UV_SCALE = {"gate_arch": 1.0, "gate_tower": 1.0, "wall_seg": 1.3, "wall_tower": 1.1, "wall_end": 1.0}
FAR_RATIO = {g: 0.45 for g in GROUPS}

SPAN = 22.0
WALL_H = 13.0
TH = 2.6
SPRING = 5.5
RISE = 4.6
_bumped = False


def add_bump():
    """Coursed blocks with mortar grooves (Voronoi distance-to-edge)."""
    for name in STONE:
        nt = K.MATS[name].node_tree
        bsdf = nt.nodes["Principled BSDF"]
        tc = nt.nodes.new("ShaderNodeTexCoord")
        mp = nt.nodes.new("ShaderNodeMapping")
        mp.inputs["Scale"].default_value = (1 / 1.1, 1 / 0.5, 1 / 1.1)
        vo = nt.nodes.new("ShaderNodeTexVoronoi")
        vo.feature = "DISTANCE_TO_EDGE"
        mr = nt.nodes.new("ShaderNodeMapRange")
        mr.inputs["From Max"].default_value = 0.07
        bump = nt.nodes.new("ShaderNodeBump")
        bump.inputs["Strength"].default_value = 0.75
        bump.inputs["Distance"].default_value = 0.04
        nt.links.new(tc.outputs["Object"], mp.inputs["Vector"])
        nt.links.new(mp.outputs["Vector"], vo.inputs["Vector"])
        nt.links.new(vo.outputs["Distance"], mr.inputs["Value"])
        nt.links.new(mr.outputs["Result"], bump.inputs["Height"])
        nt.links.new(bump.outputs["Normal"], bsdf.inputs["Normal"])


def pointed(half, spring, rise, n):
    """Pointed (two-centred, elliptic) arch curve from (-half, spring) over the
    apex to (half, spring)."""
    a = 1.15 * half
    t0 = math.acos((half - a) / a)
    left = []
    for k in range(n + 1):
        t = math.pi - (math.pi - t0) * k / n
        left.append((-half + a + a * math.cos(t), spring + rise * math.sin(t) / math.sin(t0)))
    right = [(-x, y) for (x, y) in reversed(left[:-1])]
    return left + right


def extrude(name, outline, z0, z1, mat, g, hi):
    """Simple polygon (local XY, may be concave) extruded from z0 to z1."""
    from mathutils.geometry import tessellate_polygon
    bm = bmesh.new()
    front = [bm.verts.new((x, y, z1)) for x, y in outline]
    back = [bm.verts.new((x, y, z0)) for x, y in outline]
    # Concave caps: ear-clipped triangles (an n-gon would fill the arch).
    for tri in tessellate_polygon([[Vector((x, y, 0.0)) for x, y in outline]]):
        bm.faces.new([front[i] for i in tri])
        bm.faces.new([back[i] for i in reversed(tri)])
    n = len(outline)
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((front[j], front[i], back[i], back[j]))
    return K.finish(bm, name, mat, g, hi, smooth=False)


def merlon(name, x, y, z, w, h, d, mat, g, hi, rot_y=0.0):
    """Rounded-top merlon (İçərişəhər walls), front +z, depth d."""
    hw = w * 0.5
    pts = [(-hw, 0.0), (hw, 0.0)]
    n = L(hi, 4, 10)
    for k in range(n + 1):
        a = math.pi * k / n
        pts.append((math.cos(a) * hw, h - hw + math.sin(a) * hw))
    m = Matrix.Translation(Vector((x, y, z))) @ Matrix.Rotation(rot_y, 4, "Y")
    return puffy(name, pts, d, 0.0, m, mat, g, hi)


def slit(name, x, y, z, rot_y, g, hi):
    bbox(name, (0.3, 1.2, 0.4), (x, y, z), "slit", g, hi, 0.0, rot=(0, rot_y, 0))


def build_gate_arch(hi):
    tag = "H" if hi else "L"
    g = "gate_arch"
    half = SPAN * 0.5
    jamb = half + 1.0
    curve = pointed(half, SPRING, RISE, L(hi, 10, 28))
    outline = [(-jamb, 0.0), (half * -1.0, 0.0)] + curve + [(half, 0.0), (jamb, 0.0), (jamb, WALL_H), (-jamb, WALL_H)]
    # outline order: around the solid (inverted U), counter-clockwise from the outer left foot
    extrude(f"arch_wall_{tag}", list(reversed(outline)), -TH * 0.5, TH * 0.5, "limestone_warm", g, hi)
    # Arch ring mouldings both faces + keystone
    for s in (-1, 1):
        z = s * (TH * 0.5 + 0.12)
        ring = [Vector((x * 1.02, y + 0.12, z)) for (x, y) in curve]
        tube(f"arch_ring{s}_{tag}", ring, 0.22, "trim", g, hi, 1, L(hi, 4, 8), False)
        bbox(f"keystone{s}_{tag}", (1.0, 1.4, 0.35), (0, SPRING + RISE + 0.5, s * (TH * 0.5 + 0.1)), "trim", g, hi,
             L(hi, 0.0, 0.05))
        # Impost blocks at the springing
        for sx in (-1, 1):
            bbox(f"impost{s}{sx}_{tag}", (1.4, 0.45, 0.4), (sx * (half + 0.2), SPRING, s * (TH * 0.5 + 0.1)),
                 "trim", g, hi, L(hi, 0.0, 0.05))
        # Sign panel frame above the arch (the name sign is a Godot label)
        bbox(f"panel{s}_{tag}", (9.0, 1.9, 0.18), (0, 11.2, s * (TH * 0.5 + 0.06)), "stone_dark", g, hi,
             L(hi, 0.0, 0.04))
    # Machicolation: band on corbels, then merlons
    bbox(f"band_{tag}", (jamb * 2.0, 0.8, TH + 1.0), (0, WALL_H - 0.4, 0), "limestone", g, hi, L(hi, 0.0, 0.06))
    nc = int(jamb * 2.0 / 1.6)
    for k in range(nc):
        x = -jamb + 0.8 + k * (jamb * 2.0 / nc)
        for s in (-1, 1):
            bbox(f"corbel{k}{s}_{tag}", (0.6, 0.7, 0.5), (x, WALL_H - 1.15, s * (TH * 0.5 + 0.25)), "limestone", g, hi,
                 L(hi, 0.0, 0.05))
    nm = int(jamb * 2.0 / 2.0)
    for k in range(nm):
        for s in (-1, 1):
            merlon(f"merlon{k}{s}_{tag}", -jamb + 1.0 + k * 2.0, WALL_H, s * (TH * 0.5 + 0.1), 1.1, 1.6, 0.7,
                   "limestone_warm", g, hi)


def round_tower(g, tag, hi, r, h, base_r, merlons, full=True, cz=0.0, slits=()):
    """Battered round tower; full=False builds the outer (-z) half only."""
    up = K.trs((0, 0, 0), (0, 0, math.pi / 2))
    steps = L(hi, 16, 48)
    prof = [(0.0, base_r), (1.8, r), (h, r), (h, 0.0)]
    if full:
        ob = lathe(f"{g}_body_{tag}", prof, (0, 0, 0), "limestone_warm", g, hi, steps, False, False)
        ob.data.transform(up)
        ob.data.transform(Matrix.Translation(Vector((0, 0, cz))))
    else:
        bm = bmesh.new()
        rows = []
        for (yy, rr) in prof:
            row = []
            for k in range(steps // 2 + 1):
                a = math.pi + math.pi * k / (steps // 2)
                row.append(bm.verts.new((math.cos(a) * rr, yy, cz + math.sin(a) * rr)))
            rows.append(row)
        for i in range(len(rows) - 1):
            for k in range(len(rows[i]) - 1):
                bm.faces.new((rows[i][k], rows[i][k + 1], rows[i + 1][k + 1], rows[i + 1][k]))
        K.finish(bm, f"{g}_body_{tag}", "limestone_warm", g, hi,
                 outward=lambda p: Vector((p.x, 2.0 if p.y > h - 0.01 else 0.0, p.z - cz)))
    # Corbel ring and parapet
    ring_n = merlons
    a0, a1 = (0.0, 2 * math.pi) if full else (math.pi, 2 * math.pi)
    for k in range(ring_n):
        t = (k + 0.5) / ring_n
        a = a0 + (a1 - a0) * t
        x, z = math.cos(a) * (r + 0.05), cz + math.sin(a) * (r + 0.05)
        bbox(f"{g}_corbel{k}_{tag}", (0.55, 0.7, 0.6), (x, h - 1.0, z), "limestone", g, hi, L(hi, 0.0, 0.05),
             rot=(0, -a + math.pi / 2, 0))
        merlon(f"{g}_m{k}_{tag}", x, h + 0.55, z, 0.95, 1.4, 0.7, "limestone_warm", g, hi, rot_y=-a + math.pi / 2)
    if full:
        lathe(f"{g}_band_{tag}", [(h - 0.6, r + 0.32), (h + 0.55, r + 0.32), (h + 0.55, r - 0.3)], (0, 0, 0), "limestone",
              g, hi, steps).data.transform(up)
    else:
        bm = bmesh.new()
        rows = []
        for (yy, rr) in [(h - 0.6, r + 0.32), (h + 0.55, r + 0.32), (h + 0.55, 0.0)]:
            row = []
            for k in range(steps // 2 + 1):
                a = math.pi + math.pi * k / (steps // 2)
                row.append(bm.verts.new((math.cos(a) * rr, yy, cz + math.sin(a) * rr)))
            rows.append(row)
        for i in range(len(rows) - 1):
            for k in range(len(rows[i]) - 1):
                bm.faces.new((rows[i][k], rows[i][k + 1], rows[i + 1][k + 1], rows[i + 1][k]))
        K.finish(bm, f"{g}_band_{tag}", "limestone", g, hi,
                 outward=lambda p: Vector((p.x, 2.0 if p.y > h + 0.5 else 0.0, p.z - cz)))
    for i, (a, y) in enumerate(slits):
        slit(f"{g}_slit{i}_{tag}", math.cos(a) * (r - 0.05), y, cz + math.sin(a) * (r - 0.05), -a + math.pi / 2, g, hi)


def pointed_recess(name, cx, z, sz, w, h, g, hi):
    """Blind gate: wooden leaf in a pointed frame, front facing sz."""
    hw = w * 0.5
    curve = pointed(hw, h - hw * 1.1, hw * 1.1, L(hi, 6, 14))
    outline = [(-hw, 0.0)] + curve + [(hw, 0.0)]
    m = Matrix.Translation(Vector((cx, 0.0, z))) @ Matrix.Rotation(0.0 if sz > 0 else math.pi, 4, "Y")
    puffy(f"{name}_leaf", outline, 0.12, 0.0, m, "wood", g, hi)
    ring = [m @ Vector((x * 1.08, y + 0.1, 0.08)) for (x, y) in curve]
    tube(f"{name}_frame", ring, 0.16, "trim", g, hi, 1, L(hi, 4, 8), False)
    if hi:
        for k in range(4):
            y = 0.8 + k * (h - 2.0) / 3.0
            bbox(f"{name}_strap{k}", (w * 0.9, 0.1, 0.06), m @ Vector((0, y, 0.09)), "iron", g, hi, 0.0,
                 rot=(0, 0.0 if sz > 0 else math.pi, 0))


def build_gate_tower(hi):
    tag = "H" if hi else "L"
    g = "gate_tower"
    tw_h = WALL_H + 3.0
    round_tower(g, tag, hi, 4.6, tw_h, 5.1, L(hi, 12, 14), True, 0.0,
                slits=((1.2, 6.0), (2.0, 9.5), (4.4, 6.5), (5.2, 10.0), (0.4, 12.0)))
    # Side block with the blind second gate (the "double" of Qoşa Qala)
    bh = WALL_H - 1.0
    bbox(f"block_{tag}", (8.0, bh, TH), (6.4, bh * 0.5, 0), "limestone_warm", g, hi, L(hi, 0.0, 0.06))
    bbox(f"block_base_{tag}", (8.0, 1.2, TH + 0.6), (6.4, 0.6, 0), "stone_dark", g, hi, L(hi, 0.0, 0.05))
    bbox(f"block_band_{tag}", (8.2, 0.5, TH + 0.5), (6.4, bh - 0.25, 0), "limestone", g, hi, L(hi, 0.0, 0.05))
    for k in range(4):
        for s in (-1, 1):
            merlon(f"block_m{k}{s}_{tag}", 3.4 + k * 2.0, bh, s * (TH * 0.5 + 0.05), 1.1, 1.5, 0.7, "limestone_warm",
                   g, hi)
    for s in (-1, 1):
        pointed_recess(f"blind{s}_{tag}", 6.4, s * (TH * 0.5 + 0.06), s, 3.4, 6.0, g, hi)


def build_wall_seg(hi):
    tag = "H" if hi else "L"
    g = "wall_seg"
    h = 9.0
    bbox(f"seg_body_{tag}", (4.02, h, 2.4), (2.0, h * 0.5, 0), "limestone_warm", g, hi, 0.0)
    bbox(f"seg_base_{tag}", (4.02, 1.6, 3.2), (2.0, 0.8, 0), "stone_dark", g, hi, 0.0)
    bbox(f"seg_top_{tag}", (4.02, 0.35, 2.8), (2.0, h - 0.2, 0), "stone_dark", g, hi, 0.0)
    for k in range(2):
        # Outer (-z) parapet: thin rounded-top merlons; low inner parapet.
        merlon(f"seg_m{k}_{tag}", 1.0 + k * 2.0, h, -1.0, 1.0, 1.5, 0.7, "limestone_warm", g, hi)
    bbox(f"seg_inner_{tag}", (4.02, 0.6, 0.45), (2.0, h + 0.3, 1.05), "limestone_warm", g, hi, 0.0)
    if hi:
        # Putlog holes and a few weathered stones for variety
        for k, (x, y) in enumerate(((0.9, 3.2), (3.1, 5.6), (1.8, 7.1))):
            for s in (-1, 1):
                bbox(f"seg_hole{k}{s}", (0.22, 0.22, 0.1), (x, y, s * 1.2), "slit", g, hi, 0.0)


def build_wall_tower(hi):
    tag = "H" if hi else "L"
    round_tower("wall_tower", tag, hi, 3.4, 11.5, 3.8, L(hi, 7, 8), False, -1.6,
                slits=((math.pi * 1.3, 6.0), (math.pi * 1.7, 7.5)))


def build_wall_end(hi):
    tag = "H" if hi else "L"
    round_tower("wall_end", tag, hi, 3.4, 11.0, 3.8, L(hi, 10, 12), True, 0.0,
                slits=((0.6, 6.0), (2.6, 7.0), (4.4, 5.5)))


OFFSET = {g: Vector((i * 40.0, 0.0, 0.0)) for i, g in enumerate(GROUPS)}


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
    _built(lambda: build_gate_arch(hi), "gate_arch")
    _built(lambda: build_gate_tower(hi), "gate_tower")
    _built(lambda: build_wall_seg(hi), "wall_seg")
    _built(lambda: build_wall_tower(hi), "wall_tower")
    _built(lambda: build_wall_end(hi), "wall_end")


def _home(groups):
    for o in groups:
        o.data.transform(Matrix.Translation(-OFFSET[o.name]))


K.PRE_EXPORT.append(_home)


K.setup("gate_props", "assets/models/gate", PALETTE, PAINT_MAT, GROUPS, UV_SCALE, FAR_RATIO, stone_mats=STONE)
K.run(build)
