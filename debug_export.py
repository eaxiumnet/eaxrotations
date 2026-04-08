#!/usr/bin/env python3
"""Debug script to trace export process for EAXDruidFeral"""

import sys
import re
from pathlib import Path

ROOT = Path(".").resolve()
plugin_dir = ROOT / "EAXDruidFeral"

REQ_RE = re.compile(r"""\b(?:require|loadfile|dofile)\s*\(\s*(["'])(.+?)\1""")


def extract_refs(text):
    for m in REQ_RE.finditer(text):
        yield m.group(2)


def resolve_repo_path(ref, current_dir):
    ref = ref.replace("\\", "/")
    if ref.startswith("."):
        candidate = (current_dir / ref).resolve()
        if candidate.exists():
            return candidate
        return None

    # Attempt Lua module lookup from repo roots.
    candidates = []
    if ref.endswith(".lua"):
        candidates.append(ref)
    else:
        candidates.extend([f"{ref}.lua", f"{ref}/init.lua", ref])

    bases = [
        ROOT,
        ROOT / "eax_shared",
        ROOT / "common",
        ROOT / ".api",
        ROOT / "libraries",
    ]
    for base in bases:
        for rel in candidates:
            candidate = (base / rel).resolve()
            if candidate.exists():
                return candidate
    return None


# Read main.lua
main_file = plugin_dir / "main.lua"
text = main_file.read_text(encoding="utf-8")

print(f"Reading: {main_file}")
print(f"File size: {len(text)} characters")
print()

# Extract requires
refs = list(extract_refs(text))
print(f"Found {len(refs)} require statements:")
for ref in refs:
    print(f"  - {ref}")
print()

# Resolve each ref
current_dir = main_file.parent
for ref in refs:
    resolved = resolve_repo_path(ref, current_dir)
    if resolved:
        print(f"OK {ref} -> {resolved}")
        # Check if it's in the libraries folder
        if resolved.is_relative_to(ROOT / "libraries"):
            print(f"   -> This is a shared library!")
    else:
        print(f"MISSING {ref} -> NOT FOUND")

print()
print("Checking if ROOT/libraries/powershift.lua exists:")
p = ROOT / "libraries" / "powershift.lua"
print(f"  Path: {p}")
print(f"  Exists: {p.exists()}")
