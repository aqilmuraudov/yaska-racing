"""Qarabağ forest for Yaska Racing (0.18.0): the trees of the Karabakh
mountain forests, summer foliage (owner's pick), plus the roadside pieces.

  blender --background --factory-startup --python tools/blender/karabakh_flora.py -- --bake-res 2048 --tex-res 1024

Species after the Shusha / Lachin forest descriptions (oriental beech, oak,
Caucasian hornbeam dominate; maple, a few Kochi pines on the rocky tops):
  kb_beech     Fagus orientalis: tall straight smooth grey trunk, broad high dome
  kb_oak       Quercus (iberica / macranthera): stout furrowed brown trunk,
               crooked limbs, wide irregular crown of heavy dark clumps
  kb_hornbeam  Carpinus caucasica: fluted grey trunk, compact egg-shaped crown,
               fresh green
  kb_maple     Acer: short trunk, round crown, light yellow-green
  kb_pine      Pinus kochiana: bare trunk, orange upper bark, flat tiered crown
  kb_bush      hazel / blackberry thicket on forest edges
  kb_rock      grey limestone boulders (Shusha cliffs, Laçın gorge)
  kb_post      white roadside reflector post with a black band and red reflector
Sizes are game-fitted (a kart is ~1.2 m high): trees 9-14 m instead of the
real 20-30 m, so the forest closes over the road without hiding the sky.
Low models are light (instanced in thousands); leaf clumps, bark furrows and
the rock grain come from the bake.
"""

import math
import os
import random
import sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from kart_common import *  # noqa: F401,F403
import kart_common as K
from mathutils import Vector, Matrix

PALETTE = {
    "bark_beech": ("9A9890", 0.85, 0.0), "bark_oak": ("5E4A38", 0.95, 0.0), "bark_hornbeam": ("8E8B80", 0.85, 0.0),
    "bark_maple": ("6F6253", 0.9, 0.0), "bark_pine_low": ("5A4434", 0.95, 0.0), "bark_pine_top": ("B5683A", 0.85, 0.0),
    "leaf_beech": ("466F2E", 0.8, 0.0), "leaf_beech_lt": ("5A843A", 0.8, 0.0),
    "leaf_oak": ("3A5A28", 0.85, 0.0), "leaf_oak_dk": ("2C4720", 0.85, 0.0),
    "leaf_hornbeam": ("4F7A31", 0.8, 0.0), "leaf_hornbeam_lt": ("638C3B", 0.8, 0.0),
    "leaf_maple": ("6C8E40", 0.8, 0.0), "leaf_maple_lt": ("7F9F4A", 0.8, 0.0),
    "needle": ("2A452C", 0.9, 0.0), "needle_lt": ("365638", 0.9, 0.0),
    "bush": ("3C5A2A", 0.85, 0.0), "bush_lt": ("4D6E34", 0.85, 0.0), "berry": ("2A1F3A", 0.5, 0.0),
    "rock": ("A7A49B", 0.9, 0.0), "rock_dk": ("7E7B73", 0.9, 0.0), "moss": ("5F7A35", 0.95, 0.0),
    "post_white": ("F2F1EC", 0.5, 0.0), "post_black": ("1E1E1E", 0.6, 0.0), "reflector": ("E3262B", 0.2, 0.0),
    "lamp_pole": ("A3AAAE", 0.35, 0.7), "lamp_head": ("5B6166", 0.4, 0.6), "lamp_led": ("FFF4D6", 0.2, 0.0),
}
# orm.a (the "paint" mask) marks what glows at night: the reflectors and the
# LED heads (PropKit.PROP_GLOW "lamps" for this set).
PAINT_MAT = ["reflector", "lamp_led"]
STONE = ["__no_stone__"]  # albedo alpha = 0: no limestone coursing on trees (prop_baked)
GROUPS = ["kb_beech", "kb_oak", "kb_hornbeam", "kb_maple", "kb_pine", "kb_bush", "kb_rock", "kb_post", "kb_lamp"]
UV_SCALE = {"kb_beech": 0.7, "kb_oak": 0.7, "kb_hornbeam": 0.8, "kb_maple": 0.8, "kb_pine": 0.75,
            "kb_bush": 1.0, "kb_rock": 1.0, "kb_post": 1.6, "kb_lamp": 1.4}
