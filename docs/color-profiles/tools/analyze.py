"""Gamut charts + numbers for each ICC profile (JSON from inspect.py)."""
import json
import sys

import colour
import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np
from colour.plotting import plot_chromaticity_diagram_CIE1931
from shapely.geometry import Polygon

REF = {
    "sRGB": colour.RGB_COLOURSPACES["sRGB"],
    "Display P3": colour.RGB_COLOURSPACES["Display P3"],
    "Rec.2020": colour.RGB_COLOURSPACES["ITU-R BT.2020"],
}
REF_STYLE = {"sRGB": ("#888888", ":"), "Display P3": ("#c08a3e", "--"), "Rec.2020": ("#6a6aa8", "-.")}


def xy(XYZ):
    X, Y, Z = XYZ
    return np.array([X / (X + Y + Z), Y / (X + Y + Z)])


def uv(p):
    x, y = p
    d = -2 * x + 12 * y + 3
    return np.array([4 * x / d, 9 * y / d])


def coverage(tri, ref, space=lambda p: p):
    a = Polygon([space(p) for p in tri])
    b = Polygon([space(p) for p in ref])
    return a.intersection(b).area / b.area, a.area / b.area


def eff_gamma(curve):
    if curve["type"] == "gamma":
        return curve["gamma"]
    if curve["type"] == "table":
        v = np.array(curve["values"])
        x = np.linspace(0, 1, len(v))
        g = [np.log(np.interp(t, x, v)) / np.log(t) for t in (0.2, 0.5, 0.8)]
        return [round(float(t), 3) for t in g]
    return None


