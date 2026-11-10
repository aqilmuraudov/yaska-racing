"""Qarabağ terrain for Yaska Racing (0.18.0), built and baked in Blender.

  godot --headless --path . -s tools/export_road_samples.gd -- karabakh
  blender --background --factory-startup --python tools/blender/karabakh_terrain.py [-- --res 2048 --no-bake]

Reads tools/blender/out/karabakh_road.json (TrackPath samples: the road is
the one source of truth) and data/tracks/karabakh.json (landmark plots).
Writes assets/models/karabakh/:
  terrain.glb        Tile_<i>_<j> (near) + Tile_<i>_<j>_far, Mountains, River
  terrain_albedo.png the valley around the course, baked (colour x AO)
  mountains_albedo.png the ring of mountains
  heights.bin + heights.json  the height grid Godot samples (tree / prop
                     placement, TrackBuilder.terrain_height)
  trees.json         the forest: [kind, x, y, z, yaw, scale] in Godot space
Godot space throughout the maths (x east, y up, z south); meshes are built
in Blender space (X = x, Y = -z, Z = y) and the glTF export (+Y up) turns
them back.

The landscape (north = -z):
  * Laçın: the start straight in the river valley (y 0) in the west.
  * the climb to the Şuşa plateau (y 28-34) in the north-east; east of the
    plateau the Daşaltı gorge drops ~60 m below a limestone cliff.
  * the descent towards Xankəndi and the forest valley road back west; the
    Həkəri river runs along the south of the valley.
  * a ring of forested mountains (to ~150 m) closes the horizon.
Beside the road the ground always stays below the road surface (0.7 m under
the verge), then blends into the hillside within ~25 m (cut / fill banks).
"""

import json
import math
import os
import random
import sys
import time

import bmesh
import bpy
import numpy as np
from mathutils import Vector, kdtree

ARGV = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []


def arg(name, default):
    return ARGV[ARGV.index(name) + 1] if name in ARGV else default


ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "assets", "models", "karabakh")
WORK = os.path.join(ROOT, "tools", "blender", "out")
RES = int(arg("--res", "2048"))
BAKE = "--no-bake" not in ARGV
RENDER = "--render" in ARGV

ROAD = json.load(open(os.path.join(WORK, "karabakh_road.json"), encoding="utf-8"))
TRACK = json.load(open(os.path.join(ROOT, "data", "tracks", "karabakh.json"), encoding="utf-8"))
PTS = np.array(ROAD["points"], dtype=np.float64)  # (n, 3) x, y, z
HW = np.array(ROAD["half_widths"], dtype=np.float64)
OW = float(ROAD["offroad_width"])
PLOTS = TRACK.get("landmark_plots", [])

# Inner (detailed) region and the mountain ring, in Godot x / z.
CELL = 3.0
X0, X1 = -612.0, 600.0
Z0, Z1 = -372.0, 444.0
MCELL = 16.0
MX0, MX1 = -1712.0, 1712.0
MZ0, MZ1 = -1600.0, 1680.0
TILE = 152.0  # near tiles (multiple of CELL in metres: 50.67 cells -> use cell counts)
TILE_CELLS = 48

# Landscape anchors (Godot x, z).
SHUSHA = (230.0, -215.0)      # plateau centre, north of the plateau road
# Daşaltı gorge: a winding canyon east of the plateau / descent (centreline).
GORGE = np.array([[470.0, -420.0], [452.0, -260.0], [468.0, -130.0], [478.0, -10.0], [462.0, 110.0],
                  [430.0, 230.0], [455.0, 380.0]])
RIVER_Z = 262.0               # Həkəri river, south of the valley road


# --- Noise -------------------------------------------------------------------------

_rng = np.random.RandomState(1918)
_PERM = _rng.permutation(256)
_PERM = np.concatenate([_PERM, _PERM])
_GRAD = _rng.uniform(-1, 1, 256)


def vnoise(x, z):
    """Smooth value noise in [-1, 1] (vectorised)."""
    xi = np.floor(x).astype(np.int64)
    zi = np.floor(z).astype(np.int64)
    xf = x - xi
    zf = z - zi
    u = xf * xf * (3 - 2 * xf)
    v = zf * zf * (3 - 2 * zf)

    def h(i, j):
        return _GRAD[_PERM[(_PERM[i & 255] + j) & 255]]
    a = h(xi, zi)
    b = h(xi + 1, zi)
    c = h(xi, zi + 1)
    d = h(xi + 1, zi + 1)
    return (a + (b - a) * u) + ((c + (d - c) * u) - (a + (b - a) * u)) * v