FAR_RATIO = {"kb_beech": 0.16, "kb_oak": 0.16, "kb_hornbeam": 0.18, "kb_maple": 0.18, "kb_pine": 0.2,
             "kb_bush": 0.25, "kb_rock": 0.3, "kb_post": 0.5, "kb_lamp": 0.5}
LEAVES = {"leaf_beech": 2.6, "leaf_beech_lt": 2.6, "leaf_oak": 2.2, "leaf_oak_dk": 2.2, "leaf_hornbeam": 3.0,
          "leaf_hornbeam_lt": 3.0, "leaf_maple": 2.4, "leaf_maple_lt": 2.4, "needle": 5.0, "needle_lt": 5.0,
          "bush": 4.0, "bush_lt": 4.0}
BARK = {"bark_oak": (6.0, 0.06), "bark_pine_low": (5.0, 0.05), "bark_hornbeam": (3.0, 0.03),
        "bark_beech": (2.0, 0.012), "bark_maple": (4.0, 0.03)}
_bumped = False


def add_bumps():
    """High model only: lumpy leaf clumps (Voronoi), furrowed bark (stretched
    wave), grainy limestone. All of it ends up in the baked normal map."""
    for name, scale in LEAVES.items():
        nt = K.MATS[name].node_tree
        bsdf = nt.nodes["Principled BSDF"]
        tc = nt.nodes.new("ShaderNodeTexCoord")
        vo = nt.nodes.new("ShaderNodeTexVoronoi")
        vo.inputs["Scale"].default_value = scale
        inv = nt.nodes.new("ShaderNodeMath")
        inv.operation = "SUBTRACT"
        inv.inputs[0].default_value = 1.0
        bump = nt.nodes.new("ShaderNodeBump")
        bump.inputs["Strength"].default_value = 0.95
        bump.inputs["Distance"].default_value = 0.1
        nt.links.new(tc.outputs["Object"], vo.inputs["Vector"])
        nt.links.new(vo.outputs["Distance"], inv.inputs[1])
        nt.links.new(inv.outputs["Value"], bump.inputs["Height"])
        nt.links.new(bump.outputs["Normal"], bsdf.inputs["Normal"])
    for name, (scale, dist) in BARK.items():
        nt = K.MATS[name].node_tree
        bsdf = nt.nodes["Principled BSDF"]
        tc = nt.nodes.new("ShaderNodeTexCoord")
        mp = nt.nodes.new("ShaderNodeMapping")
        mp.inputs["Scale"].default_value = (scale, scale * 0.15, scale)  # stretched along the trunk (Y)
        wv = nt.nodes.new("ShaderNodeTexWave")
        wv.wave_type = "BANDS"
        wv.bands_direction = "X"
        wv.inputs["Distortion"].default_value = 6.0
        wv.inputs["Detail"].default_value = 3.0
        bump = nt.nodes.new("ShaderNodeBump")
        bump.inputs["Strength"].default_value = 0.8
        bump.inputs["Distance"].default_value = dist
        nt.links.new(tc.outputs["Object"], mp.inputs["Vector"])
        nt.links.new(mp.outputs["Vector"], wv.inputs["Vector"])
        nt.links.new(wv.outputs["Fac"], bump.inputs["Height"])
        nt.links.new(bump.outputs["Normal"], bsdf.inputs["Normal"])
    for name in ("rock", "rock_dk"):
        nt = K.MATS[name].node_tree
        bsdf = nt.nodes["Principled BSDF"]
        tc = nt.nodes.new("ShaderNodeTexCoord")
        no = nt.nodes.new("ShaderNodeTexNoise")
        no.inputs["Scale"].default_value = 3.5
        no.inputs["Detail"].default_value = 8.0
        bump = nt.nodes.new("ShaderNodeBump")
        bump.inputs["Strength"].default_value = 0.9
        bump.inputs["Distance"].default_value = 0.08
        nt.links.new(tc.outputs["Object"], no.inputs["Vector"])
        nt.links.new(no.outputs["Fac"], bump.inputs["Height"])
        nt.links.new(bump.outputs["Normal"], bsdf.inputs["Normal"])


