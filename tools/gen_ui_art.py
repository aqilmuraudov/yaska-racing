"""Generates the original UI artwork used by UITheme (no third-party art):

* assets/ui/btn_<color>[_pressed].png  glossy, dimensional 9-patch buttons
* assets/ui/panel_*.png                rounded panels / cards (9-patch)
* assets/ui/pattern_blue.png           tileable patterned menu backdrop
* assets/ui/sparkle.png, glow.png      small effect sprites

Run from the project root:  python tools/gen_ui_art.py
Then let Godot import (open the editor or run with --headless --import).
"""
import os

import numpy as np
from PIL import Image

OUT = "assets/ui"
SS = 4  # supersampling


def hexc(h, a=1.0):
    h = h.lstrip("#")
    return np.array([int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4)] + [a])


def rr_sdf(w, h, x0, y0, x1, y1, r):
    """Signed distance (px, negative inside) to a rounded rectangle."""
    ys, xs = np.mgrid[0:h, 0:w].astype(np.float32) + 0.5
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
    hx, hy = (x1 - x0) / 2 - r, (y1 - y0) / 2 - r
    qx = np.abs(xs - cx) - hx
    qy = np.abs(ys - cy) - hy
    out = np.hypot(np.maximum(qx, 0), np.maximum(qy, 0))
    ins = np.minimum(np.maximum(qx, qy), 0)
    return out + ins - r


def cover(d):
    return np.clip(0.5 - d, 0, 1)


def over(dst, rgb, a):
    """Alpha-composite colour rgb (3,) or (h,w,3) with coverage a onto dst."""
    a = a[..., None]
    src_a = a
    out_a = src_a + dst[..., 3:4] * (1 - src_a)
    rgb = np.broadcast_to(rgb[..., :3] if rgb.ndim == 3 else rgb[:3], dst[..., :3].shape)
    out_rgb = (rgb * src_a + dst[..., :3] * dst[..., 3:4] * (1 - src_a)) / np.maximum(out_a, 1e-6)
    dst[..., :3] = out_rgb
    dst[..., 3:4] = out_a
    return dst


def save(img, name, size):
    im = Image.fromarray((np.clip(img, 0, 1) * 255).astype(np.uint8), "RGBA")
    im = im.resize(size, Image.LANCZOS)
    os.makedirs(OUT, exist_ok=True)
    im.save(os.path.join(OUT, name))


def mix(a, b, t):
    return a * (1 - t) + b * t


def button(name, base, pressed=False, size=96, radius=30, lip=8):
    S = size * SS
    img = np.zeros((S, S, 4), np.float32)
    ys = (np.mgrid[0:S, 0:S][0].astype(np.float32) + 0.5) / S
    outline = mix(base, hexc("0b1d4a"), 0.72)
    dark = mix(base, hexc("0b1d4a"), 0.38)
    light = mix(base, hexc("ffffff"), 0.32)
    m = 3 * SS
    top_off = (lip * SS if pressed else 0)
    body_bottom = S - m - (0 if pressed else lip * SS)
    # soft drop shadow
    d_sh = rr_sdf(S, S, m, m + 3 * SS, S - m, S - m + 1 * SS, radius * SS)
    img = over(img, hexc("000000"), np.clip(0.5 - d_sh / (4 * SS), 0, 1) * 0.28)
    # outline + lip
    d_out = rr_sdf(S, S, m - 2 * SS, m - 2 * SS + top_off, S - m + 2 * SS, S - m + 2 * SS, (radius + 2) * SS)
    img = over(img, outline, cover(d_out / SS * 1.0))
    d_lip = rr_sdf(S, S, m, m + top_off, S - m, S - m, radius * SS)
    img = over(img, dark, cover(d_lip / SS))
    # body gradient
    d_body = rr_sdf(S, S, m, m + top_off, S - m, body_bottom, radius * SS)
    t = np.clip((ys - (m + top_off) / S) / ((body_bottom - m - top_off) / S), 0, 1)
    grad = mix(light, base, np.clip(t * 1.6, 0, 1)[..., None]) if not pressed else mix(base, dark, (t * 0.5)[..., None])
    img = over(img, grad, cover(d_body / SS))
    # gloss band on the upper half
    if not pressed:
        d_gl = rr_sdf(S, S, m + 7 * SS, m + 5 * SS, S - m - 7 * SS, m + (body_bottom - m) * 0.46, (radius - 8) * SS)
        g = cover(d_gl / SS) * np.clip(1.0 - (ys - m / S) * 2.2, 0, 1) * 0.42
        img = over(img, hexc("ffffff"), g)
    # inner rim highlight
    rim = cover(np.abs(d_body + 2.5 * SS) / SS - 1.0) * np.clip(1.0 - ys * 1.6, 0, 1) * 0.55
    img = over(img, hexc("ffffff"), rim)
    save(img, name, (size, size))


