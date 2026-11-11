"""Landmark layout for the short Qarabağ maps (0.20.1+): Şuşa, Laçın, Xankəndi.

  godot --headless --path . -s tools/export_road_samples.gd -- <track>
  python tools/karabakh_maps_layout.py <track>

The big map keeps its own script (tools/karabakh_layout.py). This one reads the
per-map CONFIG below and writes "landmarks", "lines", "peaks" and
"landmark_plots" into data/tracks/<track>.json, with the same rules as the big
map: every footprint >= 3 m behind the run-off (the sign 1.5 m), clear of the
rivers and of each other; a view lane to the road kept free of forest; the
entry sign on the right of the road, turned 30° to face the karts.
"""

import io
import json
import math
import os
import re
import sys

import numpy as np

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
TID = sys.argv[1] if len(sys.argv) > 1 else "karabakh_shusha"
TRACK_PATH = os.path.join(ROOT, "data", "tracks", TID + ".json")
road = json.load(open(os.path.join(ROOT, "tools", "blender", "out", TID + "_road.json"), encoding="utf-8"))
text = io.open(TRACK_PATH, encoding="utf-8").read()
track = json.loads(text)
P = np.array(road["points"])
HW = np.array(road["half_widths"])
OW = float(road["offroad_width"])
N = len(P)
CLEAR = 3.0
COMPASS = {"N": (0.0, -1.0), "S": (0.0, 1.0), "E": (1.0, 0.0), "W": (-1.0, 0.0)}

# id, road hint (x, z), side (compass), w (along road), d (deep)
CONFIG = {
    "karabakh_shusha": {
        "zone": "shusha",
        "landmarks": [("kb_mosque", (0, -135), "N", 28, 32), ("kb_vagif", (-200, 112), "N", 18, 18),
                      ("kb_bulbul", (200, -125), "S", 18, 13)],
        # old stone houses along the streets (both sides; skipped where there is no room)
        "houses": [((x, z), side) for (x, z, side) in [
            (150, -128, "N"), (240, -110, "N"), (-130, -138, "N"), (-160, -132, "S"), (-60, -128, "S"),
            (60, -138, "S"), (-250, -95, "N"), (-260, -90, "S"), (-300, 0, "W"), (-300, -30, "E"),
            (-280, 60, "E"), (-120, 92, "S"), (-60, 110, "N"), (100, 130, "N"), (210, 100, "N"),
            (300, 40, "W"), (310, -50, "W"), (300, -80, "E")]],
        "sign": ("kb_sign_shusha", 170.0),         # metres after the start line (past the mosque)
        # the fortress wall beside the south leg, on its gorge (south) side
        "wall": {"x": (-240.0, 230.0), "side": "S", "zmin": 60.0},
        "peaks": [],
    },
    "karabakh_lachin": {
        "zone": "lachin",
        "landmarks": [("kb_cinema", (133, 70), "E", 32, 28), ("kb_hotel", (115, 215), "E", 80, 46)],
        # 0.20.1 (owner's aerial photos): a dense hillside town - streets along the contours inside the
        # loop and beyond the east leg, cross streets from the road, roundabouts, houses on both sides
        "town": {"rings_in": [40.0, 80.0], "rings_out": [48.0], "cross": [(118, -120), (-140, -90), (122, 150),
                                                                          (-140, 170), (10, 305), (20, -320)],
                 "rounds": [0, 2], "street_w": 6.0, "seed": 11},
        "sign": ("kb_sign_lachin", 60.0),
        "boulevard": {"river": "hakari", "z": (-300.0, 260.0)},
        "cafe": True,
        # Hoçaz (owner's photo): beyond the river, its cliff face turned to the town
        "peaks": [{"id": "hocaz", "x": -470.0, "z": -60.0, "h": 220.0, "r": 300.0, "face": [0.9923, 0.124]}],
    },
    # 0.20.1 the big map: only the Laçın town fill (its landmarks / lines / plots stay as
    # tools/karabakh_layout.py made them); the town keeps to its area round the Laçın zone
    "karabakh": {
        "zone": "lachin", "town_only": True, "landmarks": [],
        "town": {"rings_in": [40.0, 80.0, 120.0], "rings_out": [40.0, 80.0], "cross": [(-700, -75), (-765, 15),
                                                                                     (-766, 90)],
                 "rounds": [1], "street_w": 6.0, "seed": 5, "area": (-690.0, 0.0, 240.0)},
    },
}
CFG = CONFIG[TID]
TOWN_ONLY = CFG.get("town_only", False)
if TOWN_ONLY:
    CFG["peaks"] = track.get("peaks", [])
