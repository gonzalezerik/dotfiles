"""Yosemite Valley topo wallpaper, rendered once at build time to a plain PNG.

Draws anti-aliased contour lines from a 16-bit heightmap (AWS Terrain Tiles /
USGS 3DEP, made by gen_heightmap.py) at the panel's native resolution: one
heightmap texel per physical pixel, 9.375 m per logical pixel on every
machine.

Usage: render.py <heightmap.png> <out.png> <LINE_MINOR hex> <LINE_MAJOR hex>
                 <DEM_MIN_M> <DEM_RANGE_M>
(DEM_MIN_M / DEM_RANGE_M are what gen_heightmap.py printed for that heightmap.)
"""
import sys

import numpy as np
from PIL import Image

GROUND = np.array([0x00, 0x00, 0x00]) / 255.0       # pitch black
INTERVAL_M = 20.0     # metres between contour lines
MAJOR_EVERY = 5.0     # every 5th line (100 m) is an index line
MINOR_PX = 1.25       # line widths in physical pixels
MAJOR_PX = 1.8


def rgb(hexstr):
    hexstr = hexstr.lstrip("#")
    return np.array([int(hexstr[i:i + 2], 16) for i in (0, 2, 4)]) / 255.0


def smoothstep(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def contour(h, slope, interval, width_px):
    spacing = interval / np.maximum(slope, 1e-4)        # px between neighbouring lines
    v = h / interval + 0.5
    dist = np.abs(v - np.floor(v) - 0.5) * spacing
    line = np.clip(0.5 * width_px + 0.5 - dist, 0.0, 1.0)
    average = np.minimum(1.0, width_px / spacing)       # lines packed tighter than pixels
    a = smoothstep(3.0, 1.2, spacing)
    return line * (1.0 - a) + average * a


def main(src, dst, line_minor, line_major, dem_min_m, dem_range_m):
    line_minor, line_major = rgb(line_minor), rgb(line_major)
    raw = np.asarray(Image.open(src), dtype=np.float64)
    h = float(dem_min_m) + raw / 65535.0 * float(dem_range_m)
    hx = np.concatenate([h[:, 1:], h[:, -1:]], axis=1)  # edge-clamped neighbours
    hy = np.concatenate([h[1:, :], h[-1:, :]], axis=0)
    slope = np.hypot(hx - h, hy - h)                    # metres per pixel

    minor = contour(h, slope, INTERVAL_M, MINOR_PX)[..., None]
    major = contour(h, slope, INTERVAL_M * MAJOR_EVERY, MAJOR_PX)[..., None]
    col = GROUND * (1.0 - minor) + line_minor * minor
    col = col * (1.0 - major) + line_major * major

    out = np.clip(np.rint(col * 255.0), 0, 255).astype(np.uint8)
    Image.fromarray(out, "RGB").save(dst, optimize=True)


if __name__ == "__main__":
    main(*sys.argv[1:7])
