"""Shared Blender tooling for Yaska Racing's baked kart + driver models.

Each racer has a small script (yaska_star.py, havhav_buddy.py, ...) that sets
the palette / groups / rig numbers and builds its parts with the helpers here;
run() does the rest: low model per rig node, UV atlas, Cycles bake (colour,
roughness, metallic, paint mask, tangent normal, AO, coverage), dilated 1024
textures, near + far glTF, editable .blend, previews.
  blender --background --factory-startup --python tools/blender/<racer>.py -- [--preview] [--no-bake]
"""

import bpy
import bmesh
import math
import os
import sys
import time
from mathutils import Vector, Matrix, Euler, Quaternion

ARGV = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))


def arg_value(name, default):
    if name in ARGV:
        return ARGV[ARGV.index(name) + 1]
    return default


OUT_DIR = ""  # set by setup()
WORK_DIR = os.path.join(ROOT, "tools", "blender", "out")
BAKE = "--no-bake" not in ARGV
PREVIEW = "--preview" in ARGV
BAKE_RES = int(arg_value("--bake-res", "2048"))
TEX_RES = int(arg_value("--tex-res", "1024"))
FONT_PATH = os.path.join(ROOT, "assets", "fonts", "Baloo2-Variable.ttf")

# --- Per-racer configuration (setup()) -------------------------------------------------
PALETTE = {}
PAINT_MAT = ""
GROUPS = []
UV_SCALE = {}
FAR_RATIO = {}
MODEL = ""
# Materials marked in albedo.png alpha (props: world-space stone detail).
STONE_MATS = []
# Callables run after the bake, before the far copies / export: f(groups).
PRE_EXPORT = []
# Bake ray settings (metres): karts / small props by default; big buildings
# raise them (their high-only details stand further off the low surface).
CAGE = 0.025
RAY = 0.06
AO_DIST = 0.22
# Kart space rig shared by every racer (KartModel / AnimalDriver).
STEER_POS = Vector((0.0, 0.88, -0.30))
STEER_TILT = math.radians(-55.0)
SHOULDER = (0.20, 0.98, 0.17)
ARM_LEN = 0.40
HEAD_PIVOT = Vector((0.0, 1.06, 0.18))
EYES_Y = 1.22


def setup(model, out_dir, palette, paint_mat, groups, uv_scale, far_ratio, stone_mats=()):
    global MODEL, OUT_DIR, PALETTE, PAINT_MAT, GROUPS, UV_SCALE, FAR_RATIO, STONE_MATS
    STONE_MATS = list(stone_mats)
    MODEL = model
    OUT_DIR = os.path.join(ROOT, arg_value("--out-dir", out_dir))
    PALETTE, PAINT_MAT, GROUPS, UV_SCALE, FAR_RATIO = palette, paint_mat, groups, uv_scale, far_ratio


MATS = {}
COLL = None


# --- Scene / materials -------------------------------------------------------------

