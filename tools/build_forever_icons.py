#!/usr/bin/env python3
"""build_forever_icons.py -- BLP -> PNG sprite sheet for the datamine viewer.

WHAT:  decodes the icon BLP textures exported from the Forever beta client
        (tools-style CASC export: one <fdid>.blp per icon, see
        docs/forever/dbc_runbook.md) into a single PNG sprite sheet
        (icons.png) plus a fdid -> cell index map (icons.json) that the
        offline viewer uses via CSS background-position.
WHEN:  after a client patch + icon export; output is consumed by
        tools/build_forever_bundle.py (viewer + zip).
WHY:   item icon file ids are in Item.db2, but the pixels live in CASC BLP
        files -- this is the piece that turns ids into visible icons, fully
        offline, and works for items Wowhead does not know yet.
SAFETY: read-only against the BLP dir; writes only the two output files.
        Stdlib only (zlib for PNG). Deterministic: sorted by fdid.
        Sheet cells are downscaled by an integer factor (default 2: 64->32).

Usage:
    python tools/build_forever_icons.py --blp-dir <dir> --out-dir <pkg dir>
    python tools/build_forever_icons.py --blp-dir <dir> --out-dir <dir> --check
"""

import argparse
import json
import os
import re
import struct
import sys
import zlib

CELL = 32
COLS = 64


