#!/usr/bin/env python3
"""Trace export process for EAXDruidFeral"""

import sys
import re
from pathlib import Path

ROOT = Path(".").resolve()
plugin_dir = ROOT / "EAXDruidFeral"

REQ_RE = re.compile(r"""\b(?:require|loadfile|dofile)\s*\(\s*(["'])(.+?)\1""")


def read_text(path):
    return path.read_text(encoding="utf-8", errors="replace")


def extract_refs(text):
    for m in REQ_RE.finditer(text):
        yield m.group(2)


def repo_candidates():
    return [
        ROOT,
        ROOT / "eax_shared",
        ROOT / "common",
        ROOT / ".api",
        ROOT / "libraries",
    ]


def resolve_repo_path(ref, current_dir):
    ref = ref.replace("\\", "/")
    if ref.startswith("."):
        candidate = (current_dir / ref).resolve()
        if candidate.exists():
            return candidate
        return None

    # Attempt Lua module lookup from current directory first
    candidates = []
    if ref.endswith(".lua"):
        candidates.append(ref)
    else:
        candidates.extend([f"{ref}.lua", f"{ref}/init.lua", ref])

    # Check current directory first
    for rel in candidates:
        candidate = (current_dir / rel).resolve()
        if candidate.exists():
            return candidate

    # Then check repo roots
    for base in repo_candidates():
        for rel in candidates:
            candidate = (base / rel).resolve()
            if candidate.exists():
                return candidate
    return None


# Start with main.lua
queue = [plugin_dir / "main.lua"]
seen = set()
files = {}

print("Starting collection...")

while queue:
    current = queue.pop()
    current = current.resolve()
    if current in seen or not current.exists() or current.suffix.lower() != ".lua":
        continue
    seen.add(current)

    print(f"\nProcessing: {current}")

    # Determine destination
    try:
        rel = current.relative_to(plugin_dir)
        if str(rel).startswith("libraries/"):
            dst_rel = rel
        else:
            dst_rel = Path("libraries") / rel
        print(f"  -> Plugin file: {dst_rel}")
    except ValueError:
        try:
            rel = current.relative_to(ROOT / "eax_shared")
            dst_rel = Path("libraries") / "eax_shared" / rel
            print(f"  -> eax_shared file: {dst_rel}")
        except ValueError:
            try:
                rel = current.relative_to(ROOT / "common")
                dst_rel = Path("libraries") / "common" / rel
                print(f"  -> common file: {dst_rel}")
            except ValueError:
                try:
                    rel = current.relative_to(ROOT / ".api")
                    dst_rel = Path(".api") / rel
                    print(f"  -> .api file: {dst_rel}")
                except ValueError:
                    try:
                        rel = current.relative_to(ROOT / "libraries")
                        dst_rel = Path("libraries") / rel
                        print(f"  -> ROOT/libraries file: {dst_rel}")
                    except ValueError:
                        print(f"  -> SKIPPED (not in allowed paths)")
                        continue

    files[current] = dst_rel

    # Extract requires and queue dependencies
    text = read_text(current)
    current_dir = current.parent
    for ref in extract_refs(text):
        resolved = resolve_repo_path(ref, current_dir)
        if resolved and resolved.suffix.lower() == ".lua" and resolved not in seen:
            # Only include repo-local Lua deps
            if (
                resolved.is_relative_to(plugin_dir)
                or resolved.is_relative_to(ROOT / "eax_shared")
                or resolved.is_relative_to(ROOT / "common")
                or resolved.is_relative_to(ROOT / ".api")
                or resolved.is_relative_to(ROOT / "libraries")
            ):
                print(f"  + Queue: {ref} -> {resolved}")
                queue.append(resolved)
            else:
                print(f"  - Skip (not in allowed paths): {ref} -> {resolved}")

print(f"\n\nTotal files collected: {len(files)}")
print("\nShared libraries collected:")
for src, dst in files.items():
    if str(src).startswith(str(ROOT / "libraries")):
        print(f"  {src.name} -> {dst}")
