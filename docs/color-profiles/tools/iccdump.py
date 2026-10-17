"""Dump an ICC profile's header and tags (text, XYZ, curves, MHC2) as JSON."""
import json
import struct
import sys


def s15(b):
    return struct.unpack(">i", b)[0] / 65536.0


def parse_text(data):
    t = data[:4]
    if t == b"desc":
        n = struct.unpack(">I", data[8:12])[0]
        return data[12:12 + n].split(b"\0")[0].decode("latin-1")
    if t == b"mluc":
        count, size = struct.unpack(">II", data[8:16])
        out = []
        for i in range(count):
            lang, country, ln, off = struct.unpack(">2s2sII", data[16 + i * size:16 + i * size + 12])
            out.append(data[off:off + ln].decode("utf-16-be"))
        return out[0] if len(out) == 1 else out
    if t == b"text":
        return data[8:].split(b"\0")[0].decode("latin-1")
    return None


def parse_curve(data):
    t = data[:4]
    if t == b"curv":
        n = struct.unpack(">I", data[8:12])[0]
        if n == 0:
            return {"type": "identity"}
        if n == 1:
            return {"type": "gamma", "gamma": struct.unpack(">H", data[12:14])[0] / 256.0}
        vals = struct.unpack(">%dH" % n, data[12:12 + 2 * n])
        return {"type": "table", "n": n, "values": [v / 65535.0 for v in vals]}
    if t == b"para":
        fn = struct.unpack(">H", data[8:10])[0]
        k = [1, 3, 4, 5, 7][fn]
        params = [s15(data[12 + 4 * i:16 + 4 * i]) for i in range(k)]
        return {"type": "parametric", "function": fn, "params": params}
    return {"type": t.decode("latin-1")}


def parse_mhc2(data):
    # Microsoft MHC2: min/max luminance, a 3x4 matrix and per-channel regamma LUTs.
    n, min_lum, max_lum, moff, r0, r1, r2 = struct.unpack(">IiiIIII", data[8:36])
    out = {"entries": n, "min_nits": min_lum / 65536.0, "max_nits": max_lum / 65536.0}
    if moff:
        m = [s15(data[moff + 4 * i:moff + 4 * i + 4]) for i in range(12)]
        out["matrix"] = [m[0:4], m[4:8], m[8:12]]
    luts = []
    for off in (r0, r1, r2):
        if not off:
            continue
        cnt = struct.unpack(">I", data[off + 4:off + 8])[0] if data[off:off + 4] == b"sf32" else n
        body = data[off + 8:off + 8 + 4 * n]
        luts.append([s15(body[4 * i:4 * i + 4]) for i in range(n)])
    out["luts"] = luts
    return out


def main(path):
    b = open(path, "rb").read()
    hdr = {
        "size": struct.unpack(">I", b[0:4])[0],
        "cmm": b[4:8].decode("latin-1"),
        "version": "%d.%d" % (b[8], b[9] >> 4),
        "class": b[12:16].decode("latin-1"),
        "colorspace": b[16:20].decode("latin-1"),
        "pcs": b[20:24].decode("latin-1"),
        "date": "%04d-%02d-%02d" % struct.unpack(">HHH", b[24:30]),
        "manufacturer": b[48:52].decode("latin-1"),
        "model": b[52:56].hex(),
        "creator": b[80:84].decode("latin-1"),
    }
    count = struct.unpack(">I", b[128:132])[0]
    tags = {}
    for i in range(count):
        sig, off, size = struct.unpack(">4sII", b[132 + 12 * i:144 + 12 * i])
        sig = sig.decode("latin-1")
        data = b[off:off + size]
        typ = data[:4]
        if typ in (b"desc", b"mluc", b"text"):
            tags[sig] = parse_text(data)
        elif typ == b"XYZ ":
            tags[sig] = [s15(data[8 + 4 * j:12 + 4 * j]) for j in range(3)]
        elif typ == b"sf32":
            tags[sig] = [s15(data[8 + 4 * j:12 + 4 * j]) for j in range((size - 8) // 4)]
        elif typ in (b"curv", b"para"):
            tags[sig] = parse_curve(data)
        elif sig == "MHC2":
            tags[sig] = parse_mhc2(data)
        else:
            tags[sig] = {"type": typ.decode("latin-1"), "size": size}
    json.dump({"file": path.rsplit("/", 1)[-1], "header": hdr, "tags": tags}, sys.stdout)


if __name__ == "__main__":
    main(sys.argv[1])
