"""Shared shapes and procedural looks for the Qarabağ landmark sets (0.19.1).

Imported by karabakh_khankendi.py / karabakh_shusha.py / karabakh_lachin.py
after `from kart_common import *` (uses kart_common's MATS, finish, bbox, L).
Model frame: x across (width, along the road), y up, z towards the road
(front); origin at the footprint centre on the pad (y 0). Every model has a
plinth / foundation reaching FOUND m below the pad so it never floats.
"""

import math

import bmesh
import bpy
from mathutils import Vector, Matrix, noise
from mathutils.geometry import tessellate_polygon

import kart_common as K

FOUND = 1.5
COLOR_NODES = {}


# --- Looks -----------------------------------------------------------------------------------

def add_looks(look):
    """look: {material: kind}; kinds: cobble, cut, brick, rock, paving, tile, plain, grass.
    Colour (with per-stone tone variation) goes to the albedo bake, relief to the normal bake."""
    for name, kind in look.items():
        m = K.MATS[name]
        nt = m.node_tree
        bsdf = nt.nodes["Principled BSDF"]
        base = tuple(m["yaska"][:3])
        tc = nt.nodes.new("ShaderNodeTexCoord")
        height = None
        if kind == "brick":
            br = nt.nodes.new("ShaderNodeTexBrick")
            br.inputs["Scale"].default_value = 1.0
            br.inputs["Brick Width"].default_value = 0.46
            br.inputs["Row Height"].default_value = 0.13
            br.inputs["Mortar Size"].default_value = 0.014
            br.inputs["Color1"].default_value = (*(c * 1.12 for c in base), 1.0)
            br.inputs["Color2"].default_value = (*(c * 0.8 for c in base), 1.0)
            br.inputs["Mortar"].default_value = (*K.hex_lin("C2B8A4"), 1.0)
            nt.links.new(tc.outputs["Object"], br.inputs["Vector"])
            colour = br.outputs["Color"]
            inv = nt.nodes.new("ShaderNodeMath")
            inv.operation = "SUBTRACT"
            inv.inputs[0].default_value = 1.0
            nt.links.new(br.outputs["Fac"], inv.inputs[1])
            height, strength, dist = inv.outputs[0], 0.8, 0.02
        elif kind in ("cobble", "cut", "paving", "tile"):
            scale = {"cobble": (2.4, 2.9, 2.4), "cut": (1.0, 2.2, 1.0), "paving": (1.0, 1.0, 1.0),
                     "tile": (2.0, 2.0, 2.0)}[kind]
            mp = nt.nodes.new("ShaderNodeMapping")
            mp.inputs["Scale"].default_value = scale
            nt.links.new(tc.outputs["Object"], mp.inputs["Vector"])
            if kind in ("paving", "tile"):
                # square slabs: a brick texture with equal width / height, on the ground plane
                br = nt.nodes.new("ShaderNodeTexBrick")
                br.inputs["Scale"].default_value = 1.0
                br.inputs["Brick Width"].default_value = 1.0
                br.inputs["Row Height"].default_value = 1.0
                br.inputs["Mortar Size"].default_value = 0.025
                br.offset = 0.0
                br.inputs["Color1"].default_value = (*(c * 1.06 for c in base), 1.0)
                br.inputs["Color2"].default_value = (*(c * 0.9 for c in base), 1.0)
                br.inputs["Mortar"].default_value = (*(c * 0.6 for c in base), 1.0)
                sw = nt.nodes.new("ShaderNodeSeparateXYZ")
                cm = nt.nodes.new("ShaderNodeCombineXYZ")
                nt.links.new(mp.outputs["Vector"], sw.inputs["Vector"])
                nt.links.new(sw.outputs["X"], cm.inputs["X"])
                nt.links.new(sw.outputs["Z"], cm.inputs["Y"])
                nt.links.new(cm.outputs["Vector"], br.inputs["Vector"])
                colour = br.outputs["Color"]
                inv = nt.nodes.new("ShaderNodeMath")
                inv.operation = "SUBTRACT"
                inv.inputs[0].default_value = 1.0
                nt.links.new(br.outputs["Fac"], inv.inputs[1])
                height, strength, dist = inv.outputs[0], 0.5, 0.01
            else:
                vo = nt.nodes.new("ShaderNodeTexVoronoi")
                vo.feature = "DISTANCE_TO_EDGE"
                vo.inputs["Scale"].default_value = 1.0
                nt.links.new(mp.outputs["Vector"], vo.inputs["Vector"])
                vc = nt.nodes.new("ShaderNodeTexVoronoi")
                vc.inputs["Scale"].default_value = 1.0
                nt.links.new(mp.outputs["Vector"], vc.inputs["Vector"])
                sc = nt.nodes.new("ShaderNodeSeparateColor")
                nt.links.new(vc.outputs["Color"], sc.inputs["Color"])
                cut = kind == "cut"
                tint = nt.nodes.new("ShaderNodeMapRange")
                tint.inputs["To Min"].default_value = 0.88 if cut else 0.72
                tint.inputs["To Max"].default_value = 1.08 if cut else 1.2
                nt.links.new(sc.outputs["Red"], tint.inputs["Value"])
                joint = nt.nodes.new("ShaderNodeMapRange")
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
                height, strength, dist = hr.outputs["Result"], (0.7 if cut else 0.9), (0.04 if cut else 0.07)
        else:   # rock, plain, grass: noise tone
            no = nt.nodes.new("ShaderNodeTexNoise")
            no.inputs["Scale"].default_value = {"rock": 1.6, "grass": 3.0}.get(kind, 0.8)
            no.inputs["Detail"].default_value = 6.0 if kind == "rock" else 3.0
            nt.links.new(tc.outputs["Object"], no.inputs["Vector"])
            mr = nt.nodes.new("ShaderNodeMapRange")
            mr.inputs["From Min"].default_value = 0.3
            mr.inputs["From Max"].default_value = 0.7
            amp = {"rock": 0.25, "grass": 0.18}.get(kind, 0.06)
            mr.inputs["To Min"].default_value = 1.0 - amp
            mr.inputs["To Max"].default_value = 1.0 + amp
            nt.links.new(no.outputs["Fac"], mr.inputs["Value"])
            mul = nt.nodes.new("ShaderNodeVectorMath")
            mul.operation = "SCALE"
            mul.inputs[0].default_value = base
            nt.links.new(mr.outputs["Result"], mul.inputs["Scale"])
            colour = mul.outputs["Vector"]
            if kind == "rock":
                height, strength, dist = no.outputs["Fac"], 0.9, 0.12
        COLOR_NODES[name] = colour
        if height is not None:
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
        sock = m.node_tree.nodes["Principled BSDF"].inputs["Emission Color"]
        for link in list(sock.links):
            m.node_tree.links.remove(link)
        if mode == "albedo" and name in COLOR_NODES:
            m.node_tree.links.new(COLOR_NODES[name], sock)


