"""Remaining Baku set pieces for Yaska Racing (0.15.x Blender models).

  blender --background --factory-startup --python tools/blender/plaza_props.py -- --bake-res 4096 --tex-res 2048
Groups (same local frames as LandmarkKit / TrackDecor, front +Z, origin on the
ground):
  hac_base       Heydar Aliyev Center: curved glass front under the shell lip
                 (glass mask -> world-space grid + night glow in the shader),
                 plaza, stairs, terraced lawns with white edges, round pools.
                 The white shell stays LandmarkKit's self-lit mesh.
  flag_square    State Flag Square: radial paving, three-step podium, flag
                 colour rings, 64 m tapered mast with gold ball, eight-point
                 star plaques, lamp ring (globes glow at night). The waving
                 flag stays LandmarkKit.attach_flag.
  gantry_pillar  start / finish gantry leg with base and "YASKA" panels
  gantry_seg     2 m of the gantry beam (two checker squares top and bottom
                 band, both faces), repeated across the road
  gantry_lights  countdown light housing (the lamps are Godot spheres)
  carpet_hang    carpet hanging on a rod with soft folds and fringe (the
                 carpet shader paints the pattern from UVs rebuilt in Godot)
  bunting_pole   pole for the pennant strings (base, collar, finial)
"""

import math
import os
import sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from kart_common import *  # noqa: F401,F403
import kart_common as K
from mathutils import Vector, Matrix

PALETTE = {
    "paving": ("E6DFD2", 0.75, 0.0), "paving_dark": ("BDB3A2", 0.8, 0.0), "white": ("F4F3EF", 0.5, 0.0),
    "limestone": ("D9C29A", 0.85, 0.0), "granite": ("8E8A86", 0.55, 0.0), "lawn": ("4FA83D", 0.9, 0.0),
    "hedge": ("3F8F37", 0.9, 0.0), "water": ("5FC6D6", 0.08, 0.2), "glass": ("2C4A66", 0.08, 0.3),
    "steel": ("C9CDD2", 0.4, 0.35), "metal_dark": ("3A3F48", 0.45, 0.7), "gold": ("E8B84A", 0.3, 1.0),
    "flag_blue": ("00B5E2", 0.6, 0.0), "flag_red": ("EF3340", 0.6, 0.0), "flag_green": ("509E2F", 0.6, 0.0),
    "navy": ("1B2A4A", 0.5, 0.2), "chk_white": ("F7F7F7", 0.5, 0.0), "chk_black": ("1A1C22", 0.5, 0.0),
    "yellow": ("FFC93C", 0.45, 0.0), "lamp_glass": ("FFF1C8", 0.15, 0.0), "cloth": ("B3263A", 0.85, 0.0),
    "fringe": ("F0DDB8", 0.85, 0.0), "wood": ("6A4026", 0.6, 0.0),
}
PAINT_MAT = ["glass", "lamp_glass"]
STONE = ["paving", "paving_dark", "limestone"]
GROUPS = ["hac_base", "flag_square", "gantry_pillar", "gantry_seg", "gantry_lights", "carpet_hang", "bunting_pole"]
UV_SCALE = {"hac_base": 0.55, "flag_square": 0.75, "gantry_pillar": 1.4, "gantry_seg": 1.6, "gantry_lights": 1.5,
            "carpet_hang": 1.6, "bunting_pole": 1.4}
FAR_RATIO = {g: 0.45 for g in GROUPS}
UP = Matrix.Rotation(math.pi / 2, 4, "Z")  # lathe axis X -> Y

# --- Heydar Aliyev Center (same formula as LandmarkKit.hac_point) ---------------
HAC_L = 196.0
HAC_D = 74.0
HAC_EDGE = 0.4


def smooth(a, b, x):
    t = min(max((x - a) / (b - a), 0.0), 1.0)
    return t * t * (3 - 2 * t)


def hac_height(u):
    return smooth(0.0, 0.22, u) * smooth(1.0, 0.7, u) * (
        13.0 + 41.0 * math.exp(-((u - 0.3) / 0.13) ** 2) + 17.0 * math.exp(-((u - 0.66) / 0.1) ** 2))


def hac_point(u, v):
    h = hac_height(u)
    te = math.asin(HAC_EDGE)
    th = math.pi + (te - math.pi) * v
    rz = HAC_D * 0.5
    zc = 5.0 * math.sin(u * math.pi * 1.4 + 0.5) - 4.0
    s = math.sin(th)
    curl = 0.3 * h * s ** 4 * (h / 54.0)
    return Vector(((u - 0.5) * HAC_L, h * s + 0.25, zc + rz * math.cos(th) + curl))