def fbm(x, z, octaves=5, scale=1.0 / 160.0, gain=0.5):
    s = np.zeros_like(x)
    amp = 1.0
    f = scale
    for o in range(octaves):
        s += amp * vnoise(x * f + o * 17.3, z * f - o * 9.1)
        amp *= gain
        f *= 2.03
    return s


def ridge(x, z, scale=1.0 / 260.0):
    """Ridged noise in [0, 1]: sharp mountain crests."""
    s = np.zeros_like(x)
    amp = 0.6
    f = scale
    for o in range(4):
        s += amp * (1.0 - np.abs(vnoise(x * f + 40 + o * 11.0, z * f - 70 - o * 5.0)))
        amp *= 0.5
        f *= 2.1
    return s / 1.125


def smooth(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0.0, 1.0)
    return t * t * (3 - 2 * t)


# --- Road queries --------------------------------------------------------------------

_tree = kdtree.KDTree(len(PTS))
for i, p in enumerate(PTS):
    _tree.insert((p[0], p[2], 0.0), i)
_tree.balance()


def road_query(xs, zs):
    """Nearest road sample: distance (plan), road height, edge distance."""
    d = np.empty(xs.size)
    y = np.empty(xs.size)
    e = np.empty(xs.size)
    for k, (x, z) in enumerate(zip(xs.ravel(), zs.ravel())):
        _co, i, dist = _tree.find((x, z, 0.0))
        d[k] = dist
        y[k] = PTS[i, 1]
        e[k] = HW[i] + OW + 0.6
    return d.reshape(xs.shape), y.reshape(xs.shape), e.reshape(xs.shape)


def inside_loop(xs, zs):
    """Even-odd test against the road centreline polygon."""
    px = PTS[:, 0]
    pz = PTS[:, 2]
    qx = np.roll(px, -1)
    qz = np.roll(pz, -1)
    res = np.zeros(xs.shape, dtype=bool)
    fx = xs.ravel()
    fz = zs.ravel()
    out = np.zeros(fx.size, dtype=bool)
    for a, b, c, d in zip(px, pz, qx, qz):
        cond = (b > fz) != (d > fz)
        with np.errstate(divide="ignore", invalid="ignore"):
            xint = a + (fz - b) * (c - a) / (d - b)
        out ^= cond & (fx < xint)
    res[:] = out.reshape(xs.shape)
    return res


def idw_road_height(xs, zs, power=2.0, every=4):
    """Inverse-distance weighted road height (the valley floor follows the road)."""
    sub = PTS[::every]
    num = np.zeros(xs.size)
    den = np.zeros(xs.size)
    fx = xs.ravel()
    fz = zs.ravel()
    for p in sub:
        w = 1.0 / np.maximum((fx - p[0]) ** 2 + (fz - p[2]) ** 2, 25.0) ** (power / 2)
        num += w * p[1]
        den += w
    return (num / den).reshape(xs.shape)


def polyline_dist(xs, zs, poly):
    """Plan distance to a polyline (vectorised)."""
    d = np.full(xs.shape, 1e9)
    for (ax, az), (bx, bz) in zip(poly[:-1], poly[1:]):
        vx, vz = bx - ax, bz - az
        t = np.clip(((xs - ax) * vx + (zs - az) * vz) / (vx * vx + vz * vz), 0.0, 1.0)
        d = np.minimum(d, np.hypot(xs - (ax + t * vx), zs - (az + t * vz)))
    return d


def river_center(xs):
    return RIVER_Z + 16.0 * np.sin(xs / 95.0) + 9.0 * np.sin(xs / 41.0 + 1.3)


# --- Height ----------------------------------------------------------------------------