def srgb_to_lin(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def hex_lin(h):
    return tuple(srgb_to_lin(int(h[i:i + 2], 16) / 255.0) for i in (0, 2, 4))


def reset_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    global COLL
    COLL = bpy.data.collections.new("Yaska")
    bpy.context.scene.collection.children.link(COLL)
    for name, (hx, rough, metal) in PALETTE.items():
        m = bpy.data.materials.new(name)
        m.use_nodes = True
        bsdf = m.node_tree.nodes["Principled BSDF"]
        col = hex_lin(hx)
        bsdf.inputs["Base Color"].default_value = (*col, 1.0)
        bsdf.inputs["Roughness"].default_value = rough
        bsdf.inputs["Metallic"].default_value = metal
        m["yaska"] = [*col, rough, metal]
        m.diffuse_color = (*col, 1.0)
        MATS[name] = m


def finish(bm, name, mat, group, hi, smooth=True, outward=None, keep=False):
    """outward(p) -> direction the face at p must face (open surfaces, where
    recalc_face_normals can guess wrong); keep = leave winding as built."""
    if outward is not None:
        bm.normal_update()
        for f in bm.faces:
            if f.normal.dot(outward(f.calc_center_median())) < 0:
                f.normal_flip()
    elif not keep:
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    for p in me.polygons:
        p.use_smooth = smooth
    me.materials.append(MATS[mat])
    ob = bpy.data.objects.new(name, me)
    COLL.objects.link(ob)
    ob["group"] = group
    ob["hi"] = hi
    return ob


def xform(bm, m):
    bmesh.ops.transform(bm, matrix=m, verts=bm.verts)


def trs(pos=(0, 0, 0), rot=(0, 0, 0), scale=(1, 1, 1)):
    return (Matrix.Translation(Vector(pos)) @ Euler(rot).to_matrix().to_4x4()
            @ Matrix.Diagonal((*scale, 1.0)))


def spow(v, e):
    return math.copysign(abs(v) ** e, v)


# --- Primitive builders (all return objects) -----------------------------------------

def superellipsoid(name, half, center, mat, group, hi, e=(1.0, 1.0), seg=(16, 10),
                   rot=(0, 0, 0), deform=None, matrix=None):
    """Poles along local Y. e=(vertical, horizontal) exponents: 1 = ellipsoid,
    smaller = boxier. deform(p, n) gets the scaled point and unit param coords."""
    segs, rings = seg
    bm = bmesh.new()
    rows = []
    for i in range(1, rings):
        v = -math.pi / 2 + math.pi * i / rings
        row = []
        for j in range(segs):
            u = -math.pi + 2 * math.pi * j / segs
            n = Vector((spow(math.cos(v), e[0]) * spow(math.cos(u), e[1]),
                        spow(math.sin(v), e[0]),
                        spow(math.cos(v), e[0]) * spow(math.sin(u), e[1])))
            p = Vector((n.x * half[0], n.y * half[1], n.z * half[2]))
            if deform:
                p = deform(p, n)
            row.append(bm.verts.new(p))
        rows.append(row)
    pb, pt = Vector((0, -half[1], 0)), Vector((0, half[1], 0))
    if deform:
        pb, pt = deform(pb, Vector((0, -1, 0))), deform(pt, Vector((0, 1, 0)))
    bot, top = bm.verts.new(pb), bm.verts.new(pt)
    for i in range(len(rows) - 1):
        for j in range(segs):
            a, b = rows[i][j], rows[i][(j + 1) % segs]
            c, d = rows[i + 1][(j + 1) % segs], rows[i + 1][j]
            bm.faces.new((a, b, c, d))
    for j in range(segs):
        bm.faces.new((rows[0][(j + 1) % segs], rows[0][j], bot))
        bm.faces.new((rows[-1][j], rows[-1][(j + 1) % segs], top))
    m = matrix if matrix is not None else trs(center, rot)
    xform(bm, m)
    return finish(bm, name, mat, group, hi)


def ellipsoid(name, radii, center, mat, group, hi, seg=(16, 10), rot=(0, 0, 0), matrix=None):
    return superellipsoid(name, radii, center, mat, group, hi, (1.0, 1.0), seg, rot, matrix=matrix)


def capsule(name, a, b, r, mat, group, hi, seg=(12, 8), e=0.7, r_end=None):
    """Rounded limb from a to b (radius r, optionally tapering to r_end)."""
    a, b = Vector(a), Vector(b)
    d = b - a
    half_len = d.length / 2 + r
    r2 = r if r_end is None else r_end

    def taper(p, n):
        k = (n.y + 1) / 2  # 0 at a, 1 at b
        s = (r + (r2 - r) * k) / r
        return Vector((p.x * s, p.y, p.z * s))
    q = Vector((0, 1, 0)).rotation_difference(d.normalized())
    m = Matrix.Translation((a + b) / 2) @ q.to_matrix().to_4x4()
    return superellipsoid(name, (r, half_len, r), (0, 0, 0), mat, group, hi, (e, 1.0), seg,
                          deform=taper, matrix=m)


def torus(name, R, r, matrix, mat, group, hi, seg=(24, 8)):
    """Ring around local Y."""
    bm = bmesh.new()
    rows = []
    for i in range(seg[0]):
        u = 2 * math.pi * i / seg[0]
        row = []
        for j in range(seg[1]):
            t = 2 * math.pi * j / seg[1]
            rr = R + r * math.cos(t)
            row.append(bm.verts.new((rr * math.cos(u), r * math.sin(t), rr * math.sin(u))))
        rows.append(row)
    for i in range(seg[0]):
        for j in range(seg[1]):
            a, b = rows[i][j], rows[(i + 1) % seg[0]][j]
            c, d = rows[(i + 1) % seg[0]][(j + 1) % seg[1]], rows[i][(j + 1) % seg[1]]
            bm.faces.new((a, b, c, d))
    xform(bm, matrix)
    return finish(bm, name, mat, group, hi)


def lathe(name, profile, center, mat, group, hi, steps=24, cap_start=False, cap_end=False, outward=None):
    """Surface of revolution around the X axis; profile = [(x, radius), ...].
    outward(p) in local space (default: away from the axis)."""
    bm = bmesh.new()
    rows = []
    for (x, rad) in profile:
        row = []
        for k in range(steps):
            a = 2 * math.pi * k / steps
            row.append(bm.verts.new((x, rad * math.cos(a), rad * math.sin(a))))
        rows.append(row)
    for i in range(len(rows) - 1):
        for k in range(steps):
            bm.faces.new((rows[i][k], rows[i][(k + 1) % steps], rows[i + 1][(k + 1) % steps], rows[i + 1][k]))
    if cap_start:
        bm.faces.new(list(reversed(rows[0])))
    if cap_end:
        bm.faces.new(rows[-1])
    out = outward or (lambda p: Vector((0.0, p.y, p.z)))
    bm.normal_update()
    for f in bm.faces:
        if f.normal.dot(out(f.calc_center_median())) < 0:
            f.normal_flip()
    xform(bm, Matrix.Translation(Vector(center)))
    return finish(bm, name, mat, group, hi, keep=True)


def catmull(points, samples):
    pts = [Vector(p) for p in points]
    out = []
    for i in range(len(pts) - 1):
        p0 = pts[i - 1] if i > 0 else pts[i] * 2 - pts[i + 1]
        p1, p2 = pts[i], pts[i + 1]
        p3 = pts[i + 2] if i + 2 < len(pts) else pts[i + 1] * 2 - pts[i]
        for s in range(samples):
            t = s / samples
            t2, t3 = t * t, t * t * t
            out.append(0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2
                              + (-p0 + 3 * p1 - 3 * p2 + p3) * t3))
    out.append(pts[-1])
    return out


def tube(name, points, r, mat, group, hi, samples=4, sides=8, caps=True):
    """Swept circle along a Catmull-Rom path (parallel-transport frames)."""
    path = catmull(points, samples)
    bm = bmesh.new()
    rows = []
    tan = (path[1] - path[0]).normalized()
    nrm = tan.orthogonal().normalized()
    for i, p in enumerate(path):
        if i > 0:
            t_new = ((path[min(i + 1, len(path) - 1)] - path[i - 1])).normalized()
            q = tan.rotation_difference(t_new)
            nrm = (q @ nrm).normalized()
            tan = t_new
        bin_ = tan.cross(nrm)
        row = []
        for k in range(sides):
            a = 2 * math.pi * k / sides
            row.append(bm.verts.new(p + (nrm * math.cos(a) + bin_ * math.sin(a)) * r))
        rows.append(row)
    for i in range(len(rows) - 1):
        for k in range(sides):
            bm.faces.new((rows[i][k], rows[i][(k + 1) % sides], rows[i + 1][(k + 1) % sides], rows[i + 1][k]))
    if caps:
        bm.faces.new(list(reversed(rows[0])))
        bm.faces.new(rows[-1])
    return finish(bm, name, mat, group, hi)


