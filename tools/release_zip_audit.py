#!/usr/bin/env python3
"""Release zip content audit: verify what users DOWNLOAD, not what master holds.

Closes the second release-staleness audit finding: the guard proves a tag and
a Release exist; nothing verified the zip users actually download. A tag can
exist with a mis-built, partially-uploaded, or wrong-commit zip, and every
prior check passed. This tool downloads the newest Release's asset and checks
its real contents:

  1. asset version -- the asset name's version equals the RELEASE it comes
     from (not header.lua: a release can legitimately ship while header.lua
     has moved on; that inconsistency is the staleness guard's verdict, not
     a corrupt zip).
  2. header version -- the zip's EaxRotations/header.lua must parse and equal
     the release version (so the zip claims the release it ships in). With
     --expect-header-version (CI), it must additionally equal that pin; when
     header.lua is AHEAD of the auto-discovered newest release the tool exits
     UNVERIFIED instead -- that state is the staleness guard's STALE verdict,
     not this audit's, and duplicating it here would double-signal one fault.
  3. entry floor -- entry count >= --min-entries (default 900): a "zip with
     3 entries" class of mis-build fails hard. Sanity floor, not a pin: the
     tracked-file count grows with every rotation addition, so any floor
     below the current count is era-correct and needs no bump per release.
  4. shape -- mirroring create_release_zip.py's own verify block: every entry
     is a file (no directory entries) ending .lua or .md. Paths keep their
     subdirectory structure with the EaxRotations/ prefix stripped
     (classes/..., header.lua) -- exactly how the builder emits them.

The release checked is --release=X.Y.Z, default: the newest published
(via `gh release list`). Without gh/network the tool exits 0 UNVERIFIED so it
can never break an unrelated gate; `--self-test` is fully offline and
deterministic (in-memory zips, no subprocess, no network) for the gates.

Usage:
    python tools/release_zip_audit.py                       # newest release
    python tools/release_zip_audit.py --release=2.25.0      # explicit
    python tools/release_zip_audit.py --expect-header-version=2.25.0
    python tools/release_zip_audit.py --self-test           # offline, gates
    python tools/release_zip_audit.py --keep                # keep the download

Exit codes:
    0 PASS / UNVERIFIED (no gh, no network, no asset-able release)
    1 FAIL (no zip asset, version mismatches, entry floor, shape)
"""
import argparse
import io
import json
import os
import re
import subprocess
import sys
import tempfile
import zipfile

HERE = os.path.dirname(os.path.abspath(__file__))
REPO_ROOT = os.path.dirname(HERE)          # tools/ -> repo root
HEADER_PATH = os.path.join(REPO_ROOT, "EaxRotations", "header.lua")
REPO = "eaxiumnet/eaxrotations"
# Same contract as tools/release_staleness_check.lua's header_version() and
# EaxRotations/tests/run_version_consistency_audit_tests.lua -- kept in sync
# by that audit's self-test; if header.lua's format ever changes, all three
# move together.
HEADER_RE = re.compile(r'plugin\s*\[\s*["\']version["\']\s*\]\s*=\s*"([\d.]+)"')
ASSET_RE = re.compile(r"^eaxrotations_v([\d.]+)\.zip$")


def header_version_from_text(text):
    m = HEADER_RE.search(text)
    return m.group(1) if m else None


def asset_version(asset_name):
    m = ASSET_RE.match(asset_name or "")
    return m.group(1) if m else None


def shape_violations(names):
    """Entries that are directories or not .lua/.md (builder contract)."""
    bad = []
    for n in names:
        base = n.rstrip("/")
        if base != n or not (base.endswith(".lua") or base.endswith(".md")):
            bad.append(n)
    return bad


def semver_key(v):
    return [int(p) for p in v.split(".")]


def gh_json(args):
    """Best-effort `gh` call: None on absence/auth/network failure (exit 0)."""
    try:
        result = subprocess.run(
            ["gh"] + args, capture_output=True, text=True, timeout=60
        )
    except (OSError, subprocess.TimeoutExpired):
        return None
    if result.returncode != 0:
        return None
    try:
        return json.loads(result.stdout)
    except (ValueError, TypeError):
        return None


def newest_release():
    releases = gh_json(["release", "list", "--repo", REPO, "--limit", "10",
                        "--json", "tagName"])
    if not releases:
        return None
    versions = []
    for rel in releases:
        m = re.match(r"^v([\d.]+)$", rel.get("tagName", ""))
        if m:
            versions.append(m.group(1))
    if not versions:
        return None
    versions.sort(key=semver_key, reverse=True)
    return versions[0]