def natural(xs, zs, droad, inside):
    """The landscape before the road is cut in."""
    base = idw_road_height(xs, zs)
    n = fbm(xs, zs)
    h = base + n * 2.2
    # Inside the loop: a forested hump between the valley and the plateau.
    hump = 9.0 * np.exp(-(((xs - 120.0) / 140.0) ** 2 + ((zs - 40.0) / 90.0) ** 2))
    h = np.where(inside, h + hump * smooth(20.0, 70.0, droad), h)
    # Outside: the mountain ring rises with distance from the course.
    far = smooth(70.0, 520.0, droad)
    mount = (55.0 + 95.0 * ridge(xs, zs)) * far * far + fbm(xs, zs, 4, 1.0 / 90.0) * 6.0 * far
    h = np.where(inside, h, h + mount)
    # Şuşa plateau: a raised table north of the plateau road.
    dsx = (xs - SHUSHA[0]) / 210.0
    dsz = (zs - SHUSHA[1]) / 120.0
    plate = 1.0 - smooth(0.85, 1.25, np.sqrt(dsx * dsx + dsz * dsz))
    h = np.maximum(h, (33.0 + fbm(xs, zs, 3, 1.0 / 60.0) * 1.5) * plate)
    # Daşaltı gorge east of the descent: limestone cliffs, then the gorge floor.
    dg = polyline_dist(xs, zs, GORGE) + fbm(xs, zs, 3, 1.0 / 45.0) * 9.0
    cut = 1.0 - smooth(22.0, 48.0, dg)
    h = h * (1.0 - cut) + (-32.0 + fbm(xs, zs, 3, 1.0 / 50.0) * 3.0) * cut
    # Həkəri river valley along the south.
    dr = np.abs(zs - river_center(xs))
    bank = smooth(14.0, 70.0, dr)
    valley_floor = -3.0 + fbm(xs, zs, 3, 1.0 / 70.0) * 0.6
    south = zs > 200.0
    h = np.where(south, valley_floor + (h - valley_floor) * bank, h)
    h = np.where(south & (dr < 11.0), -5.2 + dr * 0.05, h)
    return h


def height(xs, zs, with_canopy=False):
    droad, yroad, edge = road_query(xs, zs)
    inside = inside_loop(xs, zs)
    nat = natural(xs, zs, droad, inside)
    # Cut the road in: 0.7 m under the verge, banks blending within ~25 m.
    k = droad - (edge + 1.2)
    t = smooth(0.0, 25.0, k)
    h = (yroad - 0.7) * (1.0 - t) + nat * t
    cut_max = yroad - 0.5 + np.maximum(k, 0.0) * 0.9     # cut slope <= ~42 deg
    fill_min = yroad - 0.7 - np.maximum(k, 0.0) * 1.4
    h = np.clip(h, fill_min, cut_max)
    h = np.where(k < 0.0, yroad - 0.7, h)
    info = {"droad": droad, "yroad": yroad, "edge": edge, "inside": inside}
    return h, info


# --- Build ------------------------------------------------------------------------------

def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    coll = bpy.data.collections.new("Karabakh")
    bpy.context.scene.collection.children.link(coll)
    return coll


def grid_mesh(name, coll, xs, zs, hs, uv_rect, keep=None, attrs=None):
    """Heightfield mesh from (nz, nx) arrays. keep(i, j) -> bool per cell."""
    nz, nx = hs.shape
    bm = bmesh.new()
    verts = {}
    uvl = bm.loops.layers.uv.new("UVMap")
    layers = {}
    for an in (attrs or {}):
        layers[an] = bm.verts.layers.float.new(an)

    def vert(i, j):
        key = (i, j)
        if key not in verts:
            v = bm.verts.new((xs[i, j], -zs[i, j], hs[i, j]))
            for an, arr in (attrs or {}).items():
                v[layers[an]] = float(arr[i, j])
            verts[key] = v
        return verts[key]
    ux0, uz0, uw, uh = uv_rect
    for i in range(nz - 1):
        for j in range(nx - 1):
            if keep is not None and not keep(i, j):
                continue
            q = [vert(i, j), vert(i, j + 1), vert(i + 1, j + 1), vert(i + 1, j)]
            f = bm.faces.new((q[0], q[3], q[2], q[1]))  # Blender +Z normal up
            for loop in f.loops:
                co = loop.vert.co
                loop[uvl].uv = ((co.x - ux0) / uw, 1.0 - ((-co.y) - uz0) / uh)
    bmesh.ops.triangulate(bm, faces=bm.faces)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    for p in me.polygons:
        p.use_smooth = True
    ob = bpy.data.objects.new(name, me)
    coll.objects.link(ob)
    return ob


def decimate(ob, ratio, protect=None):
    m = ob.modifiers.new("dec", "DECIMATE")
    m.decimate_type = "COLLAPSE"
    m.ratio = ratio
    if protect:
        m.vertex_group = protect
        m.vertex_group_factor = 4.0
        m.invert_vertex_group = True
    bpy.context.view_layer.objects.active = ob
    deps = bpy.context.evaluated_depsgraph_get()
    me = bpy.data.meshes.new_from_object(ob.evaluated_get(deps))
    ob.modifiers.clear()
    old = ob.data
    ob.data = me
    bpy.data.meshes.remove(old)


