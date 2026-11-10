"""Review renders of the Qarabağ map in Blender (no Godot window - owner's
choice): the baked terrain, the road with its markings and guardrails, the
Blender forest from trees.json, a summer sky.

  blender --background --factory-startup --python tools/blender/karabakh_render.py -- [--samples 48] [--out DIR]

Needs tools/blender/out/karabakh_terrain.blend (karabakh_terrain.py) and
assets/models/karabakh_flora (karabakh_flora.py). Writes <out>/kb_*.jpg and
the city card assets/ui/cities/karabakh.jpg (640 x 400).
"""

import json
import math
import os
import sys

import bmesh
import bpy
from mathutils import Vector

ARGV = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []


def arg(name, default):
    return ARGV[ARGV.index(name) + 1] if name in ARGV else default


ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
WORK = os.path.join(ROOT, "tools", "blender", "out")
OUT = os.path.join(ROOT, arg("--out", "docs/screenshots/0.18.0"))
SAMPLES = int(arg("--samples", "48"))
KB = os.path.join(ROOT, "assets", "models", "karabakh")
FL = os.path.join(ROOT, "assets", "models", "karabakh_flora")
ROAD = json.load(open(os.path.join(WORK, "karabakh_road.json"), encoding="utf-8"))


def B(x, y, z):
    """Godot -> Blender coordinates."""
    return Vector((x, -z, y))


def lin(h):
    c = tuple(int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4))
    return tuple(v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4 for v in c) + (1.0,)


def image_mat(name, path, rough=0.95):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    bsdf = nt.nodes["Principled BSDF"]
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = bpy.data.images.load(path)
    tex.extension = "EXTEND"
    nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = rough
    bsdf.inputs["Specular IOR Level"].default_value = 0.1  # as the game's terrain shader (SPECULAR 0.2)
    return m


def flora_mat():
    m = bpy.data.materials.new("flora")
    m.use_nodes = True
    nt = m.node_tree
    bsdf = nt.nodes["Principled BSDF"]
    a = nt.nodes.new("ShaderNodeTexImage")
    a.image = bpy.data.images.load(os.path.join(FL, "albedo.png"))
    a.image.alpha_mode = "NONE"  # alpha is the (empty) stone mask, not coverage
    nt.links.new(a.outputs["Color"], bsdf.inputs["Base Color"])
    n = nt.nodes.new("ShaderNodeTexImage")
    n.image = bpy.data.images.load(os.path.join(FL, "normal.png"))
    n.image.colorspace_settings.name = "Non-Color"
    nm = nt.nodes.new("ShaderNodeNormalMap")
    nt.links.new(n.outputs["Color"], nm.inputs["Color"])
    nt.links.new(nm.outputs["Normal"], bsdf.inputs["Normal"])
    bsdf.inputs["Roughness"].default_value = 0.85
    bsdf.inputs["Specular IOR Level"].default_value = 0.25
    return m


