"""Qarabağ terrain for Yaska Racing (0.19.0, the big map), built and baked in Blender.

  godot --headless --path . -s tools/export_road_samples.gd -- karabakh
  blender --background --factory-startup --python tools/blender/karabakh_terrain.py [-- --res 4096 --no-bake]

Reads tools/blender/out/karabakh_road.json (TrackPath samples: the road is
the one source of truth) and data/tracks/karabakh.json (zones, rivers,
landmark plots).
Writes assets/models/karabakh/:
  terrain.glb        Tile_<i>_<j> (near) + Tile_<i>_<j>_far, Mountains, River_<id>
  terrain_albedo.png the valley around the course, baked (colour x AO)
  mountains_albedo.png the ring of mountains
  heights.bin + heights.json  the height grid Godot samples (tree / prop
                     placement, TrackBuilder.terrain_height)
  trees.json         the forest: [kind, x, y, z, yaw, scale] in Godot space
Godot space throughout the maths (x east, y up, z south); meshes are built
in Blender space (X = x, Y = -z, Z = y) and the glTF export (+Y up) turns
them back.

The landscape (north = -z), a 4.9 km loop:
  * Xankəndi: the start straight in the north-east (y 12), open town ground.
  * the climb to the Şuşa plateau (y 44) in the centre-north: a flat table
    of rock; south of it the Daşaltı gorge drops ~38 m below limestone cliffs.
  * the descent west to Laçın (y 20) above the Həkəri river, then south down
    the Həkəri valley to the Araz.
  * the Araz bank (y 2) in the south: the wide river, the Xudafərin bridges,
    the drier far bank; then north through forest hills back to Xankəndi.
  * forest hills fill the inside of the loop, a ring of forested mountains
    (to ~190 m) closes the horizon.
Zones (towns / sights) are flattened open ground with few trees.
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
# 0.20.1: one script for every Qarabağ map: --track <id> (default the big map).
TRACK_ID = arg("--track", "karabakh")
WORK = os.path.join(ROOT, "tools", "blender", "out")
RES = int(arg("--res", "4096" if TRACK_ID == "karabakh" else "2048"))
BAKE = "--no-bake" not in ARGV
RENDER = "--render" in ARGV

ROAD = json.load(open(os.path.join(WORK, TRACK_ID + "_road.json"), encoding="utf-8"))
TRACK = json.load(open(os.path.join(ROOT, "data", "tracks", TRACK_ID + ".json"), encoding="utf-8"))
OUT = os.path.join(ROOT, TRACK["terrain_dir"].replace("res://", ""))
TERRAIN = TRACK.get("terrain", {})   # short maps: their own extents and landscape anchors
PTS = np.array(ROAD["points"], dtype=np.float64)  # (n, 3) x, y, z
HW = np.array(ROAD["half_widths"], dtype=np.float64)
OW = float(ROAD["offroad_width"])
PLOTS = list(TRACK.get("landmark_plots", []))
for _nb in TRACK.get("name_boards", []):     # 0.20.1: 30 m in front of a name board kept free of trees
    _fx, _fz = math.sin(_nb["yaw"]), math.cos(_nb["yaw"])
    for _k in range(0, 31, 6):
        PLOTS.append([_nb["x"] + _fx * _k, _nb["z"] + _fz * _k, _nb["w"] / 2 + 2.0, _nb["zone"]])

# Inner (detailed) region and the mountain ring, in Godot x / z.
CELL = 3.0
X0, X1 = -1200.0, 1248.0     # 17 x 13 tiles: the coarse mountain mesh starts >= 380 m from the road
Z0, Z1 = -912.0, 960.0
MCELL = 20.0
MX0, MX1 = -2300.0, 2300.0
MZ0, MZ1 = -2100.0, 2220.0
if "inner" in TERRAIN:
    X0, X1, Z0, Z1 = (float(v) for v in TERRAIN["inner"])
    MX0, MX1, MZ0, MZ1 = (float(v) for v in TERRAIN["ring"])
TILE_CELLS = 48               # near tiles: 144 m

# Landscape anchors (Godot x, z).
SHUSHA = (50.0, -255.0, 300.0, 150.0)   # plateau centre and radii (the town table)
# Daşaltı gorge: a winding canyon under the southern edge of the plateau.
GORGE = np.array([[345.0, -140.0], [200.0, -92.0], [20.0, -68.0], [-150.0, -92.0]])
GORGE_FLOOR = 6.0
if "inner" in TERRAIN:
    SHUSHA = tuple(TERRAIN["plateau"]) if TERRAIN.get("plateau") else None
    GORGE = np.array(TERRAIN["gorge"], dtype=np.float64) if TERRAIN.get("gorge") else None
    GORGE_FLOOR = float(TERRAIN.get("gorge_floor", 6.0))
ZONES = TRACK.get("zones", [])          # [id, x, z, radius]
# 0.19.1 landmarks (tools/karabakh_layout.py): level pads under the footprints,
# terraces under boulevard runs, big peaks (Hoçaz).
LANDMARKS = TRACK.get("landmarks", []) + TRACK.get("name_boards", [])   # 0.20.1 the sights' name boards
LINES = TRACK.get("lines", [])
PEAKS = TRACK.get("peaks", [])
# 0.20.1 town fill (tools/karabakh_maps_layout.py "town"): decorative streets painted into the
# ground on their own terraces, roundabouts, houses on level pads. Heights resolved here
# (resolve_town) and written to town.json for Godot.
TOWN = TRACK.get("town")
TOWN_ON = False              # height() leaves the town out while its street heights are sampled
STREETS = []                 # {"pts": (n, 2), "y": (n,), "hw"}
TOWN_PADS = []               # {"id", "x", "y", "z", "yaw", "w", "d"} (houses, roundabout islands)
TOWN_HILL = float(TERRAIN.get("town_hill", 0.0))      # the town on a hill inside the loop
ZONE_FLAT = float(TERRAIN.get("zone_flat", 0.75))


def _chaikin(pts, rounds=3):
    """Corner cutting: the river polylines become smooth bends."""
    for _ in range(rounds):
        q = [pts[0]]
        for a, b in zip(pts[:-1], pts[1:]):
            q.append(a * 0.75 + b * 0.25)
            q.append(a * 0.25 + b * 0.75)
        q.append(pts[-1])
        pts = np.array(q)
    return pts


RIVERS = []
for _rv in TRACK.get("rivers", []):
    _p = _chaikin(np.array(_rv["points"], dtype=np.float64))
    _cum = np.concatenate([[0.0], np.cumsum(np.hypot(*np.diff(_p, axis=0).T))])
    if _rv.get("level") is not None:
        _lev = np.full(len(_p), float(_rv["level"]))
    else:  # falls along its length
        _lev = _rv["drop"][0] + (_rv["drop"][1] - _rv["drop"][0]) * _cum / _cum[-1]
    RIVERS.append({"id": _rv["id"], "pts": _p, "lev": _lev, "hw": float(_rv["width"]) / 2.0})
_ARAZ = next((r["pts"] for r in RIVERS if r["id"] == "araz"), None)


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
    px = PTS[::4, 0]
    pz = PTS[::4, 2]
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


def idw_road_height(xs, zs, power=2.0, every=6):
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


def river_fields(xs, zs):
    """Per river: plan distance to the centreline, water level there, half width."""
    out = []
    for rv in RIVERS:
        d = np.full(xs.shape, 1e9)
        lv = np.zeros(xs.shape)
        p = rv["pts"]
        lev = rv["lev"]
        for i in range(len(p) - 1):
            ax, az = p[i]
            vx, vz = p[i + 1] - p[i]
            t = np.clip(((xs - ax) * vx + (zs - az) * vz) / (vx * vx + vz * vz), 0.0, 1.0)
            dd = np.hypot(xs - (ax + t * vx), zs - (az + t * vz))
            m = dd < d
            d = np.where(m, dd, d)
            lv = np.where(m, lev[i] + (lev[i + 1] - lev[i]) * t, lv)
        out.append((d, lv, rv["hw"]))
    return out


def araz_z(xs):
    """The Araz's course (the dry far bank lies south of it); far away without the Araz."""
    if _ARAZ is None:
        return np.full(np.shape(xs), 1e6)
    return np.interp(xs, _ARAZ[:, 0], _ARAZ[:, 1])