def tri_count(ob):
    ob.data.calc_loop_triangles()
    return len(ob.data.loop_triangles)


# --- Forest ------------------------------------------------------------------------------

SPECIES = ["kb_beech", "kb_oak", "kb_hornbeam", "kb_maple", "kb_pine"]
TREE_BAND = 82.0        # instanced trees up to this far from the road edge
CANOPY_START = 74.0     # beyond it the hillside carries the forest canopy


def plot_clear(x, z, margin=0.0):
    for pl in PLOTS:
        if (x - pl[0]) ** 2 + (z - pl[1]) ** 2 < (pl[2] + margin) ** 2:
            return False
    return True


def scatter_forest(hfun):
    rnd = random.Random(2026)
    pts = []
    step = 7.0
    xs = np.arange(X0 + 4, X1 - 4, step)
    zs = np.arange(Z0 + 4, Z1 - 4, step)
    gx, gz = np.meshgrid(xs, zs)
    gx = gx + np.array([[rnd.uniform(-2.6, 2.6) for _ in range(gx.shape[1])] for _ in range(gx.shape[0])])
    gz = gz + np.array([[rnd.uniform(-2.6, 2.6) for _ in range(gx.shape[1])] for _ in range(gx.shape[0])])
    h, info = hfun(gx, gz)
    # slope from neighbouring samples
    hx, _ = hfun(gx + 1.5, gz)
    hz, _ = hfun(gx, gz + 1.5)
    slope = np.sqrt(((hx - h) / 1.5) ** 2 + ((hz - h) / 1.5) ** 2)
    k = info["droad"] - info["edge"]
    for idx in np.ndindex(gx.shape):
        x, z, y = float(gx[idx]), float(gz[idx]), float(h[idx])
        kk = float(k[idx])
        if kk < 5.0 or kk > TREE_BAND:
            continue
        if not plot_clear(x, z, 3.0):
            continue
        if z > 200.0 and abs(z - float(river_center(np.array([x]))[0])) < 15.0:
            continue
        s = float(slope[idx])
        # A meadow strip along the road, then closed forest.
        if rnd.random() < max(0.0, 1.0 - (kk - 5.0) / 22.0) * 0.8:
            if kk < 30.0 and rnd.random() < 0.08:
                pts.append(["kb_bush", x, y - 0.15, z, rnd.uniform(0, 6.28), rnd.uniform(0.8, 1.3)])
            continue
        if s > 1.1:  # cliff: rocks, no trees
            if rnd.random() < 0.35:
                pts.append(["kb_rock", x, y - 0.4, z, rnd.uniform(0, 6.28), rnd.uniform(0.8, 1.8)])
            continue
        r = rnd.random()
        high = y > 18.0
        if s > 0.6 and high and r < 0.35:
            kind = "kb_pine"
        elif r < (0.42 if high else 0.25):
            kind = "kb_beech"
        elif r < 0.70:
            kind = "kb_oak" if not high or rnd.random() < 0.5 else "kb_beech"
        elif r < 0.93:
            kind = "kb_hornbeam"
        else:
            kind = "kb_maple"
        sc = rnd.uniform(0.85, 1.25)
        if kk < 14.0:
            sc *= 0.85
        pts.append([kind, round(x, 2), round(y - 0.25, 2), round(z, 2), round(rnd.uniform(0, 6.28), 3), round(sc, 3)])
        if 14.0 < kk < 40.0 and rnd.random() < 0.12:
            a = rnd.uniform(0, 6.28)
            bx, bz = x + math.cos(a) * 3.2, z + math.sin(a) * 3.2
            bh, _ = hfun(np.array([[bx]]), np.array([[bz]]))
            pts.append(["kb_bush", round(bx, 2), round(float(bh[0, 0]) - 0.15, 2), round(bz, 2), round(a, 3), 1.0])
    return pts


def canopy(xs, zs, info):
    """Forest canopy carried by the far hillsides (seen as forest from the road)."""
    k = info["droad"] - info["edge"]
    lumps = 6.5 + 2.5 * fbm(xs, zs, 3, 1.0 / 14.0) + 1.5 * fbm(xs, zs, 2, 1.0 / 40.0)
    on = smooth(CANOPY_START, CANOPY_START + 24.0, k)
    cliff = np.zeros_like(xs)
    return lumps * on, on


# --- Materials and bake --------------------------------------------------------------------