def turned(name, profile, base, mat, g, hi, steps):
    ob = lathe(name, profile, (0, 0, 0), mat, g, hi, steps)
    ob.data.transform(Matrix.Translation(Vector(base)) @ UP)
    return ob


def disc(name, r, y0, y1, mat, g, hi, steps):
    return turned(name, [(y0, r), (y1, r), (y1, 0.0)], (0, 0, 0), mat, g, hi, steps)


def build_hac(hi):
    tag = "H" if hi else "L"
    g = "hac_base"
    te = math.asin(HAC_EDGE)
    vg = (math.pi - (te + 0.32)) / (math.pi - te)
    n = L(hi, 40, 120)
    # Curved glass front: ground line set 2 m back, top on the shell underside.
    bm = bmesh.new()
    bottom, top = [], []
    for i in range(n + 1):
        p = hac_point(i / n, vg)
        if p.y < 2.0:
            p = Vector((p.x, 2.0, p.z))
        top.append(bm.verts.new((p.x, p.y + 0.4, p.z)))
        bottom.append(bm.verts.new((p.x, 0.0, p.z - 2.0)))
    for i in range(n):
        bm.faces.new((bottom[i], bottom[i + 1], top[i + 1], top[i]))
    K.finish(bm, f"hac_glass_{tag}", "glass", g, hi, outward=lambda p: Vector((0, 0, 1)))
    # Entrance canopy and doors at the centre of the glass front.
    for k, x in enumerate((-38.0, 0.0, 30.0)):
        u = x / HAC_L + 0.5
        z = hac_point(u, vg).z - 1.2
        bbox(f"hac_door{k}_{tag}", (9.0, 4.2, 0.4), (x, 2.1, z), "metal_dark", g, hi, L(hi, 0.0, 0.05))
        bbox(f"hac_canopy{k}_{tag}", (12.0, 0.35, 4.0), (x, 4.6, z + 1.6), "white", g, hi, L(hi, 0.0, 0.08))
    # Plaza in front, a wide flight of steps, terraces with white edges, pools.
    front = HAC_D * 0.5 + 4.0
    bbox(f"hac_plaza_{tag}", (HAC_L * 1.05, 0.5, 18.0), (0, 0.25, front + 3.0), "paving", g, hi, 0.0)
    bbox(f"hac_apron_{tag}", (HAC_L * 0.92, 0.3, 14.0), (0, 0.15, front - 12.0), "paving", g, hi, 0.0)
    for k in range(4):
        bbox(f"hac_step{k}_{tag}", (40.0 - k * 2.0, 0.18, 1.2), (0, 0.55 + k * 0.18 - 0.4, front + 12.6 + k * 1.2 - 4.8),
             "white", g, hi, 0.0)
    for k in range(3):
        w = HAC_L * (0.78 - k * 0.12)
        z = front + 18.0 + k * 11.0
        x = k * 8.0 + 6.0
        hgt = 1.6 - k * 0.5
        bbox(f"hac_lawn{k}_{tag}", (w, hgt, 8.0), (x, hgt * 0.5, z), "lawn", g, hi, L(hi, 0.0, 0.3))
        bbox(f"hac_edge{k}_{tag}", (w + 0.6, 0.35, 0.6), (x, hgt + 0.05, z + 4.0), "white", g, hi, L(hi, 0.0, 0.08))
        bbox(f"hac_walk{k}_{tag}", (w, 0.3, 3.0), (x, 0.15, z + 5.5), "paving_dark", g, hi, 0.0)
        # Rounded hedge bands on the terraces
        for j in range(int(w / 16.0)):
            superellipsoid(f"hac_hedge{k}{j}_{tag}", (5.5, 0.7, 1.0), (x - w * 0.5 + 8.0 + j * 16.0, hgt + 0.55, z - 1.5),
                           "hedge", g, hi, (0.6, 0.6), L(hi, (8, 4), (16, 8)))
    for k in range(3):
        cx = -50.0 + k * 50.0
        turned(f"hac_pool_rim{k}_{tag}", [(0.0, 5.0), (0.75, 5.0), (0.75, 4.6), (0.55, 4.6)], (cx, 0, front + 3.0),
               "white", g, hi, L(hi, 20, 56))
        disc(f"hac_pool{k}_{tag}", 4.6, 0.0, 0.62, "water", g, hi, L(hi, 20, 56)).data.transform(
            Matrix.Translation(Vector((cx, 0, front + 3.0))))