def trunk(name, path, r0, r1, mat, g, hi, sides, flute=0.0):
    """Tapered tube along a polyline; flute > 0 ridges it (hornbeam)."""
    pts = catmull(path, L(hi, 1, 4))
    bm = bmesh.new()
    rows = []
    n = len(pts)
    for i, p in enumerate(pts):
        d = (pts[min(i + 1, n - 1)] - pts[max(i - 1, 0)]).normalized()
        q = Vector((0, 1, 0)).rotation_difference(d)
        r = r0 + (r1 - r0) * i / (n - 1)
        row = []
        for k in range(sides):
            a = 2 * math.pi * k / sides
            rr = r * (1.0 + flute * math.cos(a * 5)) if hi else r
            row.append(bm.verts.new(p + q @ Vector((math.cos(a) * rr, 0, math.sin(a) * rr))))
        rows.append(row)
    for i in range(n - 1):
        for k in range(sides):
            bm.faces.new((rows[i][k], rows[i][(k + 1) % sides], rows[i + 1][(k + 1) % sides], rows[i + 1][k]))
    bm.faces.new(list(reversed(rows[0])))
    bm.faces.new(rows[-1])
    return K.finish(bm, name, mat, g, hi)


def lumpy(seed, amp):
    """Deform for crown clumps: a few lobes so silhouettes are not spheres."""
    rnd = random.Random(seed)
    ph = [rnd.uniform(0, 6.28) for _ in range(4)]

    def f(p, n):
        k = 1.0 + amp * (math.sin(n.x * 5 + ph[0]) * math.sin(n.z * 4 + ph[1]) +
                         0.6 * math.sin(n.y * 6 + ph[2]) * math.cos(n.x * 3 + ph[3]))
        return p * k
    return f


def crown(g, tag, hi, clumps, mats, seed):
    """clumps: [(center, radii)] - the canopy as overlapping lumpy masses;
    each mass also sprouts a few smaller lobes on its upper side, so the
    outline reads as foliage, not as one smooth ball."""
    rnd = random.Random(seed * 101)
    for i, (c, r) in enumerate(clumps):
        superellipsoid(f"{g}_cl{i}_{tag}", r, c, mats[i % len(mats)], g, hi, (1.15, 1.0),
                       L(hi, (8, 6), (40, 24)), deform=lumpy(seed * 31 + i, 0.13))
        c = Vector(c)
        for k in range(2):
            a = rnd.uniform(0, 6.28)
            el = rnd.uniform(0.2, 0.9)
            off = Vector((math.cos(a) * math.cos(el) * r[0], math.sin(el) * r[1], math.sin(a) * math.cos(el) * r[2])) * 0.8
            rr = min(r) * rnd.uniform(0.38, 0.5)
            superellipsoid(f"{g}_lb{i}_{k}_{tag}", (rr, rr * 0.85, rr), c + off, mats[(i + k + 1) % len(mats)], g, hi,
                           (1.0, 1.0), L(hi, (6, 4), (24, 14)), deform=lumpy(seed * 57 + i * 3 + k, 0.12))


def ring_clumps(rnd, center_y, radius, count, size, spread_y, jitter):
    out = []
    for k in range(count):
        a = 2 * math.pi * k / count + rnd.uniform(-0.3, 0.3)
        rr = radius * rnd.uniform(0.75, 1.0)
        c = Vector((math.cos(a) * rr, center_y + rnd.uniform(-spread_y, spread_y), math.sin(a) * rr))
        s = size * rnd.uniform(1.0 - jitter, 1.0 + jitter)
        out.append((c, (s, s * 0.8, s)))
    return out