def audit_zip(zip_bytes, release, expect_header=None, min_entries=900):
    """All content checks over zip bytes. Returns (failures, summary_info)."""
    failures = []
    with zipfile.ZipFile(io.BytesIO(zip_bytes)) as z:
        names = z.namelist()

        if len(names) < min_entries:
            failures.append(f"entry count {len(names)} < floor {min_entries}")

        bad_shape = shape_violations(names)
        if bad_shape:
            failures.append(f"{len(bad_shape)} malformed entries "
                            f"(e.g. {bad_shape[:3]})")

        header_name = None
        for candidate in ("EaxRotations/header.lua", "header.lua"):
            if candidate in names:
                header_name = candidate
        zip_version = None
        if header_name is None:
            failures.append("no header.lua in zip")
        else:
            header_text = z.read(header_name).decode("utf-8", errors="replace")
            zip_version = header_version_from_text(header_text)
            if zip_version is None:
                failures.append("header.lua in zip has no parseable version")
            elif zip_version != release:
                failures.append(f"zip header {zip_version} != release {release}")
            if expect_header and zip_version is not None \
                    and zip_version != expect_header:
                failures.append(f"zip header {zip_version} != expected "
                                f"{expect_header}")
    return failures, {"entries": len(names), "zip_version": zip_version}


def run_self_tests():
    """Offline, deterministic: synthetic in-memory zips, no network."""
    real_header = 'plugin["version"] = "2.25.0"\n'
    assert header_version_from_text(real_header) == "2.25.0"
    # Single-quoted KEY, double-quoted VALUE -- the same case the Lua guard's
    # self-test pins (header.lua itself uses double quotes for both).
    assert header_version_from_text("plugin['version'] = \"2.18.1\"") == "2.18.1"
    assert header_version_from_text('plugin["version"]  =  "2.25.0" -- x') == "2.25.0"
    assert header_version_from_text("nothing here") is None
    assert header_version_from_text("") is None

    assert asset_version("eaxrotations_v2.25.0.zip") == "2.25.0"
    assert asset_version("eaxrotations_v2.9.0.zip") == "2.9.0"
    assert asset_version("eaxrotations.zip") is None
    assert asset_version("eaxrotations_v2.25.0.tar.gz") is None
    assert asset_version(None) is None

    # Shape: clean tree passes; directory entries and debris are flagged.
    assert shape_violations(["header.lua", "classes/foo.lua", "docs/a.md"]) == []
    assert shape_violations(["classes/", "junk.txt", "readme"]) == \
        ["classes/", "junk.txt", "readme"]

    assert semver_key("2.9.0") < semver_key("2.10.0"), "numeric compare"
    assert semver_key("2.25.0") == semver_key("2.25.0")

    # End-to-end over a synthetic good zip (mirrors the builder's layout).
    buf = io.BytesIO()
    with zipfile.ZipFile(buf, "w") as z:
        entries = {"header.lua": real_header}
        entries.update({f"classes/mod_{i}.lua": "return {}" for i in range(905)})
        for name, content in entries.items():
            z.writestr(name, content)
    failures, info = audit_zip(buf.getvalue(), "2.25.0",
                               expect_header="2.25.0", min_entries=900)
    assert failures == [], f"clean synthetic zip flagged: {failures}"
    assert info["zip_version"] == "2.25.0"
    assert info["entries"] == 906

    # Same zip but header claims the wrong version -> FAIL.
    buf2 = io.BytesIO()
    with zipfile.ZipFile(buf2, "w") as z:
        z.writestr("header.lua", 'plugin["version"] = "2.24.9"\n')
        z.writestr("classes/x.lua", "return {}")
    failures, _ = audit_zip(buf2.getvalue(), "2.25.0", min_entries=1)
    assert any("2.24.9" in f for f in failures), failures

    # Mis-built zip: 3 entries -> floor fires; junk entry -> shape fires.
    buf3 = io.BytesIO()
    with zipfile.ZipFile(buf3, "w") as z:
        z.writestr("header.lua", real_header)
        z.writestr("a.lua", "x")
        z.writestr("b/", "")           # directory entry
    failures, _ = audit_zip(buf3.getvalue(), "2.25.0", min_entries=900)
    assert any("entry count 3" in f for f in failures), failures
    assert any("malformed" in f for f in failures), failures

    print("[PASS] release zip audit self-tests: header/asset extraction, "
          "shape rule (dir + non-lua/md flagged), semver ordering, and the "
          "full audit_zip path on synthetic good/wrong-version/mis-built zips")