def panel(name, base, edge, size=96, radius=30, alpha=0.96, stripes=False):
    S = size * SS
    img = np.zeros((S, S, 4), np.float32)
    ys = (np.mgrid[0:S, 0:S][0].astype(np.float32) + 0.5) / S
    m = 4 * SS
    d_sh = rr_sdf(S, S, m, m + 4 * SS, S - m, S - m + 2 * SS, radius * SS)
    img = over(img, hexc("000000"), np.clip(0.5 - d_sh / (5 * SS), 0, 1) * 0.30)
    d_e = rr_sdf(S, S, m - 2 * SS, m - 2 * SS, S - m + 2 * SS, S - m + 2 * SS, (radius + 2) * SS)
    img = over(img, edge, cover(d_e / SS))
    d = rr_sdf(S, S, m + 2 * SS, m + 2 * SS, S - m - 2 * SS, S - m - 2 * SS, (radius - 2) * SS)
    light = mix(base, hexc("ffffff"), 0.16)
    grad = mix(light, base, np.clip(ys * 2.0, 0, 1)[..., None])
    grad[..., 3] = alpha
    img = over(img, grad, cover(d / SS) * alpha)
    rim = cover(np.abs(d + 2 * SS) / SS - 0.8) * np.clip(1.0 - ys * 2.0, 0, 1) * 0.35
    img = over(img, hexc("ffffff"), rim)
    save(img, name, (size, size))


def pattern(name, size=256):
    """Tileable blue backdrop: diagonal bands with soft star sparkles."""
    S = size
    ys, xs = np.mgrid[0:S, 0:S].astype(np.float32)
    base = hexc("1d5fc8")
    deep = hexc("1749ad")
    band = (np.sin((xs + ys) / S * 2 * np.pi * 4) > 0.55).astype(np.float32)
    img = np.zeros((S, S, 4), np.float32)
    img[..., :3] = mix(base[:3], deep[:3], band[..., None] * 0.6)
    img[..., 3] = 1
    # tileable stars
    rng = np.random.default_rng(7)
    for _ in range(9):
        cx, cy = rng.uniform(0, S, 2)
        r = rng.uniform(5, 11)
        for ox in (-S, 0, S):
            for oy in (-S, 0, S):
                dx = xs - (cx + ox)
                dy = ys - (cy + oy)
                ang = np.arctan2(dy, dx)
                rad = np.hypot(dx, dy)
                star_r = r * (0.45 + 0.55 * np.abs(np.cos(ang * 2)) ** 6)
                a = np.clip(star_r - rad, 0, 1) * 0.16
                img = over(img, hexc("ffffff"), a)
    save(img, name, (S, S))


def sparkle(name, size=64):
    S = size * SS
    ys, xs = np.mgrid[0:S, 0:S].astype(np.float32) + 0.5
    dx, dy = (xs - S / 2) / (S / 2), (ys - S / 2) / (S / 2)
    rad = np.hypot(dx, dy)
    ang = np.arctan2(dy, dx)
    star = (0.18 + 0.82 * np.abs(np.cos(ang * 2)) ** 18)
    a = np.clip((star - rad) * 6, 0, 1) + np.clip(1 - rad * 3.0, 0, 1) * 0.6
    img = np.zeros((S, S, 4), np.float32)
    img[..., :3] = 1
    img[..., 3] = np.clip(a, 0, 1)
    save(img, name, (size, size))


def glow(name, size=64):
    ys, xs = np.mgrid[0:size, 0:size].astype(np.float32) + 0.5
    rad = np.hypot(xs - size / 2, ys - size / 2) / (size / 2)
    img = np.zeros((size, size, 4), np.float32)
    img[..., :3] = 1
    img[..., 3] = np.clip(1 - rad, 0, 1) ** 2
    save(img, name, (size, size))


COLORS = {
    "yellow": "ffc21a",
    "orange": "ff8a1f",
    "blue": "2f7de1",
    "turquoise": "17b9c9",
    "coral": "ff5f6d",
    "lime": "6fcf3c",
    "violet": "8b5cf6",
    "grey": "8d98ad",
}

if __name__ == "__main__":
    for n, h in COLORS.items():
        button(f"btn_{n}.png", hexc(h))
        button(f"btn_{n}_pressed.png", hexc(h), pressed=True)
    panel("panel_blue.png", hexc("1f63cf"), hexc("0d2f78"))
    panel("panel_card.png", hexc("2b78e4"), hexc("174aa6"), alpha=1.0)
    panel("panel_card_selected.png", hexc("ffd23f"), hexc("ff8a1f"), alpha=1.0)
    panel("panel_hud.png", hexc("163f99"), hexc("0b1d4a"), alpha=0.88)
    panel("panel_white.png", hexc("ffffff"), hexc("bcd3f5"), alpha=1.0)
    pattern("pattern_blue.png")
    sparkle("sparkle.png")
    glow("glow.png")
    print("UI art written to", OUT)