def read_blp(path):
    """Decode the first mip of a BLP2 icon into (w, h, RGBA bytes).

    Note on this client's variant: the 1.60 icons are BLP2 with the classic
    header layout, but the `type` field reads 1 while the payload is DXT
    block data (verified by size math: 64x64 mip = 4096 bytes = 16 bytes per
    4x4 block). Format is therefore chosen by payload size + alphaDepth:
    DXT1 (w*h/2), DXT3/DXT5 (w*h) -- palette-table BLPs and BGRA are still
    handled should a future build ship them.
    """
    with open(path, "rb") as f:
        data = f.read()
    magic = data[:4]
    if magic == b"BLP2":
        typ = struct.unpack_from("<I", data, 4)[0]
        alpha_depth = data[9]
        w, h = struct.unpack_from("<II", data, 12)
        offs = struct.unpack_from("<16I", data, 20)
        sizes = struct.unpack_from("<16I", data, 20 + 64)
        payload = data[offs[0]:offs[0] + sizes[0]]
        blocks = (w // 4) * (h // 4)
        if typ == 3:
            px = bgra_to_rgba(payload, w, h)
        elif len(payload) >= blocks * 16 and alpha_depth == 8:
            px = decode_dxt5(payload, w, h)
        elif len(payload) >= blocks * 16 and alpha_depth == 4:
            px = decode_dxt3(payload, w, h)
        elif len(payload) >= blocks * 8:
            px = decode_dxt1(payload, w, h)
        else:
            px = decode_paletted(payload, w, h, alpha_depth)
    elif magic == b"BLP1":
        compression = struct.unpack_from("<I", data, 4)[0]
        w, h = struct.unpack_from("<II", data, 12)
        offs = struct.unpack_from("<16I", data, 28)
        sizes = struct.unpack_from("<16I", data, 28 + 64)
        payload = data[offs[0]:offs[0] + sizes[0]]
        if compression == 2:
            px = decode_dxt1(payload, w, h)
        elif compression == 1:
            px = decode_paletted(payload, w, h, 1)
        else:
            raise ValueError("BLP1 compression %d unsupported" % compression)
    else:
        raise ValueError("not a BLP file")
    return w, h, px


def bgra_to_rgba(buf, w, h):
    out = bytearray(w * h * 4)
    for i in range(0, w * h * 4, 4):
        b, g, r, a = buf[i], buf[i + 1], buf[i + 2], buf[i + 3]
        out[i], out[i + 1], out[i + 2], out[i + 3] = r, g, b, a
    return bytes(out)


def _c565(v):
    r = (v >> 11) & 0x1F
    g = (v >> 5) & 0x3F
    b = v & 0x1F
    return [(r << 3) | (r >> 2), (g << 2) | (g >> 4), (b << 3) | (b >> 2)]


def _dxt_colors(buf, off):
    c0, c1 = struct.unpack_from("<HH", buf, off)
    i0, i1 = _c565(c0), _c565(c1)
    table = [i0, i1]
    if c0 > c1:
        table.append([(i0[k] * 2 + i1[k]) // 3 for k in range(3)])
        table.append([(i0[k] + 2 * i1[k]) // 3 for k in range(3)])
        alpha = 255
    else:
        table.append([(i0[k] + i1[k]) // 2 for k in range(3)])
        table.append([0, 0, 0])
        alpha = 0
    return table, alpha


def decode_dxt1(buf, w, h):
    out = bytearray(w * h * 4)
    for by in range(0, h, 4):
        for bx in range(0, w, 4):
            off = (by // 4) * (w // 4) * 8 + (bx // 4) * 8
            table, alpha = _dxt_colors(buf, off)
            bits = struct.unpack_from("<I", buf, off + 4)[0]
            for py in range(4):
                for px_ in range(4):
                    idx = (bits >> (2 * (py * 4 + px_))) & 3
                    c = table[idx]
                    a = alpha if not (idx == 3 and alpha == 0) else 0
                    o = ((by + py) * w + bx + px_) * 4
                    out[o], out[o + 1], out[o + 2], out[o + 3] = \
                        c[0], c[1], c[2], a
    return bytes(out)


def decode_dxt3(buf, w, h):
    out = bytearray(w * h * 4)
    for by in range(0, h, 4):
        for bx in range(0, w, 4):
            off = (by // 4) * (w // 4) * 16 + (bx // 4) * 16
            alpha_bits = struct.unpack_from("<Q", buf, off)[0]
            table, _ = _dxt_colors(buf, off + 8)
            bits = struct.unpack_from("<I", buf, off + 12)[0]
            for py in range(4):
                for px_ in range(4):
                    i = py * 4 + px_
                    a4 = (alpha_bits >> (4 * i)) & 0xF
                    c = table[(bits >> (2 * i)) & 3]
                    o = ((by + py) * w + bx + px_) * 4
                    out[o], out[o + 1], out[o + 2], out[o + 3] = \
                        c[0], c[1], c[2], a4 * 17
    return bytes(out)


def decode_dxt5(buf, w, h):
    out = bytearray(w * h * 4)
    for by in range(0, h, 4):
        for bx in range(0, w, 4):
            off = (by // 4) * (w // 4) * 16 + (bx // 4) * 16
            a0, a1 = buf[off], buf[off + 1]
            abits = int.from_bytes(buf[off + 2:off + 8], "little")
            if a0 > a1:
                atab = [a0, a1] + [
                    ((7 - i) * a0 + i * a1) // 7 for i in range(1, 7)]
            else:
                atab = [a0, a1] + [
                    ((5 - i) * a0 + i * a1) // 5 for i in range(1, 5)] + [0, 255]
            table, _ = _dxt_colors(buf, off + 8)
            bits = struct.unpack_from("<I", buf, off + 12)[0]
            for py in range(4):
                for px_ in range(4):
                    i = py * 4 + px_
                    ai = (abits >> (3 * i)) & 7
                    c = table[(bits >> (2 * i)) & 3]
                    o = ((by + py) * w + bx + px_) * 4
                    out[o], out[o + 1], out[o + 2], out[o + 3] = \
                        c[0], c[1], c[2], atab[ai]
    return bytes(out)


def decode_paletted(buf, w, h, alpha_depth):
    pal = []
    for i in range(256):
        b, g, r, a = buf[i * 4:i * 4 + 4]
        pal.append((r, g, b))
    idx_off = 256 * 4
    n = w * h
    indices = buf[idx_off:idx_off + n]
    alpha = bytearray([255]) * n
    if alpha_depth == 8:
        a_off = idx_off + n
        alpha = bytearray(buf[a_off:a_off + n])
    elif alpha_depth == 1:
        a_off = idx_off + n
        bits = buf[a_off:a_off + (n // 8)]
        for i in range(n):
            if not (bits[i // 8] >> (i % 8)) & 1:
                alpha[i] = 0
    out = bytearray(n * 4)
    for i in range(n):
        if indices[i] == 0 and alpha_depth == 1:
            out[i * 4 + 3] = 0
            continue
        r, g, b = pal[indices[i]]
        out[i * 4:i * 4 + 4] = bytes((r, g, b, alpha[i] if indices[i] else 0))
    return bytes(out)


def downscale(rgba, w, h, factor):
    if factor == 1:
        return rgba, w, h
    nw, nh = w // factor, h // factor
    out = bytearray(nw * nh * 4)
    f2 = factor * factor
    for y in range(nh):
        for x in range(nw):
            r = g = b = a = 0
            for dy in range(factor):
                row = (y * factor + dy) * w
                for dx in range(factor):
                    o = (row + x * factor + dx) * 4
                    r += rgba[o]
                    g += rgba[o + 1]
                    b += rgba[o + 2]
                    a += rgba[o + 3]
            o = (y * nw + x) * 4
            out[o], out[o + 1], out[o + 2], out[o + 3] = \
                r // f2, g // f2, b // f2, a // f2
    return bytes(out), nw, nh


def write_png(path, w, h, rgba):
    raw = bytearray()
    stride = w * 4
    for y in range(h):
        raw.append(0)
        raw += rgba[y * stride:(y + 1) * stride]
    def chunk(tag, payload):
        c = struct.pack(">I", len(payload)) + tag + payload
        return c + struct.pack(">I", zlib.crc32(tag + payload) & 0xFFFFFFFF)
    png = b"\x89PNG\r\n\x1a\n"
    png += chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(bytes(raw), 9))
    png += chunk(b"IEND", b"")
    with open(path, "wb") as f:
        f.write(png)


def build(blp_dir, out_dir, cell, cols, factor):
    files = []
    for name in os.listdir(blp_dir):
        m = re.fullmatch(r"(\d+)\.blp", name)
        if m:
            files.append((int(m.group(1)), os.path.join(blp_dir, name)))
    files.sort()
    if not files:
        print("ERROR: no <fdid>.blp files in %s" % blp_dir)
        return 2
    rows = (len(files) + cols - 1) // cols
    sheet = bytearray(cols * cell * rows * cell * 4)
    index = {}
    decoded = failed = 0
    for i, (fdid, path) in enumerate(files):
        try:
            w, h, px = read_blp(path)
            if w != h:
                factor = max(1, w // cell)
            px, cw, ch = downscale(px, w, h, max(1, w // cell))
            cx = (i % cols) * cell
            cy = (i // cols) * cell
            for y in range(min(ch, cell)):
                src = y * cw * 4
                dst = ((cy + y) * cols * cell + cx) * 4
                sheet[dst:dst + min(cw, cell) * 4] = \
                    px[src:src + min(cw, cell) * 4]
            index[str(fdid)] = i
            decoded += 1
        except Exception as e:
            failed += 1
            if failed <= 5:
                print("FAIL %s: %s" % (path, e))
    os.makedirs(out_dir, exist_ok=True)
    png_path = os.path.join(out_dir, "icons.png")
    json_path = os.path.join(out_dir, "icons.json")
    write_png(png_path, cols * cell, rows * cell, bytes(sheet))
    with open(json_path, "w", encoding="utf-8", newline="\n") as f:
        json.dump({"cell": cell, "cols": cols, "count": decoded,
                   "index": index}, f, separators=(",", ":"))
    print("icons: %d decoded, %d failed" % (decoded, failed))
    print("sheet: %s (%d x %d, %s bytes)" % (
        png_path, cols * cell, rows * cell,
        format(os.path.getsize(png_path), ",")))
    print("index: %s" % json_path)
    return 0


def check(out_dir, expect_min):
    png_path = os.path.join(out_dir, "icons.png")
    json_path = os.path.join(out_dir, "icons.json")
    problems = []
    for p in (png_path, json_path):
        if not os.path.exists(p):
            problems.append("missing %s" % p)
    if problems:
        print("FAIL:", problems)
        return 1
    with open(json_path, encoding="utf-8") as f:
        meta = json.load(f)
    with open(png_path, "rb") as f:
        png = f.read(33)
    w, h = struct.unpack_from(">II", png, 16)
    if meta.get("count", 0) < expect_min:
        problems.append("only %d icons indexed" % meta.get("count", 0))
    if w % meta.get("cell", 32) or h % meta.get("cell", 32):
        problems.append("sheet %dx%d not divisible by cell" % (w, h))
    if len(png) < 32 or png[:8] != b"\x89PNG\r\n\x1a\n":
        problems.append("icons.png is not a PNG")
    if not any(re.fullmatch(r"\d+", k) for k in list(meta.get("index", {}))[:5]):
        problems.append("index keys are not fdids")
    if problems:
        print("FAIL:", problems)
        return 1
    print("OK: icons (%d icons, sheet %dx%d, cell %d)" % (
        meta["count"], w, h, meta["cell"]))
    return 0


def main():
    ap = argparse.ArgumentParser(description="BLP -> PNG icon sheet")
    ap.add_argument("--blp-dir", help="dir with <fdid>.blp files")
    ap.add_argument("--out-dir", required=True)
    ap.add_argument("--cell", type=int, default=CELL)
    ap.add_argument("--cols", type=int, default=COLS)
    ap.add_argument("--check", action="store_true")
    ap.add_argument("--expect", type=int, default=3500,
                    help="minimum expected icons for --check")
    args = ap.parse_args()
    if args.check:
        sys.exit(check(args.out_dir, args.expect))
    if not args.blp_dir:
        ap.error("--blp-dir is required unless --check")
    sys.exit(build(args.blp_dir, args.out_dir, args.cell, args.cols, 2))


if __name__ == "__main__":
    main()