def main():
    ap = argparse.ArgumentParser(description="Release zip content audit")
    ap.add_argument("--release", help="version to audit (default: newest published)")
    ap.add_argument("--expect-header-version",
                    help="override the header pin (default: read header.lua "
                         "from this checkout)")
    ap.add_argument("--min-entries", type=int, default=900,
                    help="minimum sane entry count (default 900; v2.25.0 ships 944)")
    ap.add_argument("--self-test", action="store_true",
                    help="offline deterministic self-tests (gates run this)")
    ap.add_argument("--keep", action="store_true", help="keep the downloaded zip")
    args = ap.parse_args()

    if args.self_test:
        run_self_tests()
        sys.exit(0)

    # Header pin: explicit flag wins, else read this checkout's header.lua
    # (create_release_zip.py's ROOT convention -- ci.yml stays a dumb run:).
    expect = args.expect_header_version
    if expect is None and os.path.exists(HEADER_PATH):
        with open(HEADER_PATH, encoding="utf-8", errors="replace") as f:
            expect = header_version_from_text(f.read())

    release = args.release or newest_release()
    if not release:
        # No gh, no network, or no releases: UNVERIFIED, exit 0 -- a gate that
        # fails on a flaky remote is a gate that gets deleted.
        print("UNVERIFIED: no published release reachable (gh/network absent?)")
        sys.exit(0)

    # Header pin ahead of the AUTO-DISCOVERED newest release is the staleness
    # guard's STALE verdict -- exit 0 here, skip the download. With an
    # explicit --release the caller opted into auditing that exact artifact,
    # so a mismatch fails for real instead.
    if expect and args.release is None \
            and semver_key(expect) > semver_key(release):
        print(f"UNVERIFIED: header.lua ({expect}) is ahead of "
              f"the newest release ({release}) -- staleness guard's STALE verdict, "
              "not this audit's; rerun after publishing")
        sys.exit(0)

    assets = gh_json(["release", "view", f"v{release}", "--repo", REPO,
                      "--json", "assets"])
    asset = None
    if assets:
        for a in assets.get("assets", []):
            if ASSET_RE.match(a.get("name", "")):
                asset = a
                break
    if asset is None:
        # A release with no zip asset is exactly the failure class this audit
        # exists for (tag pushed, release step died): FAIL, not UNVERIFIED.
        print(f"FAIL: release v{release} has no eaxrotations zip asset")
        sys.exit(1)

    asset_name = asset["name"]
    if asset_version(asset_name) != release:
        print(f"FAIL: asset {asset_name} does not match release v{release}")
        sys.exit(1)

    url = f"https://github.com/{REPO}/releases/download/v{release}/{asset_name}"
    fd, zip_path = tempfile.mkstemp(suffix=".zip")
    os.close(fd)
    try:
        rc = subprocess.run(["curl", "-sSL", "--max-time", "300", "-o", zip_path, url],
                            capture_output=True, text=True, timeout=330)
        if rc.returncode != 0:
            print("UNVERIFIED: download failed (network) -- never break a build on a blip")
            sys.exit(0)

        if os.path.getsize(zip_path) < 1_000_000:
            print(f"FAIL: downloaded artifact is {os.path.getsize(zip_path)} bytes; "
                  "a real release zip is ~20MB")
            sys.exit(1)

        with open(zip_path, "rb") as f:
            zip_bytes = f.read()
        failures, info = audit_zip(zip_bytes, release,
                                   expect_header=expect,
                                   min_entries=args.min_entries)

        if args.keep:
            kept = f"eaxrotations_v{release}.zip"
            os.replace(zip_path, kept)
            print(f"kept download as ./{kept}")

        if failures:
            for f in failures:
                print(f"FAIL: {f}")
            sys.exit(1)

        print(f"[PASS] release v{release}: {asset_name}, "
              f"{info['entries']} entries (floor {args.min_entries}), "
              f"lua/md-only shape clean, zip header == release version")
        sys.exit(0)
    finally:
        if os.path.exists(zip_path) and not args.keep:
            os.remove(zip_path)


if __name__ == "__main__":
    main()
