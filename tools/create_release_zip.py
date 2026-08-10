#!/usr/bin/env python3
"""Build the release artifact: eaxrotations.zip (lua + md only).

Usage:
    python tools/create_release_zip.py [output_path]

Output defaults to ./eaxrotations.zip in the current directory. The script
locates the repo root from its own file path, so it works from any cwd.
The zip is built from `git archive HEAD` (tracked files only) filtered to
.lua and .md — no zips, no .git, no build debris. Entry timestamps are
pinned (1980-01-01) so the zip is byte-reproducible. Zips are gitignored
artifacts (root `/*` ignore); never commit one.

Run from anywhere:
    python tools/create_release_zip.py /tmp/eaxrotations.zip
"""
import os
import sys
import tempfile
import subprocess
import zipfile

HERE = os.path.dirname(os.path.abspath(__file__))
REPO_ROOT = os.path.dirname(HERE)          # tools/ -> repo root
OUT = sys.argv[1] if len(sys.argv) > 1 else "eaxrotations.zip"

fd, tmp_archive = tempfile.mkstemp(suffix=".zip")
os.close(fd)
os.remove(tmp_archive)

try:
    # Stage the tracked EaxRotations/ tree from HEAD (never working-tree debris).
    result = subprocess.run(
        ["git", "-C", REPO_ROOT, "archive", "--format=zip", "-o", tmp_archive,
         "HEAD", "--", "EaxRotations/"],
        capture_output=True, text=True,
    )
    if result.returncode != 0:
        print("ERROR: git archive failed:", result.stderr.strip(), file=sys.stderr)
        if os.path.exists(OUT):
            os.remove(OUT)
        sys.exit(1)

    # Re-package: strip EaxRotations/ prefix, filter to .lua and .md only.
    with zipfile.ZipFile(tmp_archive) as zin:
        with zipfile.ZipFile(OUT, "w", zipfile.ZIP_DEFLATED) as zout:
            for item in zin.infolist():
                name = item.filename
                if not name.startswith("EaxRotations/"):
                    continue
                newname = name[len("EaxRotations/"):]
                if not newname or newname.endswith("/"):
                    continue
                if not (newname.endswith(".lua") or newname.endswith(".md")):
                    continue
                # Pin entry timestamps so the artifact is byte-reproducible
                # (metadata-only; contents identical either way).
                zout.writestr(zipfile.ZipInfo(newname, date_time=(1980, 1, 1, 0, 0, 0)), zin.read(item))
finally:
    if os.path.exists(tmp_archive):
        os.remove(tmp_archive)

# Verify
with zipfile.ZipFile(OUT) as z:
    bad = [n for n in z.namelist() if not n.endswith("/") and not
           (n.endswith(".lua") or n.endswith(".md"))]
    txt = [n for n in z.namelist() if n.endswith(".txt")]
    print(f"Entries: {len(z.namelist())}")
    print(f"Bad non-lua/md: {len(bad)}")
    print(f"Txt: {len(txt)}")
    if bad or txt:
        print("ERROR: zip contains invalid files!")
        if os.path.exists(OUT):
            os.remove(OUT)
        sys.exit(1)
    print("Zip is clean (lua + md only).")
