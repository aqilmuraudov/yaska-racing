"""İçərişəhər props for Yaska Racing (0.14.x Blender models): four Old City
houses (house_a..house_d) and the Maiden Tower (maiden_tower).

  blender --background --factory-startup --python tools/blender/oldcity_props.py -- --bake-res 4096 --tex-res 2048
Same pipeline as the karts (kart_common.run): one mesh per prop id (the node
names are PropKit ids), one shared 2048² texture set. Footprints, heights and
the +Z facade match PropKit._house / _maiden_tower, so placement, occluders and
the AoMap stay valid. Stone relief comes from a Voronoi bump in the high
model's material (Cycles bakes it into the normal map); albedo alpha marks
stone for the world-space limestone detail in prop_baked.gdshader, orm alpha
marks window glass for the night glow.
"""

import math
import os
import sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from kart_common import *  # noqa: F401,F403
import kart_common as K
from mathutils import Vector, Matrix, Euler, Quaternion

PALETTE = {
    "limestone": ("D9C29A", 0.85, 0.0),
    "limestone_warm": ("E0B98A", 0.85, 0.0),
    "plinth": ("B59A72", 0.9, 0.0),
    "tower_stone": ("CDBB98", 0.85, 0.0),
    "tower_course": ("B8A47F", 0.85, 0.0),
    "rock": ("8F8170", 0.9, 0.0),
    "plaster_cream": ("EADCC0", 0.75, 0.0),
    "plaster_white": ("F2ECE0", 0.75, 0.0),
    "wood": ("7A4A2A", 0.6, 0.0),
    "wood_teal": ("2F7F86", 0.55, 0.0),
    "door": ("6A3E22", 0.6, 0.0),
    "iron": ("2E2B36", 0.5, 0.6),
    "glass": ("2F5F86", 0.08, 0.3),
    "terracotta": ("C8643C", 0.7, 0.0),
    "slit": ("1E2A3A", 0.8, 0.0),
}
PAINT_MAT = "glass"   # orm alpha = window glass (night glow)
STONE = ["limestone", "limestone_warm", "plinth", "tower_stone", "tower_course"]
GROUPS = ["house_a", "house_b", "house_c", "house_d", "maiden_tower"]
UV_SCALE = {g: 1.0 for g in GROUPS}
FAR_RATIO = {"house_a": 0.55, "house_b": 0.5, "house_c": 0.55, "house_d": 0.5, "maiden_tower": 0.35}

HOUSE_W = [9.0, 8.0, 10.0, 7.5]
HOUSE_H = [8.5, 10.5, 7.2, 11.5]
HOUSE_D = 8.0
_bumped = False


def add_bump():
    """Voronoi 'distance to edge' bump on the stone materials: coursed blocks
    (stretched cells) with mortar grooves, baked into the normal map."""
    for name in STONE:
        m = K.MATS[name]
        nt = m.node_tree
        bsdf = nt.nodes["Principled BSDF"]
        tc = nt.nodes.new("ShaderNodeTexCoord")
        mp = nt.nodes.new("ShaderNodeMapping")
        mp.inputs["Scale"].default_value = (1 / 0.9, 1 / 0.42, 1 / 0.9) if name != "rock" else (1, 1, 1)
        vo = nt.nodes.new("ShaderNodeTexVoronoi")
        vo.feature = "DISTANCE_TO_EDGE"
        vo.inputs["Scale"].default_value = 1.0
        mr = nt.nodes.new("ShaderNodeMapRange")
        mr.inputs["From Min"].default_value = 0.0
        mr.inputs["From Max"].default_value = 0.08
        bump = nt.nodes.new("ShaderNodeBump")
        bump.inputs["Strength"].default_value = 0.7
        bump.inputs["Distance"].default_value = 0.03
        nt.links.new(tc.outputs["Object"], mp.inputs["Vector"])
        nt.links.new(mp.outputs["Vector"], vo.inputs["Vector"])
        nt.links.new(vo.outputs["Distance"], mr.inputs["Value"])
        nt.links.new(mr.outputs["Result"], bump.inputs["Height"])
        nt.links.new(bump.outputs["Normal"], bsdf.inputs["Normal"])