def zone_mask(xs, zs):
    """1 inside a town / sight zone, fading out over its outer quarter."""
    m = np.zeros(xs.shape)
    for _id, zx, zz, zr in ZONES:
        m = np.maximum(m, 1.0 - smooth(zr * 0.75, zr, np.hypot(xs - zx, zs - zz)))
    return m


# --- Height ----------------------------------------------------------------------------

def peak_frame(pk, xs, zs):
    """u along the ridge (to the viewer's right, in radii), v towards the cliff face."""
    fx, fz = pk["face"]
    rx, rz = fz, -fx            # right of a viewer looking at the face
    dx, dz = xs - pk["x"], zs - pk["z"]
    return (dx * rx + dz * rz) / pk["r"], (dx * fx + dz * fz) / pk["r"]


def peak_crest(pk, xs, zs):
    """Hoçaz after the owner's photo: the summit at u = -0.25, a steep drop to the
    left, a long ridge falling to the right; a near-vertical limestone face on
    the town side (v > 0), a gentler wooded back."""
    u, v = peak_frame(pk, xs, zs)
    us = -0.25
    left = np.clip(1.0 - (us - u) / 0.42, 0.0, 1.0) ** 1.3
    right = np.clip(1.0 - (u - us) / 1.3, 0.0, 1.0) ** 1.15
    along = np.where(u < us, left, right)
    vv = v + 0.04 * fbm(xs, zs, 3, 1.0 / 40.0)          # a ragged foot of the cliff
    front = np.clip(1.0 - np.maximum(vv, 0.0) / 0.3, 0.0, 1.0) ** 0.7
    back = np.clip(1.0 - (np.maximum(-v, 0.0) / 0.75) ** 2, 0.0, 1.0)
    across = np.where(vv > 0.0, front, back)
    ledges = 1.0 + 0.05 * fbm(xs, zs, 4, 1.0 / 25.0) * smooth(0.0, 0.1, v)
    return pk["h"] * along * across * ledges * (0.94 + 0.12 * ridge(xs * 1.4, zs * 1.4))


def peak_mask(xs, zs):
    m = np.zeros(xs.shape)
    for pk in PEAKS:
        m = np.maximum(m, smooth(10.0, 40.0, peak_crest(pk, xs, zs)))
    return m


def natural(xs, zs, droad, inside):
    """The landscape before the road is cut in. Returns (h, river distance
    past the bank [< 0 in the water], zone mask)."""
    base = idw_road_height(xs, zs)
    h = base + fbm(xs, zs) * 2.2
    # Inside the loop: forest hills, higher towards the north.
    hills = np.maximum(11.0 + 9.0 * fbm(xs, zs, 4, 1.0 / 240.0) + 6.0 * smooth(300.0, -500.0, zs), 2.0)
    h = np.where(inside, h + hills * smooth(30.0, 170.0, droad), h)
    if TOWN_HILL > 0.0:      # Laçın: the town climbs a hill inside the loop (owner's aerial photos)
        h = np.where(inside, h + TOWN_HILL * smooth(15.0, 110.0, droad), h)
    # Outside: the mountain ring rises with distance from the course.
    far = smooth(70.0, 520.0, droad)
    mount = (55.0 + 95.0 * ridge(xs, zs)) * far * far + fbm(xs, zs, 4, 1.0 / 90.0) * 6.0 * far
    h = np.where(inside, h, h + mount)
    # Big peaks (Hoçaz): a rocky mass well above the ring, a ridged crest.
    for pk in PEAKS:
        h = h + peak_crest(pk, xs, zs)
    # Towns and sights stand on open, nearly level ground at road height;
    # the Şuşa plateau is a full table.
    zm = zone_mask(xs, zs)
    if SHUSHA is None:
        plate = np.zeros(xs.shape)
    else:
        plate = 1.0 - smooth(0.8, 1.15, np.hypot((xs - SHUSHA[0]) / SHUSHA[2], (zs - SHUSHA[1]) / SHUSHA[3]))
    flat = np.maximum(zm * ZONE_FLAT, plate)
    h = h * (1.0 - flat) + (base + 0.8 + fbm(xs, zs, 3, 1.0 / 60.0)) * flat
    # Daşaltı gorge under the plateau: limestone cliffs, then the gorge floor.
    if GORGE is not None:
        dg = polyline_dist(xs, zs, GORGE) + fbm(xs, zs, 3, 1.0 / 45.0) * 9.0
        cut = 1.0 - smooth(34.0, 52.0, dg)
        h = h * (1.0 - cut) + (GORGE_FLOOR + fbm(xs, zs, 3, 1.0 / 50.0) * 2.5) * cut
    # Rivers: a bed 1.4 m under the water, a gravel shore just above it, then
    # banks blending into the land.
    rdist = np.full(xs.shape, 1e9)
    wob = fbm(xs, zs, 2, 1.0 / 35.0) * 4.0
    for d, lv, hw in river_fields(xs, zs):
        bed = lv - 1.4
        # 0.20.1: far from the road (the mountain ring) the valley opens wide - no dark slit canyon
        bank = smooth(hw - 6.0, hw + 38.0 + hw + 160.0 * far, d + wob)
        carved = bed + (h - bed) * bank
        shore = np.minimum(h, bed + 1.75 * np.clip((d - hw + 1.0) / 3.0, 0.0, 1.0))
        carved = np.where(d > hw - 1.0, np.maximum(carved, shore), carved)
        h = np.where(h > bed, carved, h)
        rdist = np.minimum(rdist, d - hw)
    return h, rdist, zm