SIGN_W, SIGN_D = 26.0, 4.0


def nearest(x, z):
    return int(np.argmin(np.hypot(P[:, 0] - x, P[:, 2] - z)))


def road_gap(xs, zs):
    best = 1e9
    for x, z in zip(xs, zs):
        best = min(best, float((np.hypot(P[:, 0] - x, P[:, 2] - z) - HW - OW).min()))
    return best


def rect_points(cx, cz, yaw, w, d, step=3.0):
    fx, fz = math.sin(yaw), math.cos(yaw)
    ax, az = fz, -fx
    xs, zs = [], []
    nu = max(2, int(w / step) + 1)
    nv = max(2, int(d / step) + 1)
    for i in range(nu):
        u = -w / 2 + w * i / (nu - 1)
        for j in range(nv):
            v = -d / 2 + d * j / (nv - 1)
            xs.append(cx + ax * u + fx * v)
            zs.append(cz + az * u + fz * v)
    return xs, zs


placed = [dict(q) for q in track.get("landmarks", [])] if TOWN_ONLY else []
lines = [dict(q) for q in track.get("lines", [])] if TOWN_ONLY else []


def clashes(xs, zs, margin=4.0):
    for q in placed:
        fx, fz = math.sin(q["yaw"]), math.cos(q["yaw"])
        for x, z in zip(xs, zs):
            u = (x - q["x"]) * fz - (z - q["z"]) * fx
            v = (x - q["x"]) * fx + (z - q["z"]) * fz
            if abs(u) < q["w"] / 2 + margin and abs(v) < q["d"] / 2 + margin:
                return q["id"]
    for ln in lines:
        lp = np.array([[q[0], q[1]] for q in ln["points"]])
        for x, z in zip(xs, zs):
            if float(np.min(np.hypot(lp[:, 0] - x, lp[:, 1] - z))) < ln["width"] / 2 + 3.0:
                return ln["id"]
    return None


def tangent(i):
    t = P[(i + 3) % N][[0, 2]] - P[i - 3][[0, 2]]
    return t / np.linalg.norm(t)


def pad_y(c, reach):
    near = np.hypot(P[:, 0] - c[0], P[:, 2] - c[1]) < reach
    return float(P[near, 1].min()) - 0.4


def chaikin(pts, rounds=3):
    pts = np.array(pts, dtype=np.float64)
    for _ in range(rounds):
        q = [pts[0]]
        for a, b in zip(pts[:-1], pts[1:]):
            q.append(a * 0.75 + b * 0.25)
            q.append(a * 0.25 + b * 0.75)
        q.append(pts[-1])
        pts = np.array(q)
    return pts


RIVERS = []
for rv in track.get("rivers", []):
    rp = chaikin(rv["points"])
    cum = np.concatenate([[0.0], np.cumsum(np.hypot(*np.diff(rp, axis=0).T))])
    lev = np.full(len(rp), float(rv["level"])) if rv.get("level") is not None else \
        rv["drop"][0] + (rv["drop"][1] - rv["drop"][0]) * cum / cum[-1]
    RIVERS.append({"id": rv["id"], "pts": rp, "lev": lev, "hw": rv["width"] / 2.0})


def river_gap(xs, zs):
    best = 1e9
    for rv in RIVERS:
        for x, z in zip(xs, zs):
            best = min(best, float(np.min(np.hypot(rv["pts"][:, 0] - x, rv["pts"][:, 1] - z))) - rv["hw"])
    return best