def arch_outline(w, h, n):
    hw = w * 0.5
    pts = [(-hw, 0.0), (hw, 0.0)]
    for k in range(n + 1):
        a = math.pi * k / n
        pts.append((math.cos(a) * hw, h - hw + math.sin(a) * hw))
    return pts


def arch(name, base, w, h, fill, g, hi, normal=(0, 0, 1), surround="plaster_cream", depth=0.08, sill=True):
    """Arched window / door on a wall: filled panel, stone surround, sill."""
    n = Vector(normal)
    up = Vector((0, 1, 0))
    x = up.cross(n).normalized()
    m = Matrix((x, up, n)).transposed().to_4x4()
    m.translation = Vector(base)
    puffy(f"{name}_panel_{'H' if hi else 'L'}", arch_outline(w, h, L(hi, 4, 16)), depth, 0.0, m, fill, g, hi)
    hw = w * 0.5 + 0.08
    path = [Vector((-hw, 0.0, 0.05)), Vector((-hw, h - hw + 0.08, 0.05))]
    for k in range(1, L(hi, 4, 16)):
        a = math.pi - math.pi * k / L(hi, 4, 16)
        path.append(Vector((math.cos(a) * hw, h - hw + 0.08 + math.sin(a) * hw, 0.05)))
    path += [Vector((hw, h - hw + 0.08, 0.05)), Vector((hw, 0.0, 0.05))]
    tube(f"{name}_frame_{'H' if hi else 'L'}", [m @ p for p in path], 0.07, surround, g, hi, 1, L(hi, 3, 8), False)
    if sill:
        bbox(f"{name}_sill_{'H' if hi else 'L'}", (w + 0.35, 0.12, 0.3), m @ Vector((0, -0.06, 0.12)), surround, g, hi,
             L(hi, 0.0, 0.03), rot=Matrix((x, up, n)).transposed().to_euler())