def height(xs, zs, with_canopy=False):
    droad, yroad, edge = road_query(xs, zs)
    inside = inside_loop(xs, zs)
    nat, rdist, zm = natural(xs, zs, droad, inside)
    # Cut the road in: 0.7 m under the verge, banks blending within ~25 m.
    k = droad - (edge + 1.2)
    t = smooth(0.0, 25.0, k)
    h = (yroad - 0.7) * (1.0 - t) + nat * t
    cut_max = yroad - 0.5 + np.maximum(k, 0.0) * 0.9     # cut slope <= ~42 deg
    fill_min = yroad - 0.7 - np.maximum(k, 0.0) * 1.4
    h = np.clip(h, fill_min, cut_max)
    h = np.where(k < 0.0, yroad - 0.7, h)
    # Level pads under the landmarks and terraces under the boulevard (after
    # the road cut: their edges stay >= 3 m behind the run-off).
    pad = np.zeros(xs.shape)
    for ln in LINES:
        if ln["points"][0][2] is None:      # a wall on the ground: protect its corridor from decimation only
            pts = ln["points"]
            d = np.full(xs.shape, 1e9)
            for a, b in zip(pts[:-1], pts[1:]):
                vx, vz = b[0] - a[0], b[1] - a[1]
                t2 = np.clip(((xs - a[0]) * vx + (zs - a[1]) * vz) / (vx * vx + vz * vz), 0.0, 1.0)
                d = np.minimum(d, np.hypot(xs - (a[0] + t2 * vx), zs - (a[1] + t2 * vz)))
            pad = np.maximum(pad, 1.0 - smooth(ln["width"] / 2 + 2.0, ln["width"] / 2 + 6.0, d))
            continue
        pts = [q for q in ln["points"] if q[2] is not None]
        if len(pts) < 2:
            continue
        d = np.full(xs.shape, 1e9)
        ly = np.zeros(xs.shape)
        for a, b in zip(pts[:-1], pts[1:]):
            vx, vz = b[0] - a[0], b[1] - a[1]
            t2 = np.clip(((xs - a[0]) * vx + (zs - a[1]) * vz) / (vx * vx + vz * vz), 0.0, 1.0)
            dd = np.hypot(xs - (a[0] + t2 * vx), zs - (a[1] + t2 * vz))
            mm = dd < d
            d = np.where(mm, dd, d)
            ly = np.where(mm, a[2] + (b[2] - a[2]) * t2, ly)
        m = 1.0 - smooth(ln["width"] / 2, ln["width"] / 2 + 10.0, d)
        h = h * (1.0 - m) + ly * m
        pad = np.maximum(pad, 1.0 - smooth(ln["width"] / 2, ln["width"] / 2 + 2.0, d))
    street = np.zeros(xs.shape)
    clear = np.zeros(xs.shape)       # town: no forest canopy round the houses / along the streets
    if TOWN_ON:              # town streets: each on its own terrace, painted (asphalt)
        fx_, fz_ = xs.ravel(), zs.ravel()
        hf, sf, pf = h.ravel().copy(), street.ravel(), pad.ravel()
        cf = clear.ravel()
        for st in STREETS:
            win = np.nonzero((fx_ > st["box"][0]) & (fx_ < st["box"][1]) & (fz_ > st["box"][2]) & (fz_ < st["box"][3]))[0]
            if win.size == 0:
                continue
            wx, wz = fx_[win], fz_[win]
            d = np.full(wx.shape, 1e9)
            ly = np.zeros(wx.shape)
            sp, sy = st["pts"], st["y"]
            for a in range(len(sp) - 1):
                vx, vz = sp[a + 1, 0] - sp[a, 0], sp[a + 1, 1] - sp[a, 1]
                t2 = np.clip(((wx - sp[a, 0]) * vx + (wz - sp[a, 1]) * vz) / (vx * vx + vz * vz + 1e-9), 0.0, 1.0)
                dd = np.hypot(wx - (sp[a, 0] + t2 * vx), wz - (sp[a, 1] + t2 * vz))
                mm = dd < d
                d = np.where(mm, dd, d)
                ly = np.where(mm, sy[a] + (sy[a + 1] - sy[a]) * t2, ly)
            m = 1.0 - smooth(st["hw"], st["hw"] + 7.0, d)
            hf[win] = hf[win] * (1.0 - m) + ly * m
            sf[win] = np.maximum(sf[win], 1.0 - smooth(st["hw"] - 0.4, st["hw"] + 0.3, d))
            pf[win] = np.maximum(pf[win], 1.0 - smooth(st["hw"], st["hw"] + 2.0, d))
            cf[win] = np.maximum(cf[win], 1.0 - smooth(st["hw"] + 3.0, st["hw"] + 9.0, d))
        for rx, rz, rr, ry in TOWN_ROUNDS:
            d = np.hypot(fx_ - rx, fz_ - rz)
            m = 1.0 - smooth(rr, rr + 6.0, d)
            hf = hf * (1.0 - m) + ry * m
            sf[:] = np.maximum(sf, 1.0 - smooth(rr - 0.4, rr + 0.3, d))
            pf[:] = np.maximum(pf, 1.0 - smooth(rr, rr + 2.0, d))
        h = hf.reshape(xs.shape)
        street = sf.reshape(xs.shape)
        clear = cf.reshape(xs.shape)
        pad = pf.reshape(xs.shape)
    # pads last: a pad on a terrace (the café on the boulevard) stays exactly level
    mbest = np.zeros(xs.shape)
    ybest = np.zeros(xs.shape)
    for lm in LANDMARKS:     # the nearest pad wins (no neighbour pulls a pad off level)
        fx, fz = math.sin(lm["yaw"]), math.cos(lm["yaw"])
        u = np.abs((xs - lm["x"]) * fz - (zs - lm["z"]) * fx) - lm["w"] / 2
        v = np.abs((xs - lm["x"]) * fx + (zs - lm["z"]) * fz) - lm["d"] / 2
        e = np.maximum(u, v)                     # < 0 inside the footprint
        m = 1.0 - smooth(1.0, 24.0, e)   # gentle banks round the pad
        better = m > mbest
        mbest = np.where(better, m, mbest)
        ybest = np.where(better, lm["y"], ybest)
        pad = np.maximum(pad, 1.0 - smooth(0.0, 2.0, e))
    if TOWN_ON and TOWN_PADS:   # town houses: small pads with short banks (terraces), windowed
        fx_, fz_ = xs.ravel(), zs.ravel()
        mb, yb, pf = mbest.ravel().copy(), ybest.ravel().copy(), pad.ravel().copy()
        cf = clear.ravel().copy()
        for lm in TOWN_PADS:
            r = math.hypot(lm["w"], lm["d"]) / 2 + 10.0
            win = np.nonzero(np.abs(fx_ - lm["x"]) < r)[0]
            win = win[np.abs(fz_[win] - lm["z"]) < r]
            if win.size == 0:
                continue
            fx, fz = math.sin(lm["yaw"]), math.cos(lm["yaw"])
            u = np.abs((fx_[win] - lm["x"]) * fz - (fz_[win] - lm["z"]) * fx) - lm["w"] / 2
            v = np.abs((fx_[win] - lm["x"]) * fx + (fz_[win] - lm["z"]) * fz) - lm["d"] / 2
            e = np.maximum(u, v)
            m = 1.0 - smooth(1.5, 8.0, e)     # level 1.5 m round the plot (a 3 m cell never straddles the bank)
            m = m + 0.01 * (e < 0.0)          # inside its own plot a house's pad always wins over a neighbour's rim
            better = m > mb[win]
            mb[win] = np.where(better, m, mb[win])
            yb[win] = np.where(better, lm["y"], yb[win])
            pf[win] = np.maximum(pf[win], 1.0 - smooth(0.0, 2.0, e))
            cf[win] = np.maximum(cf[win], 1.0 - smooth(4.0, 10.0, e))
        mbest, ybest, pad = np.minimum(mb, 1.0).reshape(xs.shape), yb.reshape(xs.shape), pf.reshape(xs.shape)
        clear = cf.reshape(xs.shape)
    h = h * (1.0 - mbest) + ybest * mbest
    # the road rule again: pads / terraces never lift the ground over the verge
    h = np.minimum(h, cut_max)
    h = np.where(k < 0.0, yroad - 0.7, h)
    info = {"droad": droad, "yroad": yroad, "edge": edge, "inside": inside, "rdist": rdist, "zone": zm, "pad": pad,
            "street": street, "clear": clear}
    return h, info