_clashes_plain = clashes


def clashes(xs, zs, margin=4.0):
    if RIVERS and river_gap(xs, zs) < 6.0:
        return "river"
    return _clashes_plain(xs, zs, margin)


# the boulevard on the road side of the river, the café between it and the road
if "boulevard" in CFG:
    bc = CFG["boulevard"]
    hk = next(r for r in RIVERS if r["id"] == bc["river"])
    blvd = []
    for k in range(len(hk["pts"]) - 1):
        p0, p1 = hk["pts"][k], hk["pts"][k + 1]
        if not (bc["z"][0] <= p0[1] <= bc["z"][1]):
            continue
        t = (p1 - p0) / np.linalg.norm(p1 - p0)
        n = np.array([-t[1], t[0]])
        j = nearest(p0[0], p0[1])
        if n @ (np.array([P[j][0], P[j][2]]) - p0) < 0:
            n = -n                                  # towards the road
        q = p0 + n * (hk["hw"] + 6.0)
        blvd.append([round(float(q[0]), 2), round(float(q[1]), 2), round(float(hk["lev"][k]) + 1.8, 2)])
    _g = [road_gap([q[0]], [q[1]]) for q in blvd]
    _in = [k for k, g in enumerate(_g) if g < 4.5 + 12.0]
    blvd = blvd[_in[0]:_in[-1] + 1]
    lines.append({"id": "hakari_boulevard", "zone": CFG["zone"], "module": "kb_blvd_seg", "step": 10.0, "width": 9.0,
                  "points": blvd})
    if CFG.get("cafe"):
        CAFE_W, CAFE_D = 22.0, 16.0
        bp = np.array([[q[0], q[1]] for q in blvd])
        k = max(range(len(bp)), key=lambda k: float(np.min(np.hypot(P[:, 0] - bp[k][0], P[:, 2] - bp[k][1]))))
        t = bp[min(k + 1, len(bp) - 1)] - bp[max(k - 1, 0)]
        t /= np.linalg.norm(t)
        n_land = np.array([-t[1], t[0]])
        j = nearest(*bp[k])
        if n_land @ (np.array([P[j][0], P[j][2]]) - bp[k]) < 0:
            n_land = -n_land
        c = bp[k] + n_land * (9.0 / 2 + CAFE_D / 2 + 1.5)   # the smoothed bulge is a little narrower
        yaw = math.atan2(n_land[0], n_land[1])     # terrace faces the road
        xs, zs = rect_points(c[0], c[1], yaw, CAFE_W, CAFE_D)
        assert river_gap(xs, zs) > 6.0 and road_gap(xs, zs) > CLEAR, ("café", bp[k], river_gap(xs, zs), road_gap(xs, zs))
        cafe_y = min(q[2] for q in blvd if math.hypot(q[0] - c[0], q[1] - c[1]) < 40.0)
        placed.append({"id": "kb_garden_cafe", "x": round(float(c[0]), 2), "y": round(float(cafe_y), 2),
                       "z": round(float(c[1]), 2), "yaw": round(yaw, 4), "w": CAFE_W, "d": CAFE_D, "zone": CFG["zone"],
                       "setback": round(road_gap(xs, zs), 2)})
        print(f"kb_garden_cafe       ({c[0]:7.1f}, {c[1]:7.1f}) on the boulevard, {road_gap(xs, zs):.1f} m from the run-off")