def build_house(v, hi):
    tag = "H" if hi else "L"
    g = GROUPS[v]
    w, h, d = HOUSE_W[v], HOUSE_H[v], HOUSE_D
    stone = "limestone" if v % 2 == 0 else "limestone_warm"
    bbox(f"{g}_walls_{tag}", (w, h, d), (0, h * 0.5, 0), stone, g, hi, 0.06)
    bbox(f"{g}_plinth_{tag}", (w + 0.12, 0.6, d + 0.12), (0, 0.3, 0), "plinth", g, hi, 0.04)
    bbox(f"{g}_cornice_{tag}", (w + 0.3, 0.3, d + 0.3), (0, h + 0.05, 0), "plaster_cream", g, hi, 0.1)
    bbox(f"{g}_parapet_{tag}", (w, 0.6, 0.25), (0, h + 0.45, d * 0.5 - 0.12), stone, g, hi, 0.04)
    fz = d * 0.5 + 0.01
    arch(f"{g}_door", (-w * 0.25, 0.0, fz), 1.5, 2.6, "door", g, hi, sill=False)
    arch(f"{g}_shop", (w * 0.22, 0.6, fz), 1.8, 1.9, "glass", g, hi)
    floors = int((h - 3.6) / 3.0) + 1
    for f in range(floors):
        y = 3.8 + f * 3.0
        if y + 2.0 > h:
            break
        count = int(w / 2.6)
        for i in range(count):
            x = -w * 0.5 + (i + 0.5) * (w / count)
            if f == 0 and v != 2 and count // 2 - 1 <= i <= count // 2:
                continue
            arch(f"{g}_win{f}{i}", (x, y, fz), 1.0, 1.7, "glass", g, hi)
        # One small window on each side wall per floor.
        for s in (-1, 1):
            arch(f"{g}_side{f}{s}", (s * (w * 0.5 + 0.01), y, -0.5), 0.8, 1.4, "glass", g, hi, normal=(s, 0, 0))
    if v != 2:
        bw = min(w * 0.5, 4.6)
        by = 3.5
        wood = "wood_teal" if v % 2 == 0 else "wood"
        bbox(f"{g}_bal_floor_{tag}", (bw, 0.25, 1.1), (0, by, fz + 0.55), wood, g, hi, 0.03)
        bbox(f"{g}_bal_low_{tag}", (bw, 0.9, 1.0), (0, by + 0.55, fz + 0.55), wood, g, hi, 0.03)
        bbox(f"{g}_bal_glass_{tag}", (bw - 0.1, 1.2, 0.9), (0, by + 1.6, fz + 0.5), "glass", g, hi, 0.0)
        mull = int(bw / 0.7)
        for k in range(mull + 1):
            mx = -bw * 0.5 + k * (bw / mull)
            bbox(f"{g}_bal_mull{k}_{tag}", (0.09, 1.25, 0.12), (mx, by + 1.6, fz + 0.97), wood, g, hi, 0.0)
            for s in (-1, 1):
                bbox(f"{g}_bal_side{k}{s}_{tag}", (0.12, 1.25, 0.09), (s * (bw * 0.5 + 0.02), by + 1.6,
                                                                          fz + 0.1 + 0.8 * k / max(mull, 1)),
                     wood, g, hi, 0.0)
        bbox(f"{g}_bal_rail_{tag}", (bw + 0.2, 0.22, 1.2), (0, by + 2.3, fz + 0.55), wood, g, hi, 0.03)
        bbox(f"{g}_bal_roof_{tag}", (bw + 0.4, 0.12, 1.4), (0, by + 2.45, fz + 0.6), "terracotta", g, hi, 0.02,
             rot=(0.12, 0, 0))
        bbox(f"{g}_bal_mid_{tag}", (bw - 0.1, 0.06, 0.92), (0, by + 1.6, fz + 0.5), wood, g, hi, 0.0)
        if hi:
            # Carved panel diamonds on the lower balcony boards.
            for k in range(int(bw / 0.45)):
                mx = -bw * 0.5 + 0.22 + k * 0.45
                puffy(f"{g}_carve{k}", [(-0.14, 0), (0, 0.24), (0.14, 0), (0, -0.24)], 0.012, 0.004,
                      K.trs((mx, by + 0.55, fz + 1.06)), wood, g, True)
    if v in (1, 3):
        superellipsoid(f"{g}_dome_{tag}", (1.3, 1.0, 1.3), (w * 0.2, h + 0.9, -1.0), "plaster_cream", g, hi,
                       (0.8, 1.0), L(hi, (14, 8), (40, 20)))
        lathe(f"{g}_drum_{tag}", [(0.0, 1.4), (0.4, 1.4)], (0, 0, 0), stone, g, hi, L(hi, 14, 40), False, True
              ).data.transform(K.trs((w * 0.2, h, -1.0), (0, 0, math.pi / 2)))
    else:
        bbox(f"{g}_kiosk_{tag}", (1.2, 1.0, 1.2), (-w * 0.3, h + 0.5, -2.0), "plaster_white", g, hi, 0.06)
        bbox(f"{g}_kiosk_cap_{tag}", (1.4, 0.12, 1.4), (-w * 0.3, h + 1.05, -2.0), "plaster_cream", g, hi, 0.04)


