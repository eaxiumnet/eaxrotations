#!/usr/bin/env python3
"""Audit eax_shared Lua files against per-spec EAX* copies.

Read-only: reports exact matches, drifted copies, and missing copies.
"""

from __future__ import annotations

import hashlib
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SHARED_DIR = ROOT / "eax_shared"


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def main() -> int:
    shared_files = sorted(SHARED_DIR.glob("*.lua"))
    spec_dirs = [
        p
        for p in sorted(ROOT.iterdir())
        if p.is_dir()
        and p.name.startswith("EAX")
        and (p / "main.lua").exists()
        and any(p.glob("*.toc"))
    ]

    exact = []
    drifted = []
    missing = []

    for shared in shared_files:
        rel = shared.name
        shared_hash = sha256(shared)
        for spec_dir in spec_dirs:
            copy = spec_dir / rel
            spec_name = spec_dir.name
            if not copy.exists():
                missing.append((spec_name, rel))
                continue
            if sha256(copy) == shared_hash:
                exact.append((spec_name, rel))
            else:
                drifted.append((spec_name, rel))

    print(f"shared files: {len(shared_files)}")
    print(f"spec dirs: {len(spec_dirs)}")
    print(f"exact matches: {len(exact)}")
    print(f"drifted copies: {len(drifted)}")
    print(f"missing copies: {len(missing)}")

    if exact:
        print("exact:")
        for spec, rel in exact[:20]:
            print(f"  {spec}/{rel}")
    if drifted:
        print("drifted:")
        for spec, rel in drifted[:20]:
            print(f"  {spec}/{rel}")
    if missing:
        print("missing:")
        for spec, rel in missing[:20]:
            print(f"  {spec}/{rel}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
