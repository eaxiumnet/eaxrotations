#!/usr/bin/env python3
"""build_forever_models.py -- M2 model export + 3D preview pack for the
Forever datamine viewer.

WHAT:  for a chosen set of items and mounts, resolves the client model chain
        (item -> ItemModifiedAppearance -> ItemAppearance -> ItemDisplayInfo
        -> ModelResourcesID; mount -> MountXDisplay -> CreatureDisplayInfo ->
        CreatureModelData.FileDataID), exports the M2 + skin + texture files
        from CASC with tools/forever_export_cs (built binary), converts the
        geometry with the wowser-based m2_to_preview.js, decodes textures
        with build_forever_icons' BLP decoder, and writes models.js (the
        data-URI style payload pack the offline 3D viewer reads) plus
        models_index.json (the picker list).
WHEN:  after a client patch; the curated default set is a shareable demo
        (all mounts / weapons can be passed via --mounts all --items ...).
WHY:   the 3D viewer must work offline from file://: <script src=models.js>
        loads everywhere, fetch() does not. Geometry + one texture per model
        is enough for a product preview (no skeleton/animation yet).
SAFETY: read-only against the package DB and exported files; writes only
        models.js / models_index.json in the package dir and scratch files in
        the work dir. Node + the export tool are invoked as subprocesses.

Usage:
    python tools/build_forever_models.py --work-dir <dir> --mounts 6,12,17 \
        --items 19019,17182 --out-dir wowheadScrape/dbc_extract/forever_community
    python tools/build_forever_models.py --out-dir <pkg> --check
"""

import argparse
import base64
import json
import os
import sqlite3
import struct
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import build_forever_icons as icons  # BLP decoder reuse

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC_DB = os.path.join(ROOT, "wowheadScrape", "dbc_extract", "wowsims_forever.db")

CHUNK_TAGS = (b"MD21", b"SFID", b"AFID", b"BFID", b"PFID", b"TXID", b"EXPT")
TEX_MAX = 192


def arr(text):
    s = str(text or "").strip()
    if s.startswith("[") and s.endswith("]"):
        s = s[1:-1]
    return [x.strip() for x in s.split(",")] if s else []


def m2_chunks(blob):
    i, out = 0, []
    while i + 8 <= len(blob):
        tag = blob[i:i + 4]
        if tag not in CHUNK_TAGS:
            i += 1
            continue
        size = struct.unpack_from("<I", blob, i + 4)[0]
        out.append((tag, blob[i + 8:i + 8 + size]))
        i += 8 + size
    return out


def resolve_models(conn, item_ids, mount_ids):
    """Return [(model_fdid, label)] for the requested items/mounts."""
    jobs = []
    for iid in item_ids:
        row = conn.execute(
            "SELECT ItemAppearanceID FROM ItemModifiedAppearance WHERE "
            "ItemID = ? ORDER BY ItemAppearanceModifierID LIMIT 1",
            (iid,)).fetchone()
        if not row:
            print("  item %s: no appearance" % iid)
            continue
        ap = conn.execute("SELECT ItemDisplayInfoID FROM ItemAppearance "
                          "WHERE ID = ?", (row[0],)).fetchone()
        di = conn.execute("SELECT ModelResourcesID FROM ItemDisplayInfo "
                          "WHERE ID = ?", (ap[0],)).fetchone() if ap else None
        name = conn.execute("SELECT Display_lang FROM ItemSparse WHERE ID = ?",
                            (iid,)).fetchone()
        if not di:
            print("  item %s: no display info" % iid)
            continue
        res = [int(x) for x in arr(di[0]) if x.strip().isdigit() and
               int(x) > 0]
        mfd = conn.execute("SELECT FileDataID FROM ModelFileData WHERE "
                           "ModelResourcesID = ? ORDER BY FileDataID LIMIT 1",
                           (res[0],)).fetchone() if res else None
        if not mfd:
            print("  item %s: no model file" % iid)
            continue
        jobs.append((mfd[0], (name[0] if name else "item %s" % iid)))
    for mid in mount_ids:
        row = conn.execute(
            "SELECT x.CreatureDisplayInfoID FROM MountXDisplay x "
            "WHERE x.MountID = ? ORDER BY x.ID LIMIT 1", (mid,)).fetchone()
        cd = conn.execute("SELECT ModelID FROM CreatureDisplayInfo "
                          "WHERE ID = ?", (row[0],)).fetchone() if row else None
        cmd = conn.execute("SELECT FileDataID FROM CreatureModelData "
                           "WHERE ID = ?", (cd[0],)).fetchone() if cd else None
        name = conn.execute("SELECT Name_lang FROM Mount WHERE ID = ?",
                            (mid,)).fetchone()
        if not cmd:
            print("  mount %s: no model" % mid)
            continue
        jobs.append((cmd[0], (name[0] if name else "mount %s" % mid)))
    seen, out = set(), []
    for fdid, label in jobs:
        if fdid in seen:
            continue
        seen.add(fdid)
        out.append((fdid, label))
    return out


