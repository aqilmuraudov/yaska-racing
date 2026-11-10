"""Qarabağ landmark layout (0.19.x): where every named landmark stands.

  python tools/karabakh_layout.py

Reads tools/blender/out/karabakh_road.json (road samples) and
data/tracks/karabakh.json; writes into the track JSON:
  landmarks       [{id, x, y, z, yaw, w, d, zone}]: model origin (front centre
                  line of the footprint is local +z, facing the road), the
                  w x d footprint (w along the road), y = the level pad the
                  Blender terrain flattens under it
  lines           wall / boulevard runs: [{id, module, step, width, points
                  [[x, z, y]...], ...}]; y = null follows the terrain
  peaks           big terrain features (Hoçaz): [{id, x, z, h, r}]
  landmark_plots  [x, z, r, zone] circles covering every footprint and line
                  (forest / canopy clearing in Blender, KarabakhDecor._reserved)
The owner names the landmarks (2026-11-10); see docs/TUNING.md "Qarabağ map".
Every footprint is checked against all road samples (run-off + CLEAR m),
the rivers and the other footprints; the script fails loudly if one does not fit.
"""

import io
import json
import math
import os
import re
import sys

import numpy as np

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
TRACK_PATH = os.path.join(ROOT, "data", "tracks", "karabakh.json")
road = json.load(open(os.path.join(ROOT, "tools", "blender", "out", "karabakh_road.json"), encoding="utf-8"))
text = io.open(TRACK_PATH, encoding="utf-8").read()
track = json.loads(text)
P = np.array(road["points"])
HW = np.array(road["half_widths"])
OW = float(road["offroad_width"])
N = len(P)
CLEAR = 3.0     # footprint edge >= 3 m behind the run-off

COMPASS = {"N": (0.0, -1.0), "S": (0.0, 1.0), "E": (1.0, 0.0), "W": (-1.0, 0.0)}

# id, zone, road hint (x, z), side (compass), w (along road), d (deep), extra setback, along-road shift
WANT = [
    # Xankəndi - Zəfər meydanı first (owner: "ən əsası")
    ("kb_victory_square", "khankendi", (600, -528), "N", 70, 52, 0, 0),
    ("kb_university", "khankendi", (790, -490), "N", 46, 24, 2, 0),
    ("kb_stadium", "khankendi", (585, -528), "S", 100, 74, 14, 0),
    ("kb_our_mountains", "khankendi", (470, -500), "N", 16, 12, 22, 0),
    # Şuşa
    ("kb_shusha_sign", "shusha", (395, -330), "E", 14, 6, -1.5, 0),
    ("kb_mosque", "shusha", (150, -255), "N", 28, 32, 0, 0),
    ("kb_vagif", "shusha", (-30, -272), "S", 18, 18, 2, 0),
    # Laçın
    ("kb_cinema", "lachin", (-700, -80), "E", 32, 24, 0, 0),
    ("kb_hotel", "lachin", (-735, 175), "E", 44, 22, 8, 0),
    ("kb_garden_cafe", "lachin", (-772, 20), "W", 22, 16, 0, 0),
    ("kb_house_a", "lachin", (-655, -105), "N", 12, 11, 0, 0),
    ("kb_house_b", "lachin", (-765, -10), "E", 12, 11, 0, 0),
    ("kb_house_c", "lachin", (-768, 75), "E", 12, 11, 0, 0),
    ("kb_house_a", "lachin", (-752, 115), "E", 12, 11, 0, 0),
    ("kb_house_b", "lachin", (-680, -100), "S", 12, 11, 0, 0),
    ("kb_house_c", "lachin", (-718, -62), "S", 12, 11, 0, 0),
    ("kb_house_a", "lachin", (-760, 45), "W", 12, 11, 0, 0),
    ("kb_house_b", "lachin", (-748, 140), "W", 12, 11, 0, 0),
]
SMALL_SETBACK = {"kb_shusha_sign"}   # a sign stands close to the road (guardrail in front)


def nearest(x, z):
    d = np.hypot(P[:, 0] - x, P[:, 2] - z)
    return int(np.argmin(d))


