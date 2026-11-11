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
    ("kb_victory_square", "khankendi", (600, -528), "N", 70, 64, 0, 0),
    ("kb_university", "khankendi", (790, -490), "N", 46, 24, 0, 0),
    ("kb_stadium", "khankendi", (585, -528), "S", 100, 74, 0, 0),
    ("kb_our_mountains", "khankendi", (470, -500), "N", 16, 12, 0, 0),
    # Şuşa
    ("kb_mosque", "shusha", (75, -262), "N", 28, 32, 0, 0),     # 0.20.1: west of the fortress
    ("kb_vagif", "shusha", (-30, -272), "S", 18, 18, 0, 0),
    # Laçın: the Həkəri runs on the west / north side (boulevard, café), the town on the east / south side
    ("kb_cinema", "lachin", (-700, -80), "E", 32, 28, 0, 0),
    ("kb_hotel", "lachin", (-735, 175), "E", 80, 46, 0, 0),
    ("kb_flag_square", "lachin", (-655, -105), "N", 40, 34, 0, 0),   # 0.20.1 Bayraq meydanı (owner)
    ("kb_house_a", "lachin", (-640, -110), "S", 12, 11, 0, 0),
    ("kb_house_b", "lachin", (-620, -120), "S", 12, 11, 0, 0),
    ("kb_house_c", "lachin", (-600, -128), "S", 12, 11, 0, 0),
    ("kb_house_a", "lachin", (-580, -134), "S", 12, 11, 0, 0),
    ("kb_house_b", "lachin", (-730, -50), "E", 12, 11, 0, 0),
    ("kb_house_c", "lachin", (-748, -25), "E", 12, 11, 0, 0),
    ("kb_house_a", "lachin", (-758, 0), "E", 12, 11, 0, 0),
    ("kb_house_b", "lachin", (-765, 25), "E", 12, 11, 0, 0),
    ("kb_house_c", "lachin", (-768, 50), "E", 12, 11, 0, 0),
    ("kb_house_a", "lachin", (-767, 75), "E", 12, 11, 0, 0),
    ("kb_house_b", "lachin", (-762, 100), "E", 12, 11, 0, 0),
    ("kb_house_c", "lachin", (-640, -112), "N", 12, 11, 0, 0),
    ("kb_house_a", "lachin", (-615, -122), "N", 12, 11, 0, 0),
    ("kb_house_b", "lachin", (-700, 230), "E", 12, 11, 0, 0),
    ("kb_house_c", "lachin", (-680, 255), "E", 12, 11, 0, 0),
    ("kb_house_a", "lachin", (-690, 225), "W", 12, 11, 0, 0),
]
SMALL_SETBACK = set()


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
# 0.20.1 (owner): Şuşa qalası is a small fortress the road runs through, gate to gate (was a
# 300 m wall beside the plateau road): on the straightest stretch of the plateau road, between the
# town sign (east, the karts come from there) and the mosque (moved west for it).
import kb_fortress
_cands = [i for i in range(N) if 110.0 <= P[i][0] <= 210.0 and -330.0 <= P[i][2] <= -180.0]


def _fort_ok(xs, zs):
    for q in placed:
        fx, fz = math.sin(q["yaw"]), math.cos(q["yaw"])
        for x, z in zip(xs, zs):
            u = (x - q["x"]) * fz - (z - q["z"]) * fx
            v = (x - q["x"]) * fx + (z - q["z"]) * fz
            if abs(u) < q["w"] / 2 + 4 and abs(v) < q["d"] / 2 + 4:
                return False
    return river_gap(xs, zs) > 6.0


_fort = kb_fortress.place(P, HW, OW, _cands, _fort_ok, "shusha")
assert _fort is not None, "no straight stretch for Şuşa qalası"
placed.append(_fort)
print(f"kb_sh_fortress       shusha     ({_fort['x']:7.1f}, {_fort['z']:7.1f}) the road through its gates")

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
    for grow in np.arange(0.0, 8.0 if lid.startswith("kb_house") else 60.0, 1.0):   # a house stays by the road
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
    if not ok and lid.startswith("kb_house"):
        print(f"{lid} at {hint}: no room, skipped")
        continue
    assert ok, f"{lid} at {hint}: no room"
    # Model origin = footprint front centre? No: the footprint centre (models are built centred).
    # the pad sits 0.4 m under the lowest road point beside the footprint (the
    # road may slope along a long front; the ground must stay under the verge)
    near = np.hypot(P[:, 0] - c[0], P[:, 2] - c[1]) < math.hypot(w, d) / 2 + base + grow + 15.0
    y = float(P[near, 1].min()) - 0.4
    placed.append({"id": lid, "x": round(float(c[0]), 2), "y": round(y, 2), "z": round(float(c[1]), 2),
                   "yaw": round(yaw, 4), "w": w, "d": d, "zone": zone,
                   "setback": round(float(base + grow - HW[i] - OW), 2)})
    print(f"{lid:20s} {zone:10s} ({c[0]:7.1f}, {c[1]:7.1f}) y {y:5.1f} yaw {math.degrees(yaw):6.1f}  "
          f"setback {base + grow - HW[i] - OW:5.1f} m")