def star8(r, ri):
    pts = []
    for k in range(16):
        a = math.pi * k / 8 + math.pi / 2
        rr = r if k % 2 == 0 else ri
        pts.append((math.cos(a) * rr, math.sin(a) * rr))
    return pts


def build_flag_square(hi):
    tag = "H" if hi else "L"
    g = "flag_square"
    steps = L(hi, 28, 96)
    # Plaza with a 4 m skirt: it may stand above sloping ground.
    turned(f"fs_plaza_{tag}", [(-4.0, 34.6), (0.0, 34.6), (0.35, 34.0), (0.35, 0.0)], (0, 0, 0), "paving", g,
           hi, steps)
    # Radial paving joints: darker spokes and rings.
    for k in range(L(hi, 0, 24)):
        a = 2 * math.pi * k / 24
        bbox(f"fs_spoke{k}", (13.0, 0.04, 0.35), (math.cos(a) * 27.0, 0.36, math.sin(a) * 27.0), "paving_dark", g, hi,
             0.0, rot=(0, -a, 0))
    for rr in (26.0, 31.0):
        turned(f"fs_ring{rr}_{tag}", [(0.35, rr), (0.39, rr), (0.39, rr - 0.5), (0.35, rr - 0.5)], (0, 0, 0),
               "paving_dark", g, hi, steps)
    # Flag colour rings, just inside the lamp ring.
    for k, col in enumerate(("flag_blue", "flag_red", "flag_green")):
        r0 = 22.6 + k * 1.6
        turned(f"fs_col{k}_{tag}", [(0.35, r0 + 0.8), (0.5, r0 + 0.8), (0.5, r0), (0.35, r0)], (0, 0, 0), col, g, hi, steps)
    # Three-step podium with rounded nosing.
    for k, rr in enumerate((20.0, 14.5, 9.0)):
        y0 = 0.35 + k * 0.75
        turned(f"fs_step{k}_{tag}", [(y0 - 0.05, rr), (y0 + 0.62, rr), (y0 + 0.75, rr - 0.12), (y0 + 0.75, 0.0)],
               (0, 0, 0), "limestone" if k < 2 else "granite", g, hi, steps)
    # Mast base drum, tapered mast, collar rings, gold ball.
    turned(f"fs_drum_{tag}", [(2.6, 2.4), (3.6, 2.2), (3.8, 1.6), (3.8, 0.0)], (0, 0, 0), "granite", g, hi, L(hi, 20, 48))
    turned(f"fs_mast_{tag}", [(3.8, 0.9), (2.6 + 64.0, 0.45), (2.6 + 64.0, 0.0)], (0, 0, 0), "steel", g, hi, L(hi, 12, 32))
    for k, y in enumerate((8.0, 30.0, 52.0)):
        rr = 0.9 + (0.45 - 0.9) * (y - 1.2) / 64.0 + 0.08
        turned(f"fs_collar{k}_{tag}", [(y, rr), (y + 0.4, rr), (y + 0.4, rr - 0.1), (y, rr - 0.1)], (0, 0, 0), "steel", g,
               hi, L(hi, 12, 32))
    ellipsoid(f"fs_ball_{tag}", (1.0, 1.0, 1.0), (0, 2.6 + 64.0 + 0.7, 0), "gold", g, hi, L(hi, (12, 8), (32, 16)))
    # Eight-point star plaques on the top step (state emblem motif).
    for k in range(4):
        a = math.pi / 4 + k * math.pi / 2
        m = Matrix.Translation(Vector((math.cos(a) * 8.95, 1.85 + 0.62, math.sin(a) * 8.95))) @ \
            Matrix.Rotation(-a + math.pi / 2, 4, "Y")
        puffy(f"fs_star{k}_{tag}", star8(0.55, 0.32), 0.08, L(hi, 0.0, 0.05), m, "gold", g, hi)
    # Lamp ring: slim posts, collar, glowing globes.
    for i in range(8):
        a = 2 * math.pi * i / 8
        x, z = math.cos(a) * 30.0, math.sin(a) * 30.0
        turned(f"fs_post{i}_{tag}", [(0.35, 0.3), (0.9, 0.22), (0.9, 0.12), (5.9, 0.09), (5.9, 0.0)], (x, 0, z),
               "metal_dark", g, hi, L(hi, 8, 16))
        ellipsoid(f"fs_globe{i}_{tag}", (0.55, 0.62, 0.55), (x, 6.4, z), "lamp_glass", g, hi, L(hi, (10, 6), (20, 12)))
        turned(f"fs_cap{i}_{tag}", [(6.95, 0.3), (7.15, 0.12), (7.15, 0.0)], (x, 0, z), "metal_dark", g, hi, L(hi, 8, 16))