# the fortress wall first (landmarks must keep clear of it) -----------------------------------
if "wall" in CFG:
    wc = CFG["wall"]
    sec = [i for i in range(N) if wc["x"][0] <= P[i][0] <= wc["x"][1] and P[i][2] >= wc["zmin"]]
    pts = []
    for i in sec[::2]:
        t = tangent(i)
        sn = np.array([-t[1], t[0]])
        if sn @ np.array(COMPASS[wc["side"]]) < 0:
            sn = -sn
        q = np.array([P[i][0], P[i][2]]) + sn * (HW[i] + OW + 3.6 + 3.0)
        pts.append([round(float(q[0]), 2), round(float(q[1]), 2), None])
    pts.sort(key=lambda q: q[0])    # west -> east: module +z = south (the gorge, outer side)
    lines.append({"id": "shusha_wall", "zone": CFG["zone"], "module": "kb_wall_seg", "tower": "kb_wall_tower",
                  "gate": "kb_wall_gate", "step": 8.0, "tower_every": 6, "gate_at": 0.5, "width": 6.0, "points": pts})

for lid, hint, side, w, d in CFG["landmarks"]:
    i = nearest(*hint)
    t = tangent(i)
    n = np.array([-t[1], t[0]])
    if n @ np.array(COMPASS[side]) < 0:
        n = -n
    base = HW[i] + OW + CLEAR
    ok = False
    for grow in np.arange(0.0, 60.0, 1.0):
        c = np.array([P[i][0], P[i][2]]) + n * (base + grow + d / 2)
        yaw = math.atan2(-n[0], -n[1])
        xs, zs = rect_points(c[0], c[1], yaw, w, d)
        if road_gap(xs, zs) < CLEAR - 0.01 or clashes(xs, zs):
            continue
        ok = True
        break
    assert ok, f"{lid}: no room"
    placed.append({"id": lid, "x": round(float(c[0]), 2), "y": round(pad_y(c, math.hypot(w, d) / 2 + base + grow + 15), 2),
                   "z": round(float(c[1]), 2), "yaw": round(yaw, 4), "w": w, "d": d, "zone": CFG["zone"],
                   "setback": round(float(base + grow - HW[i] - OW), 2)})
    print(f"{lid:20s} ({c[0]:7.1f}, {c[1]:7.1f}) setback {base + grow - HW[i] - OW:4.1f} m")

# old town houses (instanced): three variants in turn; a house without room is skipped
HOUSE_IDS = CFG.get("house_ids", ["kb_sh_house_a", "kb_sh_house_b", "kb_sh_house_c"])
for k, (hint, side) in enumerate(CFG.get("houses", [])):
    lid = HOUSE_IDS[k % 3]
    w, d = 12.0, 11.0
    i = nearest(*hint)
    t = tangent(i)
    n = np.array([-t[1], t[0]])
    if n @ np.array(COMPASS[side]) < 0:
        n = -n
    base = HW[i] + OW + CLEAR
    ok = False
    for grow in np.arange(0.0, 8.0, 1.0):
        c = np.array([P[i][0], P[i][2]]) + n * (base + grow + d / 2)
        yaw = math.atan2(-n[0], -n[1])
        xs, zs = rect_points(c[0], c[1], yaw, w, d)
        if road_gap(xs, zs) < CLEAR - 0.01 or clashes(xs, zs, 2.0):
            continue
        ok = True
        break
    if not ok:
        print(f"house at {hint} {side}: no room, skipped")
        continue
    placed.append({"id": lid, "x": round(float(c[0]), 2), "y": round(pad_y(c, 30.0), 2), "z": round(float(c[1]), 2),
                   "yaw": round(yaw, 4), "w": w, "d": d, "zone": CFG["zone"],
                   "setback": round(float(base + grow - HW[i] - OW), 2)})
print(f"HOUSES {sum(1 for q in placed if q['id'] in HOUSE_IDS)}")

