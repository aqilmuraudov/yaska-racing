"""Generates the original, tileable scenery textures in three quality tiers
(assets/textures/{low,normal,high}/<name>.png = 256 / 512 / 1024 px base).
Texture Quality in Settings picks the tier (scripts/core/texture_library.gd).

Textures are painted, not photographed: stylised cartoon surfaces with baked
ambient occlusion in the albedo, so they read well on a phone without normal
maps. Run from the project root:  python tools/gen_textures.py
"""
import os

import numpy as np
from PIL import Image

TIERS = {"low": 256, "normal": 512, "high": 1024}
OUT = "assets/textures"


def hexc(h):
    h = h.lstrip("#")
    return np.array([int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4)], np.float32)


def periodic_noise(n, cells, seed, octaves=4, gain=0.5):
    """Tileable fractal value noise in [0,1], shape (n, n)."""
    rng = np.random.default_rng(seed)
    total = np.zeros((n, n), np.float32)
    amp, norm = 1.0, 0.0
    c = cells
    for _ in range(octaves):
        lat = rng.random((c, c)).astype(np.float32)
        xs = np.arange(n, dtype=np.float32) * c / n
        i0 = np.floor(xs).astype(int) % c
        i1 = (i0 + 1) % c
        f = xs - np.floor(xs)
        f = f * f * (3 - 2 * f)
        a = lat[i0][:, i0] * (1 - f)[None, :] + lat[i0][:, i1] * f[None, :]
        b = lat[i1][:, i0] * (1 - f)[None, :] + lat[i1][:, i1] * f[None, :]
        layer = a * (1 - f)[:, None] + b * f[:, None]
        total += layer * amp
        norm += amp
        amp *= gain
        c *= 2
    return total / norm


def grain(n, seed, amount):
    rng = np.random.default_rng(seed)
    return (rng.random((n, n)).astype(np.float32) - 0.5) * amount


def save(name, rgb, size):
    img = Image.fromarray((np.clip(rgb, 0, 1) * 255).astype(np.uint8), "RGB")
    for tier, base in TIERS.items():
        w, h = int(size[0] * base), int(size[1] * base)
        d = os.path.join(OUT, tier)
        os.makedirs(d, exist_ok=True)
        img.resize((w, h), Image.LANCZOS).save(os.path.join(d, name + ".png"))


def lerp3(a, b, t):
    return a[None, None, :] * (1 - t[..., None]) + b[None, None, :] * t[..., None]


# --- Asphalt -------------------------------------------------------------------
def asphalt(n=1024):
    base = periodic_noise(n, 4, 1, 5)
    patches = periodic_noise(n, 3, 2, 3)
    col = lerp3(hexc("4a4c57"), hexc("5f6170"), base)
    col *= (0.94 + 0.10 * patches)[..., None]
    rng = np.random.default_rng(3)
    # aggregate: small light and dark stones
    speck = rng.random((n, n))
    col[speck > 0.985] = col[speck > 0.985] * 0.6 + hexc("9a9aa6") * 0.4
    col[speck < 0.012] *= 0.72
    col += grain(n, 4, 0.05)[..., None]
    return col


# --- Cobbles (Old City setts) ----------------------------------------------------------
def cobbles(n=1024, rows=10, cols=8):
    ys, xs = np.mgrid[0:n, 0:n].astype(np.float32) / n
    row = np.floor(ys * rows)
    xx = xs * cols + (row % 2) * 0.5
    cell_x = np.floor(xx) % cols
    fx, fy = xx - np.floor(xx), ys * rows - row
    edge = np.minimum(np.minimum(fx, 1 - fx) * 1.0 / rows * cols, np.minimum(fy, 1 - fy))
    rng = np.random.default_rng(5)
    tint = rng.random((rows, cols + 1)).astype(np.float32)
    t = tint[row.astype(int) % rows, cell_x.astype(int)]
    stone = lerp3(hexc("c9a87c"), hexc("e3c79b"), t)
    n1 = periodic_noise(n, 8, 6, 4)
    stone *= (0.9 + 0.18 * n1)[..., None]
    dome = np.clip(edge * 6, 0, 1) ** 0.5  # rounded stone tops (baked AO)
    stone *= (0.84 + 0.16 * dome)[..., None]
    mortar = np.clip((0.045 - edge) / 0.03, 0, 1) * 0.6
    col = stone * (1 - mortar[..., None]) + hexc("9c8466") * mortar[..., None]
    col += grain(n, 7, 0.04)[..., None]
    return col


# --- Limestone wall (Old City) -------------------------------------------------------------
def limestone(n=1024, courses=4, blocks=2):
    """Square texture covering 4 courses × 2 blocks; mapped at world scale."""
    ys, xs = np.mgrid[0:n, 0:n].astype(np.float32) / n
    row = np.floor(ys * courses)
    xx = xs * blocks + (row % 2) * 0.5
    fx, fy = xx - np.floor(xx), ys * courses - row
    ex = np.minimum(fx, 1 - fx) / courses * blocks
    ey = np.minimum(fy, 1 - fy)
    edge = np.minimum(ex * 1.0, ey) / courses
    rng = np.random.default_rng(9)
    tint = rng.random((courses, blocks + 1)).astype(np.float32)
    t = tint[row.astype(int) % courses, (np.floor(xx) % blocks).astype(int)]
    stone = lerp3(hexc("e9cf9f"), hexc("f6e2b8"), t)
    weather = periodic_noise(n, 6, 10, 5)
    pits = periodic_noise(n, 32, 11, 2)
    stone *= (0.88 + 0.16 * weather)[..., None]
    stone[pits > 0.78] *= 0.9
    bevel = np.clip(edge * 60, 0, 1)
    stone *= (0.92 + 0.08 * bevel)[..., None]
    # warm sunlit top edge on each block
    top = np.clip(1 - (fy - 0.02) / 0.08, 0, 1) * (fy > 0.02)
    stone += (top * 0.05)[..., None]
    mortar = np.clip((0.004 - edge) / 0.003, 0, 1) * 0.55
    col = stone * (1 - mortar[..., None]) + hexc("c4a676") * mortar[..., None]
    col += grain(n, 12, 0.03)[..., None]
    return col