# --- Start / finish gantry ------------------------------------------------------
GANTRY_H = 7.6


def build_gantry(hi):
    tag = "H" if hi else "L"
    g = "gantry_pillar"
    bbox(f"gp_foot_{tag}", (1.6, 0.5, 1.6), (0, 0.25, 0), "granite", g, hi, L(hi, 0.0, 0.08))
    bbox(f"gp_leg_{tag}", (0.9, GANTRY_H, 0.9), (0, GANTRY_H * 0.5, 0), "navy", g, hi, L(hi, 0.0, 0.18))
    for s in (-1, 1):
        panel = bbox(f"gp_panel{s}_{tag}", (0.12, 3.0, 0.7), (s * 0.5, 3.4, 0), "yellow", g, hi, L(hi, 0.0, 0.04))
        if hi:
            text_decal(f"gp_text{s}", "YASKA", 0.42, facing((s * 0.57, 3.4, 0), (s, 0, 0), up=(0, 1, 0)), "navy", g,
                       panel)
    bbox(f"gp_cap_{tag}", (1.1, 0.3, 1.1), (0, GANTRY_H + 0.95, 0), "navy", g, hi, L(hi, 0.0, 0.08))

    g = "gantry_seg"
    # 2 m beam piece; top of the beam at GANTRY_H + 1.05 like the old one.
    bbox(f"gs_beam_{tag}", (2.02, 1.5, 1.0), (1.0, GANTRY_H + 0.3, 0), "navy", g, hi, 0.0)
    for s in (-1, 1):
        for row, y in enumerate((GANTRY_H + 0.65, GANTRY_H - 0.05)):
            for k in range(2):
                col = "chk_white" if (k + row) % 2 == 0 else "chk_black"
                bbox(f"gs_chk{s}{row}{k}_{tag}", (1.0, 0.5, 0.04), (0.5 + k, y, s * 0.52), col, g, hi, 0.0)
    bbox(f"gs_rail_{tag}", (2.02, 0.12, 1.15), (1.0, GANTRY_H + 1.08, 0), "steel", g, hi, 0.0)

    g = "gantry_lights"
    # Light box on top of the beam, seen from both sides (the Godot lamps sit
    # at z = 0 and stick out of both faces).
    ly = GANTRY_H + 1.85
    bbox(f"gl_box_{tag}", (5.4, 1.3, 0.6), (0, ly, 0), "metal_dark", g, hi, L(hi, 0.0, 0.1))
    for s in (-1, 1):
        bbox(f"gl_strut{s}_{tag}", (0.25, 0.3, 0.25), (s * 2.2, GANTRY_H + 1.1, 0), "metal_dark", g, hi, 0.0)
    for k in range(3):
        # Hood around each lamp on both faces.
        lathe(f"gl_hood{k}_{tag}", [(-0.6, 0.6), (0.6, 0.6), (0.6, 0.5), (-0.6, 0.5)], (0, 0, 0), "metal_dark", g,
              hi, L(hi, 10, 24)).data.transform(
            Matrix.Translation(Vector((-1.6 + k * 1.6, ly, 0))) @ Matrix.Rotation(math.pi / 2, 4, "Y"))


# --- Hanging carpet ---------------------------------------------------------------
def build_carpet(hi):
    tag = "H" if hi else "L"
    g = "carpet_hang"
    w, h = 1.6, 2.4
    nx, ny = L(hi, 6, 24), L(hi, 6, 24)
    bm = bmesh.new()
    rows = []
    for j in range(ny + 1):
        row = []
        for i in range(nx + 1):
            u, v = i / nx, j / ny
            x = (u - 0.5) * w
            y = h * 0.5 - v * h
            # Soft vertical folds, deeper towards the bottom; a slight belly.
            z = 0.05 * math.sin(u * math.pi * 3.0) * (0.3 + 0.7 * v) + 0.04 * math.sin(v * math.pi)
            row.append(bm.verts.new((x, y, z)))
        rows.append(row)
    for j in range(ny):
        for i in range(nx):
            bm.faces.new((rows[j][i], rows[j + 1][i], rows[j + 1][i + 1], rows[j][i + 1]))
    K.finish(bm, f"carpet_cloth_{tag}", "cloth", g, hi, outward=lambda p: Vector((0, 0, 1)))
    rod = turned(f"carpet_rod_{tag}", [(-0.95, 0.035), (0.95, 0.035)], (0, 0, 0), "wood", g, hi, L(hi, 6, 12))
    rod.data.transform(Matrix.Translation(Vector((0, h * 0.5 + 0.04, 0.03))) @ Matrix.Rotation(-math.pi / 2, 4, "Z"))
    for s in (-1, 1):
        ellipsoid(f"carpet_knob{s}_{tag}", (0.06, 0.06, 0.06), (s * 0.97, h * 0.5 + 0.04, 0.03), "gold", g, hi,
                  L(hi, (6, 4), (12, 8)))
    if hi:
        for k in range(16):
            x = -w * 0.5 + 0.05 + k * (w - 0.1) / 15
            bbox(f"carpet_fringe{k}", (0.03, 0.14, 0.02), (x, -h * 0.5 - 0.06, 0.04 + 0.03), "fringe", g, hi, 0.0)
    else:
        bbox(f"carpet_fringe_L", (w, 0.12, 0.02), (0, -h * 0.5 - 0.05, 0.07), "fringe", g, hi, 0.0)