# the sign: some way after the start, on the right, facing the karts ----------------------------
if "sign" in CFG:
    sid, after = CFG["sign"]
    f0 = nearest(*track["finish_at"])
    step = road["length"] / N
    done = False
    for extra in range(0, 200, 3):
        i = (f0 + int((after + extra) / step)) % N
        t = tangent(i)
        right = np.array([-t[1], t[0]])
        f = -t * math.cos(math.radians(30)) - right * math.sin(math.radians(30))
        yaw = math.atan2(f[0], f[1])
        for off in np.arange(HW[i] + OW + 1.5 + SIGN_W / 4, HW[i] + OW + 20.0, 1.0):
            c = np.array([P[i][0], P[i][2]]) + right * off
            xs, zs = rect_points(c[0], c[1], yaw, SIGN_W, SIGN_D, 2.0)
            if road_gap(xs, zs) < 1.5 or clashes(xs, zs):
                continue
            done = True
            break
        if done:
            break
    assert done, sid
    placed.append({"id": sid, "x": round(float(c[0]), 2), "y": round(pad_y(c, 30.0), 2), "z": round(float(c[1]), 2),
                   "yaw": round(yaw, 4), "w": SIGN_W, "d": SIGN_D, "zone": CFG["zone"],
                   "setback": round(road_gap(xs, zs), 2)})
    print(f"{sid:20s} ({c[0]:7.1f}, {c[1]:7.1f}) {after + extra:.0f} m after the start")


# 0.20.1 town fill (Laçın, after the owner's aerial photos) -------------------------------------
# Decorative streets (painted into the terrain, not driven), roundabouts and a few hundred houses
# on both sides of every street and of the race road. Heights are resolved by the Blender terrain
# (karabakh_terrain.py -> town.json); here only the plan.
TOWN_TYPES = [  # id, w (along the street), d (deep), weight
    ("kb_lc_house_1", 12.0, 10.0, 0.22), ("kb_lc_house_2", 12.0, 11.0, 0.26), ("kb_lc_house_3", 13.0, 11.0, 0.14),
    ("kb_lc_house_4", 12.0, 13.0, 0.14), ("kb_house_a", 12.0, 11.0, 0.08), ("kb_house_b", 12.0, 11.0, 0.08),
    ("kb_house_c", 12.0, 11.0, 0.08)]