def build_beech(hi):
    tag, g = ("H" if hi else "L"), "kb_beech"
    rnd = random.Random(11)
    trunk(f"{g}_trunk_{tag}", [Vector((0, 0, 0)), Vector((0.1, 4.0, 0)), Vector((0.15, 8.0, 0.1))], 0.38, 0.2,
          "bark_beech", g, hi, L(hi, 6, 18))
    for k, (dx, dz) in enumerate(((1.6, 0.4), (-1.4, 0.9), (0.3, -1.6))):
        trunk(f"{g}_limb{k}_{tag}", [Vector((0.1, 6.0 + k * 0.6, 0)), Vector((dx, 8.6 + k * 0.4, dz))], 0.14, 0.08,
              "bark_beech", g, hi, L(hi, 4, 10))
    cl = [(Vector((0.1, 10.2, 0.0)), (3.4, 2.6, 3.3))]
    cl += ring_clumps(rnd, 9.2, 2.6, 5, 2.3, 0.6, 0.2)
    cl += [(Vector((0.4, 12.0, -0.3)), (2.2, 1.6, 2.1))]
    crown(g, tag, hi, cl, ["leaf_beech", "leaf_beech_lt", "leaf_beech"], 1)


def build_oak(hi):
    tag, g = ("H" if hi else "L"), "kb_oak"
    rnd = random.Random(23)
    trunk(f"{g}_trunk_{tag}", [Vector((0, 0, 0)), Vector((0.25, 2.2, 0.1)), Vector((-0.1, 4.2, 0.2))], 0.52, 0.34,
          "bark_oak", g, hi, L(hi, 7, 18))
    limbs = [((2.6, 6.4, 0.6), 0.2), ((-2.4, 6.8, 1.1), 0.19), ((0.4, 7.2, -2.5), 0.18), ((0.9, 7.8, 1.9), 0.15)]
    for k, (end, r) in enumerate(limbs):
        e = Vector(end)
        mid = Vector((e.x * 0.45, 5.4, e.z * 0.45)) + Vector((rnd.uniform(-0.3, 0.3), 0, rnd.uniform(-0.3, 0.3)))
        trunk(f"{g}_limb{k}_{tag}", [Vector((-0.05, 3.9, 0.15)), mid, e], r, r * 0.45, "bark_oak", g, hi, L(hi, 4, 10))
    cl = [(Vector((2.7, 7.6, 0.7)), (2.7, 2.0, 2.6)), (Vector((-2.5, 8.0, 1.2)), (2.6, 2.0, 2.5)),
          (Vector((0.4, 8.2, -2.6)), (2.6, 1.9, 2.4)), (Vector((0.9, 9.0, 2.0)), (2.3, 1.8, 2.3)),
          (Vector((0.0, 9.6, 0.0)), (3.0, 2.0, 2.9)), (Vector((-1.2, 7.0, -1.0)), (1.8, 1.4, 1.8))]
    crown(g, tag, hi, cl, ["leaf_oak", "leaf_oak_dk", "leaf_oak"], 2)


def build_hornbeam(hi):
    tag, g = ("H" if hi else "L"), "kb_hornbeam"
    rnd = random.Random(37)
    trunk(f"{g}_trunk_{tag}", [Vector((0, 0, 0)), Vector((-0.1, 2.5, 0.05)), Vector((0.05, 5.2, 0))], 0.3, 0.17,
          "bark_hornbeam", g, hi, L(hi, 6, 20), flute=0.12)
    cl = [(Vector((0, 7.4, 0)), (2.4, 3.2, 2.3))]
    cl += ring_clumps(rnd, 6.6, 1.6, 4, 1.7, 0.8, 0.2)
    cl += [(Vector((0.1, 9.6, 0.1)), (1.5, 1.4, 1.5))]
    crown(g, tag, hi, cl, ["leaf_hornbeam", "leaf_hornbeam_lt"], 3)