def puffy(name, outline, depth, puff, matrix, mat, group, hi):
    """Flat 2D outline (local XY) given thickness, front centre raised by
    `puff` (faceted star / puffy heart look). Front faces +Z."""
    bm = bmesh.new()
    n = len(outline)
    cx = sum(p[0] for p in outline) / n
    cy = sum(p[1] for p in outline) / n
    front = [bm.verts.new((x, y, depth / 2)) for x, y in outline]
    back = [bm.verts.new((x, y, -depth / 2)) for x, y in outline]
    fc = bm.verts.new((cx, cy, depth / 2 + puff))
    bc = bm.verts.new((cx, cy, -depth / 2 - puff * 0.3))
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((front[i], front[j], fc))
        bm.faces.new((back[j], back[i], bc))
        bm.faces.new((front[j], front[i], back[i], back[j]))
    xform(bm, matrix)
    return finish(bm, name, mat, group, hi, smooth=False)


def star_outline(R, r, n=5, rot=0.0):
    pts = []
    for k in range(n * 2):
        a = rot + math.pi / 2 + math.pi * k / n
        rad = R if k % 2 == 0 else r
        pts.append((math.cos(a) * rad, math.sin(a) * rad))
    return pts


def heart_outline(w, steps):
    pts = []
    for k in range(steps):
        t = 2 * math.pi * k / steps
        x = 16 * math.sin(t) ** 3
        y = 13 * math.cos(t) - 5 * math.cos(2 * t) - 2 * math.cos(3 * t) - math.cos(4 * t)
        pts.append((x * w / 34.0, (y + 3) * w / 34.0))
    return pts


def circle_outline(rx, ry, steps, a0=0.0, a1=2 * math.pi):
    return [(math.cos(a0 + (a1 - a0) * k / steps) * rx, math.sin(a0 + (a1 - a0) * k / steps) * ry)
            for k in range(steps)]


def drop_faces(ob, test):
    """Delete low-model faces where test(centre, normal) is true."""
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    bm.normal_update()
    gone = [f for f in bm.faces if test(f.calc_center_median(), f.normal)]
    bmesh.ops.delete(bm, geom=gone, context="FACES")
    bm.to_mesh(ob.data)
    bm.free()


def face_plus_z(bm):
    bm.normal_update()
    for f in bm.faces:
        if f.normal.z < 0:
            f.normal_flip()


def grooves(bm, center, count, depth):
    """Hair strand grooves: radial ripple around the vertical axis through
    `center`, so strands run from the crown down (high model only)."""
    c = Vector(center)
    for v in bm.verts:
        d = v.co - c
        phi = math.atan2(d.x, d.z)
        k = 1.0 + depth * (0.5 + 0.5 * math.cos(phi * count)) ** 3
        v.co = c + d * k


def decal(name, outline, matrix, mat, group, target, offset=0.003, cuts=2):
    """High-poly only: flat 2D shape shrink-wrapped just above `target`."""
    bm = bmesh.new()
    vs = [bm.verts.new((x, y, 0.0)) for x, y in outline]
    f = bm.faces.new(vs)
    bmesh.ops.triangulate(bm, faces=[f])
    if cuts > 0:
        bmesh.ops.subdivide_edges(bm, edges=bm.edges[:], cuts=cuts, use_grid_fill=True)
    face_plus_z(bm)
    xform(bm, matrix)
    ob = finish(bm, name, mat, group, True, keep=True)
    sw = ob.modifiers.new("wrap", "SHRINKWRAP")
    sw.target = target
    sw.wrap_method = "NEAREST_SURFACEPOINT"
    sw.wrap_mode = "ABOVE_SURFACE"
    sw.offset = offset
    ob["decal"] = True
    return ob


def text_decal(name, text, size, matrix, mat, group, target, offset=0.0025, extrude=0.0):
    cu = bpy.data.curves.new(name, "FONT")
    cu.body = text
    try:
        cu.font = bpy.data.fonts.load(FONT_PATH, check_existing=True)
    except Exception:
        pass
    cu.size = size
    cu.align_x = "CENTER"
    cu.align_y = "CENTER"
    cu.extrude = extrude
    cu.resolution_u = 4
    tmp = bpy.data.objects.new(name + "_txt", cu)
    COLL.objects.link(tmp)
    deps = bpy.context.evaluated_depsgraph_get()
    me = bpy.data.meshes.new_from_object(tmp.evaluated_get(deps))
    bpy.data.objects.remove(tmp)
    bm = bmesh.new()
    bm.from_mesh(me)
    bpy.data.meshes.remove(me)
    bmesh.ops.triangulate(bm, faces=bm.faces[:])
    if extrude == 0.0:
        face_plus_z(bm)
    xform(bm, matrix)
    ob = finish(bm, name, mat, group, True, smooth=False, keep=extrude == 0.0)
    if target is not None:
        sw = ob.modifiers.new("wrap", "SHRINKWRAP")
        sw.target = target
        sw.wrap_method = "NEAREST_SURFACEPOINT"
        sw.wrap_mode = "ABOVE_SURFACE"
        sw.offset = offset
        ob["decal"] = True
    return ob


def subsurf(ob, levels):
    if levels > 0:
        m = ob.modifiers.new("sub", "SUBSURF")
        m.levels = levels
        m.render_levels = levels
    return ob


def strands(ob, strength=0.004, scale=0.012):
    """Hair strand grooves (high model only)."""
    tex = bpy.data.textures.get("strands") or bpy.data.textures.new("strands", "WOOD")
    tex.wood_type = "BANDS"
    tex.noise_basis_2 = "SIN"
    tex.noise_scale = scale
    tex.turbulence = 0.0
    d = ob.modifiers.new("strands", "DISPLACE")
    d.texture = tex
    d.texture_coords = "GLOBAL"
    d.strength = strength
    d.mid_level = 0.5
    return ob


