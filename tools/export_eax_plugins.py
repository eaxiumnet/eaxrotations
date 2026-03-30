#!/usr/bin/env python3
"""Export ship-ready EAX plugin packages.

Scans EAX* plugin folders under scripts/, collects Lua dependencies, rewrites a
few packaging-specific loadfile wrappers, and emits both a package directory and
zip archive for each exported plugin.
"""

from __future__ import annotations

import argparse
import os
import re
import shutil
import sys
import zipfile
from dataclasses import dataclass
from pathlib import Path
from typing import Dict, Iterable, Iterator, List, Optional, Set, Tuple


ROOT = Path(__file__).resolve().parents[1]

REQ_RE = re.compile(r"""\b(?:require|loadfile|dofile)\s*\(\s*(["'])(.+?)\1""")
EAX_SHARED_STUB_RE = re.compile(
    r"""return\s+assert\(loadfile\(\s*scripts_dir\s*\.\.\s*(["'])eax_shared/([^"']+)\1\s*\)\)\s*\(\s*\)""",
    re.M,
)


def norm_rel(p: Path) -> str:
    return p.as_posix()


def is_plugin_dir(p: Path) -> bool:
    return p.is_dir() and p.name.startswith("EAX") and (p / "main.lua").exists()


def discover_plugins(root: Path) -> List[Path]:
    return sorted([p for p in root.iterdir() if is_plugin_dir(p)], key=lambda x: x.name)


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8", errors="replace")


def repo_candidates() -> List[Path]:
    # Keep lookup narrow; do not include reference trees.
    return [ROOT, ROOT / "eax_shared", ROOT / "common", ROOT / ".api"]


def resolve_repo_path(ref: str, current_dir: Path) -> Optional[Path]:
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

    for base in repo_candidates():
        for rel in candidates:
            candidate = (base / rel).resolve()
            if candidate.exists():
                return candidate
    return None


def module_name_from_path(path: Path) -> Optional[str]:
    try:
        rel = path.resolve().relative_to(ROOT)
    except ValueError:
        return None
    parts = rel.parts
    if not parts:
        return None
    if parts[-1] == "init.lua":
        parts = parts[:-1]
    elif parts[-1].endswith(".lua"):
        parts = parts[:-1] + (parts[-1][:-4],)
    return "/".join(parts)


def extract_refs(text: str) -> Iterator[str]:
    for m in REQ_RE.finditer(text):
        yield m.group(2)


def rewrite_for_package(text: str) -> str:
    text = EAX_SHARED_STUB_RE.sub(
        lambda m: (
            f'return require("eax_shared/{m.group(2)[:-4] if m.group(2).endswith(".lua") else m.group(2)}")'
        ),
        text,
    )
    if ".api/common/modules/health_prediction.lua" in text:
        helper = (
            'local __eax_src = debug.getinfo(1, "S").source:gsub("^@", "")\n'
            'local __eax_root = __eax_src:match("^(.*[\\\\/] )libraries[\\\\/]")\n'
        )
        # Fix the helper string if needed below.
        helper = (
            'local __eax_src = debug.getinfo(1, "S").source:gsub("^@", "")\n'
            'local __eax_root = __eax_src:match("^(.*[\\\\/])libraries[\\\\/]") or (__eax_src:match("^(.*[\\\\/])") or "")\n'
        )
        text = text.replace(
            'local chunk = loadfile(".api/common/modules/health_prediction.lua")',
            helper
            + 'local chunk = loadfile(__eax_root .. ".api/common/modules/health_prediction.lua")',
        )
    return text


@dataclass
class ExportedFile:
    src: Path
    dst_rel: Path
    rewritten_text: Optional[str] = None


