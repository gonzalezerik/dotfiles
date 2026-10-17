import io, math, os, sys, urllib.request
import numpy as np
from PIL import Image
from scipy.ndimage import gaussian_filter, map_coordinates

# usage: gen_heightmap.py WIDTH_PX HEIGHT_PX WIDTH_KM OUT.png
#   px13:    2880 2880 18.0  (6.25 m/px; square, so it fits portrait too)
#   desktop: 5120 2160 38.4  (7.5 m/px; same 9.375 m per logical px as px13)
W = int(sys.argv[1]) if len(sys.argv) > 1 else 2880
H = int(sys.argv[2]) if len(sys.argv) > 2 else 1800
Z = 14
# Yosemite Valley: El Capitan (west) to Half Dome / Tenaya Canyon (east)
CLON, CLAT = -119.575, 37.738
WIDTH_KM = float(sys.argv[3]) if len(sys.argv) > 3 else 18.0
OUT = sys.argv[4] if len(sys.argv) > 4 else "yosemite-heightmap.png"
SMOOTH_M = 18.75   # gaussian sigma in metres (= 3 px at 6.25 m/px)
CACHE = "tiles"
os.makedirs(CACHE, exist_ok=True)

km_per_deg_lon = 111.32 * math.cos(math.radians(CLAT))
dlon = WIDTH_KM / km_per_deg_lon
dlat = (WIDTH_KM * H / W) / 110.57
lon0, lon1 = CLON - dlon / 2, CLON + dlon / 2
lat0, lat1 = CLAT - dlat / 2, CLAT + dlat / 2

def lonlat_to_px(lon, lat):
    n = 2 ** Z * 256
    x = (lon + 180) / 360 * n
    y = (1 - math.asinh(math.tan(math.radians(lat))) / math.pi) / 2 * n
    return x, y

x0, y1 = lonlat_to_px(lon0, lat0)
x1, y0 = lonlat_to_px(lon1, lat1)
tx0, tx1 = int(x0 // 256), int(x1 // 256)
ty0, ty1 = int(y0 // 256), int(y1 // 256)

mosaic = np.zeros(((ty1 - ty0 + 1) * 256, (tx1 - tx0 + 1) * 256), np.float32)
for ty in range(ty0, ty1 + 1):
    for tx in range(tx0, tx1 + 1):
        path = f"{CACHE}/{Z}_{tx}_{ty}.png"
        if not os.path.exists(path):
            url = f"https://s3.amazonaws.com/elevation-tiles-prod/terrarium/{Z}/{tx}/{ty}.png"
            urllib.request.urlretrieve(url, path)
        a = np.asarray(Image.open(path).convert("RGB")).astype(np.float32)
        elev = a[..., 0] * 256 + a[..., 1] + a[..., 2] / 256 - 32768
        oy, ox = (ty - ty0) * 256, (tx - tx0) * 256
        mosaic[oy:oy + 256, ox:ox + 256] = elev

# Resample the exact frame to screen resolution (bicubic)
gy, gx = np.mgrid[0:H, 0:W].astype(np.float32)
sx = x0 + (x1 - x0) * (gx + 0.5) / W - tx0 * 256
sy = y0 + (y1 - y0) * (gy + 0.5) / H - ty0 * 256
dem = map_coordinates(mosaic, [sy, sx], order=3, mode="nearest")
m_per_px = WIDTH_KM * 1000 / W
dem = gaussian_filter(dem, sigma=SMOOTH_M / m_per_px)  # clean, flowing lines
print(f"frame lon {lon0:.4f}..{lon1:.4f} lat {lat0:.4f}..{lat1:.4f}  "
      f"elev {dem.min():.0f}..{dem.max():.0f} m  tiles {tx1-tx0+1}x{ty1-ty0+1}")

lo, hi = float(dem.min()), float(dem.max())
q = np.round((dem - lo) / (hi - lo) * 65535).astype(np.uint16)
Image.fromarray(q).save(OUT)   # 16-bit grayscale, row 0 = north
print(f"wrote {OUT}  DEM_MIN_M={lo:.4f}  DEM_RANGE_M={hi - lo:.4f}  DEM_M_PER_TEXEL={m_per_px:.4f}")