def facing(pos, normal, up=(0, 1, 0), size=1.0):
    """Matrix putting local +Z along `normal` at `pos` (for decals / emblems)."""
    z = Vector(normal).normalized()
    upv = Vector(up)
    if abs(z.dot(upv)) > 0.98:
        upv = Vector((0, 0, -1))
    x = upv.cross(z).normalized()
    y = z.cross(x).normalized()
    m = Matrix((x, y, z)).transposed().to_4x4()
    m.translation = Vector(pos)
    return m @ Matrix.Diagonal((size, size, size, 1.0))


def bbox(name, size, center, mat, g, hi, bevel=0.05, rot=(0, 0, 0)):
    """Box with bevelled edges (1 segment low, 3 high)."""
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    xform(bm, Matrix.Diagonal((size[0], size[1], size[2], 1.0)))
    if bevel > 0:
        bmesh.ops.bevel(bm, geom=list(bm.edges), offset=min(bevel, min(size) * 0.3), segments=L(hi, 1, 3),
                        profile=0.5, affect="EDGES", clamp_overlap=True)
    xform(bm, trs(center, rot))
    return finish(bm, name, mat, g, hi, smooth=False)


# --- Shared parts ----------------------------------------------------------------------

def L(hi, lo_val, hi_val):
    return hi_val if hi else lo_val


def build_wheel(group, center, radius, width, outer, hi, text="YASKA"):
    """Chunky tyre + chrome deep-dish rim, axle along X. outer = +1/-1."""
    tag = "H" if hi else "L"
    hw = width / 2
    rin = radius * 0.6
    pts = L(hi, 7, 26)
    prof = []
    for k in range(pts + 1):
        t = math.pi - math.pi * k / pts
        prof.append((hw * spow(math.cos(t), 0.4), rin + (radius - rin) * spow(math.sin(t), 0.35)))
    cx, cy, cz = center
    steps = L(hi, 24, 72)
    tyre = lathe(f"{group}_tyre_{tag}", prof, center, "tire", group, hi, steps, outward=lambda p: p)
    # Rim: lip, deep dish and hub on the outer side; flat disc on the inner side.
    o = outer
    rim_prof = [(o * hw * 0.82, rin * 1.04), (o * hw * 0.86, rin * 0.92), (o * hw * 0.55, rin * 0.84),
                (o * hw * 0.25, rin * 0.62), (o * hw * 0.3, rin * 0.3), (o * hw * 0.62, rin * 0.22),
                (o * hw * 0.7, 0.0)]
    if not hi:
        rim_prof = [rim_prof[0], rim_prof[2], rim_prof[3], rim_prof[5], rim_prof[6]]
    lathe(f"{group}_rim_{tag}", rim_prof, center, "chrome", group, hi, L(hi, 12, 48),
          outward=lambda p: Vector((o, 0.0, 0.0)))
    lathe(f"{group}_rimin_{tag}", [(-o * hw * 0.6, rin * 0.95), (-o * hw * 0.6, 0.0)], center, "rim_purple", group,
          hi, L(hi, 10, 32), outward=lambda p: Vector((-o, 0.0, 0.0)))
    if hi:
        # Chevron tread blocks.
        n = 34
        for k in range(n):
            a = 2 * math.pi * k / n
            for s in (-1, 1):
                bm = bmesh.new()
                bmesh.ops.create_cube(bm, size=1.0)
                xform(bm, trs((s * hw * 0.27, radius + 0.002, 0.0), (0.0, s * 0.5, 0.0),
                              (hw * 0.5, 0.016, 0.03)))
                xform(bm, Matrix.Translation(Vector(center)) @ Matrix.Rotation(a, 4, "X"))
                finish(bm, f"{group}_tread{k}_{s}", "tread", group, True, smooth=False)
        # Sidewall text "YASKA" (3x) and lug nuts.
        rr = (rin + radius) / 2 + 0.005
        for k in range(3):
            a = 2 * math.pi * k / 3 + 0.4
            m = (Matrix.Translation(Vector(center)) @ Matrix.Rotation(a, 4, "X")
                 @ Matrix.Translation(Vector((o * (hw + 0.01), rr, 0.0))) @ Matrix.Rotation(o * math.pi / 2, 4, "Y"))
            text_decal(f"{group}_txt{k}", text, 0.075, m, "tire_text", group, tyre, 0.0025)
        for k in range(5):
            a = 2 * math.pi * k / 5
            bm = bmesh.new()
            bmesh.ops.create_cone(bm, cap_ends=True, segments=6, radius1=0.014, radius2=0.014, depth=0.02)
            xform(bm, Matrix.Translation(Vector((cx + o * hw * 0.32, cy + math.cos(a) * rin * 0.45,
                                                 cz + math.sin(a) * rin * 0.45))) @ Matrix.Rotation(math.pi / 2, 4, "Y"))
            finish(bm, f"{group}_nut{k}", "gold", group, True)
        ellipsoid(f"{group}_cap", (0.02, 0.05, 0.05), (cx + o * hw * 0.38, cy, cz), "rim_purple", group, True, (16, 10))
    return tyre


def build_steering(hi):
    tag = "H" if hi else "L"
    g = "SteeringWheel"
    base = Matrix.Translation(STEER_POS) @ Matrix.Rotation(STEER_TILT, 4, "X")
    torus(f"steer_rim_{tag}", 0.13, 0.022, base, "seat", g, hi, L(hi, (16, 6), (48, 12)))
    for k in range(3):
        a = math.pi / 2 + 2 * math.pi * k / 3
        p0 = base @ Vector((0, 0.0, 0))
        p1 = base @ Vector((math.cos(a) * 0.12, 0.0, math.sin(a) * 0.12))
        tube(f"steer_spoke{k}_{tag}", [p0, p1], 0.012, "graphite", g, hi, 1, L(hi, 5, 10), True)
    hub = ellipsoid(f"steer_hub_{tag}", (0.045, 0.02, 0.045), (0, 0, 0), "body_pink", g, hi,
                    L(hi, (10, 6), (24, 12)), matrix=base)
    if hi:
        puffy("steer_star", star_outline(0.032, 0.014), 0.006, 0.008,
              base @ Matrix.Translation(Vector((0, 0.024, 0))) @ Matrix.Rotation(-math.pi / 2, 4, "X"),
              "gold", g, True)
    return hub


