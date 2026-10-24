"""Generates the startup artwork so every startup stage shows the same picture
on the same background colour (no third-party art):

* assets/splash/splash.png              1920x1080 boot splash (Godot boot splash
                                        and the boot scene use the same file)
* assets/icons/launcher_192.png         Android launcher icon (legacy)
* assets/icons/adaptive_fg_432.png      Android adaptive icon foreground; the
                                        Android 12+ system splash shows it
* assets/icons/adaptive_bg_432.png      adaptive icon background, solid BG

The splash fades to BG at every edge, so letterboxing on any screen ratio is
invisible when project.godot's boot_splash/bg_color equals BG.

Run from the project root:  python tools/gen_splash.py
"""
import math
import os

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

BG = (18, 63, 154)  # UITheme.BLUE_DEEP #123f9a — keep in sync with project.godot
SS = 3
HEAD_FONT = "assets/fonts/Baloo2-Variable.ttf"


def kart_layer(size):
    """The app's kart mark (same shapes as assets/icons/icon.svg), drawn on a
    transparent square of `size` px at 4x supersampling."""
    s = size * 4
    img = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    k = s / 256.0

    def r(v):
        return v * k

    # Ground shadow and speed lines
    d.ellipse([r(52), r(182), r(204), r(200)], fill=(12, 37, 89, 90))
    for y, x0, x1 in ((126, 18, 50), (144, 8, 46), (162, 18, 50)):
        d.line([r(x0), r(y), r(x1), r(y)], fill=(255, 250, 240, 255), width=int(r(8)))
        for x in (x0, x1):
            d.ellipse([r(x) - r(4), r(y) - r(4), r(x) + r(4), r(y) + r(4)], fill=(255, 250, 240, 255))
    # Driver helmet (dome sits on the body), body with highlight, spoiler, wheels
    d.chord([r(88), r(78), r(168), r(150)], 180, 360, fill=(255, 210, 63, 255))
    d.rectangle([r(98), r(100), r(158), r(110)], fill=(12, 37, 89, 255))
    d.rounded_rectangle([r(50), r(96), r(70), r(132)], radius=r(6), fill=(23, 185, 201, 255))
    d.rounded_rectangle([r(58), r(114), r(200), r(162)], radius=r(20), fill=(224, 52, 75, 255))
    d.rounded_rectangle([r(66), r(118), r(192), r(130)], radius=r(6), fill=(250, 120, 135, 255))
    for cx in (92, 168):
        d.ellipse([r(cx - 24), r(170 - 24), r(cx + 24), r(170 + 24)], fill=(16, 26, 48, 255))
        d.ellipse([r(cx - 10), r(170 - 10), r(cx + 10), r(170 + 10)], fill=(255, 201, 60, 255))
    return img.resize((size, size), Image.LANCZOS)


def heading_font(px):
    f = ImageFont.truetype(HEAD_FONT, px)
    try:
        f.set_variation_by_axes([800])
    except Exception:
        pass
    return f


def outlined_text(canvas, xy, text, font, fill, outline, stroke):
    d = ImageDraw.Draw(canvas)
    d.text(xy, text, font=font, fill=fill, stroke_width=stroke, stroke_fill=outline, anchor="mm")


def splash():
    w, h = 1920, 1080
    W, H = w * SS, h * SS
    ys, xs = np.mgrid[0:H, 0:W].astype(np.float32)
    cx, cy = W * 0.5, H * 0.46
    # Radial glow toward the centre, exactly BG at the edges.
    ry = np.where(ys < cy, cy, H - cy)
    dist = np.hypot((xs - cx) / (W * 0.5), (ys - cy) / ry)
    glow = np.clip(1.0 - dist, 0.0, 1.0) ** 1.6
    # Soft sun rays, faded with the glow so edges stay flat BG.
    ang = np.arctan2(ys - cy, xs - cx)
    rays = (0.5 + 0.5 * np.cos(ang * 14.0)) * glow * 0.10
    base = np.array(BG, np.float32) / 255.0
    light = np.array((47, 125, 225), np.float32) / 255.0  # UITheme.SKY
    rgb = base[None, None, :] * (1 - glow[..., None]) + light[None, None, :] * glow[..., None]
    rgb = np.clip(rgb + rays[..., None] * np.array((1.0, 0.95, 0.7)), 0, 1)
    img = Image.fromarray((rgb * 255).astype(np.uint8), "RGB").convert("RGBA")

    # Kart mark with a soft shadow
    mark = kart_layer(int(H * 0.50))
    mx, my = int(cx - mark.width / 2), int(H * 0.06)
    shadow = Image.new("RGBA", img.size, (0, 0, 0, 0))
    sh = Image.new("RGBA", mark.size, (12, 37, 89, 0))
    sh.putalpha(mark.getchannel("A").point(lambda a: int(a * 0.45)))
    shadow.paste(sh, (mx + 10 * SS, my + 14 * SS), sh)
    shadow = shadow.filter(ImageFilter.GaussianBlur(10 * SS))
    img = Image.alpha_composite(img, shadow)
    img.alpha_composite(mark, (mx, my))

    # Title: yellow with an ink outline, like the in-game Title style
    title_font = heading_font(int(150 * SS))
    outlined_text(img, (cx, H * 0.66), "BAKU TURBO", title_font, (255, 210, 63, 255), (12, 37, 89, 255), int(9 * SS))
    sub_font = heading_font(int(46 * SS))
    outlined_text(img, (cx, H * 0.78), "KART  •  BAKI", sub_font, (255, 255, 255, 255), (12, 37, 89, 255), int(5 * SS))

    out = img.resize((w, h), Image.LANCZOS).convert("RGB")
    os.makedirs("assets/splash", exist_ok=True)
    out.save("assets/splash/splash.png", optimize=True)
    # Edge check: letterbox bands must match boot_splash/bg_color exactly.
    a = np.asarray(out)
    edge = np.concatenate([a[0], a[-1], a[:, 0], a[:, -1]])
    assert np.abs(edge.astype(int) - np.array(BG)).max() <= 2, "splash edges must equal BG"


def icons():
    os.makedirs("assets/icons", exist_ok=True)
    # Adaptive background: solid BG (also the Android 12 splash background).
    Image.new("RGB", (432, 432), BG).save("assets/icons/adaptive_bg_432.png")
    # Adaptive foreground: the mark inside the 66% safe zone (masks crop the rest).
    fg = Image.new("RGBA", (432, 432), (0, 0, 0, 0))
    mark = kart_layer(int(432 * 0.62))
    fg.alpha_composite(mark, ((432 - mark.width) // 2, (432 - mark.height) // 2 + 6))
    fg.save("assets/icons/adaptive_fg_432.png")
    # Legacy launcher icon: rounded square on BG with the mark.
    s = 192 * 4
    leg = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    ImageDraw.Draw(leg).rounded_rectangle([0, 0, s - 1, s - 1], radius=s * 0.22, fill=BG + (255,))
    m = kart_layer(int(s * 0.86))
    leg.alpha_composite(m, ((s - m.width) // 2, (s - m.height) // 2 + 8))
    leg.resize((192, 192), Image.LANCZOS).save("assets/icons/launcher_192.png")


if __name__ == "__main__":
    splash()
    icons()
    print("splash and launcher icons written")