def main(json_path, out_png, title):
    d = json.load(open(json_path))
    t = d["tags"]
    cols = [np.array(t[k]) for k in ("rXYZ", "gXYZ", "bXYZ")]
    wt = np.array(t["wtpt"])
    # Colorants are stored adapted to the D50 PCS. With a chad tag, undo
    # that matrix; without one (v2), the adaptation is Bradford from the
    # media white point (wtpt) to D50.
    if "chad" in t:
        inv = np.linalg.inv(np.array(t["chad"]).reshape(3, 3))
        adaptation = "chad tag"
    else:
        D50 = np.array([0.9642, 1.0, 0.8249])
        inv = colour.adaptation.matrix_chromatic_adaptation_VonKries(D50, wt, transform="Bradford")
        adaptation = "Bradford from wtpt"
    cols = [inv @ c for c in cols]
    prim = [xy(c) for c in cols]
    white = xy(sum(cols))
    res = {
        "file": d["file"],
        "description": t.get("desc"),
        "copyright": t.get("cprt"),
        "device": t.get("dmdd"),
        "date": d["header"]["date"],
        "version": d["header"]["version"],
        "primaries_xy": [[round(float(a), 4) for a in p] for p in prim],
        "white_xy": [round(float(a), 4) for a in white],
        "white_cct": round(float(colour.xy_to_CCT(white, method="McCamy 1992"))),
        "adaptation": adaptation,
        "peak_nits": t["lumi"][1] if "lumi" in t else None,
        "trc": eff_gamma(t["rTRC"]),
        "trc_type": t["rTRC"]["type"],
        "mhc2": None,
        "coverage": {},
    }
    for name, cs in REF.items():
        cov, rel = coverage(prim, cs.primaries)
        cov_uv, rel_uv = coverage(prim, cs.primaries, uv)
        res["coverage"][name] = {
            "xy_coverage": round(cov * 100, 1),
            "xy_relative_area": round(rel * 100, 1),
            "uv_coverage": round(cov_uv * 100, 1),
        }
    if "MHC2" in t:
        m = t["MHC2"]
        info = {"min_nits": m["min_nits"], "max_nits": round(m["max_nits"], 1), "lut_entries": m["entries"]}
        if "matrix" in m:
            info["matrix"] = [[round(v, 4) for v in row[:3]] for row in m["matrix"]]
        if m["luts"] and m["entries"] > 2:
            lut = np.array(m["luts"])
            ident = np.linspace(0, 1, m["entries"])
            info["lut_max_deviation"] = float(np.abs(lut - ident).max())
        res["mhc2"] = info

    fig, (ax, ax2) = plt.subplots(1, 2, figsize=(13, 6.6), gridspec_kw={"width_ratios": [1.1, 1]})
    plot_chromaticity_diagram_CIE1931(axes=ax, show=False, title=False, standalone=False)
    for name, cs in REF.items():
        p = np.vstack([cs.primaries, cs.primaries[:1]])
        c, ls = REF_STYLE[name]
        ax.plot(p[:, 0], p[:, 1], ls, color=c, lw=1.6, label=name)
    p = np.vstack(prim + prim[:1])
    ax.plot(p[:, 0], p[:, 1], "-", color="black", lw=2.2, label="This profile")
    ax.plot(p[:, 0], p[:, 1], "o", color="black", ms=5)
    ax.plot(*white, "x", color="black", ms=9, mew=2, label="White point")
    ax.set_xlim(-0.05, 0.8)
    ax.set_ylim(-0.05, 0.9)
    cov = res["coverage"]
    ax.text(0.40, 0.80, "\n".join([
        f"sRGB coverage  {cov['sRGB']['xy_coverage']:.1f}%",
        f"P3 coverage    {cov['Display P3']['xy_coverage']:.1f}%",
        f"Rec.2020 cov.  {cov['Rec.2020']['xy_coverage']:.1f}%",
        f"White {res['white_cct']} K  (x {res['white_xy'][0]:.4f}, y {res['white_xy'][1]:.4f})",
    ]), fontsize=9, family="monospace", va="top",
        bbox=dict(boxstyle="round", fc="white", ec="#999999"))
    ax.legend(loc="lower right", fontsize=9)
    ax.set_title("CIE 1931 chromaticity: gamut vs sRGB / Display P3 / Rec.2020", fontsize=10)

    # Tone response: each channel's curve, against plain gamma 2.2.
    x = np.linspace(0, 1, 512)
    ax2.plot(x, x ** 2.2, color="#bbbbbb", lw=4, label="gamma 2.2 (reference)")
    for key, c in (("rTRC", "#d04040"), ("gTRC", "#40a040"), ("bTRC", "#4060d0")):
        cv = t[key]
        if cv["type"] == "gamma":
            y = x ** cv["gamma"]
            lab = f"{key[0].upper()}: gamma {cv['gamma']:.2f}"
        elif cv["type"] == "table":
            v = np.array(cv["values"])
            y = np.interp(x, np.linspace(0, 1, len(v)), v)
            g = eff_gamma(cv)
            lab = f"{key[0].upper()}: {len(v)}-pt table, eff. gamma {g[0]:.2f}/{g[1]:.2f}/{g[2]:.2f}"
        else:
            continue
        ax2.plot(x, y, color=c, lw=1.3, label=lab)
    if res["mhc2"] and res["mhc2"]["lut_entries"] > 2:
        lut = np.array(t["MHC2"]["luts"][0])
        ax2.plot(np.linspace(0, 1, len(lut)), lut, ":", color="black", lw=1.2,
                 label=f"MHC2 regamma LUT (max dev. {res['mhc2']['lut_max_deviation']:.1e})")
    ax2.set_xlabel("input signal")
    ax2.set_ylabel("relative output luminance")
    ax2.set_xlim(0, 1)
    ax2.set_ylim(0, 1)
    ax2.grid(alpha=0.3)
    ax2.legend(loc="upper left", fontsize=8.5)
    ax2.set_title("Tone response (per channel; effective gamma at 20/50/80 %)", fontsize=10)
    fig.suptitle(title, fontsize=13)
    fig.tight_layout()
    fig.savefig(out_png, dpi=110)
    json.dump(res, sys.stdout, indent=1)


if __name__ == "__main__":
    main(*sys.argv[1:4])