def build_legs(g, hi):
    tag = "H" if hi else "L"
    seg = L(hi, (8, 6), (24, 14))
    for s in (-1, 1):
        n = "LR"[s > 0]
        hip, knee, ankle = (s * 0.11, 0.60, 0.12), (s * 0.14, 0.74, -0.18), (s * 0.15, 0.60, -0.40)
        capsule(f"thigh{n}_{tag}", hip, knee, 0.058, "leggings", g, hi, seg)
        capsule(f"shin{n}_{tag}", knee, ankle, 0.05, "leggings", g, hi, seg, r_end=0.044)
        ellipsoid(f"sock{n}_{tag}", (0.05, 0.03, 0.05), (s * 0.15, 0.585, -0.42), "sock", g, hi, L(hi, (8, 4), (20, 10)),
                  rot=(0.5, 0, 0))
        shoe = superellipsoid(f"shoe{n}_{tag}", (0.065, 0.055, 0.115), (s * 0.15, 0.555, -0.50), "shoe", g, hi,
                              (0.6, 0.7), L(hi, (10, 6), (32, 16)), rot=(0.35, 0, 0))
        superellipsoid(f"sole{n}_{tag}", (0.07, 0.022, 0.12), (s * 0.15, 0.51, -0.51), "sole", g, hi,
                       (0.4, 0.7), L(hi, (10, 4), (32, 10)), rot=(0.35, 0, 0))
        if hi:
            m = facing((s * 0.15, 0.62, -0.53), (0, 0.9, -0.45))
            for k in range(3):
                decal(f"lace{n}{k}", [(-0.03, -0.004), (0.03, -0.004), (0.03, 0.004), (-0.03, 0.004)],
                      m @ Matrix.Translation(Vector((0, -0.02 + k * 0.022, 0))), "sole", g, shoe, 0.003, 1)
            ms = facing((s * 0.216, 0.56, -0.50), (s, 0, 0))
            decal(f"shoestar{n}", star_outline(0.026, 0.012), ms, "star_yellow", g, shoe, 0.003, 1)


def build_eyes(hi):
    tag = "H" if hi else "L"
    g = "Eyes"
    eyes = []
    for s in (-1, 1):
        c = Vector((s * 0.088, EYES_Y, -0.098))
        rot = (0.0, s * 0.22, 0.0)
        e = ellipsoid(f"eye{s}_{tag}", (0.068, 0.088, 0.042), c, "eye_white", g, hi, L(hi, (14, 10), (48, 32)), rot=rot)
        eyes.append(e)
        if hi:
            look = Vector((s * 0.12, 0.0, -1.0)).normalized()
            front = c + Vector((s * 0.006, -0.004, -0.04))
            m = facing(front, look)
            decal(f"iris{s}", circle_outline(0.042, 0.05, 24), m @ Matrix.Translation(Vector((-s * 0.008, -0.004, 0))),
                  "iris_ring", g, e, 0.002, 2)
            decal(f"iris_in{s}", circle_outline(0.034, 0.042, 24), m @ Matrix.Translation(Vector((-s * 0.008, -0.004, 0))),
                  "iris", g, e, 0.003, 2)
            decal(f"pupil{s}", circle_outline(0.018, 0.024, 20), m @ Matrix.Translation(Vector((-s * 0.008, -0.004, 0))),
                  "pupil", g, e, 0.004, 1)
            decal(f"shine{s}", circle_outline(0.011, 0.013, 12), m @ Matrix.Translation(Vector((-s * 0.008 + 0.012, 0.016, 0))),
                  "eye_white", g, e, 0.005, 1)
            decal(f"shine2{s}", circle_outline(0.005, 0.005, 10), m @ Matrix.Translation(Vector((-s * 0.008 - 0.012, -0.018, 0))),
                  "eye_white", g, e, 0.005, 1)
    for s in (-1, 1):
        # Upper lid line: a thin dark arc hugging the top of the eye.
        c = Vector((s * 0.088, EYES_Y, -0.098))
        rm = Euler((0.0, s * 0.22, 0.0)).to_matrix()
        arc = []
        n_arc = L(hi, 6, 16)
        for k in range(n_arc + 1):
            a = 0.25 + (math.pi - 0.5) * k / n_arc
            x, y = math.cos(a) * 0.9, math.sin(a) * 0.9
            z = -math.sqrt(max(0.0, 1 - x * x - y * y))
            arc.append(c + rm @ Vector((x * 0.068, y * 0.088, z * 0.042 - 0.004)))
        tube(f"lid{s}_{tag}", arc, 0.007, "lash", g, hi, 1, L(hi, 4, 8), True)
        for k in range(2):
            a = 0.35 + k * 0.32
            base = Vector((s * (0.088 + math.cos(a) * 0.066), EYES_Y + math.sin(a) * 0.082, -0.118))
            tube(f"lash{s}{k}_{tag}", [base, base + Vector((s * 0.03, 0.018 + k * 0.006, -0.006))], 0.0055,
                 "lash", g, hi, 1, L(hi, 4, 8), True)
    return eyes


