#!/usr/bin/env python3
"""Rewrite an ICC v2 profile's description ('desc') tag, leaving every other
tag byte-identical:  iccrename.py in.icm out.icm "New description"
"""
import struct
import sys


def desc_tag(text, old):
    """A v2 textDescriptionType with `text` (ASCII; the Unicode and Mac
    script parts are rewritten to match when the original had them)."""
    a = text.encode("ascii") + b"\0"
    _, _, n = struct.unpack(">4sII", old[:12])
    lang, ucount = struct.unpack(">II", old[12 + n:20 + n])
    u = text.encode("utf-16-be") + b"\0\0" if ucount else b""
    script = old[20 + n + 2 * ucount:]
    out = b"desc" + b"\0" * 4 + struct.pack(">I", len(a)) + a
    out += struct.pack(">II", lang, len(u) // 2) + u
    return out + (script if len(script) == 70 else b"\0" * 70)


def main(src, dst, text):
    d = open(src, "rb").read()
    count = struct.unpack(">I", d[128:132])[0]
    table = [struct.unpack(">4sII", d[132 + 12 * i:144 + 12 * i]) for i in range(count)]
    body = bytearray()
    start = 132 + 12 * count
    placed = {}  # (offset, size) -> new offset, for tags that share data
    entries = []
    for sig, off, size in table:
        data = d[off:off + size]
        if sig == b"desc":
            data = desc_tag(text, data)
            key = ("desc",)
        else:
            key = (off, size)
        if key not in placed:
            while (start + len(body)) % 4:
                body += b"\0"
            placed[key] = start + len(body)
            body += data
        entries.append((sig, placed[key], len(data)))
    head = bytearray(d[:128])
    head[0:4] = struct.pack(">I", start + len(body))
    head[84:100] = b"\0" * 16  # profile ID: unset (it was unset in the originals)
    out = bytes(head) + struct.pack(">I", count)
    out += b"".join(struct.pack(">4sII", *e) for e in entries) + bytes(body)
    open(dst, "wb").write(out)


if __name__ == "__main__":
    main(*sys.argv[1:4])
