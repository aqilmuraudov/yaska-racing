"""Quick look at a Qarabağ landmark set before / after its bake (no Godot window).

  blender --background --factory-startup --python tools/blender/kb_preview.py -- <set> [--baked] [--samples 24]
<set> = karabakh_khankendi | karabakh_shusha | karabakh_lachin; reads tools/blender/out/<set>.blend
(saved by kart_common.run). Writes tools/blender/out/preview_<set>_<group>.jpg: each model from
the road side (its front, +z in Godot = -y in Blender) and above. --baked shows the exported
glTF with its baked atlas instead of the flat palette colours.
"""

import math
import os
import sys

import bpy
from mathutils import Vector

ARGV = sys.argv[sys.argv.index("--") + 1:]
SET = ARGV[0]
BAKED = "--baked" in ARGV
SAMPLES = int(ARGV[ARGV.index("--samples") + 1]) if "--samples" in ARGV else 24
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
WORK = os.path.join(ROOT, "tools", "blender", "out")
FOLDER = os.path.join(ROOT, "assets", "models", SET)


def main():
    if BAKED:
        bpy.ops.wm.read_factory_settings(use_empty=True)
        bpy.ops.import_scene.gltf(filepath=os.path.join(FOLDER, SET + ".glb"))
        m = bpy.data.materials.new("baked")
        m.use_nodes = True
        nt = m.node_tree
        bsdf = nt.nodes["Principled BSDF"]
        a = nt.nodes.new("ShaderNodeTexImage")
        a.image = bpy.data.images.load(os.path.join(FOLDER, "albedo.png"))
        a.image.alpha_mode = "NONE"
        nt.links.new(a.outputs["Color"], bsdf.inputs["Base Color"])
        n = nt.nodes.new("ShaderNodeTexImage")
        n.image = bpy.data.images.load(os.path.join(FOLDER, "normal.png"))
        n.image.colorspace_settings.name = "Non-Color"
        nm = nt.nodes.new("ShaderNodeNormalMap")
        nt.links.new(n.outputs["Color"], nm.inputs["Color"])
        nt.links.new(nm.outputs["Normal"], bsdf.inputs["Normal"])
        bsdf.inputs["Roughness"].default_value = 0.8
        objs = [o for o in bpy.data.objects if o.type == "MESH"]
        for o in objs:
            o.data.materials.clear()
            o.data.materials.append(m)
    else:
        bpy.ops.wm.open_mainfile(filepath=os.path.join(WORK, SET + ".blend"))
        objs = [o for o in bpy.data.objects if o.type == "MESH" and not o.get("hi") and not o.name.endswith("_far")
                and not o.hide_render]
    sc = bpy.context.scene
    w = bpy.data.worlds.new("w")
    sc.world = w
    w.use_nodes = True
    w.node_tree.nodes["Background"].inputs["Color"].default_value = (0.55, 0.7, 0.9, 1)
    w.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.6
    sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", "SUN"))
    sun.data.energy = 3.0
    sun.rotation_euler = (math.radians(40), 0, math.radians(30))
    sc.collection.objects.link(sun)
    ground = bpy.data.meshes.new("g")
    ground.from_pydata([(-400, -400, -0.05), (400, -400, -0.05), (400, 400, -0.05), (-400, 400, -0.05)], [], [(0, 1, 2, 3)])
    gm = bpy.data.materials.new("gm")
    gm.use_nodes = True
    gm.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.2, 0.32, 0.1, 1)
    ground.materials.append(gm)
    sc.collection.objects.link(bpy.data.objects.new("Ground", ground))
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
    sc.view_settings.view_transform = "Standard"
    sc.render.image_settings.file_format = "JPEG"
    sc.render.resolution_x, sc.render.resolution_y = 1280, 720
    cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
    cam.data.lens = 24
    cam.data.clip_end = 3000
    sc.collection.objects.link(cam)
    sc.camera = cam
    for o in objs:
        o.hide_render = True
    for o in objs:
        o.hide_render = False
        bb = [o.matrix_world @ Vector(c) for c in o.bound_box]
        lo = Vector((min(v.x for v in bb), min(v.y for v in bb), min(v.z for v in bb)))
        hi = Vector((max(v.x for v in bb), max(v.y for v in bb), max(v.z for v in bb)))
        c = (lo + hi) / 2
        size = max(hi.x - lo.x, hi.y - lo.y, hi.z - lo.z)
        # front = -y in Blender (Godot +z); look from front-right, raised
        eye = c + Vector((size * 0.55, -size * 1.05, size * 0.45))
        cam.location = eye
        cam.rotation_euler = (c - eye).to_track_quat("-Z", "Y").to_euler()
        sc.render.filepath = os.path.join(WORK, f"preview_{SET}_{o.name}.jpg")
        bpy.ops.render.render(write_still=True)
        print("WROTE", sc.render.filepath)
        o.hide_render = True


main()