def build_arm(group, s, hi):
    tag = "H" if hi else "L"
    sh = Vector((s * SHOULDER[0], SHOULDER[1], SHOULDER[2]))
    ellipsoid(f"{group}_sleeve_{tag}", (0.072, 0.068, 0.08), sh + Vector((0, 0, -0.03)), "shirt", group, hi,
              L(hi, (12, 8), (32, 20)))
    capsule(f"{group}_arm_{tag}", sh + Vector((0, 0, -0.06)), sh + Vector((0, 0, -0.34)), 0.04, "skin", group, hi,
            L(hi, (10, 6), (24, 12)), r_end=0.036)
    torus(f"{group}_cuff_{tag}", 0.04, 0.012, Matrix.Translation(sh + Vector((0, 0, -0.32))) @
          Matrix.Rotation(math.pi / 2, 4, "X"), "hair_tie", group, hi, L(hi, (10, 4), (24, 8)))
    ellipsoid(f"{group}_hand_{tag}", (0.052, 0.048, 0.058), sh + Vector((0, 0, -0.39)), "skin", group, hi,
              L(hi, (10, 6), (28, 16)))
    capsule(f"{group}_thumb_{tag}", sh + Vector((-s * 0.03, 0.025, -0.37)), sh + Vector((-s * 0.045, 0.04, -0.41)),
            0.018, "skin", group, hi, L(hi, (6, 4), (16, 8)))


# --- Mesh utilities ------------------------------------------------------------------

def realize(objs):
    """Apply modifiers (decals first: they shrink-wrap onto unapplied targets)."""
    deps = bpy.context.evaluated_depsgraph_get()
    order = sorted(objs, key=lambda o: 0 if o.get("decal") else 1)
    baked = {}
    for o in order:
        if not o.modifiers:
            continue
        baked[o] = bpy.data.meshes.new_from_object(o.evaluated_get(deps))
    for o, me in baked.items():
        o.modifiers.clear()
        old = o.data
        o.data = me
        if old.users == 0:
            bpy.data.meshes.remove(old)


def tri_count(o):
    o.data.calc_loop_triangles()
    return len(o.data.loop_triangles)


def join_group(name, parts):
    """Merge parts into one object named after the rig node (origin at kart origin)."""
    bm = bmesh.new()
    mats = []
    for p in parts:
        me = p.data.copy()
        me.transform(p.matrix_world)
        base = len(bm.faces)
        remap = []
        for m in me.materials:
            if m not in mats:
                mats.append(m)
            remap.append(mats.index(m))
        bm.from_mesh(me)
        bm.faces.ensure_lookup_table()
        for f in bm.faces[base:]:
            f.material_index = remap[f.material_index] if remap else 0
        bpy.data.meshes.remove(me)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    for m in mats:
        me.materials.append(m)
    for p in parts:
        bpy.data.objects.remove(p)
    ob = bpy.data.objects.new(name, me)
    COLL.objects.link(ob)
    return ob


def select_only(objs, active=None):
    for o in bpy.context.scene.objects:
        if o is not None:
            o.select_set(False)
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = active or (objs[0] if objs else None)


def unwrap(objs):
    bpy.context.scene.tool_settings.use_uv_select_sync = True
    select_only(objs)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(58), island_margin=0.0, area_weight=0.0)
    bpy.ops.uv.average_islands_scale()
    bpy.ops.object.mode_set(mode="OBJECT")
    for o in objs:
        k = UV_SCALE.get(o.name, 1.0)
        uv = o.data.uv_layers.active.data
        for d in uv:
            d.uv = d.uv * k
    select_only(objs)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.select_all(action="SELECT")
    bpy.ops.uv.pack_islands(rotate=True, margin=0.006)
    bpy.ops.object.mode_set(mode="OBJECT")


# --- Baking --------------------------------------------------------------------------

def setup_cycles(samples):
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    try:
        prefs = bpy.context.preferences.addons["cycles"].preferences
        for kind in ("OPTIX", "CUDA"):
            try:
                prefs.compute_device_type = kind
                prefs.refresh_devices()
                gpus = [d for d in prefs.devices if d.type == kind]
                if gpus:
                    for d in prefs.devices:
                        d.use = d.type == kind
                    sc.cycles.device = "GPU"
                    print("BAKE device", kind, [d.name for d in gpus])
                    break
            except Exception:
                continue
    except Exception as e:
        print("GPU setup failed, CPU bake:", e)
    sc.cycles.samples = samples
    sc.cycles.use_denoising = False
    if sc.world is None:
        sc.world = bpy.data.worlds.new("World")
    sc.world.light_settings.distance = AO_DIST


def new_image(name, color, non_color):
    img = bpy.data.images.new(name, BAKE_RES, BAKE_RES, alpha=False, float_buffer=False)
    img.generated_color = color
    if non_color:
        img.colorspace_settings.name = "Non-Color"
    return img


def set_emit(mode):
    for m in MATS.values():
        y = list(m["yaska"])
        col, rough, metal = y[:3], y[3], y[4]
        bsdf = m.node_tree.nodes["Principled BSDF"]
        if mode == "albedo":
            v = tuple(col)
        elif mode == "rough":
            v = (rough,) * 3
        elif mode == "paint":
            masked = PAINT_MAT if isinstance(PAINT_MAT, (list, tuple)) else [PAINT_MAT]
            v = (1.0 if m.name in masked else 0.0,) * 3
        elif mode == "stone":
            v = (1.0 if m.name in STONE_MATS else 0.0,) * 3
        elif mode == "cover":
            v = (1.0, 1.0, 1.0)
        else:
            v = (metal,) * 3
        bsdf.inputs["Emission Color"].default_value = (*v, 1.0)
        bsdf.inputs["Emission Strength"].default_value = 1.0