K.set_emit = _set_emit


# --- Shapes ----------------------------------------------------------------------------------

def box(name, size, center, mat, g, hi, rot=(0, 0, 0), bevel=0.03):
    return K.bbox(name, size, center, mat, g, hi, K.L(hi, 0.0, bevel), rot=rot)


def slab(name, x0, x1, y0, y1, z0, z1, mat, g, hi, bevel=0.03):
    """Axis-aligned box from its extents."""
    return box(name, (x1 - x0, y1 - y0, z1 - z0), ((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2), mat, g, hi,
               bevel=bevel)


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


def round_arch(half, spring, n, cx=0.0):
    return [(cx - half * math.cos(math.pi * k / n), spring + half * math.sin(math.pi * k / n)) for k in range(n + 1)]


def extrude(name, outline, z0, z1, mat, g, hi, matrix=None):
    """Simple polygon (local XY, may be concave) extruded along z from z0 to z1."""
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
    if matrix is not None:
        K.xform(bm, matrix)
    return K.finish(bm, name, mat, g, hi, smooth=False)


def prism(name, poly_xz, y0, y1, mat, g, hi, apex=None):
    """Polygon in plan (x, z) from y0 to y1; capped flat, or with a pyramid to `apex`."""
    bm = bmesh.new()
    bot = [bm.verts.new((x, y0, z)) for x, z in poly_xz]
    top = [bm.verts.new((x, y1, z)) for x, z in poly_xz]
    n = len(poly_xz)
    bm.faces.new(bot)
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((bot[i], bot[j], top[j], top[i]))
    if apex is None:
        bm.faces.new(list(reversed(top)))
    else:
        a = bm.verts.new(apex)
        for i in range(n):
            bm.faces.new((top[i], top[(i + 1) % n], a))
    return K.finish(bm, name, mat, g, hi, smooth=False)


def cylinder(name, r, y0, y1, center_xz, mat, g, hi, seg=(8, 20), r_top=None):
    n = K.L(hi, seg[0], seg[1])
    cx, cz = center_xz
    rt = r if r_top is None else r_top
    poly = [(cx + r * math.cos(2 * math.pi * k / n), cz + r * math.sin(2 * math.pi * k / n)) for k in range(n)]
    bm = bmesh.new()
    bot = [bm.verts.new((x, y0, z)) for x, z in poly]
    top = [bm.verts.new((cx + (x - cx) * rt / r, y1, cz + (z - cz) * rt / r)) for x, z in poly]
    bm.faces.new(bot)
    bm.faces.new(list(reversed(top)))
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((bot[i], bot[j], top[j], top[i]))
    return K.finish(bm, name, mat, g, hi, smooth=hi)


def cone(name, r, y0, y1, center_xz, mat, g, hi, seg=(8, 20)):
    n = K.L(hi, seg[0], seg[1])
    cx, cz = center_xz
    poly = [(cx + r * math.cos(2 * math.pi * k / n), cz + r * math.sin(2 * math.pi * k / n)) for k in range(n)]
    return prism(name, poly, y0, y0 + 0.001, mat, g, hi, apex=(cx, y1, cz))


def dome(name, r, y0, center_xz, mat, g, hi, rise=1.0, seg=(8, 20), rings=(3, 8), point=0.0):
    """Hemisphere-ish dome (rise x r tall), optionally pointed (point > 0)."""
    n = K.L(hi, seg[0], seg[1])
    m = K.L(hi, rings[0], rings[1])
    cx, cz = center_xz
    bm = bmesh.new()
    rows = []
    for i in range(m):
        a = math.pi / 2 * i / m
        rr = r * math.cos(a)
        yy = y0 + r * rise * math.sin(a) * (1.0 + point * math.sin(a) ** 4)
        rows.append([bm.verts.new((cx + rr * math.cos(2 * math.pi * k / n), yy, cz + rr * math.sin(2 * math.pi * k / n)))
                     for k in range(n)])
    top = bm.verts.new((cx, y0 + r * rise * (1.0 + point), cz))
    for i in range(m - 1):
        for k in range(n):
            j = (k + 1) % n
            bm.faces.new((rows[i][k], rows[i][j], rows[i + 1][j], rows[i + 1][k]))
    for k in range(n):
        bm.faces.new((rows[-1][k], rows[-1][(k + 1) % n], top))
    bm.faces.new(list(reversed(rows[0])))
    bm.normal_update()
    c = Vector((cx, y0, cz))
    for f in bm.faces:
        if f.normal.dot(f.calc_center_median() - c) < 0:
            f.normal_flip()
    return K.finish(bm, name, mat, g, hi, smooth=hi, keep=True)


def rock(name, radii, center, seed, mat, g, hi, sub=2):
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=sub, radius=1.0)
    for v in bm.verts:
        k = 1.0 + 0.3 * noise.noise(v.co * 1.6 + Vector((seed * 7.3, seed * 1.9, 0.0)))
        v.co = Vector((v.co.x * radii[0] * k + center[0], v.co.y * radii[1] * k + center[1],
                       v.co.z * radii[2] * k + center[2]))
    return K.finish(bm, name, mat, g, hi, smooth=False)