def build_maple(hi):
    tag, g = ("H" if hi else "L"), "kb_maple"
    rnd = random.Random(41)
    trunk(f"{g}_trunk_{tag}", [Vector((0, 0, 0)), Vector((0.1, 2.0, 0)), Vector((0.0, 3.6, 0.1))], 0.3, 0.2,
          "bark_maple", g, hi, L(hi, 6, 16))
    for k, (dx, dz) in enumerate(((1.3, 0.3), (-1.2, 0.6), (0.2, -1.3))):
        trunk(f"{g}_limb{k}_{tag}", [Vector((0.0, 3.3, 0.1)), Vector((dx, 5.4, dz))], 0.14, 0.08, "bark_maple", g, hi,
              L(hi, 4, 10))
    cl = [(Vector((0, 6.4, 0)), (3.0, 2.5, 3.0))]
    cl += ring_clumps(rnd, 6.0, 2.0, 5, 1.8, 0.5, 0.2)
    crown(g, tag, hi, cl, ["leaf_maple", "leaf_maple_lt"], 4)


def build_pine(hi):
    tag, g = ("H" if hi else "L"), "kb_pine"
    trunk(f"{g}_trunk_{tag}", [Vector((0, 0, 0)), Vector((0.15, 5.0, 0)), Vector((0.35, 9.0, 0.1))], 0.32, 0.22,
          "bark_pine_low", g, hi, L(hi, 6, 16))
    trunk(f"{g}_top_{tag}", [Vector((0.35, 9.0, 0.1)), Vector((0.45, 12.4, 0.2))], 0.22, 0.1,
          "bark_pine_top", g, hi, L(hi, 5, 12))
    # Flat, tiered umbrella crown of the mountain pine.
    tiers = [((0.4, 10.0, 0.1), (2.6, 0.75, 2.4)), ((1.1, 11.1, 0.6), (2.1, 0.65, 1.9)),
             ((-0.4, 11.6, -0.4), (1.9, 0.6, 1.8)), ((0.5, 12.5, 0.2), (1.5, 0.55, 1.4))]
    for i, (c, r) in enumerate(tiers):
        superellipsoid(f"{g}_tier{i}_{tag}", r, c, "needle" if i % 2 == 0 else "needle_lt", g, hi, (0.8, 1.0),
                       L(hi, (9, 5), (40, 18)), deform=lumpy(90 + i, 0.08))


def build_bush(hi):
    tag, g = ("H" if hi else "L"), "kb_bush"
    rnd = random.Random(53)
    for i in range(4):
        a = 2 * math.pi * i / 4 + rnd.uniform(-0.3, 0.3)
        c = Vector((math.cos(a) * 0.9, 0.85 + rnd.uniform(0, 0.3), math.sin(a) * 0.9))
        superellipsoid(f"{g}_m{i}_{tag}", (1.1, 0.9, 1.0), c, "bush" if i % 2 else "bush_lt", g, hi, (1.0, 1.0),
                       L(hi, (8, 5), (32, 18)), deform=lumpy(60 + i, 0.1))
    superellipsoid(f"{g}_top_{tag}", (1.0, 0.8, 1.0), (0.0, 1.5, 0.0), "bush_lt", g, hi, (1.0, 1.0),
                   L(hi, (8, 5), (32, 18)), deform=lumpy(66, 0.1))
    if hi:
        for i in range(14):
            a = rnd.uniform(0, 6.28)
            ellipsoid(f"{g}_b{i}", (0.07, 0.07, 0.07),
                      (math.cos(a) * 1.5, rnd.uniform(0.6, 1.6), math.sin(a) * 1.5), "berry", g, True, (8, 6))


def build_rock(hi):
    tag, g = ("H" if hi else "L"), "kb_rock"
    pieces = [((0, 0.9, 0), (1.9, 1.2, 1.5), 70), ((1.6, 0.6, 0.8), (1.0, 0.75, 0.9), 71),
              ((-1.3, 0.5, -0.6), (1.1, 0.7, 1.0), 72)]
    for i, (c, r, sd) in enumerate(pieces):
        superellipsoid(f"{g}_p{i}_{tag}", r, c, "rock" if i == 0 else "rock_dk", g, hi, (0.7, 0.8),
                       L(hi, (8, 6), (32, 20)), deform=lumpy(sd, 0.12))
    superellipsoid(f"{g}_moss_{tag}", (1.5, 0.25, 1.1), (0.0, 2.0, 0.0), "moss", g, hi, (0.6, 0.9),
                   L(hi, (8, 4), (28, 10)), deform=lumpy(73, 0.1))