def bake_all(groups, highs):
    import numpy as np
    setup_cycles(1)
    imgs = {
        "albedo": new_image("bake_albedo", (0.8, 0.4, 0.6, 1), False),
        "rough": new_image("bake_rough", (0.5, 0.5, 0.5, 1), True),
        "metal": new_image("bake_metal", (0, 0, 0, 1), True),
        "normal": new_image("bake_normal", (0.5, 0.5, 1.0, 1), True),
        "ao": new_image("bake_ao", (1, 1, 1, 1), True),
        "paint": new_image("bake_paint", (0, 0, 0, 1), True),
        "cover": new_image("bake_cover", (0, 0, 0, 1), True),
        "stone": new_image("bake_stone", (0, 0, 0, 1), True),
    }
    bake_mat = bpy.data.materials.new("bake_target")
    bake_mat.use_nodes = True
    node = bake_mat.node_tree.nodes.new("ShaderNodeTexImage")
    bake_mat.node_tree.nodes.active = node
    saved = {}
    for o in groups:
        saved[o.name] = list(o.data.materials)
        o.data.materials.clear()
        o.data.materials.append(bake_mat)
        for attr in ("visible_camera", "visible_diffuse", "visible_glossy", "visible_transmission",
                     "visible_volume_scatter", "visible_shadow"):
            setattr(o, attr, False)
    by_group = {}
    for h in highs:
        by_group.setdefault(h["group"], []).append(h)
    # "cover" (margin 0) marks the texels the islands really use, for dilation.
    passes = [("albedo", "EMIT", 4), ("rough", "EMIT", 1), ("metal", "EMIT", 1), ("paint", "EMIT", 4),
              ("normal", "NORMAL", 4), ("ao", "AO", 96), ("cover", "EMIT", 1)]
    if STONE_MATS:
        passes.append(("stone", "EMIT", 1))
    for pname, ptype, samples in passes:
        bpy.context.scene.cycles.samples = samples
        node.image = imgs[pname]
        if ptype == "EMIT":
            set_emit(pname)
        t0 = time.time()
        for o in groups:
            hs = by_group.get(o.name, [])
            if not hs:
                continue
            select_only(hs + [o], o)
            bpy.ops.object.bake(type=ptype, use_selected_to_active=True, cage_extrusion=CAGE,
                                max_ray_distance=RAY, margin=0 if pname == "cover" else 4, margin_type="EXTEND",
                                use_clear=False,
                                normal_space="TANGENT", target="IMAGE_TEXTURES")
        print(f"BAKE {pname}: {time.time() - t0:.1f}s")
    for o in groups:
        o.data.materials.clear()
        for m in saved[o.name]:
            o.data.materials.append(m)
        for attr in ("visible_camera", "visible_diffuse", "visible_glossy", "visible_transmission",
                     "visible_volume_scatter", "visible_shadow"):
            setattr(o, attr, True)

    def px(img):
        a = np.empty(BAKE_RES * BAKE_RES * 4, dtype=np.float32)
        img.pixels.foreach_get(a)
        return a.reshape(BAKE_RES, BAKE_RES, 4)
    alb, ao = px(imgs["albedo"]), px(imgs["ao"])
    rough, metal = px(imgs["rough"]), px(imgs["metal"])
    # Cartoon contact shading: half of the AO also darkens the colour, since
    # Godot's AO only touches ambient light.
    shade = 0.5 + 0.5 * ao[..., :1]
    alb[..., :3] *= shade
    orm = np.ones_like(alb)
    orm[..., 0] = ao[..., 0]
    orm[..., 1] = rough[..., 0]
    orm[..., 2] = metal[..., 0]
    orm[..., 3] = px(imgs["paint"])[..., 0]
    os.makedirs(OUT_DIR, exist_ok=True)

    cover = (px(imgs["cover"])[..., 0] > 0.5).astype(np.float32)
    f = BAKE_RES // TEX_RES

    def shrink(arr):
        # Coverage-weighted 2x2 (f x f) average: empty background never leaks in.
        if f == 1:
            return arr, cover
        w = cover.reshape(TEX_RES, f, TEX_RES, f).sum(axis=(1, 3))
        a = (arr * cover[..., None]).reshape(TEX_RES, f, TEX_RES, f, 4).sum(axis=(1, 3))
        return a / np.maximum(w, 1e-6)[..., None], (w > 0).astype(np.float32)

    def dilate(arr, m, iters=40):
        # Grow island colours into the empty atlas so mipmaps (far LOD, tyre
        # spin blur) never pick up the background colour.
        a = arr * m[..., None]
        for _ in range(iters):
            acc = np.zeros_like(a)
            cnt = np.zeros_like(m)
            for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1), (1, 1), (1, -1), (-1, 1), (-1, -1)):
                acc += np.roll(np.roll(a * m[..., None], dy, 0), dx, 1)
                cnt += np.roll(np.roll(m, dy, 0), dx, 1)
            grow = (m == 0) & (cnt > 0)
            if not grow.any():
                break
            a[grow] = acc[grow] / cnt[grow][..., None]
            m = np.where(grow, 1.0, m).astype(np.float32)
        rest = m == 0
        if rest.any():
            a[rest] = (a * m[..., None]).sum(axis=(0, 1)) / max(m.sum(), 1.0)
        return a

    def save(arr, name, non_color, alpha=False):
        small, m = shrink(arr)
        out = dilate(small, m)
        out[..., 3] = out[..., 3] if alpha else 1.0
        img = bpy.data.images.new(name, TEX_RES, TEX_RES, alpha=alpha)
        if non_color:
            img.colorspace_settings.name = "Non-Color"
        img.pixels.foreach_set(np.clip(out, 0.0, 1.0).astype(np.float32).ravel())
        img.filepath_raw = os.path.join(OUT_DIR, name + ".png")
        img.file_format = "PNG"
        img.save(filepath=img.filepath_raw)
        print("WROTE", img.filepath_raw)
    if STONE_MATS:
        alb[..., 3] = px(imgs["stone"])[..., 0]
    save(alb, "albedo", False, alpha=bool(STONE_MATS))
    save(px(imgs["normal"]), "normal", True)
    save(orm, "orm", True, alpha=True)


# --- Export / preview ------------------------------------------------------------------

def to_blender_up(objs):
    """Godot space (Y up, -Z forward) -> Blender Z up; glTF export (+Y up)
    turns it back into Godot space."""
    rot = Matrix.Rotation(math.pi / 2, 4, "X")
    done = set()
    for o in objs:
        if o.type == "MESH" and o.data not in done:
            o.data.transform(rot)
            done.add(o.data)


def export(objs, path):
    for o in objs:
        o.data.validate(clean_customdata=False)
    select_only(objs)
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True, export_apply=True,
                              export_yup=True, export_materials="NONE", export_normals=True,
                              export_texcoords=True, export_tangents=False, export_animations=False,
                              export_skins=False, export_morph=False, export_cameras=False,
                              export_lights=False)
    print("WROTE", path)