BLOCK = ("kb_lc_block", 28.0, 14.0)
town = None
if "town" in CFG:
    tc = CFG["town"]
    rnd = __import__("random").Random(tc["seed"])
    SW = tc["street_w"]
    P2 = P[:, [0, 2]]
    area = 0.5 * float(np.sum(P2[:, 0] * np.roll(P2[:, 1], -1) - np.roll(P2[:, 0], -1) * P2[:, 1]))
    TX = track.get("terrain", {}).get("inner", [-1200.0, 1248.0, -912.0, 960.0])   # the big map: its default
    _c = P2.mean(axis=0)
    _t0 = tangent(0)
    IN_SIGN = 1.0 if np.array([-_t0[1], _t0[0]]) @ (_c - P2[0]) > 0 else -1.0

    def inward(i):
        t = tangent(i)
        return np.array([-t[1], t[0]]) * IN_SIGN

    def resample(pts, step=4.0):
        pts = np.asarray(pts, dtype=np.float64)
        seg = np.hypot(*np.diff(pts, axis=0).T)
        cum = np.concatenate([[0.0], np.cumsum(seg)])
        ss = np.arange(0.0, cum[-1], step)
        return np.stack([np.interp(ss, cum, pts[:, 0]), np.interp(ss, cum, pts[:, 1])], axis=1)

    def keepout(q, margin):
        """Landmarks (footprint + their view lane to the road)."""
        x, z = float(q[0]), float(q[1])
        for lm in placed:
            fx, fz = math.sin(lm["yaw"]), math.cos(lm["yaw"])
            lane = 0.0 if lm["id"] == "kb_garden_cafe" or lm["id"].startswith("kb_house") else                 (30.0 if lm["id"].startswith("kb_sign") else lm["setback"])
            u = (x - lm["x"]) * fz - (z - lm["z"]) * fx
            v = (x - lm["x"]) * fx + (z - lm["z"]) * fz
            if abs(u) < lm["w"] / 2 + margin and -lm["d"] / 2 - margin < v < lm["d"] / 2 + lane + margin:
                return True
        return False

    AREA = tc.get("area")

    def in_area(x, z, margin=0.0):
        return AREA is None or math.hypot(x - AREA[0], z - AREA[1]) < AREA[2] - margin

    def street_ok(q):
        x, z = float(q[0]), float(q[1])
        if not in_area(x, z):
            return False
        if not (TX[0] + 40 < x < TX[1] - 40 and TX[2] + 40 < z < TX[3] - 40):
            return False
        if RIVERS and river_gap([x], [z]) < SW / 2 + 12.0:
            return False
        if any(math.hypot(x - pk["x"], z - pk["z"]) < pk["r"] for pk in CFG["peaks"]):
            return False
        return not keepout(q, 3.0) and _clashes_plain([x], [z], 3.0) is None

    def runs(cands, cyclic):
        """Split a list of (point, ok) into runs of ok points (cyclic: the first and last runs join)."""
        out, cur = [], []
        for q, ok in cands:
            if ok:
                cur.append(q)
            elif cur:
                out.append(cur)
                cur = []
        if cur:
            if cyclic and out and cands[0][1]:
                out[0] = cur + out[0]
            else:
                out.append(cur)
        return out

    streets = []

    def add_street(sid, pts, closed=False):
        if len(pts) < 3:
            return
        sm = chaikin(np.vstack([pts, pts[:1]]) if closed else pts, 2)
        rs = resample(sm)
        if len(rs) * 4.0 < 60.0:
            return
        streets.append({"id": sid, "width": SW, "points": [[round(float(a), 2), round(float(b), 2)] for a, b in rs]})

    # contour streets: offsets of the road loop, inside (and outside where there is room)
    for k, off in enumerate(tc["rings_in"]):
        cands = []
        for i in range(0, N, 2):
            q = P2[i] + inward(i) * off
            d = float(np.min(np.hypot(P2[:, 0] - q[0], P2[:, 1] - q[1])))
            cands.append((q, abs(d - off) < 3.0 and street_ok(q)))
        rr = runs(cands, True)
        for j, r in enumerate(rr):
            add_street(f"ring_in{k}_{j}", np.array(r), closed=(len(rr) == 1 and len(r) == len(cands)))
    for k, off in enumerate(tc["rings_out"]):
        cands = []
        for i in range(0, N, 2):
            q = P2[i] - inward(i) * off
            d = float(np.min(np.hypot(P2[:, 0] - q[0], P2[:, 1] - q[1])))
            cands.append((q, abs(d - off) < 3.0 and street_ok(q)))
        for j, r in enumerate(runs(cands, True)):
            add_street(f"ring_out{k}_{j}", np.array(r))
    # cross streets: from the verge straight in to the middle of the loop
    rounds = []
    for k, hint in enumerate(tc["cross"]):
        i = nearest(*hint)
        n = inward(i)
        pts = []
        for o in np.arange(HW[i] + OW + 0.5, 400.0, 4.0):
            q = P2[i] + n * o
            d = float(np.min(np.hypot(P2[:, 0] - q[0], P2[:, 1] - q[1])))
            if d < o - 6.0 or (o > 20.0 and not street_ok(q)):
                break
            pts.append(q)
        if len(pts) * 4.0 < 40.0:
            print(f"cross street {k}: too short, skipped")
            continue
        streets.append({"id": f"cross{k}", "width": SW, "points": [[round(float(a), 2), round(float(b), 2)]
                                                                  for a, b in pts]})
        if k in tc["rounds"]:
            q = P2[i] + n * tc["rings_in"][0]      # on the first contour street
            rounds.append([round(float(q[0]), 2), round(float(q[1]), 2), 12.0])

    SPTS = [np.array(st["points"]) for st in streets]

    def street_gap(xs, zs):
        best = 1e9
        for sp in SPTS:
            for x, z in zip(xs, zs):
                best = min(best, float(np.min(np.hypot(sp[:, 0] - x, sp[:, 1] - z))))
        best -= SW / 2
        for rx, rz, rr in rounds:
            for x, z in zip(xs, zs):
                best = min(best, math.hypot(x - rx, z - rz) - rr)
        return best

    houses = []

    def house_ok(c, yaw, w, d):
        xs, zs = rect_points(c[0], c[1], yaw, w, d, 3.0)
        if not all(TX[0] + 30 < x < TX[1] - 30 and TX[2] + 30 < z < TX[3] - 30 for x, z in zip(xs, zs)):
            return False
        if not in_area(c[0], c[1], -15.0):
            return False
        if road_gap(xs, zs) < CLEAR or street_gap(xs, zs) < 0.8:
            return False
        if RIVERS and river_gap(xs, zs) < 8.0:
            return False
        if any(math.hypot(c[0] - pk["x"], c[1] - pk["z"]) < pk["r"] for pk in CFG["peaks"]):
            return False
        # 4 m from a landmark: its pad and the house pad (level 1.5 m round the plot) never meet in a step
        if any(keepout((x, z), 4.0) for x, z in zip(xs, zs)) or _clashes_plain(xs, zs, 4.0):
            return False
        for h in houses:          # houses: bounding circles first, then the rectangles
            if math.hypot(h["x"] - c[0], h["z"] - c[1]) > (math.hypot(w, d) + math.hypot(h["w"], h["d"])) / 2 + 1.5:
                continue
            fx, fz = math.sin(h["yaw"]), math.cos(h["yaw"])
            for x, z in zip(xs, zs):
                u = (x - h["x"]) * fz - (z - h["z"]) * fx
                v = (x - h["x"]) * fx + (z - h["z"]) * fz
                if abs(u) < h["w"] / 2 + 1.2 and abs(v) < h["d"] / 2 + 1.2:
                    return False
        return True

    def line_houses(pts, gap_of, front, block_p):
        """Houses facing a polyline, both sides. gap_of(k) = distance from the line to the house front."""
        pts = np.asarray(pts)
        cum = np.concatenate([[0.0], np.cumsum(np.hypot(*np.diff(pts, axis=0).T))])
        for side in (-1.0, 1.0):
            s = rnd.uniform(2.0, 8.0)
            while s < cum[-1] - 4.0:
                k = int(np.searchsorted(cum, s))
                k = min(max(k, 1), len(pts) - 1)
                t = pts[k] - pts[k - 1]
                t = t / np.linalg.norm(t)
                n = np.array([-t[1], t[0]]) * side
                if rnd.random() < block_p:
                    hid, w, d = BLOCK
                else:
                    r = rnd.random() * sum(q[3] for q in TOWN_TYPES)
                    for hid, w, d, wt in TOWN_TYPES:
                        r -= wt
                        if r <= 0:
                            break
                if rnd.random() < 0.18:            # a garden / an empty plot between the houses
                    s += rnd.uniform(8.0, 16.0)
                    continue
                c = pts[k] + n * (gap_of(k) + rnd.uniform(0.0, 2.5) + d / 2)
                yaw = math.atan2(-n[0], -n[1]) + rnd.uniform(-0.12, 0.12)
                if house_ok(c, yaw, w, d):
                    houses.append({"id": hid, "x": round(float(c[0]), 2), "z": round(float(c[1]), 2),
                                   "yaw": round(yaw, 4), "w": w, "d": d, "front": front})
                    s += w + rnd.uniform(3.0, 8.0)
                else:
                    s += 3.0

    # the race road first (the houses the karts pass), then the streets
    line_houses(P2, lambda k: float(HW[k] + OW + CLEAR + 0.3), "road", 0.08)
    for st in streets:
        line_houses(np.array(st["points"]), lambda k: SW / 2 + 1.2, st["id"],
                    0.10 if st["id"].startswith("ring") else 0.0)
    town = {"streets": streets, "rounds": rounds, "houses": houses}
    print(f"TOWN {len(streets)} streets ({sum(len(st['points']) for st in streets) * 4.0:.0f} m), "
          f"{len(rounds)} roundabouts, {len(houses)} houses "
          f"({sum(1 for h in houses if h['front'] == 'road')} on the race road)")