def collect_files(plugin_dir: Path) -> Dict[Path, ExportedFile]:
    queue: List[Path] = [plugin_dir / "main.lua"]
    seen: Set[Path] = set()
    files: Dict[Path, ExportedFile] = {}

    while queue:
        current = queue.pop()
        current = current.resolve()
        if current in seen or not current.exists() or current.suffix.lower() != ".lua":
            continue
        seen.add(current)

        try:
            rel = current.relative_to(plugin_dir)
            dst_rel = Path("libraries") / rel
        except ValueError:
            try:
                rel = current.relative_to(ROOT / "eax_shared")
                dst_rel = Path("libraries") / "eax_shared" / rel
            except ValueError:
                try:
                    rel = current.relative_to(ROOT / "common")
                    dst_rel = Path("libraries") / "common" / rel
                except ValueError:
                    try:
                        rel = current.relative_to(ROOT / ".api")
                        dst_rel = Path(".api") / rel
                    except ValueError:
                        continue

        text = read_text(current)
        files[current] = ExportedFile(
            src=current, dst_rel=dst_rel, rewritten_text=rewrite_for_package(text)
        )

        current_dir = current.parent
        for ref in extract_refs(text):
            resolved = resolve_repo_path(ref, current_dir)
            if resolved and resolved.suffix.lower() == ".lua" and resolved not in seen:
                # Only include repo-local Lua deps.
                if (
                    resolved.is_relative_to(plugin_dir)
                    or resolved.is_relative_to(ROOT / "eax_shared")
                    or resolved.is_relative_to(ROOT / "common")
                    or resolved.is_relative_to(ROOT / ".api")
                ):
                    queue.append(resolved)

    return files


def package_main_wrapper(plugin_name: str) -> str:
    return f"""-- Auto-generated package bootstrap for {plugin_name}\n+local __eax_src = debug.getinfo(1, "S").source:gsub("^@", "")\n+local __eax_root = __eax_src:match("^(.*[\\\\/])main%.lua$") or (__eax_src:match("^(.*[\\\\/])") or "")\n+local __eax_lib = __eax_root .. "libraries"\n+package.path = table.concat({{\n+    __eax_lib .. "/?.lua",\n+    __eax_lib .. "/?/init.lua",\n+    package.path,\n+}}, ";")\n+package.cpath = package.cpath\n+assert(loadfile(__eax_lib .. "/main.lua"))()\n+"""


def export_plugin(plugin_dir: Path, output_dir: Path) -> Path:
    package_dir = output_dir / plugin_dir.name
    if package_dir.exists():
        shutil.rmtree(package_dir)
    package_dir.mkdir(parents=True, exist_ok=True)

    files = collect_files(plugin_dir)

    # Root-level header.lua if present.
    header = plugin_dir / "header.lua"
    if header.exists():
        target = package_dir / "header.lua"
        target.write_text(rewrite_for_package(read_text(header)), encoding="utf-8")

    # Write collected Lua files under libraries/.
    for item in files.values():
        out = package_dir / item.dst_rel
        out.parent.mkdir(parents=True, exist_ok=True)
        out.write_text(item.rewritten_text or read_text(item.src), encoding="utf-8")

    # Ensure package main wrapper.
    (package_dir / "main.lua").write_text(
        package_main_wrapper(plugin_dir.name), encoding="utf-8"
    )

    # Copy markdown extras from plugin folder.
    for md in plugin_dir.rglob("*.md"):
        rel = md.relative_to(plugin_dir)
        target = package_dir / "extra" / rel
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(read_text(md), encoding="utf-8")

    # Copy package zip.
    zip_path = output_dir / f"{plugin_dir.name}.zip"
    if zip_path.exists():
        zip_path.unlink()
    with zipfile.ZipFile(zip_path, "w", compression=zipfile.ZIP_DEFLATED) as zf:
        for file in package_dir.rglob("*"):
            if file.is_file():
                zf.write(file, file.relative_to(package_dir).as_posix())
    return package_dir


def main(argv: Optional[List[str]] = None) -> int:
    parser = argparse.ArgumentParser(description="Export EAX plugin packages")
    parser.add_argument("--output", required=True, help="Output directory for packages")
    parser.add_argument(
        "--plugin", action="append", help="Export only one plugin (repeatable)"
    )
    args = parser.parse_args(argv)

    output_dir = Path(args.output).resolve()
    output_dir.mkdir(parents=True, exist_ok=True)

    plugins = discover_plugins(ROOT)
    if args.plugin:
        wanted = set(args.plugin)
        plugins = [p for p in plugins if p.name in wanted]

    if not plugins:
        print("No EAX plugins found.", file=sys.stderr)
        return 1

    for plugin in plugins:
        export_plugin(plugin, output_dir)
        print(f"exported {plugin.name}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
