"""Tileable value-noise texture for the world shaders (0.11.2).

Replaces the per-pixel procedural `vnoise()` (4 hashes per call) in the road,
ground and water shaders with one mipmapped texture fetch: cheaper on phone
GPUs and no shimmer at distance (mipmaps average the noise out).

Same character as the old shader function: one lattice cell per noise unit,
smoothstep interpolation. Period 64 cells, 4 texels per cell -> 256x256 L8.
Shaders sample it as texture(yaska_noise, p / 64.0).r where vnoise(p) was used.

Usage: python tools/gen_noise.py   (writes assets/textures/noise_value.png)
"""
import os

import numpy as np
from PIL import Image

PERIOD = 64  # lattice cells per tile
RES = 4  # texels per cell
SIZE = PERIOD * RES
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "textures", "noise_value.png")


def main() -> None:
    rng = np.random.default_rng(20261031)  # fixed seed: reproducible asset
    lattice = rng.random((PERIOD, PERIOD))
    t = (np.arange(SIZE) + 0.5) / RES  # texel centre in cell units
    i0 = np.floor(t).astype(int) % PERIOD
    i1 = (i0 + 1) % PERIOD
    f = t - np.floor(t)
    u = f * f * (3.0 - 2.0 * f)  # smoothstep, as in the old vnoise()
    # rows = y, cols = x
    a = lattice[np.ix_(i0, i0)]
    b = lattice[np.ix_(i0, i1)]
    c = lattice[np.ix_(i1, i0)]
    d = lattice[np.ix_(i1, i1)]
    ux = u[None, :]
    uy = u[:, None]
    val = (a * (1 - ux) + b * ux) * (1 - uy) + (c * (1 - ux) + d * ux) * uy
    img = np.clip(np.round(val * 255.0), 0, 255).astype(np.uint8)
    Image.fromarray(img, mode="L").save(OUT, optimize=True)
    print(f"wrote {OUT} {SIZE}x{SIZE} mean={val.mean():.3f}")


if __name__ == "__main__":
    main()