def text3d(name, text, size, matrix, mat, g, hi, depth=0.12, font=None):
    """Extruded letters (low and high: big signs must read from the road).
    Local frame before `matrix`: centred, facing +z, `size` = cap height-ish."""
    cu = bpy.data.curves.new(name, "FONT")
    cu.body = text
    try:
        cu.font = bpy.data.fonts.load(font or K.FONT_PATH, check_existing=True)
    except Exception:
        pass
    cu.size = size
    cu.align_x = "CENTER"
    cu.align_y = "CENTER"
    cu.extrude = depth / 2
    cu.resolution_u = K.L(hi, 1, 3)
    tmp = bpy.data.objects.new(name + "_txt", cu)
    K.COLL.objects.link(tmp)
    deps = bpy.context.evaluated_depsgraph_get()
    me = bpy.data.meshes.new_from_object(tmp.evaluated_get(deps))
    bpy.data.objects.remove(tmp)
    bm = bmesh.new()
    bm.from_mesh(me)
    bpy.data.meshes.remove(me)
    bmesh.ops.triangulate(bm, faces=bm.faces[:])
    # curve text lies in XY facing +Z: that is already our frame (x across, y up, z front)
    K.xform(bm, matrix)
    return K.finish(bm, name, mat, g, hi, smooth=False)


def tree_ball(name, center, r, mat, g, hi, seed=0.0):
    """Clipped park tree crown (low-poly ball)."""
    return rock(name, (r, r * 0.9, r), center, seed, mat, g, hi, sub=K.L(hi, 1, 2))


def run_set(groups, build_fns, offsets_step=120.0):
    """Build each group at its own offset (bakes do not overlap), home them before export."""
    offset = {g: Vector((i * offsets_step, 0.0, 0.0)) for i, g in enumerate(groups)}

    def build(hi):
        for g in groups:
            before = set(K.COLL.objects)
            build_fns[g](hi)
            for o in set(K.COLL.objects) - before:
                o.data.transform(Matrix.Translation(offset[g]))

    def home(objs):
        for o in objs:
            o.data.transform(Matrix.Translation(-offset[o.name]))
    K.PRE_EXPORT.append(home)
    return build