def far_copies(groups):
    out = []
    for o in groups:
        c = o.copy()
        c.data = o.data.copy()
        c.name = o.name + "_far"
        COLL.objects.link(c)
        d = c.modifiers.new("dec", "DECIMATE")
        d.ratio = FAR_RATIO.get(o.name, 0.2)
        out.append(c)
    realize(out)
    for c in out:
        c.name = c.name[:-4] if False else c.name
    return out


def preview(groups, path):
    sc = bpy.context.scene
    setup_cycles(48)
    sc.cycles.use_denoising = True
    sc.render.resolution_x, sc.render.resolution_y = 1400, 900
    mat = bpy.data.materials.new("preview")
    mat.use_nodes = True
    nt = mat.node_tree
    bsdf = nt.nodes["Principled BSDF"]
    for key, sock, nc in (("albedo", "Base Color", False), ("orm", None, True), ("normal", None, True)):
        img = bpy.data.images.load(os.path.join(OUT_DIR, key + ".png"))
        if nc:
            img.colorspace_settings.name = "Non-Color"
        tex = nt.nodes.new("ShaderNodeTexImage")
        tex.image = img
        if key == "albedo":
            nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
        elif key == "orm":
            sep = nt.nodes.new("ShaderNodeSeparateColor")
            nt.links.new(tex.outputs["Color"], sep.inputs["Color"])
            nt.links.new(sep.outputs["Green"], bsdf.inputs["Roughness"])
            nt.links.new(sep.outputs["Blue"], bsdf.inputs["Metallic"])
        else:
            nm = nt.nodes.new("ShaderNodeNormalMap")
            nt.links.new(tex.outputs["Color"], nm.inputs["Color"])
            nt.links.new(nm.outputs["Normal"], bsdf.inputs["Normal"])
    for o in groups:
        o.data.materials.clear()
        o.data.materials.append(mat)
        o.hide_render = False
    sc.world.use_nodes = True
    sc.world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.55, 0.62, 0.75, 1)
    sc.world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.9
    sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN"))
    sun.data.energy = 3.5
    sun.rotation_euler = (math.radians(50), 0, math.radians(30))
    COLL.objects.link(sun)
    plane = bpy.data.meshes.new("ground")
    bm = bmesh.new()
    bmesh.ops.create_grid(bm, x_segments=1, y_segments=1, size=6)
    bm.to_mesh(plane)
    bm.free()
    g = bpy.data.objects.new("ground", plane)
    gm = bpy.data.materials.new("groundmat")
    gm.use_nodes = True
    gm.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.35, 0.33, 0.36, 1)
    plane.materials.append(gm)
    COLL.objects.link(g)
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    cam.data.lens = 50
    COLL.objects.link(cam)
    sc.camera = cam
    # Blender space now: front is +Y, up +Z.
    for name, pos in (("front", (2.6, 3.4, 1.5)), ("rear", (-1.4, -4.2, 2.0)), ("face", (0.35, 1.25, 1.25)),
                      ("wheel", (1.9, 1.6, 0.45))):
        cam.location = Vector(pos)
        target = {"face": Vector((0, 0.12, 1.2)), "wheel": Vector((0.62, 0.72, 0.3))}.get(name, Vector((0, 0.0, 0.62)))
        cam.rotation_euler = (target - cam.location).to_track_quat("-Z", "Y").to_euler()
        cam.data.lens = 85 if name in ("face", "wheel") else 50
        sc.render.filepath = os.path.join(path, f"{MODEL}_preview_{name}.png")
        bpy.ops.render.render(write_still=True)
        print("WROTE", sc.render.filepath)


def run(build):
    t0 = time.time()
    reset_scene()
    os.makedirs(WORK_DIR, exist_ok=True)
    build(False)
    lows = [o for o in COLL.objects if not o["hi"]]
    realize(lows)
    by_name = {g: [o for o in lows if o["group"] == g] for g in GROUPS}
    groups = [join_group(g, by_name[g]) for g in GROUPS]
    total = 0
    for o in groups:
        n = tri_count(o)
        total += n
        print(f"LOW {o.name}: {n} tris")
    print(f"LOW total: {total} tris")
    unwrap(groups)
    build(True)
    highs = [o for o in COLL.objects if o.get("hi")]
    realize(highs)
    by_hi = {g: [o for o in highs if o["group"] == g] for g in GROUPS}
    highs = []
    for gname in GROUPS:
        h = join_group(gname + "_hi", by_hi[gname])
        h["group"] = gname
        h["hi"] = True
        highs.append(h)
    print(f"HIGH total: {sum(tri_count(o) for o in highs)} tris ({time.time() - t0:.0f}s)")
    if BAKE:
        bake_all(groups, highs)
    for f in PRE_EXPORT:
        f(groups)
    far = far_copies(groups)
    print(f"FAR total: {sum(tri_count(o) for o in far)} tris")
    to_blender_up(groups + highs + far)
    os.makedirs(OUT_DIR, exist_ok=True)
    export(groups, os.path.join(OUT_DIR, MODEL + ".glb"))
    for c in far:
        c.name = c.name.replace("_far", "") + "~"
    for o in groups:
        o.name = o.name + "_near"
    for c in far:
        c.name = c.name[:-1]
    export(far, os.path.join(OUT_DIR, MODEL + "_far.glb"))
    for c in far:
        c.name = c.name + "_far"
    for o in groups:
        o.name = o.name[:-5]
    for h in highs:
        h.hide_render = True
        h.hide_set(True)
    for c in far:
        c.hide_render = True
        c.hide_set(True)
    if PREVIEW and BAKE and "Body" in GROUPS:
        preview(groups, WORK_DIR)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(WORK_DIR, MODEL + ".blend"))
    print(f"DONE in {time.time() - t0:.0f}s")