def terrain_material(name, crown_scale=0.22):
    """Emission material for the colour bake: meadow / forest floor / canopy /
    rock / verge / river bed, from attributes and the geometry."""
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    for n in list(nt.nodes):
        nt.nodes.remove(n)
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    emit = nt.nodes.new("ShaderNodeEmission")
    nt.links.new(emit.outputs["Emission"], out.inputs["Surface"])
    geo = nt.nodes.new("ShaderNodeNewGeometry")
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    nt.links.new(geo.outputs["Normal"], sep.inputs["Vector"])

    def attr(an):
        a = nt.nodes.new("ShaderNodeAttribute")
        a.attribute_name = an
        return a.outputs["Fac"]

    def mix(fac, c1, c2):
        mx = nt.nodes.new("ShaderNodeMix")
        mx.data_type = "RGBA"
        if isinstance(fac, float):
            mx.inputs[0].default_value = fac
        else:
            nt.links.new(fac, mx.inputs[0])
        for sock, c in ((6, c1), (7, c2)):
            if isinstance(c, tuple):
                mx.inputs[sock].default_value = (*c, 1.0)
            else:
                nt.links.new(c, mx.inputs[sock])
        return mx.outputs[2]

    def noise(scale, detail=4.0):
        tc = nt.nodes.new("ShaderNodeTexCoord")
        no = nt.nodes.new("ShaderNodeTexNoise")
        no.inputs["Scale"].default_value = scale
        no.inputs["Detail"].default_value = detail
        nt.links.new(tc.outputs["Object"], no.inputs["Vector"])
        return no.outputs["Fac"]

    def ramp(fac, a, b, ca, cb):
        mr = nt.nodes.new("ShaderNodeMapRange")
        mr.inputs["From Min"].default_value = a
        mr.inputs["From Max"].default_value = b
        nt.links.new(fac, mr.inputs["Value"])
        return mix(mr.outputs["Result"], ca, cb)

    def lin(h):
        c = tuple(int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4))
        return tuple(v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4 for v in c)

    def mr01(fac, a, b):
        mr = nt.nodes.new("ShaderNodeMapRange")
        mr.inputs["From Min"].default_value = a
        mr.inputs["From Max"].default_value = b
        nt.links.new(fac, mr.inputs["Value"])
        return mr.outputs["Result"]

    meadow = ramp(noise(0.05, 6.0), 0.35, 0.65, lin("6E8E3C"), lin("8DA64C"))
    meadow = mix(mr01(noise(0.4, 3.0), 0.55, 0.75), meadow, lin("A3A65A"))  # dry patches
    floor = ramp(noise(0.12, 5.0), 0.3, 0.7, lin("3F4F27"), lin("56602F"))
    # Canopy seen from above / afar: round crowns (Voronoi cells) lit in the
    # middle, dark gaps between them, species tints varying in patches.
    tcv = nt.nodes.new("ShaderNodeTexCoord")
    vor = nt.nodes.new("ShaderNodeTexVoronoi")
    vor.inputs["Scale"].default_value = crown_scale
    vor.inputs["Randomness"].default_value = 0.9
    nt.links.new(tcv.outputs["Object"], vor.inputs["Vector"])
    crown = mr01(vor.outputs["Distance"], 0.55, 0.05)  # 1 at the crown centre
    tint = ramp(noise(0.02, 3.0), 0.35, 0.65, lin("34552A"), lin("476A33"))
    tint = mix(mr01(vor.outputs["Color"], 0.55, 0.75), tint, lin("56763A"))
    canopy_c = mix(crown, lin("1E3117"), tint)
    rock = ramp(noise(0.3, 8.0), 0.3, 0.7, lin("7A766C"), lin("9C978A"))
    verge = ramp(noise(0.8, 4.0), 0.3, 0.7, lin("7F7562"), lin("98896B"))
    bed = lin("4A5040")
    c = mix(attr("forest"), meadow, floor)
    c = mix(attr("canopy"), c, canopy_c)
    c = mix(mr01(sep.outputs["Z"], 0.6, 0.42), c, rock)  # only cliffs (> ~55 deg) are bare limestone
    c = mix(attr("verge"), c, verge)
    c = mix(attr("riverbed"), c, bed)
    nt.links.new(c, emit.inputs["Color"])
    return m


def setup_cycles():
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    try:
        prefs = bpy.context.preferences.addons["cycles"].preferences
        prefs.compute_device_type = "OPTIX"
        prefs.refresh_devices()
        for d in prefs.devices:
            d.use = d.type == "OPTIX"
        sc.cycles.device = "GPU"
    except Exception as e:
        print("GPU setup failed:", e)
    sc.cycles.use_denoising = False
    if sc.world is None:
        sc.world = bpy.data.worlds.new("World")