if TOWN_ONLY:       # write the "town" key only, the rest of the file untouched
    def dump(obj):
        return json.dumps(obj, ensure_ascii=False)
    k = text.find('\n\t"town": {')
    base = text[:k].rstrip().rstrip(",") if k >= 0 else text.rstrip()[:-1].rstrip()
    tl = ['\t"town": {', '\t\t"streets": [']
    tl.append(",\n".join("\t\t\t" + dump(st) for st in town["streets"]))
    tl.append('\t\t],\n\t\t"rounds": ' + dump(town["rounds"]) + ',\n\t\t"houses": [')
    tl.append(",\n".join("\t\t\t" + dump(h) for h in town["houses"]))
    tl.append("\t\t]\n\t}")
    out = base + ",\n" + "\n".join(tl) + "\n}\n"
    json.loads(out)
    io.open(TRACK_PATH, "w", encoding="utf-8", newline="\n").write(out)
    print("WROTE (town only)", TRACK_PATH)
    sys.exit(0)

for ln in lines:
    g = road_gap([p[0] for p in ln["points"]], [p[1] for p in ln["points"]]) - ln["width"] / 2
    print(f"LINE {ln['id']}: {len(ln['points'])} points, {g:.1f} m behind the run-off")
    assert g > CLEAR, ln["id"]

