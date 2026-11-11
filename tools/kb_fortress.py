"""Şuşa qalası on the road (0.20.1, owner): a small fortress the road runs through, gate to gate
(tools/blender/karabakh_shusha_town.py kb_sh_fortress: 72 m along the road, 66 m across, gate
openings 26 m wide, 10.5 m clear). Shared by tools/karabakh_layout.py (big map) and
tools/karabakh_maps_layout.py (Şuşa).

place(P, HW, OW, cands, ok) -> landmark dict or None
  P (n, 3) road samples, HW half widths, OW run-off; cands: sample indices allowed as the
  centre; ok(xs, zs) -> bool: the footprint is free (other landmarks). The straightest
  stretch wins: every road sample within 40 m of the centre stays within 2 m of the axis, so
  the road (and its run-off) passes inside both gates.
"""

import math

import numpy as np

FORT_L, FORT_W = 72.0, 66.0
GATE_HALF = 13.0


def _rect(cx, cz, yaw, w, d, step=4.0):
    fx, fz = math.sin(yaw), math.cos(yaw)
    ax, az = fz, -fx
    xs, zs = [], []
    nu, nv = max(2, int(w / step) + 1), max(2, int(d / step) + 1)
    for i in range(nu):
        u = -w / 2 + w * i / (nu - 1)
        for j in range(nv):
            v = -d / 2 + d * j / (nv - 1)
            xs.append(cx + ax * u + fx * v)
            zs.append(cz + az * u + fz * v)
    return xs, zs


def place(P, HW, OW, cands, ok, zone):
    N = len(P)
    best = None
    for i in cands:
        t = P[(i + 4) % N][[0, 2]] - P[(i - 4) % N][[0, 2]]
        t = t / np.linalg.norm(t)
        c = P[i][[0, 2]]
        rel = P[:, [0, 2]] - c
        along = rel @ t
        near = np.abs(along) < FORT_L / 2 + 4.0
        near &= np.hypot(rel[:, 0], rel[:, 1]) < FORT_L       # this pass only, not another leg
        across = np.abs(rel[near] @ np.array([-t[1], t[0]]))
        dev = float(np.max(across + HW[near] + OW)) - GATE_HALF   # < 0: road + run-off inside the gates
        if dev > -0.5:
            continue
        yaw = math.atan2(-t[1], t[0])                          # local +x = the driving direction
        xs, zs = _rect(c[0], c[1], yaw, FORT_L, FORT_W)
        if not ok(xs, zs):
            continue
        score = float(np.max(across))
        if best is None or score < best[0]:
            y = float(np.min(P[near, 1])) - 0.3
            best = (score, {"id": "kb_sh_fortress", "x": round(float(c[0]), 2), "y": round(y, 2),
                            "z": round(float(c[1]), 2), "yaw": round(yaw, 4), "w": FORT_L, "d": FORT_W,
                            "zone": zone, "setback": 0.0, "spans_road": True})
    return None if best is None else best[1]