def road_gap(xs, zs):
    """Smallest distance of the points past the run-off edge."""
    best = 1e9
    for x, z in zip(xs, zs):
        d = np.hypot(P[:, 0] - x, P[:, 2] - z) - HW - OW
        best = min(best, float(d.min()))
    return best


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
for rv in track["rivers"]:
    p = chaikin(rv["points"])
    cum = np.concatenate([[0.0], np.cumsum(np.hypot(*np.diff(p, axis=0).T))])
    lev = np.full(len(p), float(rv["level"])) if rv.get("level") is not None else \
        rv["drop"][0] + (rv["drop"][1] - rv["drop"][0]) * cum / cum[-1]
    RIVERS.append({"id": rv["id"], "pts": p, "lev": lev, "hw": rv["width"] / 2.0})


def river_gap(xs, zs):
    best = 1e9
    for rv in RIVERS:
        for x, z in zip(xs, zs):
            best = min(best, float(np.min(np.hypot(rv["pts"][:, 0] - x, rv["pts"][:, 1] - z))) - rv["hw"])
    return best


def rect_points(cx, cz, yaw, w, d, step=3.0):
    """Sample points over a w x d rectangle centred at (cx, cz), turned by yaw (local +z -> (sin, cos))."""
    fx, fz = math.sin(yaw), math.cos(yaw)      # local +z (towards the road)
    ax, az = fz, -fx                            # local +x
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
for lid, zone, hint, side, w, d, extra, shift in WANT:
    i = nearest(*hint)
    a, b = P[(i - 2) % N], P[(i + 2) % N]
    t = np.array([b[0] - a[0], b[2] - a[2]])
    t /= np.linalg.norm(t)
    n = np.array([-t[1], t[0]])
    cv = np.array(COMPASS[side])
    if n @ cv < 0:
        n = -n
    clear = 1.0 if lid in SMALL_SETBACK else CLEAR
    base = HW[i] + OW + clear + extra
    ok = False
    for grow in np.arange(0.0, 60.0, 1.0):
        off = base + grow + d / 2
        c = np.array([P[i][0], P[i][2]]) + n * off + t * shift
        yaw = math.atan2(-n[0], -n[1])          # front (local +z) faces the road
        xs, zs = rect_points(c[0], c[1], yaw, w, d)
        if road_gap(xs, zs) < clear + extra - 0.01:
            continue
        if river_gap(xs, zs) < 6.0:
            continue
        clash = False
        for q in placed:
            qx, qz = rect_points(q["x"], q["z"], q["yaw"], q["w"] + 8, q["d"] + 8, 4.0)
            # inside test: distance of our samples to q's centre in q's frame
            fx, fz = math.sin(q["yaw"]), math.cos(q["yaw"])
            for x, z in zip(xs, zs):
                u = (x - q["x"]) * fz - (z - q["z"]) * fx
                v = (x - q["x"]) * fx + (z - q["z"]) * fz
                if abs(u) < q["w"] / 2 + 4 and abs(v) < q["d"] / 2 + 4:
                    clash = True
                    break
            if clash:
                break
        if clash:
            continue
        ok = True
        break
    assert ok, f"{lid} at {hint}: no room"
    # Model origin = footprint front centre? No: the footprint centre (models are built centred).
    y = float(P[i][1]) - 0.4
    placed.append({"id": lid, "x": round(float(c[0]), 2), "y": round(y, 2), "z": round(float(c[1]), 2),
                   "yaw": round(yaw, 4), "w": w, "d": d, "zone": zone,
                   "setback": round(float(base + grow - HW[i] - OW), 2)})
    print(f"{lid:20s} {zone:10s} ({c[0]:7.1f}, {c[1]:7.1f}) y {y:5.1f} yaw {math.degrees(yaw):6.1f}  "
          f"setback {base + grow - HW[i] - OW:5.1f} m")

# Lines ----------------------------------------------------------------------------------------
lines = []
# Şuşa fortress walls along the southern rim of the plateau, above the Daşaltı gorge.
SH = (50.0, -255.0, 300.0, 150.0)
wall = []
for x in np.arange(-100.0, 296.0, 4.0):
    u = (x - SH[0]) / (SH[2] * 0.9)
    z = SH[1] + SH[3] * 0.86 * math.sqrt(max(0.0, 1.0 - u * u))
    wall.append([round(float(x), 2), round(z, 2), None])
