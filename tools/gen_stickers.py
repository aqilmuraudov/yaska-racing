"""0.13.0: turns the raw renders of tools/gen_stickers.gd into stickers:
crop to the drawing, thick white die-cut border, soft drop shadow, 256 px.
Also writes the locked silhouette (<id>_locked.png).
  python tools/gen_stickers.py <raw_dir>   (writes assets/stickers/)
"""
import os
import sys

from PIL import Image, ImageFilter

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "stickers")
SIZE = 256
BORDER = 14  # px at 512


def sticker(path):
    im = Image.open(path).convert("RGBA")
    a = im.getchannel("A")
    box = a.point(lambda v: 255 if v > 8 else 0).getbbox()
    im = im.crop(box)
    pad = BORDER * 3
    canvas = Image.new("RGBA", (im.width + pad * 2, im.height + pad * 2), (0, 0, 0, 0))
    canvas.alpha_composite(im, (pad, pad))
    a = canvas.getchannel("A").point(lambda v: 255 if v > 40 else 0)
    border = a.filter(ImageFilter.MaxFilter(BORDER * 2 + 1)).filter(ImageFilter.GaussianBlur(1.2))
    white = Image.new("RGBA", canvas.size, (255, 255, 255, 0))
    white.putalpha(border)
    shadow = Image.new("RGBA", canvas.size, (20, 24, 60, 0))
    shadow.putalpha(border.filter(ImageFilter.GaussianBlur(7)).point(lambda v: int(v * 0.45)))
    out = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    out.alpha_composite(shadow, (0, 6))
    out.alpha_composite(white)
    out.alpha_composite(canvas)
    side = max(out.size)
    sq = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    sq.alpha_composite(out, ((side - out.width) // 2, (side - out.height) // 2))
    sq = sq.resize((SIZE, SIZE), Image.LANCZOS)
    locked = Image.new("RGBA", sq.size, (40, 52, 96, 0))
    locked.putalpha(sq.getchannel("A").point(lambda v: int(v * 0.85)))
    return sq, locked


def main():
    raw = sys.argv[1]
    os.makedirs(OUT, exist_ok=True)
    for f in sorted(os.listdir(raw)):
        if not f.endswith(".png"):
            continue
        s, l = sticker(os.path.join(raw, f))
        s.save(os.path.join(OUT, f), optimize=True)
        l.save(os.path.join(OUT, f.replace(".png", "_locked.png")), optimize=True)
        print("sticker", f)


if __name__ == "__main__":
    main()