def bake_to(ob, mat, res, name, occluders, ao_dist):
    """Colour (emission) x AO (with the trees as occluders) into one PNG."""
    sc = bpy.context.scene
    img_c = bpy.data.images.new(name + "_c", res, res, alpha=False)
    img_a = bpy.data.images.new(name + "_a", res, res, alpha=False)
    img_a.colorspace_settings.name = "Non-Color"
    ob.data.materials.clear()
    ob.data.materials.append(mat)
    node = mat.node_tree.nodes.new("ShaderNodeTexImage")
    mat.node_tree.nodes.active = node
    for o in bpy.context.scene.objects:
        o.select_set(False)
    ob.select_set(True)
    bpy.context.view_layer.objects.active = ob
    node.image = img_c
    sc.cycles.samples = 2
    t0 = time.time()
    bpy.ops.object.bake(type="EMIT", margin=4, use_clear=True, target="IMAGE_TEXTURES")
    print(f"BAKE {name} colour {time.time() - t0:.1f}s")
    for o in occluders:
        o.hide_render = False
    sc.world.light_settings.distance = ao_dist
    node.image = img_a
    sc.cycles.samples = 48
    t0 = time.time()
    bpy.ops.object.bake(type="AO", margin=4, use_clear=True, target="IMAGE_TEXTURES")
    print(f"BAKE {name} ao {time.time() - t0:.1f}s")
    for o in occluders:
        o.hide_render = True
    c = np.empty(res * res * 4, dtype=np.float32)
    a = np.empty(res * res * 4, dtype=np.float32)
    img_c.pixels.foreach_get(c)
    img_a.pixels.foreach_get(a)
    c = c.reshape(res, res, 4)
    a = a.reshape(res, res, 4)
    c[..., :3] *= (0.42 + 0.58 * a[..., :1])
    out = bpy.data.images.new(name, res, res, alpha=False)
    out.pixels.foreach_set(np.clip(c, 0, 1).ravel())
    out.filepath_raw = os.path.join(OUT, name + ".png")
    out.file_format = "PNG"
    out.save(filepath=out.filepath_raw)
    print("WROTE", out.filepath_raw)


def tree_proxies(coll, trees):
    """Low ellipsoids standing for the canopy, for the AO bake only."""
    bm = bmesh.new()
    sizes = {"kb_beech": (3.4, 3.0, 10.0), "kb_oak": (4.0, 2.8, 8.4), "kb_hornbeam": (2.6, 3.2, 7.6),
             "kb_maple": (3.0, 2.6, 6.2), "kb_pine": (2.4, 1.6, 11.2), "kb_bush": (1.6, 1.0, 1.0),
             "kb_rock": (1.8, 1.0, 0.9)}
    for t in trees:
        rx, ry, cy = sizes[t[0]]
        s = t[5]
        tmp = bmesh.new()
        bmesh.ops.create_icosphere(tmp, subdivisions=1, radius=1.0)
        for v in tmp.verts:
            v.co = Vector((t[1] + v.co.x * rx * s, -t[3] + v.co.y * rx * s, t[2] + cy * s + v.co.z * ry * s))
        me = bpy.data.meshes.new("tmp")
        tmp.to_mesh(me)
        tmp.free()
        bm.from_mesh(me)
        bpy.data.meshes.remove(me)
    me = bpy.data.meshes.new("Proxies")
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new("Proxies", me)
    coll.objects.link(ob)
    ob.hide_render = True
    return ob


# --- Main --------------------------------------------------------------------------------