# plots: footprints + view lanes (signs: 30 m in front), lines -----------------------------------
plots = []
for q in placed:
    s = 8.0
    lane = 30.0 if q["id"].startswith("kb_sign") else (0.0 if q["id"] == "kb_garden_cafe" else
                                                        max(q["setback"] - 4.5, 0.0))
    fx, fz = math.sin(q["yaw"]), math.cos(q["yaw"])
    cx, cz = q["x"] + fx * lane / 2, q["z"] + fz * lane / 2
    xs, zs = rect_points(cx, cz, q["yaw"], max(q["w"] - s, 0.1), max(q["d"] + lane - s, 0.1), s)
    for x, z in zip(xs, zs):
        r = min(s / math.sqrt(2) + 0.5, road_gap([x], [z]) - 0.6)
        if r >= 2.0:
            plots.append([round(x, 1), round(z, 1), round(r, 1), q["zone"]])
for ln in lines:
    for k in range(0, len(ln["points"]), 2 if ln["id"] == "shusha_wall" else 1):
        plots.append([ln["points"][k][0], ln["points"][k][1], round(ln["width"] / 2 + 3.0, 1), ln["zone"]])
print(f"PLOTS {len(plots)}")


def dump(obj):
    return json.dumps(obj, ensure_ascii=False)


track["landmarks"] = placed
track["lines"] = lines
track["peaks"] = CFG["peaks"]
track["landmark_plots"] = plots
track.pop("town", None)
body = json.dumps({k: v for k, v in track.items() if k not in ("landmarks", "lines", "peaks", "landmark_plots")},
                  ensure_ascii=False, indent="\t")
tail = ",\n".join('\t"%s": [\n%s\n\t]' % (k, ",\n".join("\t\t" + dump(v) for v in track[k]))
                  if track[k] else '\t"%s": []' % k for k in ("landmarks", "lines", "peaks", "landmark_plots"))
out = body[:body.rstrip().rfind("}")].rstrip() + ",\n" + tail + "\n}\n"
if town is not None:      # compact: one street / house per line
    tl = ['\t"town": {', '\t\t"streets": [']
    tl.append(",\n".join("\t\t\t" + dump(st) for st in town["streets"]))
    tl.append('\t\t],\n\t\t"rounds": ' + dump(town["rounds"]) + ',\n\t\t"houses": [')
    tl.append(",\n".join("\t\t\t" + dump(h) for h in town["houses"]))
    tl.append("\t\t]\n\t}")
    out = out.rstrip()[:-1].rstrip() + ",\n" + "\n".join(tl) + "\n}\n"
json.loads(out)
io.open(TRACK_PATH, "w", encoding="utf-8", newline="\n").write(out)
print("WROTE", TRACK_PATH)