# --- Promenade paving (Boulevard) --------------------------------------------------------------
def paving(n=1024, tiles=4):
    ys, xs = np.mgrid[0:n, 0:n].astype(np.float32) / n
    tx, ty = xs * tiles, ys * tiles
    fx, fy = tx - np.floor(tx), ty - np.floor(ty)
    ix, iy = np.floor(tx).astype(int), np.floor(ty).astype(int)
    checker = ((ix + iy) % 2).astype(np.float32)
    col = lerp3(hexc("f2dfbd"), hexc("e7c9a0"), checker)
    # diamond inlay in the "dark" tiles
    d = np.abs(fx - 0.5) + np.abs(fy - 0.5)
    inlay = (d < 0.28) & (checker > 0.5)
    col[inlay] = col[inlay] * 0.3 + hexc("d0795a") * 0.7
    ring = (np.abs(d - 0.28) < 0.02) & (checker > 0.5)
    col[ring] = hexc("fff4dc")
    col *= (0.93 + 0.1 * periodic_noise(n, 8, 13, 4))[..., None]
    edge = np.minimum(np.minimum(fx, 1 - fx), np.minimum(fy, 1 - fy))
    joint = np.clip((0.015 - edge) / 0.01, 0, 1)
    col = col * (1 - joint[..., None]) + hexc("a88d6a") * joint[..., None]
    col += grain(n, 14, 0.03)[..., None]
    return col


# --- Grass ---------------------------------------------------------------------------
def grass(n=1024):
    a = periodic_noise(n, 6, 15, 5)
    b = periodic_noise(n, 24, 16, 3)
    col = lerp3(hexc("4fae3a"), hexc("7fd34e"), a)
    col *= (0.9 + 0.16 * b)[..., None]
    rng = np.random.default_rng(17)
    # little clover / flower dots
    for colr, prob in (("ffffff", 0.00025), ("ffd23f", 0.0002), ("ff8fb8", 0.00015)):
        pts = np.argwhere(rng.random((n, n)) < prob)
        r = 2 + n // 512
        for dy in range(-r, r + 1):
            for dx in range(-r, r + 1):
                if dx * dx + dy * dy <= r * r:
                    col[(pts[:, 0] + dy) % n, (pts[:, 1] + dx) % n] = hexc(colr)
    blades = grain(n, 18, 0.10)
    col += blades[..., None] * np.array([0.6, 1.0, 0.4], np.float32)
    return col


# --- Azerbaijani flag (2:1) -------------------------------------------------------------------
def flag(n=1024):
    w, h = n, n // 2
    ss = 2
    W, H = w * ss, h * ss
    ys, xs = np.mgrid[0:H, 0:W].astype(np.float32) + 0.5
    band = H / 3
    col = np.zeros((H, W, 3), np.float32)
    col[ys < band] = hexc("00b5e2")
    col[(ys >= band) & (ys < 2 * band)] = hexc("ef3340")
    col[ys >= 2 * band] = hexc("509e2f")
    # Crescent: white circle minus offset red circle; star in the opening.
    cx, cy = W / 2 - band * 0.18, H / 2
    r1 = band * 0.45
    r2 = r1 * 0.8
    outer = (xs - cx) ** 2 + (ys - cy) ** 2 <= r1 ** 2
    inner = (xs - (cx + r1 * 0.25)) ** 2 + (ys - cy) ** 2 <= r2 ** 2
    col[outer & ~inner] = hexc("ffffff")
    sx, sy = cx + r1 * 0.9, cy
    ang = np.arctan2(ys - sy, xs - sx) + np.pi / 2
    rad = np.hypot(xs - sx, ys - sy)
    ro, ri = band * 0.24, band * 0.24 * 0.42
    k = 8
    a = np.mod(ang, 2 * np.pi / k) - np.pi / k
    # polar edge of a regular star polygon
    half = np.pi / k
    t = np.abs(a) / half
    edge_r = ri + (ro - ri) * (1 - t)
    col[rad <= edge_r] = hexc("ffffff")
    img = Image.fromarray((col * 255).astype(np.uint8), "RGB").resize((w, h), Image.LANCZOS)
    return np.asarray(img).astype(np.float32) / 255.0


def save_flag():
    rgb = flag(1024)
    img = Image.fromarray((rgb * 255).astype(np.uint8), "RGB")
    for tier, base in TIERS.items():
        d = os.path.join(OUT, tier)
        os.makedirs(d, exist_ok=True)
        img.resize((base, base // 2), Image.LANCZOS).save(os.path.join(d, "flag_az.png"))


if __name__ == "__main__":
    save("road", asphalt(), (1, 1))
    save("cobbles", cobbles(), (1, 1))
    save("limestone", limestone(), (1, 1))
    save("paving", paving(), (1, 1))
    save("grass", grass(), (1, 1))
    save_flag()
    print("textures written to", OUT)