def export_files(exporter, settings, tool_dir, fdids, out_dir, names):
    os.makedirs(out_dir, exist_ok=True)
    list_path = os.path.join(out_dir, "_fdids.txt")
    with open(list_path, "w", encoding="utf-8", newline="\n") as f:
        for fdid in fdids:
            f.write("%d %s\n" % (fdid, names[fdid]))
    proc = subprocess.run(
        ["dotnet", exporter, "-s", settings, "-o", out_dir, "--fdids",
         list_path],
        cwd=tool_dir, capture_output=True, text=True, errors="replace",
        timeout=7200)
    if proc.returncode != 0:
        print("  exporter failed: %s" % proc.stdout.strip().splitlines()[-1])
        return False
    return True


def convert_model(node, script, work, m2_path, skin_path, png_path, label):
    proc = subprocess.run(
        [node, script, m2_path, skin_path, png_path or "-", label],
        capture_output=True, text=True, errors="replace", timeout=1800)
    if proc.returncode != 0:
        print("  node convert failed: %s" % proc.stderr.strip()[:200])
        return None
    return json.loads(proc.stdout)


def build(args):
    conn = sqlite3.connect(SRC_DB)
    mount_ids = []
    if args.mounts == "all":
        mount_ids = [r[0] for r in conn.execute("SELECT ID FROM Mount"
                                                " ORDER BY ID")]
    elif args.mounts:
        mount_ids = [int(x) for x in args.mounts.split(",") if x.strip()]
    items = [int(x) for x in (args.items or "").split(",") if x.strip()]
    jobs = resolve_models(conn, items, mount_ids)
    conn.close()
    print("models to build: %d" % len(jobs))

    models_dir = os.path.join(args.work_dir, "models")
    tex_dir = os.path.join(args.work_dir, "tex")
    os.makedirs(tex_dir, exist_ok=True)

    # pass 1: export the M2s
    names = {}
    for fdid, label in jobs:
        names[fdid] = "%d.m2" % fdid
    if not export_files(args.exporter, args.settings, args.tool_dir,
                        [j[0] for j in jobs], models_dir, names):
        return 2

    # pass 2: read skins + textures from the M2 chunks and export them
    extra, first_tex = {}, {}
    for fdid, label in jobs:
        path = os.path.join(models_dir, "%d.m2" % fdid)
        if not os.path.exists(path):
            continue
        with open(path, "rb") as f:
            blob = f.read()
        skins, texs = [], []
        for tag, payload in m2_chunks(blob):
            if tag == b"SFID":
                skins += [struct.unpack_from("<I", payload, i)[0]
                          for i in range(0, len(payload) - 3, 4)]
            if tag == b"TXID":
                texs += [struct.unpack_from("<I", payload, i)[0]
                         for i in range(0, len(payload) - 3, 4)]
        texs = [t for t in texs if t]
        if skins:
            extra[skins[0]] = "%d.skin" % skins[0]
            first_tex[fdid] = (skins[0], texs)
        for t in texs:
            extra.setdefault(t, "%d.blp" % t)
    if extra:
        if not export_files(args.exporter, args.settings, args.tool_dir,
                            sorted(extra), models_dir, extra):
            return 2

    # pass 3: decode textures + geometry, assemble entries
    entries, index = {}, []
    for fdid, label in jobs:
        if fdid not in first_tex:
            print("  skip %s (no skin)" % label)
            continue
        skin_fdid, texs = first_tex[fdid]
        png_path = None
        for t in texs:
            blp_path = os.path.join(models_dir, "%d.blp" % t)
            if not os.path.exists(blp_path):
                continue
            try:
                w, h, px = icons.read_blp(blp_path)
                factor = max(1, max(w, h) // args.tex_max)
                px, cw, ch = icons.downscale(px, w, h, factor)
                png_path = os.path.join(tex_dir, "%d.png" % fdid)
                icons.write_png(png_path, cw, ch, px)
                break
            except Exception as e:
                print("  texture %d failed: %s" % (t, e))
        entry = convert_model(args.node, args.node_script, args.work_dir,
                              os.path.join(models_dir, "%d.m2" % fdid),
                              os.path.join(models_dir, "%d.skin" % skin_fdid),
                              png_path, label)
        if not entry:
            continue
        entry["fdid"] = fdid
        entries[str(fdid)] = entry
        index.append({"fdid": fdid, "name": label, "verts": entry["vcount"],
                      "tris": entry["tri"], "tex": bool(entry.get("tex"))})
        print("  built %-28s %5d verts %5d tris tex=%s" % (
            label[:28], entry["vcount"], entry["tri"], bool(entry.get("tex"))))

    payload = ("window.MODELS = "
               + json.dumps(entries, separators=(",", ":"))
               + ";\nwindow.MODELS_INDEX = "
               + json.dumps(index, separators=(",", ":")) + ";\n")
    with open(os.path.join(args.out_dir, "models.js"), "w", encoding="utf-8",
              newline="\n") as f:
        f.write(payload)
    with open(os.path.join(args.out_dir, "models_index.json"), "w",
              encoding="utf-8", newline="\n") as f:
        json.dump(index, f, indent=1)
    size = os.path.getsize(os.path.join(args.out_dir, "models.js"))
    print("models.js: %d models, %s bytes" % (len(entries), format(size, ",")))
    return check(args.out_dir, 1)


def check(out_dir, expect_min):
    problems = []
    js_path = os.path.join(out_dir, "models.js")
    idx_path = os.path.join(out_dir, "models_index.json")
    for p in (js_path, idx_path):
        if not os.path.exists(p):
            problems.append("missing %s" % p)
    if problems:
        print("FAIL:", problems)
        return 1
    with open(js_path, encoding="utf-8") as f:
        text = f.read()
    with open(idx_path, encoding="utf-8") as f:
        index = json.load(f)
    if not text.startswith("window.MODELS = "):
        problems.append("models.js does not start with window.MODELS")
    blob = text[len("window.MODELS = "):].strip()
    decoder = json.JSONDecoder()
    try:
        models, end = decoder.raw_decode(blob)
    except ValueError as e:
        problems.append("models.js payload is not JSON: %s" % e)
        models = {}
    if "window.MODELS_INDEX = " in blob:
        idx_blob = blob.split("window.MODELS_INDEX = ", 1)[1].strip()
        try:
            index_payload, _ = decoder.raw_decode(idx_blob)
            index = index_payload
        except ValueError as e:
            problems.append("models.js index is not JSON: %s" % e)
    if len(models) < expect_min:
        problems.append("only %d models" % len(models))
    for fdid, m in list(models.items())[:3]:
        if not m.get("verts") or not m.get("idx"):
            problems.append("model %s lacks geometry" % fdid)
    if len(index) != len(models):
        problems.append("index/models mismatch: %d vs %d" % (len(index),
                                                             len(models)))
    if problems:
        print("FAIL:", problems)
        return 1
    tri = sum(m["tris"] for m in index)
    print("OK: 3D models (%d models, %d triangles, %s bytes)"
          % (len(models), tri, format(os.path.getsize(js_path), ",")))
    return 0


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--work-dir", default=r"C:\Users\Support\AppData\Local\Temp\opencode\forever-models")
    ap.add_argument("--out-dir", default=os.path.join(
        ROOT, "wowheadScrape", "dbc_extract", "forever_community"))
    ap.add_argument("--mounts", default="6,12,17,19",
                    help="comma list of mount ids, or 'all'")
    ap.add_argument("--items", default="19019,17182,22691,19364",
                    help="comma list of item ids")
    ap.add_argument("--tex-max", type=int, default=TEX_MAX)
    ap.add_argument("--exporter", default=r"C:\Users\Support\AppData\Local\Temp\opencode\db2-export\bin\Release\net9.0\ExportTool.dll")
    ap.add_argument("--settings", default="appsettings.forever_world.json")
    ap.add_argument("--tool-dir", default=r"C:\Users\Support\AppData\Local\Temp\opencode\db2-forever")
    ap.add_argument("--node", default="node")
    ap.add_argument("--node-script", default=r"C:\Users\Support\AppData\Local\Temp\opencode\m2conv\m2_to_preview.js")
    ap.add_argument("--check", action="store_true")
    args = ap.parse_args()
    if args.check:
        sys.exit(check(args.out_dir, 1))
    sys.exit(build(args))


if __name__ == "__main__":
    main()
