#!/usr/bin/env python3
"""
Restructure EAX plugins from flat folder to:
├── main.lua
├── header.lua
└── libraries/
    └── *.lua
└── extra/
    └── *.md

Also fixes require() statements to remove eax_shared/ prefix.
"""

import os
import re
import shutil
from pathlib import Path

SCRIPTS_DIR = Path("C:/newbot/scripts")
EAX_PLUGINS = [
    "EAXApiGateSpec",
    "EAXDruidBalance",
    "EAXDruidFeral",
    "EAXDruidRestoration",
    "EAXHunterBeastMastery",
    "EAXHunterMarksmanship",
    "EAXHunterSurvival",
    "EAXMageArcane",
    "EAXMageFire",
    "EAXMageFrost",
    "EAXPaladinHoly",
    "EAXPaladinProtection",
    "EAXPaladinRetribution",
    "EAXPriestDiscipline",
    "EAXPriestHoly",
    "EAXPriestShadow",
    "EAXRogueAssassination",
    "EAXRogueCombat",
    "EAXRogueSubtlety",
    "EAXShamanElemental",
    "EAXShamanEnhancement",
    "EAXShamanRestoration",
    "EAXWarlockAffliction",
    "EAXWarlockDemonology",
    "EAXWarlockDestruction",
    "EAXWarriorArms",
    "EAXWarriorFury",
    "EAXWarriorProtection",
]

REQUIRE_PATTERN = re.compile(r"""require\s*\(?\s*['"]eax_shared/([^'"]+)['"]\s*\)?""")
PCALL_REQUIRE_PATTERN = re.compile(
    r"""pcall\s*\(\s*require\s*,\s*['"]eax_shared/([^'"]+)['"]\s*\)"""
)


def fix_requires(content):
    """Fix require statements to remove eax_shared/ prefix."""
    content = REQUIRE_PATTERN.sub(r'require("\1")', content)
    content = PCALL_REQUIRE_PATTERN.sub(r'pcall(require, "\1")', content)
    return content


def restructure_plugin(plugin_dir):
    """Restructure a single EAX plugin."""
    plugin_path = SCRIPTS_DIR / plugin_dir

    if not plugin_path.exists():
        print(f"  [SKIP] {plugin_dir} does not exist")
        return

    libraries_dir = plugin_path / "libraries"
    extra_dir = plugin_path / "extra"

    libraries_dir.mkdir(exist_ok=True)
    extra_dir.mkdir(exist_ok=True)

    files_moved = {"libraries": [], "extra": []}
    files_cleaned = []

    for item in list(plugin_path.iterdir()):
        if item.name in ("libraries", "extra", ".git"):
            continue

        if item.is_file():
            ext = item.suffix.lower()

            if ext == ".md":
                dest = extra_dir / item.name
                shutil.move(str(item), str(dest))
                files_moved["extra"].append(item.name)

            elif ext == ".lua":
                if item.name in ("main.lua", "header.lua", "plugin_info.lua"):
                    continue
                dest = libraries_dir / item.name
                shutil.move(str(item), str(dest))
                files_moved["libraries"].append(item.name)

                content = dest.read_text(encoding="utf-8", errors="ignore")
                new_content = fix_requires(content)
                if new_content != content:
                    dest.write_text(new_content, encoding="utf-8")
                    files_cleaned.append(item.name)

            elif ext == ".toc":
                print(f"  [DEL] {plugin_dir}/{item.name} - removing .toc file")
                item.unlink()

    print(f"\n{plugin_dir}:")
    if files_moved["libraries"]:
        print(f"  libraries/: {len(files_moved['libraries'])} files")
    if files_moved["extra"]:
        print(f"  extra/: {len(files_moved['extra'])} files")
    if files_cleaned:
        print(f"  Fixed requires in: {', '.join(files_cleaned)}")


def main():
    print("Restructuring EAX plugins...")
    print(f"Scripts directory: {SCRIPTS_DIR}")
    print()

    for plugin in EAX_PLUGINS:
        restructure_plugin(plugin)

    print("\nDone!")


if __name__ == "__main__":
    main()
