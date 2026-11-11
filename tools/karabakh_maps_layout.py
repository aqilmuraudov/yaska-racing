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
}
CFG = CONFIG[TID]
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


placed = []
lines = []


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
for k, (hint, side) in enumerate(CFG.get("houses", [])):
    lid = ["kb_sh_house_a", "kb_sh_house_b", "kb_sh_house_c"][k % 3]
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
print(f"HOUSES {sum(1 for q in placed if q['id'].startswith('kb_sh_house'))}")

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

for ln in lines:
    g = road_gap([p[0] for p in ln["points"]], [p[1] for p in ln["points"]]) - ln["width"] / 2
    print(f"LINE {ln['id']}: {len(ln['points'])} points, {g:.1f} m behind the run-off")
    assert g > CLEAR, ln["id"]

# plots: footprints + view lanes (signs: 30 m in front), lines -----------------------------------
plots = []
for q in placed:
    s = 8.0
    lane = 30.0 if q["id"].startswith("kb_sign") else max(q["setback"] - 4.5, 0.0)
    fx, fz = math.sin(q["yaw"]), math.cos(q["yaw"])
    cx, cz = q["x"] + fx * lane / 2, q["z"] + fz * lane / 2
    xs, zs = rect_points(cx, cz, q["yaw"], max(q["w"] - s, 0.1), max(q["d"] + lane - s, 0.1), s)
    for x, z in zip(xs, zs):
        r = min(s / math.sqrt(2) + 0.5, road_gap([x], [z]) - 0.6)
        if r >= 2.0:
            plots.append([round(x, 1), round(z, 1), round(r, 1), q["zone"]])
for ln in lines:
    for k in range(0, len(ln["points"]), 2):
        plots.append([ln["points"][k][0], ln["points"][k][1], round(ln["width"] / 2 + 3.0, 1), ln["zone"]])
print(f"PLOTS {len(plots)}")


def dump(obj):
    return json.dumps(obj, ensure_ascii=False)


track["landmarks"] = placed
track["lines"] = lines
track["peaks"] = CFG["peaks"]
track["landmark_plots"] = plots
body = json.dumps({k: v for k, v in track.items() if k not in ("landmarks", "lines", "peaks", "landmark_plots")},
                  ensure_ascii=False, indent="\t")
tail = ",\n".join('\t"%s": [\n%s\n\t]' % (k, ",\n".join("\t\t" + dump(v) for v in track[k]))
                  if track[k] else '\t"%s": []' % k for k in ("landmarks", "lines", "peaks", "landmark_plots"))
out = body[:body.rstrip().rfind("}")].rstrip() + ",\n" + tail + "\n}\n"
json.loads(out)
io.open(TRACK_PATH, "w", encoding="utf-8", newline="\n").write(out)
print("WROTE", TRACK_PATH)