lines.append({"id": "shusha_wall", "zone": "shusha", "module": "kb_wall_seg", "tower": "kb_wall_tower",
              "gate": "kb_wall_gate", "step": 8.0, "tower_every": 6, "gate_at": 0.55, "width": 6.0, "points": wall})
# Həkəri boulevard: a terrace on the east bank in Laçın (the road side).
hk = next(r for r in RIVERS if r["id"] == "hakari")
blvd = []
for k in range(len(hk["pts"]) - 1):
    p, q = hk["pts"][k], hk["pts"][k + 1]
    if not (-170.0 <= p[1] <= 110.0):
        continue
    t = (q - p) / np.linalg.norm(q - p)
    n = np.array([-t[1], t[0]])
    if n[0] < 0:          # towards the road (east)
        n = -n
    off = hk["hw"] + 6.0
    blvd.append([round(float(p[0] + n[0] * off), 2), round(float(p[1] + n[1] * off), 2),
                 round(float(hk["lev"][k]) + 1.8, 2)])
lines.append({"id": "hakari_boulevard", "zone": "lachin", "module": "kb_blvd_seg", "step": 10.0, "width": 9.0,
              "points": blvd})
for ln in lines:
    xs = [p[0] for p in ln["points"]]
    zs = [p[1] for p in ln["points"]]
    g = road_gap(xs, zs) - ln["width"] / 2
    print(f"LINE {ln['id']}: {len(xs)} points, {g:.1f} m behind the run-off")
    assert g > CLEAR, ln["id"]

# Hoçaz: the big mountain north-west of Laçın, beyond the Həkəri (the village lies ~9 km NW of the town).
peaks = [{"id": "hocaz", "x": -1160.0, "z": -330.0, "h": 300.0, "r": 420.0}]

# Plots (circles) covering every footprint and line --------------------------------------------
plots = []
for q in placed:
    # the footprint and a view lane in front of it, open to 2.5 m behind the run-off
    s = 8.0
    lane = max(q["setback"] - 2.5 - 2.0, 0.0)
    fx, fz = math.sin(q["yaw"]), math.cos(q["yaw"])
    cx, cz = q["x"] + fx * lane / 2, q["z"] + fz * lane / 2
    xs, zs = rect_points(cx, cz, q["yaw"], max(q["w"] - s, 0.1), max(q["d"] + lane - s, 0.1), s)
    for x, z in zip(xs, zs):
        plots.append([round(x, 1), round(z, 1), round(s / math.sqrt(2) + 0.5, 1), q["zone"]])
for ln in lines:
    pts = ln["points"]
    for k in range(0, len(pts), 2 if ln["id"] == "shusha_wall" else 1):
        plots.append([pts[k][0], pts[k][1], round(ln["width"] / 2 + 3.0, 1), ln["zone"]])
print(f"PLOTS {len(plots)}")


def dump(obj):
    return json.dumps(obj, ensure_ascii=False)


body = {
    "landmarks": "[\n" + ",\n".join("\t\t" + dump(q) for q in placed) + "\n\t]",
    "lines": "[\n" + ",\n".join("\t\t" + dump(ln) for ln in lines) + "\n\t]",
    "peaks": "[\n" + ",\n".join("\t\t" + dump(p) for p in peaks) + "\n\t]",
    "landmark_plots": "[\n" + ",\n".join("\t\t" + dump(p) for p in plots) + "\n\t]",
}
# Rewrite the tail of the JSON (everything from "landmark_plots" / "landmarks" on).
m = re.search(r'\t"(landmarks|landmark_plots)": ', text)
head = text[:m.start()]
tail = ",\n".join('\t"%s": %s' % (k, v) for k, v in body.items())
out = head + tail + "\n}\n"
json.loads(out)
io.open(TRACK_PATH, "w", encoding="utf-8", newline="\n").write(out)
print("WROTE", TRACK_PATH)