def road_material():
    """Asphalt with white edge lines and a dashed centre line (UV.x = lateral
    -1..1, UV.y = metres along)."""
    m = bpy.data.materials.new("road")
    m.use_nodes = True
    nt = m.node_tree
    bsdf = nt.nodes["Principled BSDF"]
    uv = nt.nodes.new("ShaderNodeUVMap")
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    nt.links.new(uv.outputs["UV"], sep.inputs["Vector"])
    absx = nt.nodes.new("ShaderNodeMath")
    absx.operation = "ABSOLUTE"
    nt.links.new(sep.outputs["X"], absx.inputs[0])
    edge = nt.nodes.new("ShaderNodeMapRange")  # 1 on the edge line band
    edge.interpolation_type = "STEPPED"
    nt.links.new(absx.outputs[0], edge.inputs["Value"])
    edge.inputs["From Min"].default_value = 0.86
    edge.inputs["From Max"].default_value = 0.92
    edge.inputs["Steps"].default_value = 1.0
    edge_cut = nt.nodes.new("ShaderNodeMath")
    edge_cut.operation = "LESS_THAN"
    nt.links.new(absx.outputs[0], edge_cut.inputs[0])
    edge_cut.inputs[1].default_value = 0.92
    e2 = nt.nodes.new("ShaderNodeMath")
    e2.operation = "MULTIPLY"
    nt.links.new(edge.outputs["Result"], e2.inputs[0])
    nt.links.new(edge_cut.outputs[0], e2.inputs[1])
    centre = nt.nodes.new("ShaderNodeMath")
    centre.operation = "LESS_THAN"
    nt.links.new(absx.outputs[0], centre.inputs[0])
    centre.inputs[1].default_value = 0.012
    dash = nt.nodes.new("ShaderNodeMath")
    dash.operation = "PINGPONG"
    nt.links.new(sep.outputs["Y"], dash.inputs[0])
    dash.inputs[1].default_value = 4.0
    dash2 = nt.nodes.new("ShaderNodeMath")
    dash2.operation = "LESS_THAN"
    nt.links.new(dash.outputs[0], dash2.inputs[0])
    dash2.inputs[1].default_value = 1.6
    cd = nt.nodes.new("ShaderNodeMath")
    cd.operation = "MULTIPLY"
    nt.links.new(centre.outputs[0], cd.inputs[0])
    nt.links.new(dash2.outputs[0], cd.inputs[1])
    lines = nt.nodes.new("ShaderNodeMath")
    lines.operation = "MAXIMUM"
    nt.links.new(e2.outputs[0], lines.inputs[0])
    nt.links.new(cd.outputs[0], lines.inputs[1])
    no = nt.nodes.new("ShaderNodeTexNoise")
    no.inputs["Scale"].default_value = 60.0
    tc = nt.nodes.new("ShaderNodeTexCoord")
    nt.links.new(tc.outputs["Object"], no.inputs["Vector"])
    asph = nt.nodes.new("ShaderNodeMix")
    asph.data_type = "RGBA"
    nt.links.new(no.outputs["Fac"], asph.inputs[0])
    asph.inputs[6].default_value = lin("3A3B3E")
    asph.inputs[7].default_value = lin("54555A")
    mixl = nt.nodes.new("ShaderNodeMix")
    mixl.data_type = "RGBA"
    nt.links.new(lines.outputs[0], mixl.inputs[0])
    nt.links.new(asph.outputs[2], mixl.inputs[6])
    mixl.inputs[7].default_value = lin("F2F1EA")
    nt.links.new(mixl.outputs[2], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 0.8
    return m


def flat(name, hx, rough=0.9, metal=0.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = lin(hx)
    b.inputs["Roughness"].default_value = rough
    b.inputs["Metallic"].default_value = metal
    return m


def build_road(coll):
    pts = [Vector(p) for p in ROAD["points"]]
    hw = ROAD["half_widths"]
    ow = ROAD["offroad_width"]
    n = len(pts)
    bm = bmesh.new()
    uvl = bm.loops.layers.uv.new("UVMap")
    vb = bmesh.new()
    rb = bmesh.new()
    rows, vrows_l, vrows_r = [], [], []
    along = 0.0
    rails = []
    for i, p in enumerate(pts):
        t = (pts[(i + 1) % n] - pts[i - 1])
        t.y = 0.0
        t.normalize()
        r = Vector((-t.z, 0.0, t.x))
        w = hw[i]
        rows.append((bm.verts.new(B(*(p - r * w + Vector((0, 0.03, 0))))), bm.verts.new(B(*(p + r * w + Vector((0, 0.03, 0))))), along))
        vrows_l.append((vb.verts.new(B(*(p - r * w))), vb.verts.new(B(*(p - r * (w + ow) - Vector((0, 0.04, 0)))))))
        vrows_r.append((vb.verts.new(B(*(p + r * w))), vb.verts.new(B(*(p + r * (w + ow) - Vector((0, 0.04, 0)))))))
        rails.append((p - r * (w + ow + 0.6), p + r * (w + ow + 0.6)))
        if i + 1 < n:
            along += (pts[i + 1] - p).length
    for i in range(n):
        a, b = rows[i], rows[(i + 1) % n]
        f = bm.faces.new((a[0], b[0], b[1], a[1]))
        for loop, uvv in zip(f.loops, ((-1, a[2]), (-1, b[2]), (1, b[2]), (1, a[2]))):
            loop[uvl].uv = uvv
        for vr in (vrows_l, vrows_r):
            c, d = vr[i], vr[(i + 1) % n]
            vb.faces.new((c[0], d[0], d[1], c[1]))
    for f in bm.faces:
        if f.normal.z < 0:
            f.normal_flip()
    bmesh.ops.recalc_face_normals(vb, faces=vb.faces)
    # Guardrail: a W-beam band 0.45-0.8 m with posts every 4 m.
    post_every = 2
    for side in (0, 1):
        for i in range(n):
            a = rails[i][side]
            b = rails[(i + 1) % n][side]
            q = [rb.verts.new(B(*(a + Vector((0, 0.45, 0))))), rb.verts.new(B(*(b + Vector((0, 0.45, 0))))),
                 rb.verts.new(B(*(b + Vector((0, 0.8, 0))))), rb.verts.new(B(*(a + Vector((0, 0.8, 0)))))]
            rb.faces.new(q)
            if i % post_every == 0:
                tmp = bmesh.ops.create_cube(rb, size=1.0)
                for v in tmp["verts"]:
                    v.co = B(*(a + Vector((v.co.x * 0.12, (v.co.z + 0.5) * 0.75, v.co.y * 0.12))))
    out = []
    for name, b_, mat in (("RoadB", bm, road_material()), ("Verge", vb, flat("verge", "7B7A5C")),
                          ("Guardrail", rb, flat("rail", "B8BEC2", 0.35, 0.8))):
        me = bpy.data.meshes.new(name)
        b_.to_mesh(me)
        b_.free()
        me.materials.append(mat)
        ob = bpy.data.objects.new(name, me)
        coll.objects.link(ob)
        out.append(ob)
    return out


def place_trees(coll):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=os.path.join(FL, "karabakh_flora.glb"))
    proto = {}
    mat = flora_mat()
    for o in set(bpy.data.objects) - before:
        if o.type == "MESH":
            o.data.materials.clear()
            o.data.materials.append(mat)
            proto[o.name] = o
            o.hide_render = True
            o.hide_viewport = True
    trees = json.load(open(os.path.join(KB, "trees.json"), encoding="utf-8"))["trees"]
    # glTF import gives Blender-space meshes already (Z up).
    for t in trees:
        src = proto.get(t[0])
        if src is None:
            continue
        ob = bpy.data.objects.new(t[0], src.data)
        ob.location = B(t[1], t[2], t[3])
        ob.rotation_euler = (0.0, 0.0, t[4])
        ob.scale = (t[5],) * 3
        coll.objects.link(ob)
    print("TREES placed", len(trees))
    posts = proto.get("kb_post")
    pts = [Vector(p) for p in ROAD["points"]]
    for i in range(0, len(pts), 12):
        p = pts[i]
        t = pts[(i + 1) % len(pts)] - pts[i - 1]
        t.y = 0
        t.normalize()
        r = Vector((-t.z, 0, t.x))
        for s in (-1, 1):
            q = p + r * s * (ROAD["half_widths"][i] + ROAD["offroad_width"] + 0.9)
            ob = bpy.data.objects.new("post", posts.data)
            ob.location = B(q.x, q.y - 0.05, q.z)
            ob.rotation_euler = (0, 0, math.atan2(-r.x * s, r.z * s))
            coll.objects.link(ob)


def sky(sc):
    w = bpy.data.worlds.new("Sky")
    sc.world = w
    w.use_nodes = True
    nt = w.node_tree
    bg = nt.nodes["Background"]
    st = nt.nodes.new("ShaderNodeTexSky")
    st.sky_type = "NISHITA"
    st.sun_elevation = math.radians(48)
    st.sun_rotation = math.radians(150)
    st.altitude = 1200.0
    st.air_density = 1.0
    st.dust_density = 2.0
    nt.links.new(st.outputs["Color"], bg.inputs["Color"])
    bg.inputs["Strength"].default_value = 0.22
    sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", "SUN"))
    sun.data.energy = 2.2
    sun.data.angle = math.radians(1.5)
    sun.rotation_euler = (math.radians(42), 0, math.radians(150))
    sc.collection.objects.link(sun)


def road_cam(s_m, back=7.0, up=2.6, ahead=18.0, lat=0.0):
    pts = [Vector(p) for p in ROAD["points"]]
    step = ROAD["length"] / len(pts)
    i = int(s_m / step) % len(pts)
    p = pts[i]
    t = pts[(i + 3) % len(pts)] - pts[i - 3]
    t.y = 0
    t.normalize()
    r = Vector((-t.z, 0, t.x))
    eye = p - t * back + Vector((0, up, 0)) + r * lat
    j = int((s_m + ahead) / step) % len(pts)
    look = pts[j] + Vector((0, 1.2, 0))
    return B(*eye), B(*look)


def shoot(sc, cam, eye, look, name, res=(1280, 720), lens=24):
    cam.location = eye
    cam.rotation_euler = (look - eye).to_track_quat("-Z", "Y").to_euler()
    cam.data.lens = lens
    sc.render.resolution_x, sc.render.resolution_y = res
    sc.render.filepath = os.path.join(OUT, name)
    bpy.ops.render.render(write_still=True)
    print("WROTE", sc.render.filepath)


def main():
    bpy.ops.wm.open_mainfile(filepath=os.path.join(WORK, "karabakh_terrain.blend"))
    sc = bpy.context.scene
    coll = bpy.data.collections.new("Review")
    sc.collection.children.link(coll)
    inner = image_mat("terrain", os.path.join(KB, "terrain_albedo.png"))
    outer = image_mat("mount", os.path.join(KB, "mountains_albedo.png"))
    water = flat("water", "3F6E7A", 0.08)
    for o in list(bpy.data.objects):
        if o.type != "MESH":
            continue
        if o.name.endswith("_far") or o.name.startswith("Bake"):
            bpy.data.objects.remove(o)
            continue
        o.data.materials.clear()
        o.data.materials.append(water if o.name == "River" else outer if o.name == "Mountains" else inner)
    build_road(coll)
    place_trees(coll)
    sky(sc)
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
    sc.cycles.samples = SAMPLES
    sc.cycles.use_denoising = True
    sc.view_settings.view_transform = "Standard"  # closest to the game's look
    sc.view_settings.exposure = -0.6
    sc.render.image_settings.file_format = "JPEG"
    sc.render.image_settings.quality = 88
    cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
    cam.data.clip_end = 4000
    sc.collection.objects.link(cam)
    sc.camera = cam
    os.makedirs(OUT, exist_ok=True)
    L = ROAD["length"]
    views = [("kb_1_lachin_start.jpg", 30.0), ("kb_2_climb.jpg", 330.0), ("kb_3_shusha_plateau.jpg", 640.0),
             ("kb_4_descent_gorge.jpg", 840.0), ("kb_5_khankendi_valley.jpg", 1050.0), ("kb_6_river_road.jpg", 1380.0)]
    for name, s in views:
        eye, look = road_cam(s)
        shoot(sc, cam, eye, look, name)
    # Overview from the south-west, high.
    shoot(sc, cam, B(-650, 260, 620), B(60, 0, 20), "kb_0_overview.jpg", lens=28)
    # City card.
    eye, look = road_cam(1380.0, back=14.0, up=6.5, ahead=70.0)
    shoot(sc, cam, eye, look, "karabakh_card.jpg", res=(640, 400), lens=22)
    import shutil
    shutil.copy(os.path.join(OUT, "karabakh_card.jpg"), os.path.join(ROOT, "assets", "ui", "cities", "karabakh.jpg"))
    print("DONE")


main()