def build_tower(hi):
    tag = "H" if hi else "L"
    g = "maiden_tower"
    r0, r1, h, base = 8.25, 7.6, 29.5, 1.2
    up = K.trs((0, 0, 0), (0, 0, math.pi / 2))  # lathe axis X -> Y
    lathe(f"rock_{tag}", [(-0.2, r0 * 1.35), (0.5, r0 * 1.3), (base + 0.2, r0 * 1.15), (base + 0.2, 0.0)], (0, 0, 0),
          "rock", g, hi, L(hi, 24, 64), False, False).data.transform(up)
    lathe(f"body_{tag}", [(base, r0), (base + h, r1), (base + h, 0.0)], (0, 0, 0), "tower_stone", g, hi,
          L(hi, 40, 128), False, False).data.transform(up)
    # 0.15.3 (photos): the upper ~45 % is dense ribbed coursing - every
    # course steps out a little with a sloped underside; the lower part is
    # plain rough masonry (the Voronoi bump). High model only: the ribs are
    # baked into the normal / AO maps of the smooth low tower.
    if hi:
        y = base + h * 0.55
        k = 0
        while y < base + h - 0.4:
            rr = r0 + (r1 - r0) * (y - base) / h
            lathe(f"rib{k}_{tag}", [(y - 0.16, rr), (y, rr + 0.13), (y + 0.06, rr + 0.13), (y + 0.06, rr)], (0, 0, 0),
                  "tower_course", g, hi, 128).data.transform(up)
            y += 0.42
            k += 1
    # Beak-shaped buttress on +x, lower than the tower (~85 %).
    bh = h * 0.85
    segs = L(hi, 8, 20)
    plan = []
    for k in range(segs + 1):
        t = k / segs
        ang = -math.pi / 2 + math.pi * t
        plan.append((r0 - 1.0 + 5.6 * math.cos(ang) * (0.35 + 0.65 * math.cos(ang)),
                     4.6 * math.sin(ang) * (1.0 - 0.45 * math.cos(ang))))
    bm = bmesh.new()
    lo = [bm.verts.new((px, base, pz)) for px, pz in plan]
    hi_v = [bm.verts.new(((px - r0) * 0.86 + r1, base + bh, pz * 0.86)) for px, pz in plan]
    for k in range(segs):
        bm.faces.new((lo[k], lo[k + 1], hi_v[k + 1], hi_v[k]))
    bm.faces.new(hi_v)
    top = base + bh - 0.01
    K.finish(bm, f"buttress_{tag}", "tower_stone", g, hi,
             outward=lambda p: Vector((p.x, 3.0 if p.y > top else 0.0, p.z)), smooth=False)
    if hi:
        # Ribbed coursing on the outer face of the buttress top as well.
        for k in range(int(bh * 0.4 / 0.42)):
            yy = base + bh * 0.6 + k * 0.42
            t = (yy - base) / bh
            bbox(f"brib{k}", (0.26, 0.1, 9.2 * (1.0 - 0.14 * t)), (r0 - 1.0 + 4.6 * (1.0 - 0.14 * t) + 0.8 + (r1 - r0) * t,
                 yy, 0.0), "tower_course", g, hi, 0.0)
    lathe(f"parapet_{tag}", [(base + h, r1 + 0.1), (base + h + 0.9, r1 + 0.1), (base + h + 0.9, r1 - 0.5),
                             (base + h + 0.4, r1 - 0.5)], (0, 0, 0), "tower_course", g, hi, L(hi, 40, 128)
          ).data.transform(up)
    for i, (ang, y) in enumerate(((0.7, 9.0), (2.3, 15.5), (3.6, 21.0), (5.2, 12.0), (1.6, 25.0))):
        rr = r0 + (r1 - r0) * y / h
        bbox(f"slit{i}_{tag}", (0.35, 1.3, 0.5), (math.cos(ang) * rr, base + y, math.sin(ang) * rr), "slit", g, hi,
             0.0, rot=(0, -ang + math.pi / 2, 0))
    arch("tower_door", (-r0 + 0.05, base, 0.0), 1.1, 2.2, "door", g, hi, normal=(-1, 0, 0), surround="tower_course",
         sill=False)


# Props are baked apart (AO must not see the neighbours) and moved back before export.
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
    for v in range(4):
        _built(lambda: build_house(v, hi), GROUPS[v])
    _built(lambda: build_tower(hi), "maiden_tower")


def _home(groups):
    for o in groups:
        o.data.transform(Matrix.Translation(-OFFSET[o.name]))


K.PRE_EXPORT.append(_home)


K.setup("oldcity_props", "assets/models/oldcity", PALETTE, PAINT_MAT, GROUPS, UV_SCALE, FAR_RATIO, stone_mats=STONE)
K.run(build)