# Lines ----------------------------------------------------------------------------------------
lines = []
# Həkəri boulevard: a terrace on the east bank in Laçın (the road side).
hk = next(r for r in RIVERS if r["id"] == "hakari")
blvd = []
for k in range(len(hk["pts"]) - 1):
    p, q = hk["pts"][k], hk["pts"][k + 1]
    if not (-90.0 <= p[1] <= 215.0):
        continue
    t = (q - p) / np.linalg.norm(q - p)
    n = np.array([-t[1], t[0]])
    if n[0] < 0:          # towards the road (east)
        n = -n
    off = hk["hw"] + 6.0
    blvd.append([round(float(p[0] + n[0] * off), 2), round(float(p[1] + n[1] * off), 2),
                 round(float(hk["lev"][k]) + 1.8, 2)])
# keep the stretch where the river runs beside the road (its ends turn away)
_g = [road_gap([q[0]], [q[1]]) for q in blvd]
_in = [k for k, g in enumerate(_g) if g < 4.5 + 12.0]
blvd = blvd[_in[0]:_in[-1] + 1]
lines.append({"id": "hakari_boulevard", "zone": "lachin", "module": "kb_blvd_seg", "step": 10.0, "width": 9.0,
              "points": blvd})
for ln in lines:
    xs = [p[0] for p in ln["points"]]
    zs = [p[1] for p in ln["points"]]
    g = road_gap(xs, zs) - ln["width"] / 2
    print(f"LINE {ln['id']}: {len(xs)} points, {g:.1f} m behind the run-off")
    assert g > CLEAR, ln["id"]

# Hoçaz: the big mountain north-west of Laçın, beyond the Həkəri (the village lies ~9 km NW of the town).
# Owner's photo (2026-11-10): a pointed summit on the left, a tall grey limestone
# cliff face under it, a long forested ridge falling away to the right. "face" =
# the cliff side, turned towards the town (the road sees it from ~350 m).
_lz = next(z for z in track["zones"] if z[0] == "lachin")
_pk = (-1150.0, -300.0)
_f = np.array([_lz[1] - _pk[0], _lz[2] - _pk[1]])
_f /= np.linalg.norm(_f)
peaks = [{"id": "hocaz", "x": _pk[0], "z": _pk[1], "h": 235.0, "r": 360.0,
          "face": [round(float(_f[0]), 4), round(float(_f[1]), 4)],
          "label": {"text": "HOÇAZ", "at": 0.5, "scale": 1.6}}]   # 0.20.1 (owner): the name on the mountain

# The garden café stands on the boulevard's land edge, its terrace facing the
# river (owner: "bulvar sahilində"), on the boulevard's terrace height.
CAFE_W, CAFE_D = 22.0, 16.0
bp = np.array([[q[0], q[1]] for q in blvd])
# where the river swings out for it (road samples 948-978, see the Həkəri course): the
# boulevard point there farthest from the road
_bulge = [k for k in range(len(bp)) if 0.0 <= bp[k][1] <= 60.0]
k = max(_bulge, key=lambda k: float(np.min(np.hypot(P[:, 0] - bp[k][0], P[:, 2] - bp[k][1]))))
t = bp[min(k + 1, len(bp) - 1)] - bp[max(k - 1, 0)]
t /= np.linalg.norm(t)
n_land = np.array([-t[1], t[0]])
if n_land[0] < 0:
    n_land = -n_land
c = bp[k] + n_land * (9.0 / 2 + CAFE_D / 2 + 0.5)
f = n_land                     # terrace and pergola face the road (seen from the race)
yaw = math.atan2(f[0], f[1])
xs, zs = rect_points(c[0], c[1], yaw, CAFE_W, CAFE_D)
assert river_gap(xs, zs) > 6.0 and road_gap(xs, zs) > CLEAR, "café"
# its pad at the lowest boulevard height beside it (its banks must not bury the paving)
cafe_y = min(q[2] for q in blvd if math.hypot(q[0] - c[0], q[1] - c[1]) < 40.0)
placed.append({"id": "kb_garden_cafe", "x": round(float(c[0]), 2), "y": round(float(cafe_y), 2),
               "z": round(float(c[1]), 2), "yaw": round(yaw, 4), "w": CAFE_W, "d": CAFE_D, "zone": "lachin",
               "setback": round(road_gap(xs, zs), 2)})