TOWN_ROUNDS = []             # [x, z, r, y]


def resolve_town():
    """Street heights: the natural ground along each street (the road cut included),
    smoothed over ~30 m. House pads: the race road (as the landmarks) or their street."""
    global TOWN_ON
    if not TOWN:
        return
    t0 = time.time()
    for st in TOWN["streets"]:
        p = np.array(st["points"], dtype=np.float64)
        h, _info = height(p[:, 0:1], p[:, 1:2])
        h = h[:, 0]
        k = 7
        hs = np.convolve(np.pad(h, (k // 2, k // 2), mode="edge"), np.ones(k) / k, mode="valid")
        hw = float(st["width"]) / 2
        STREETS.append({"id": st["id"], "pts": p, "y": hs - 0.1, "hw": hw,
                        "box": (p[:, 0].min() - hw - 9, p[:, 0].max() + hw + 9, p[:, 1].min() - hw - 9,
                                p[:, 1].max() + hw + 9)})

    def street_y(x, z, only=None):
        best = (1e9, 0.0)
        for st in STREETS:
            if only is not None and st["id"] != only:
                continue
            d = np.hypot(st["pts"][:, 0] - x, st["pts"][:, 1] - z)
            i = int(np.argmin(d))
            if d[i] < best[0]:
                best = (float(d[i]), float(st["y"][i]))
        return best[1]
    for rx, rz, rr in TOWN["rounds"]:
        TOWN_ROUNDS.append((rx, rz, rr, street_y(rx, rz)))
        TOWN_PADS.append({"id": "kb_lc_round", "x": rx, "y": street_y(rx, rz), "z": rz, "yaw": 0.0, "w": 1.0, "d": 1.0,
                          "island": True})
    for hh in TOWN["houses"]:
        if hh["front"] == "road":
            near = np.hypot(PTS[:, 0] - hh["x"], PTS[:, 2] - hh["z"]) < 30.0
            y = float(PTS[near, 1].min()) - 0.4
        else:
            y = street_y(hh["x"], hh["z"], hh["front"]) + 0.15
            # the road rule (cut slope from the verge, height()) must not shave the pad's corner
            # where a street house backs onto the race road: the pad drops to what the cut allows
            fx, fz = math.sin(hh["yaw"]), math.cos(hh["yaw"])
            cx = np.array([[hh["x"] + fz * u * (hh["w"] / 2 + 1.5) + fx * v * (hh["d"] / 2 + 1.5)
                            for u in (-1, 0, 1) for v in (-1, 0, 1)]])
            cz = np.array([[hh["z"] - fx * u * (hh["w"] / 2 + 1.5) + fz * v * (hh["d"] / 2 + 1.5)
                            for u in (-1, 0, 1) for v in (-1, 0, 1)]])
            dr, yr, ed = road_query(cx, cz)
            y = min(y, float(np.min(yr - 0.5 + np.maximum(dr - (ed + 1.2), 0.0) * 0.9)) - 0.05)
        TOWN_PADS.append(dict(hh, y=round(y, 2)))
    TOWN_ON = True
    print(f"TOWN {len(STREETS)} streets, {len(TOWN_ROUNDS)} roundabouts, "
          f"{sum(1 for q in TOWN_PADS if not q.get('island'))} houses resolved in {time.time() - t0:.0f}s")


def write_town():
    if not TOWN:
        return
    out = [[q["id"], round(q["x"], 2), round(q["y"], 2), round(q["z"], 2), round(q["yaw"], 4)] for q in TOWN_PADS]
    json.dump({"doc": "module, x, y, z, yaw (Godot space; model +z faces its street)", "instances": out},
              open(os.path.join(OUT, "town.json"), "w", encoding="utf-8", newline="\n"))
    print(f"TOWN {len(out)} instances -> town.json")


def check_far_tiles(fars, hs):
    """The far LOD (from 240 m) must still carry every landmark pad and line
    module: ray-cast down onto the decimated far tiles and compare with the
    full-resolution ground. Fails the build if a model would float / sink."""
    from mathutils.bvhtree import BVHTree
    trees = []
    for o in fars:
        me = o.data
        vs = [o.matrix_world @ v.co for v in me.vertices]
        trees.append((BVHTree.FromPolygons(vs, [p.vertices for p in me.polygons]),
                      min(v.x for v in vs), max(v.x for v in vs), min(v.y for v in vs), max(v.y for v in vs)))

    def far_h(x, z):
        for bvh, x0, x1, y0, y1 in trees:
            if x0 <= x <= x1 and y0 <= -z <= y1:
                hit = bvh.ray_cast(Vector((x, -z, 2000.0)), Vector((0, 0, -1)))
                if hit[0] is not None:
                    return hit[0].z
        return None

    def ground(x, z):
        fx = np.clip((x - X0) / CELL, 0, hs.shape[1] - 1.001)
        fz = np.clip((z - Z0) / CELL, 0, hs.shape[0] - 1.001)
        ix, iz = int(fx), int(fz)
        tx, tz = fx - ix, fz - iz
        return float((hs[iz, ix] * (1 - tx) + hs[iz, ix + 1] * tx) * (1 - tz) +
                     (hs[iz + 1, ix] * (1 - tx) + hs[iz + 1, ix + 1] * tx) * tz)
    pts = []
    for lm in LANDMARKS:
        fx, fz = math.sin(lm["yaw"]), math.cos(lm["yaw"])
        for u in np.linspace(-lm["w"] / 2 + 1.5, lm["w"] / 2 - 1.5, 6):
            for v in np.linspace(-lm["d"] / 2 + 1.5, lm["d"] / 2 - 1.5, 5):
                pts.append((lm["id"], lm["x"] + fz * u + fx * v, lm["z"] - fx * u + fz * v))
    for q in TOWN_PADS:
        if q.get("island"):
            continue
        fx, fz = math.sin(q["yaw"]), math.cos(q["yaw"])
        for u in (-q["w"] / 2 + 1.5, 0.0, q["w"] / 2 - 1.5):
            for v in (-q["d"] / 2 + 1.5, q["d"] / 2 - 1.5):
                pts.append((q["id"], q["x"] + fz * u + fx * v, q["z"] - fx * u + fz * v))
    lp = os.path.join(OUT, "lines.json")
    if os.path.exists(lp):
        for t in json.load(open(lp, encoding="utf-8"))["instances"]:
            if not t[0].startswith("kb_hl_"):        # the peak's letters stand on legs over the slope
                pts.append((t[0], t[1], t[3]))
    worst = (0.0, "")
    worst_town = (0.0, "")
    town_ids = {q["id"] for q in TOWN_PADS}
    for name, x, z in pts:
        h = far_h(x, z)
        if h is None:
            continue
        d = abs(h - ground(x, z))
        # 0.20.1 town houses: neighbours on their own levels meet in a step about a metre from a
        # plot - a 3 m far triangle can lift a corner a little; their plinths reach 1.5 m down
        if name in town_ids and not any(lm["id"] == name for lm in LANDMARKS):
            if d > worst_town[0]:
                worst_town = (d, f"{name} at ({x:.0f}, {z:.0f})")
        elif d > worst[0]:
            worst = (d, f"{name} at ({x:.0f}, {z:.0f})")
    print(f"FAR LOD under the landmarks: worst {worst[0]:.2f} m ({worst[1]}), {len(pts)} points")
    print(f"FAR LOD under the town houses: worst {worst_town[0]:.2f} m ({worst_town[1]})")
    assert worst[0] < 0.5, "far terrain tiles leave a landmark floating / sunk"
    assert worst_town[0] < 1.0, "far terrain tiles leave a town house floating / sunk"


LABEL_SIZES = os.path.join(ROOT, "assets", "models", "karabakh_names", "sizes.json")
LETTER_ID = {"H": "kb_hl_h", "O": "kb_hl_o", "Ç": "kb_hl_c", "A": "kb_hl_a", "Z": "kb_hl_z"}


def peak_labels():
    """0.20.1 (owner): the peak's name in big white letters standing on its face, turned to the
    town (as a name on a hill). Each letter on its own ground; "at" = how high up the face."""
    out = []
    sizes = json.load(open(LABEL_SIZES, encoding="utf-8"))["sizes"] if os.path.exists(LABEL_SIZES) else {}
    for pk in PEAKS:
        lb = pk.get("label")
        if not lb:
            continue
        f = np.array(pk["face"], dtype=np.float64)
        f /= np.linalg.norm(f)
        side = np.array([-f[1], f[0]])
        ss = np.linspace(0.05, 1.2, 116) * pk["r"]
        hs_, _i = height((pk["x"] + f[0] * ss)[:, None], (pk["z"] + f[1] * ss)[:, None])
        hs_ = hs_[:, 0]
        target = hs_.min() + (hs_.max() - hs_.min()) * lb.get("at", 0.45)
        top = int(np.argmax(hs_))
        k = int(np.argmin(np.where(np.arange(len(ss)) > top, np.abs(hs_ - target), 1e9)))
        c = np.array([pk["x"], pk["z"]]) + f * ss[k]
        sc = float(lb.get("scale", 1.0))
        ids = [LETTER_ID[ch] for ch in lb["text"]]
        ws = [sizes.get(i, [20.0])[0] * sc for i in ids]
        gap = 4.0 * sc
        total = sum(ws) + gap * (len(ws) - 1)
        yaw = math.atan2(f[0], f[1])
        # the letter's local +x (its reading direction) in the world: (cos yaw, -sin yaw)
        ax = np.array([math.cos(yaw), -math.sin(yaw)])
        # upright letters on one baseline along the cliff's contour at that height: each letter
        # slides along the face direction until its foot meets the contour (the face is a ~70 deg
        # cliff, so the rock rises behind the letter and never in front of it)
        base = float(target)
        u = -total / 2
        for i, w in zip(ids, ws):
            q0 = c + ax * (u + w / 2)
            sl = np.linspace(-120.0, 160.0, 281)
            gy = height((q0[0] + f[0] * sl)[:, None], (q0[1] + f[1] * sl)[:, None])[0][:, 0]
            # the first point going out towards the town where the ground drops under the baseline
            j = next((k_ for k_ in range(len(sl)) if gy[k_] <= base and sl[k_] > -120.0 and k_ > 0
                      and gy[k_ - 1] > base), int(np.argmin(np.abs(gy - base))))
            q = q0 + f * (sl[j] + 5.0)
            out.append([i, round(float(q[0]), 2), round(base - 1.0, 2), round(float(q[1]), 2), round(yaw, 4),
                        round(sc, 3), 0.0])
            u += w + gap
        print(f"PEAK LABEL {lb['text']} on {pk['id']}: ({c[0]:.0f}, {c[1]:.0f}) y {target:.0f}, {total:.0f} m wide")
    return out


def write_lines(hs):
    """Module instances along the wall / boulevard runs -> lines.json
    [module, x, y, z, yaw] (Godot space; local +x along the run). y follows
    the ground (lowest point under the module) or the run's terrace height."""
    def ground(x, z):
        fx = np.clip((x - X0) / CELL, 0, hs.shape[1] - 1.001)
        fz = np.clip((z - Z0) / CELL, 0, hs.shape[0] - 1.001)
        ix, iz = int(fx), int(fz)
        tx, tz = fx - ix, fz - iz
        a = hs[iz, ix] * (1 - tx) + hs[iz, ix + 1] * tx
        b = hs[iz + 1, ix] * (1 - tx) + hs[iz + 1, ix + 1] * tx
        return float(a * (1 - tz) + b * tz)
    out = []
    for ln in LINES:
        pts = np.array([[q[0], q[1]] for q in ln["points"]], dtype=np.float64)
        ys = [q[2] for q in ln["points"]]
        cum = np.concatenate([[0.0], np.cumsum(np.hypot(*np.diff(pts, axis=0).T))])
        step = float(ln["step"])
        n = int(cum[-1] // step)
        gate_k = int(n * ln.get("gate_at", -1)) if "gate" in ln else -1
        for k in range(n):
            s0, s1 = k * step, (k + 1) * step
            a = np.array([np.interp(s0, cum, pts[:, 0]), np.interp(s0, cum, pts[:, 1])])
            b = np.array([np.interp(s1, cum, pts[:, 0]), np.interp(s1, cum, pts[:, 1])])
            mid = (a + b) / 2
            yaw = math.atan2(-(b[1] - a[1]), b[0] - a[0])
            if ys[0] is None:
                y = min(ground(*a), ground(*b), ground(*mid)) - 0.3
            else:
                y = float(np.interp(s0 + step / 2, cum, ys))
            mod = ln["gate"] if k == gate_k else ln["module"]
            out.append([mod, round(float(mid[0]), 2), round(y, 2), round(float(mid[1]), 2), round(yaw, 4)])
            if "tower" in ln and k % ln["tower_every"] == 0 and abs(k - gate_k) > 1:
                out.append([ln["tower"], round(float(a[0]), 2), round(min(ground(*a), y + 0.3) - 0.3, 2),
                            round(float(a[1]), 2), round(yaw, 4)])
        if "tower" in ln:
            e = pts[-1]
            out.append([ln["tower"], round(float(e[0]), 2), round(ground(*e) - 0.6, 2), round(float(e[1]), 2),
                        round(math.atan2(-(pts[-1][1] - pts[-2][1]), pts[-1][0] - pts[-2][0]), 4)])
    out += peak_labels()
    json.dump({"doc": "module, x, y, z, yaw[, scale] (Godot space; local +x along the run)", "instances": out},
              open(os.path.join(OUT, "lines.json"), "w", encoding="utf-8", newline="\n"))
    print(f"LINES {len(out)} module instances")

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
        m.vertex_group_factor = 4.0 if protect == "road" else 20.0   # far tiles: pads / wall runs stay exact
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
TREE_BAND = 78.0        # instanced trees up to this far from the road edge
CANOPY_START = 70.0     # beyond it the hillside carries the forest canopy


def plot_clear(x, z, margin=0.0):
    for pl in PLOTS:
        if (x - pl[0]) ** 2 + (z - pl[1]) ** 2 < (pl[2] + margin) ** 2:
            return False
    return True


def scatter_forest(hfun):
    rnd = random.Random(2026)
    pts = []
    step = 7.5
    xs = np.arange(X0 + 4, X1 - 4, step)
    zs = np.arange(Z0 + 4, Z1 - 4, step)
    gx, gz = np.meshgrid(xs, zs)
    gx = gx + np.array([[rnd.uniform(-2.6, 2.6) for _ in range(gx.shape[1])] for _ in range(gx.shape[0])])
    gz = gz + np.array([[rnd.uniform(-2.6, 2.6) for _ in range(gx.shape[1])] for _ in range(gx.shape[0])])
    h, info = hfun(gx, gz)
    # town: streets / house plots stay clear; gardens get cypresses and fruit trees
    occupied = info["street"] > 0.0
    for q in TOWN_PADS:
        fx, fz = math.sin(q["yaw"]), math.cos(q["yaw"])
        r = (8.0 if q.get("island") else 0.0)
        u = np.abs((gx - q["x"]) * fz - (gz - q["z"]) * fx) - q["w"] / 2 - r
        v = np.abs((gx - q["x"]) * fx + (gz - q["z"]) * fz) - q["d"] / 2 - r
        occupied |= np.maximum(u, v) < 1.5
    near_house = np.zeros(gx.shape, dtype=bool)
    for q in TOWN_PADS:
        near_house |= np.hypot(gx - q["x"], gz - q["z"]) < math.hypot(q["w"], q["d"]) / 2 + 9.0
    # slope from neighbouring samples
    hx, _ = hfun(gx + 1.5, gz)
    hz, _ = hfun(gx, gz + 1.5)
    slope = np.sqrt(((hx - h) / 1.5) ** 2 + ((hz - h) / 1.5) ** 2)
    k = info["droad"] - info["edge"]
    for idx in np.ndindex(gx.shape):
        x, z, y = float(gx[idx]), float(gz[idx]), float(h[idx])
        kk = float(k[idx])
        if kk < 5.0 or kk > (TREE_BAND + 90.0 * float(info["zone"][idx]) if TOWN else TREE_BAND):
            continue      # a town-filled map: the trees reach the hilltop in the middle of the town
        if not plot_clear(x, z, 3.0):
            continue
        if float(info["rdist"][idx]) < 6.0:   # water and the gravel shore
            continue
        if occupied[idx]:
            continue
        if TOWN and near_house[idx]:     # town gardens
            if rnd.random() < 0.45:
                kind = "kb_cypress" if rnd.random() < 0.45 else ("kb_maple" if rnd.random() < 0.4 else "kb_oak")
                sc = rnd.uniform(0.8, 1.1) if kind == "kb_cypress" else rnd.uniform(0.55, 0.8)
                pts.append([kind, round(x, 2), round(y - 0.25, 2), round(z, 2), round(rnd.uniform(0, 6.28), 3),
                            round(sc, 3)])
            continue
        # towns: a few trees only (a town-filled map: the green hilltop keeps half of its trees)
        if rnd.random() < float(info["zone"][idx]) * (0.45 if TOWN else 0.9):
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
        high = y > 30.0
        if (s > 0.45 and y > 22.0 and r < 0.4) or (y > 34.0 and r < 0.10):
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

def terrain_material(name, crown_scale=0.22, rock_z=(0.6, 0.42)):
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

    meadow = ramp(noise(0.05, 6.0), 0.35, 0.65, lin("5E7E36"), lin("7B9642"))
    meadow = mix(mr01(noise(0.4, 3.0), 0.55, 0.75), meadow, lin("8F9650"))  # dry patches
    # the far bank of the Araz: dry steppe hills
    meadow = mix(attr("dry"), meadow, ramp(noise(0.07, 5.0), 0.3, 0.7, lin("9A9468"), lin("7F7D55")))
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
    bed = ramp(noise(0.5, 4.0), 0.3, 0.7, lin("7C7A6C"), lin("5E6052"))  # river gravel
    c = mix(attr("forest"), meadow, floor)
    c = mix(attr("canopy"), c, canopy_c)
    c = mix(attr("rock"), c, rock)  # cliffs: from the height grid slope (face normals gave hard facets)  # only cliffs (> ~55 deg) are bare limestone
    c = mix(attr("verge"), c, verge)
    c = mix(attr("riverbed"), c, bed)
    asphalt = ramp(noise(1.2, 3.0), 0.35, 0.65, lin("4F5256"), lin("5E6165"))
    c = mix(attr("street"), c, asphalt)
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
    if ao_dist > 0.0:
        bpy.ops.object.bake(type="AO", margin=4, use_clear=True, target="IMAGE_TEXTURES")
    else:   # no AO (the 20 m mountain triangles baked as dark / light facets)
        # 0.5: the tone of the inner bake's open ground (measured at the seam), so both textures meet
        img_a.pixels.foreach_set(np.full(res * res * 4, 0.5, dtype=np.float32))
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
             "kb_rock": (1.8, 1.0, 0.9), "kb_cypress": (1.0, 4.2, 4.6)}
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
    for q in TOWN_PADS:          # 0.20.1 town houses: boxes (contact shade round each house)
        if q.get("island"):
            continue
        tmp = bmesh.new()
        bmesh.ops.create_cube(tmp, size=1.0)
        fx, fz = math.sin(q["yaw"]), math.cos(q["yaw"])
        hgt = 12.0 if q["id"] == "kb_lc_block" else 7.0
        for v in tmp.verts:
            u, w, hh = v.co.x * (q["w"] - 3.0), v.co.y * (q["d"] - 3.0), (v.co.z + 0.5) * hgt
            gx, gz = q["x"] + fz * u + fx * w, q["z"] - fx * u + fz * w
            v.co = Vector((gx, -gz, q["y"] + hh))
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
    resolve_town()

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
    write_lines(hs)
    write_town()
    k = info["droad"] - info["edge"]
    forest = smooth(18.0, 40.0, k)
    verge = 1.0 - smooth(-0.5, 1.0, k)
    riverbed = 1.0 - smooth(0.0, 5.0, info["rdist"])
    wet = 1.0 - smooth(4.0, 14.0, info["rdist"])
    zm = info["zone"]
    dry = smooth(10.0, 90.0, zs - araz_z(xs))
    plots = np.zeros_like(xs)
    for pl in PLOTS:
        plots = np.maximum(plots, 1.0 - smooth(pl[2] - 4.0, pl[2] + 6.0, np.sqrt((xs - pl[0]) ** 2 + (zs - pl[1]) ** 2)))
    open_f = (1.0 - plots) * (1.0 - wet) * (1.0 - zm) * (1.0 - dry) * (1.0 - info["pad"]) * (1.0 - info["clear"])
    can = can * open_f
    can_on = can_on * open_f
    forest = forest * (1.0 - plots) * (1.0 - wet) * (1.0 - 0.85 * zm) * (1.0 - dry)
    shown = hs + can
    gz_, gx_ = np.gradient(hs, CELL)
    cliff = smooth(1.1, 1.7, np.hypot(gx_, gz_))   # bare limestone above ~50 deg
    attrs = {"forest": forest * (1.0 - info["street"]), "canopy": can_on, "verge": verge, "riverbed": riverbed,
             "dry": dry, "rock": cliff * (1.0 - info["street"]), "street": info["street"]}
    rmin = min((float(np.min(np.hypot(PTS[:, 0][:, None] - rv["pts"][:, 0][None, :],
                                      PTS[:, 2][:, None] - rv["pts"][:, 1][None, :]))) - rv["hw"] for rv in RIVERS),
               default=float("inf"))
    print(f"ROAD - RIVER bank: {rmin:.0f} m at the closest")

    trees = scatter_forest(hfun)
    if TOWN:   # 0.20.1: town banks are steep - stand every tree on the final 3 m grid (what Godot samples)
        def grid_y(x, z):
            fx = min(max((x - X0) / CELL, 0.0), nx - 1.001)
            fz = min(max((z - Z0) / CELL, 0.0), nz - 1.001)
            ix, iz = int(fx), int(fz)
            tx, tz = fx - ix, fz - iz
            return float((hs[iz, ix] * (1 - tx) + hs[iz, ix + 1] * tx) * (1 - tz) +
                         (hs[iz + 1, ix] * (1 - tx) + hs[iz + 1, ix + 1] * tx) * tz)
        for t in trees:
            t[2] = round(grid_y(t[1], t[3]) - {"kb_bush": 0.15, "kb_rock": 0.4}.get(t[0], 0.25), 2)
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
            # ... and the tile borders (collapse would pull them in: cracks).
            # The far tiles (seen from 240 m on) only keep their borders.
            vg = ob.vertex_groups.new(name="road")
            vgb = ob.vertex_groups.new(name="border")
            for v in ob.data.vertices:
                gx = int(round((v.co.x - X0) / CELL))
                gz = int(round((-v.co.y - Z0) / CELL))
                border = gx in (j0, j1 - 1) or gz in (i0, i1 - 1)
                if k[gz, gx] < 30.0 or border or info["pad"][gz, gx] > 0.0:
                    vg.add([v.index], 1.0, "REPLACE")
                if border or info["pad"][gz, gx] > 0.0:   # far tiles keep pads / wall runs too
                    vgb.add([v.index], 1.0, "REPLACE")
                if info["pad"][gz, gx] > 0.0:
                    ob["pads"] = True
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
        # Tiles carrying a peak keep more of it far away (Hoçaz is seen from 400+ m).
        cx = np.mean([v.co.x for v in far.data.vertices])
        cz = -np.mean([v.co.y for v in far.data.vertices])
        big = any(math.hypot(cx - pk["x"], cz - pk["z"]) < pk["r"] for pk in PEAKS)
        # tiles carrying a landmark pad / wall run keep more (a pad cut into a slope
        # collapses badly at 0.06 - 0.19.2, the stadium beside the road)
        padded = bool(far.get("pads", False))
        # 0.20.1: a tile full of town pads (most vertices protected) must keep more, or the
        # collapse has to take protected ones (a house pad 2.7 m off in the far LOD)
        town_tile = any(abs(q["x"] - cx) < 80.0 and abs(q["z"] - cz) < 80.0 for q in TOWN_PADS)
        decimate(far, 0.4 if big else (0.75 if town_tile else (0.5 if padded else 0.06)), "border")
        fars.append(far)
        decimate(ob, 0.28, "road")
    check_far_tiles(fars, hs)
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
    rock = smooth(150.0, 185.0, mhs) * (1.0 - peak_mask(mxs, mzs))  # bare tops (Hoçaz: green ridge, rock face only)
    mcan = mcan * (1.0 - rock)
    mcan_on = mcan_on * (1.0 - rock)
    print(f"HEIGHTS mountains {mnx}x{mnz} in {time.time() - t0:.0f}s, y {mhs.min():.1f}..{mhs.max():.1f}")
    # Overlap one cell under the inner region (sunk 1.5 m: no cracks at the seam).
    inner = (mxs > X0 + MCELL) & (mxs < X1 - MCELL) & (mzs > Z0 + MCELL) & (mzs < Z1 - MCELL)
    msh = np.where(inner, mhs - 1.5, mhs + mcan)
    mk = minfo["droad"] - minfo["edge"]
    mriver = 1.0 - smooth(0.0, 8.0, minfo["rdist"])
    mwet = 1.0 - smooth(4.0, 24.0, minfo["rdist"])
    mdry = smooth(10.0, 90.0, mzs - araz_z(mxs))
    mopen = (1.0 - mwet) * (1.0 - mdry)
    msh = np.where(inner, mhs - 1.5, mhs + mcan * mopen)
    mattrs = {"forest": smooth(18.0, 40.0, mk) * (1.0 - mdry), "canopy": mcan_on * mopen, "verge": np.zeros_like(mxs),
              "street": np.zeros_like(mxs),
              "riverbed": mriver, "dry": mdry,
              "rock": np.maximum(rock, smooth(1.0, 2.0, np.hypot(*np.gradient(mhs, MCELL))) * (1.0 - 0.5 * mdry))}

    def keep(i, j):
        return not (inner[i, j] and inner[i + 1, j + 1] and inner[i, j + 1] and inner[i + 1, j])
    mountains = grid_mesh("Mountains", coll, mxs, mzs, msh, (MX0, MZ0, MX1 - MX0, MZ1 - MZ0), keep, mattrs)
    mountains_full = mountains.copy()
    mountains_full.data = mountains.data.copy()
    coll.objects.link(mountains_full)
    decimate(mountains, 0.35)
    for o in [mountains] + tiles + fars:   # decimation left hard facets (dark blotches on the far bank)
        for poly in o.data.polygons:
            poly.use_smooth = True
    print(f"MOUNTAINS {tri_count(mountains)} tris")

    # River ribbon ----------------------------------------------------------------------
    rivers = []
    for rv in RIVERS:
        p = rv["pts"]
        hw = rv["hw"] + 1.0
        bm = bmesh.new()
        rows = []
        for i in range(len(p)):
            t = p[min(i + 1, len(p) - 1)] - p[max(i - 1, 0)]
            t = t / np.hypot(t[0], t[1])
            sx, sz = -t[1] * hw, t[0] * hw
            y = float(rv["lev"][i])
            rows.append([bm.verts.new((p[i][0] - sx, -(p[i][1] - sz), y)), bm.verts.new((p[i][0] + sx, -(p[i][1] + sz), y))])
        for a, b in zip(rows, rows[1:]):
            bm.faces.new((a[0], b[0], b[1], a[1]))
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        for f in bm.faces:
            if f.normal.z < 0:
                f.normal_flip()
        me = bpy.data.meshes.new("River_" + rv["id"])
        bm.to_mesh(me)
        bm.free()
        river = bpy.data.objects.new("River_" + rv["id"], me)
        coll.objects.link(river)
        rivers.append(river)

    # Bake --------------------------------------------------------------------------------
    if BAKE:
        bake_to(mountains_full, terrain_material("mount_mat", 0.15, (0.72, 0.3)), RES, "mountains_albedo", [], 0.0)
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
    for o in tiles + fars + [mountains] + rivers:
        o.data.materials.clear()
        for an in list(o.data.attributes.keys()):
            if an in attrs:
                o.data.attributes.remove(o.data.attributes[an])
    for o in bpy.context.scene.objects:
        o.select_set(False)
    for o in tiles + fars + [mountains] + rivers:
        o.select_set(True)
    bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, "terrain.glb"), export_format="GLB", use_selection=True,
                              export_apply=True, export_yup=True, export_materials="NONE", export_normals=True,
                              export_texcoords=True, export_tangents=False, export_animations=False,
                              export_skins=False, export_morph=False, export_cameras=False, export_lights=False,
                              export_attributes=False)
    print("WROTE", os.path.join(OUT, "terrain.glb"))
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(WORK, TRACK_ID + "_terrain.blend"))
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
