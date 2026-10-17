"""Read and write niri's per-output color profiles for the Noctalia Control Center.

niri (the HDR fork on this machine) reads `color-profile` sections from
~/.config/niri/color-profiles.kdl, which the main config includes and niri
reloads on change. This tool owns that file.

    niri-color-profile get OUTPUT
        JSON: the output's current settings plus the installed ICC profiles.
    niri-color-profile set OUTPUT --source srgb|icc|edid [--icc PATH]
                              [--hdr-icc PATH] [--intensity 0-100]
        Rewrites OUTPUT's section, keeping the other outputs' sections.
"""

import argparse
import json
import os
import re
import struct
import sys
import tempfile
from pathlib import Path

HOME = Path.home()
CONFIG = HOME / ".config/niri/color-profiles.kdl"
PROFILE_DIRS = [
    HOME / ".local/share/icc",
    HOME / ".color/icc",
    Path("/usr/share/color/icc"),
    Path("/var/lib/colord/icc"),
]
SOURCES = ("srgb", "icc", "edid")
HEADER = (
    "// Written by the Noctalia Control Center (Display > Colour profile).\n"
    "// Edits here are fine, but get overwritten when the setting changes.\n"
)
BLOCK_RE = re.compile(r'color-profile\s+"((?:[^"\\]|\\.)*)"\s*(\{.*?\n\})?', re.S)


def kdl_unescape(s):
    return s.replace('\\"', '"').replace("\\\\", "\\")


def kdl_escape(s):
    return s.replace("\\", "\\\\").replace('"', '\\"')


def icc_description(path):
    """The profile's embedded description, or None if it isn't an RGB display profile."""
    try:
        data = path.read_bytes()
    except OSError:
        return None
    if len(data) < 132 or data[36:40] != b"acsp":
        return None
    if data[12:16] != b"mntr" or data[16:20] != b"RGB ":
        return None
    (count,) = struct.unpack(">I", data[128:132])
    for i in range(min(count, 1024)):
        sig, off, size = struct.unpack(">4sII", data[132 + 12 * i:144 + 12 * i])
        if sig != b"desc":
            continue
        tag = data[off:off + size]
        if tag[:4] == b"desc":
            (n,) = struct.unpack(">I", tag[8:12])
            return tag[12:12 + n].rstrip(b"\0").decode("latin-1").strip()
        if tag[:4] == b"mluc" and len(tag) >= 28:
            n, o = struct.unpack(">II", tag[20:28])
            return tag[o:o + n].decode("utf-16-be", "replace").strip()
    return path.stem


def profiles():
    found, seen = [], set()
    for d in PROFILE_DIRS:
        if not d.is_dir():
            continue
        for p in sorted(d.iterdir()):
            if p.suffix.lower() not in (".icc", ".icm") or p.resolve() in seen:
                continue
            desc = icc_description(p)
            if desc is None:
                continue
            seen.add(p.resolve())
            found.append({"path": str(p), "name": desc or p.stem})
    return found


def read_blocks():
    """Output name -> settings dict, in file order."""
    try:
        text = CONFIG.read_text()
    except FileNotFoundError:
        return {}
    blocks = {}
    for m in BLOCK_RE.finditer(text):
        body = m.group(2) or ""
        s = {"source": "srgb", "icc": None, "hdrIcc": None, "intensity": 0}
        for key, field in (("icc", "icc"), ("hdr-icc", "hdrIcc")):
            v = re.search(r'^\s*' + key + r'\s+"((?:[^"\\]|\\.)*)"', body, re.M)
            if v:
                s[field] = kdl_unescape(v.group(1))
        v = re.search(r'^\s*source\s+"(\w+)"', body, re.M)
        if v and v.group(1) in SOURCES:
            s["source"] = v.group(1)
        v = re.search(r'^\s*sdr-color-intensity\s+([0-9.]+)', body, re.M)
        if v:
            s["intensity"] = round(float(v.group(1)))
        blocks[kdl_unescape(m.group(1))] = s
    return blocks


def render(blocks):
    out = [HEADER]
    for name, s in blocks.items():
        lines = [f'color-profile "{kdl_escape(name)}" {{', f'    source "{s["source"]}"']
        if s.get("icc"):
            lines.append(f'    icc "{kdl_escape(s["icc"])}"')
        if s.get("hdrIcc"):
            lines.append(f'    hdr-icc "{kdl_escape(s["hdrIcc"])}"')
        lines.append(f'    sdr-color-intensity {int(s.get("intensity") or 0)}')
        lines.append("}")
        out.append("\n".join(lines) + "\n")
    return "\n".join(out)


def write_atomic(text):
    CONFIG.parent.mkdir(parents=True, exist_ok=True)
    fd, tmp = tempfile.mkstemp(dir=CONFIG.parent, prefix=".color-profiles.")
    with os.fdopen(fd, "w") as f:
        f.write(text)
    os.replace(tmp, CONFIG)


def main():
    ap = argparse.ArgumentParser()
    sub = ap.add_subparsers(dest="cmd", required=True)
    g = sub.add_parser("get")
    g.add_argument("output")
    s = sub.add_parser("set")
    s.add_argument("output")
    s.add_argument("--source", choices=SOURCES, required=True)
    s.add_argument("--icc")
    s.add_argument("--hdr-icc")
    s.add_argument("--intensity", type=float, default=0)
    args = ap.parse_args()

    blocks = read_blocks()
    if args.cmd == "get":
        cur = blocks.get(args.output, {"source": "srgb", "icc": None, "hdrIcc": None, "intensity": 0})
        print(json.dumps({**cur, "profiles": profiles()}))
        return 0

    for path in (args.icc, args.hdr_icc):
        if path and icc_description(Path(path)) is None:
            print(f"not an RGB display ICC profile: {path}", file=sys.stderr)
            return 1
    blocks[args.output] = {
        "source": args.source,
        "icc": args.icc or None,
        "hdrIcc": args.hdr_icc or None,
        "intensity": max(0, min(100, round(args.intensity))),
    }
    write_atomic(render(blocks))
    return 0


if __name__ == "__main__":
    sys.exit(main())