# --- Bunting pole -------------------------------------------------------------------
def build_bunting_pole(hi):
    tag = "H" if hi else "L"
    g = "bunting_pole"
    turned(f"bp_base_{tag}", [(0.0, 0.22), (0.35, 0.2), (0.45, 0.12), (0.45, 0.0)], (0, 0, 0), "metal_dark", g, hi,
           L(hi, 8, 20))
    turned(f"bp_pole_{tag}", [(0.4, 0.085), (8.5, 0.06), (8.5, 0.0)], (0, 0, 0), "steel", g, hi, L(hi, 6, 14))
    turned(f"bp_collar_{tag}", [(8.05, 0.1), (8.25, 0.1), (8.25, 0.0)], (0, 0, 0), "metal_dark", g, hi, L(hi, 6, 14))
    ellipsoid(f"bp_finial_{tag}", (0.13, 0.18, 0.13), (0, 8.68, 0), "gold", g, hi, L(hi, (8, 6), (16, 10)))


OFFSET = {"hac_base": Vector((0, 0, 0)), "flag_square": Vector((260, 0, 0)), "gantry_pillar": Vector((340, 0, 0)),
          "gantry_seg": Vector((360, 0, 0)), "gantry_lights": Vector((380, 0, 0)), "carpet_hang": Vector((400, 0, 0)),
          "bunting_pole": Vector((410, 0, 0))}


def _built(fn):
    before = set(K.COLL.objects)
    fn()
    for o in set(K.COLL.objects) - before:
        o.data.transform(Matrix.Translation(OFFSET[o["group"]]))


_bumped = False


def add_bump():
    """Large paving slabs with joints on the stone materials."""
    for name in STONE:
        nt = K.MATS[name].node_tree
        bsdf = nt.nodes["Principled BSDF"]
        tc = nt.nodes.new("ShaderNodeTexCoord")
        mp = nt.nodes.new("ShaderNodeMapping")
        mp.inputs["Scale"].default_value = (1 / 1.4, 1 / 0.6, 1 / 1.4)
        vo = nt.nodes.new("ShaderNodeTexVoronoi")
        vo.feature = "DISTANCE_TO_EDGE"
        mr = nt.nodes.new("ShaderNodeMapRange")
        mr.inputs["From Max"].default_value = 0.05
        bump = nt.nodes.new("ShaderNodeBump")
        bump.inputs["Strength"].default_value = 0.5
        bump.inputs["Distance"].default_value = 0.02
        nt.links.new(tc.outputs["Object"], mp.inputs["Vector"])
        nt.links.new(mp.outputs["Vector"], vo.inputs["Vector"])
        nt.links.new(vo.outputs["Distance"], mr.inputs["Value"])
        nt.links.new(mr.outputs["Result"], bump.inputs["Height"])
        nt.links.new(bump.outputs["Normal"], bsdf.inputs["Normal"])


def build(hi):
    global _bumped
    if hi and not _bumped:
        add_bump()
        _bumped = True
    _built(lambda: build_hac(hi))
    _built(lambda: build_flag_square(hi))
    _built(lambda: build_gantry(hi))
    _built(lambda: build_carpet(hi))
    _built(lambda: build_bunting_pole(hi))


def _home(groups):
    for o in groups:
        o.data.transform(Matrix.Translation(-OFFSET[o.name]))


K.PRE_EXPORT.append(_home)

K.setup("plaza_props", "assets/models/plaza", PALETTE, PAINT_MAT, GROUPS, UV_SCALE, FAR_RATIO, stone_mats=STONE)
K.run(build)