def build_post(hi):
    """Roadside reflector post: 1.1 m white post, black band at the top, red
    reflector facing the traffic (+Z is the face the decor turns to the road)."""
    tag, g = ("H" if hi else "L"), "kb_post"
    bbox(f"{g}_body_{tag}", (0.12, 1.0, 0.12), (0, 0.5, 0), "post_white", g, hi, L(hi, 0.0, 0.015))
    bbox(f"{g}_band_{tag}", (0.125, 0.22, 0.125), (0, 0.9, 0), "post_black", g, hi, L(hi, 0.0, 0.01))
    bbox(f"{g}_refl_{tag}", (0.07, 0.14, 0.02), (0, 0.9, 0.066), "reflector", g, hi, L(hi, 0.0, 0.006))
    bbox(f"{g}_cap_{tag}", (0.13, 0.04, 0.13), (0, 1.02, 0), "post_black", g, hi, L(hi, 0.0, 0.01))


def build_lamp(hi):
    """Modern highway lamp as on the new Karabakh roads: a 9 m galvanised
    pole, an arm curving out over the road (+Z faces the road), a flat LED
    head whose underside glows at night."""
    tag, g = ("H" if hi else "L"), "kb_lamp"
    trunk(f"{g}_pole_{tag}", [Vector((0, 0, 0)), Vector((0, 4.5, 0)), Vector((0, 9.0, 0))], 0.13, 0.07,
          "lamp_pole", g, hi, L(hi, 6, 16))
    trunk(f"{g}_arm_{tag}", [Vector((0, 8.7, 0)), Vector((0, 9.35, 0.6)), Vector((0, 9.5, 1.6)), Vector((0, 9.45, 2.6))],
          0.05, 0.045, "lamp_pole", g, hi, L(hi, 5, 10))
    bbox(f"{g}_head_{tag}", (0.36, 0.13, 0.85), (0, 9.42, 2.9), "lamp_head", g, hi, L(hi, 0.0, 0.03))
    bbox(f"{g}_led_{tag}", (0.28, 0.02, 0.7), (0, 9.345, 2.92), "lamp_led", g, hi, L(hi, 0.0, 0.005))
    bbox(f"{g}_base_{tag}", (0.38, 0.5, 0.38), (0, 0.25, 0), "lamp_head", g, hi, L(hi, 0.0, 0.03))


BUILDERS = {"kb_lamp": build_lamp, "kb_beech": build_beech, "kb_oak": build_oak, "kb_hornbeam": build_hornbeam, "kb_maple": build_maple,
            "kb_pine": build_pine, "kb_bush": build_bush, "kb_rock": build_rock, "kb_post": build_post}
OFFSET = {g: Vector((i * 16.0, 0.0, 0.0)) for i, g in enumerate(GROUPS)}


def build(hi):
    global _bumped
    if hi and not _bumped:
        add_bumps()
        _bumped = True
    for g in GROUPS:
        before = set(K.COLL.objects)
        BUILDERS[g](hi)
        for o in set(K.COLL.objects) - before:
            o.data.transform(Matrix.Translation(OFFSET[g]))


def _home(groups):
    for o in groups:
        o.data.transform(Matrix.Translation(-OFFSET[o.name]))


K.PRE_EXPORT.append(_home)
K.CAGE = 0.05
K.RAY = 0.12
K.AO_DIST = 0.6
K.setup("karabakh_flora", "assets/models/karabakh_flora", PALETTE, PAINT_MAT, GROUPS, UV_SCALE, FAR_RATIO, stone_mats=STONE)
K.run(build)