def main():
    t_all = time.time()
    coll = reset()
    os.makedirs(OUT, exist_ok=True)

    def hfun(xs, zs):
        return height(xs, zs)

    # Inner grid -------------------------------------------------------------------------
    nx = int(round((X1 - X0) / CELL)) + 1
    nz = int(round((Z1 - Z0) / CELL)) + 1
    xs, zs = np.meshgrid(np.linspace(X0, X1, nx), np.linspace(Z0, Z1, nz))
    t0 = time.time()
    hs, info = height(xs, zs)
    can, can_on = canopy(xs, zs, info)
    print(f"HEIGHTS inner {nx}x{nz} in {time.time() - t0:.0f}s, y {hs.min():.1f}..{hs.max():.1f}")
    # The grid Godot samples (ground under the canopy).
    hs.astype(np.float32).tofile(os.path.join(OUT, "heights.bin"))
    json.dump({"x0": X0, "z0": Z0, "cell": CELL, "nx": nx, "nz": nz,
               "doc": "float32 little-endian, row-major (z rows, x columns), Godot metres; ground height (no canopy)"},
              open(os.path.join(OUT, "heights.json"), "w"))
    k = info["droad"] - info["edge"]
    forest = smooth(18.0, 40.0, k)
    verge = 1.0 - smooth(-0.5, 1.0, k)
    riverbed = ((zs > 200.0) & (np.abs(zs - river_center(xs)) < 13.0)).astype(np.float64)
    plots = np.zeros_like(xs)
    for pl in PLOTS:
        plots = np.maximum(plots, 1.0 - smooth(pl[2] - 4.0, pl[2] + 6.0, np.sqrt((xs - pl[0]) ** 2 + (zs - pl[1]) ** 2)))
    can = can * (1.0 - plots) * (1.0 - riverbed)
    can_on = can_on * (1.0 - plots) * (1.0 - riverbed)
    forest = forest * (1.0 - plots)
    shown = hs + can
    attrs = {"forest": forest, "canopy": can_on, "verge": verge, "riverbed": riverbed}

    trees = scatter_forest(hfun)
    print(f"TREES {len(trees)}")
    json.dump({"doc": "kind, x, y, z, yaw, scale (Godot space); y = ground - sink", "trees": trees},
              open(os.path.join(OUT, "trees.json"), "w"))

    tiles = []
    ti = 0
    for i0 in range(0, nz - 1, TILE_CELLS):
        tj = 0
        for j0 in range(0, nx - 1, TILE_CELLS):
            i1 = min(i0 + TILE_CELLS, nz - 1) + 1
            j1 = min(j0 + TILE_CELLS, nx - 1) + 1
            sl = (slice(i0, i1), slice(j0, j1))
            ob = grid_mesh(f"Tile_{ti}_{tj}", coll, xs[sl], zs[sl], shown[sl], (X0, Z0, X1 - X0, Z1 - Z0),
                           attrs={an: arr[sl] for an, arr in attrs.items()})
            # Protect the road corridor from decimation (the ground must stay under the verge).
            vg = ob.vertex_groups.new(name="road")
            near = (k[sl] < 30.0).ravel()
            for vi, v in enumerate(ob.data.vertices):
                pass
            # vertex order = creation order: rebuild the mapping from coordinates
            # ... and the tile borders (collapse would pull them in: cracks).
            for v in ob.data.vertices:
                gx = int(round((v.co.x - X0) / CELL))
                gz = int(round((-v.co.y - Z0) / CELL))
                border = gx in (j0, j1 - 1) or gz in (i0, i1 - 1)
                if k[gz, gx] < 30.0 or border:
                    vg.add([v.index], 1.0, "REPLACE")
            tiles.append(ob)
            tj += 1
        ti += 1
    full = sum(tri_count(o) for o in tiles)
    # Bake on the full-resolution tiles (the masks interpolate over 3 m cells,
    # not over the decimated triangles); the planar UVs are the same after.
    if BAKE:
        setup_cycles()
        prox = tree_proxies(coll, trees)
        inner_full = tiles_joined(coll, tiles, "BakeInner")
        bake_to(inner_full, terrain_material("inner_mat"), RES, "terrain_albedo", [prox], 14.0)
        bpy.data.objects.remove(inner_full)
    fars = []
    for ob in tiles:
        far = ob.copy()
        far.data = ob.data.copy()
        far.name = ob.name + "_far"
        coll.objects.link(far)
        decimate(far, 0.08, "road")
        fars.append(far)
        decimate(ob, 0.28, "road")
    for o in tiles:
        print(f"TILE {o.name}: {tri_count(o)} tris")
    print(f"TILES {len(tiles)}: {full} -> near {sum(tri_count(o) for o in tiles)} / far {sum(tri_count(o) for o in fars)} tris")

    # Mountain ring ----------------------------------------------------------------------
    mnx = int(round((MX1 - MX0) / MCELL)) + 1
    mnz = int(round((MZ1 - MZ0) / MCELL)) + 1
    mxs, mzs = np.meshgrid(np.linspace(MX0, MX1, mnx), np.linspace(MZ0, MZ1, mnz))
    t0 = time.time()
    mhs, minfo = height(mxs, mzs)
    mcan, mcan_on = canopy(mxs, mzs, minfo)
    rock = smooth(135.0, 160.0, mhs)  # bare tops
    mcan = mcan * (1.0 - rock)
    mcan_on = mcan_on * (1.0 - rock)
    print(f"HEIGHTS mountains {mnx}x{mnz} in {time.time() - t0:.0f}s, y {mhs.min():.1f}..{mhs.max():.1f}")
    # Overlap one cell under the inner region (sunk 1.5 m: no cracks at the seam).
    inner = (mxs > X0 + MCELL) & (mxs < X1 - MCELL) & (mzs > Z0 + MCELL) & (mzs < Z1 - MCELL)
    msh = np.where(inner, mhs - 1.5, mhs + mcan)
    mk = minfo["droad"] - minfo["edge"]
    mriver = ((mzs > 200.0) & (np.abs(mzs - river_center(mxs)) < 13.0)).astype(np.float64)
    mattrs = {"forest": smooth(18.0, 40.0, mk), "canopy": mcan_on * (1.0 - mriver), "verge": np.zeros_like(mxs),
              "riverbed": mriver}

    def keep(i, j):
        return not (inner[i, j] and inner[i + 1, j + 1] and inner[i, j + 1] and inner[i + 1, j])
    mountains = grid_mesh("Mountains", coll, mxs, mzs, msh, (MX0, MZ0, MX1 - MX0, MZ1 - MZ0), keep, mattrs)
    mountains_full = mountains.copy()
    mountains_full.data = mountains.data.copy()
    coll.objects.link(mountains_full)
    decimate(mountains, 0.35)
    print(f"MOUNTAINS {tri_count(mountains)} tris")

    # River ribbon ----------------------------------------------------------------------
    rx = np.arange(MX0, MX1 + 1, 8.0)
    rz = river_center(rx)
    bm = bmesh.new()
    rows = []
    for x, z in zip(rx, rz):
        rows.append([bm.verts.new((x, -(z - 13.0), -3.9)), bm.verts.new((x, -(z + 13.0), -3.9))])
    for a, b in zip(rows, rows[1:]):
        bm.faces.new((a[0], b[0], b[1], a[1]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    for f in bm.faces:
        if f.normal.z < 0:
            f.normal_flip()
    me = bpy.data.meshes.new("River")
    bm.to_mesh(me)
    bm.free()
    river = bpy.data.objects.new("River", me)
    coll.objects.link(river)

    # Bake --------------------------------------------------------------------------------
    if BAKE:
        bake_to(mountains_full, terrain_material("mount_mat", 0.09), RES // 2, "mountains_albedo", [], 30.0)
        bpy.data.objects.remove(prox)
    bpy.data.objects.remove(mountains_full)

    # Tiles keep their centre as origin: Godot measures visibility ranges
    # (near / far LOD) from the node's origin.
    for o in tiles + fars:
        me = o.data
        n = len(me.vertices)
        co = np.empty(n * 3)
        me.vertices.foreach_get("co", co)
        co = co.reshape(n, 3)
        c = Vector(((co[:, 0].min() + co[:, 0].max()) / 2, (co[:, 1].min() + co[:, 1].max()) / 2, 0.0))
        co -= np.array(c)
        me.vertices.foreach_set("co", co.ravel())
        me.update()
        o.location = c

    # Export (no materials: Godot applies terrain_baked.gdshader) -------------------------
    for o in tiles + fars + [mountains, river]:
        o.data.materials.clear()
        for an in list(o.data.attributes.keys()):
            if an in attrs:
                o.data.attributes.remove(o.data.attributes[an])
    for o in bpy.context.scene.objects:
        o.select_set(False)
    for o in tiles + fars + [mountains, river]:
        o.select_set(True)
    bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, "terrain.glb"), export_format="GLB", use_selection=True,
                              export_apply=True, export_yup=True, export_materials="NONE", export_normals=True,
                              export_texcoords=True, export_tangents=False, export_animations=False,
                              export_skins=False, export_morph=False, export_cameras=False, export_lights=False,
                              export_attributes=False)
    print("WROTE", os.path.join(OUT, "terrain.glb"))
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(WORK, "karabakh_terrain.blend"))
    print(f"DONE in {time.time() - t_all:.0f}s")


_joined = {}


def tiles_joined(coll, tiles, name):
    """One temporary object with every near tile (one bake target, shared UVs)."""
    bm = bmesh.new()
    for o in tiles:
        bm.from_mesh(o.data)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(name, me)
    coll.objects.link(ob)
    return ob


main()