print(f"kb_garden_cafe on the boulevard ({c[0]:.1f}, {c[1]:.1f}) y {cafe_y:.1f}, "
      f"river bank {river_gap(xs, zs):.1f} m")
for q in placed[:-1]:
    fx, fz = math.sin(q["yaw"]), math.cos(q["yaw"])
    for x, z in zip(xs, zs):
        u = (x - q["x"]) * fz - (z - q["z"]) * fx
        v = (x - q["x"]) * fx + (z - q["z"]) * fz
        assert not (abs(u) < q["w"] / 2 and abs(v) < q["d"] / 2), "café overlaps " + q["id"]

SIGN_W, SIGN_D = 26.0, 4.0
SIGNS = {"khankendi": "kb_sign_khankendi", "shusha": "kb_sign_shusha", "lachin": "kb_sign_lachin"}


def clashes(xs, zs, margin=4.0):
    for q in placed:
        fx, fz = math.sin(q["yaw"]), math.cos(q["yaw"])
        for x, z in zip(xs, zs):
            u = (x - q["x"]) * fz - (z - q["z"]) * fx
            v = (x - q["x"]) * fx + (z - q["z"]) * fz
            if abs(u) < q["w"] / 2 + margin and abs(v) < q["d"] / 2 + margin:
                return q["id"]
    return None


def wall_clash(xs, zs):
    for ln in lines:
        lp = np.array([[q[0], q[1]] for q in ln["points"]])
        for x, z in zip(xs, zs):
            if float(np.min(np.hypot(lp[:, 0] - x, lp[:, 1] - z))) < ln["width"] / 2 + 3.0:
                return True
    return False


for zid, zx, zz, zr in track["zones"]:
    if zid not in SIGNS:
        continue
    inside = np.hypot(P[:, 0] - zx, P[:, 2] - zz) < zr
    # first sample (in driving order) that enters the zone; finish line in Xankəndi: wrap
    entry = next(i for i in range(N) if inside[i] and not inside[i - 1])
    done = False
    for back in range(8, 200, 3):
        i = (entry - back) % N
        t = P[(i + 3) % N][[0, 2]] - P[i - 3][[0, 2]]
        t = t / np.linalg.norm(t)
        right = np.array([-t[1], t[0]])
        f = -t * math.cos(math.radians(30)) - right * math.sin(math.radians(30))   # faces the karts
        yaw = math.atan2(f[0], f[1])
        for off in np.arange(HW[i] + OW + 1.5 + SIGN_W / 2 * 0.5, HW[i] + OW + 20.0, 1.0):
            c = np.array([P[i][0], P[i][2]]) + right * off
            xs, zs = rect_points(c[0], c[1], yaw, SIGN_W, SIGN_D, 2.0)
            if road_gap(xs, zs) < 1.5 or river_gap(xs, zs) < 6.0 or clashes(xs, zs) or wall_clash(xs, zs):
                continue
            done = True
            break
        if done:
            break
    assert done, zid
    near = np.hypot(P[:, 0] - c[0], P[:, 2] - c[1]) < 30.0
    placed.append({"id": SIGNS[zid], "x": round(float(c[0]), 2), "y": round(float(P[near, 1].min()) - 0.4, 2),
                   "z": round(float(c[1]), 2), "yaw": round(yaw, 4), "w": SIGN_W, "d": SIGN_D, "zone": zid,
                   "setback": round(road_gap(xs, zs), 2)})
    print(f"{SIGNS[zid]:20s} ({c[0]:7.1f}, {c[1]:7.1f}) {back * 2} m before the town, "
          f"{road_gap(xs, zs):.1f} m behind the run-off")

# Plots (circles) covering every footprint and line --------------------------------------------
plots = []
for q in placed:
    # the footprint and a view lane in front of it, open to 2.5 m behind the run-off
    s = 8.0
    # signs: 30 m open in front of them (towards the oncoming karts)
    if q["id"].startswith("kb_sign"):
        lane = 30.0
    elif q["id"] == "kb_garden_cafe":
        lane = 0.0
    else:
        lane = max(q["setback"] - 2.5 - 2.0, 0.0)
    fx, fz = math.sin(q["yaw"]), math.cos(q["yaw"])
    cx, cz = q["x"] + fx * lane / 2, q["z"] + fz * lane / 2
    xs, zs = rect_points(cx, cz, q["yaw"], max(q["w"] - s, 0.1), max(q["d"] + lane - s, 0.1), s)
    for x, z in zip(xs, zs):
        r = min(s / math.sqrt(2) + 0.5, road_gap([x], [z]) - 0.6)   # never over the run-off
        if r >= 2.0:
            plots.append([round(x, 1), round(z, 1), round(r, 1), q["zone"]])
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
