"""
Strip AI-generated boilerplate comment blocks from EaxRotations .lua files
and replace with concise human-written file headers.

Patterns removed:
  - "Readability notes:" / "Decision notes:" structured blocks
  - "  What:" / "  When:" / "  Why:" / "  Safety:" / "  Performance:" sub-items
  - "  Enhanced 2026-..." date stamps
  - "Production" labels
  - "@codebuff" inline markers

Patterns preserved:
  - Section headers like "--- Buff & Debuff ID tables ---"
  - Inline code comments about specific logic
  - Human-written comments that don't match AI patterns
"""

import os
import re
import sys

ROOT = "EaxRotations"

# Directories to skip
SKIP_DIRS = {"_backup", ".git", "__pycache__", "node_modules"}

# ---------------------------------------------------------------------------
# File-purpose lookup: maps filename patterns to human-readable descriptions
# ---------------------------------------------------------------------------

def classify_file(rel_path):
    """Return (category, short_desc) for a file given its relative path."""
    path_lower = rel_path.lower().replace("\\", "/")
    name = os.path.basename(path_lower)

    # Root files
    if name == "core_sylvanas.lua":
        return "core", "Core rotation engine: context builder, spell casting, state management"
    if name == "ui_sylvanas.lua":
        return "ui", "UI rendering helpers: dashboard, profile management, schema-driven menu construction"
    if name == "common_sylvanas.lua":
        return "schema", "Common schema helpers: checkbox, dropdown, slider definitions for all spec menus"
    if name == "header.lua":
        return "header", "Plugin header: metadata, load conditions, environment checks"
    if name == "main.lua":
        return "main", "Entry point: plugin initialization, load order, callback registration"
    if name == "main_sylvanas.lua":
        return "main", "Main rotation dispatcher: playstyle selection, update loop orchestration"
    if name == "load_order_sylvanas.lua":
        return "loader", "Load order configuration: dependency chain for all spec files"
    if name == "helpers_sylvanas.lua":
        return "helpers", "Shared helper functions: combat utilities, math helpers, common patterns"
    if name == "debug_log_sylvanas.lua":
        return "debug", "Debug logging: structured log output with severity levels and filtering"
    if name == "dashboard_sylvanas.lua":
        return "dashboard", "Dashboard renderer: HUD display, performance stats, cooldown tracking"
    if name == "api_probe_sylvanas.lua":
        return "api", "API probe: runtime detection of available Sylvanas API features"
    if name == "exporter.lua":
        return "exporter", "Plugin exporter: build tool that packages rotation files for distribution"
    if name == "gear_sets_sylvanas.lua":
        return "gear", "Gear set definitions: TBC BiS lists, stat weights, item database"
    if name == "optimizer.lua":
        return "optimizer", "Rotation optimizer: decision cache, performance diagnostics"
    if name == "optimizer_bridge.lua":
        return "optimizer", "Optimizer bridge: connects core engine to the optimization framework"
    if name == "sim_constants_sylvanas.lua":
        return "sim_constants", "Simulation constants: TBC stat values, caps, and scaling parameters"
    if name == "explain_helpers_sylvanas.lua":
        return "explain", "Explanation helpers: human-readable descriptions of rotation decisions"
    if name == "changelog.md" or name == "readme.md" or name == "claude.md" or name == "agents.md":
        return "skip", None

    # Test files
    if path_lower.startswith("tests/") or path_lower.startswith("tests\\"):
        # Extract what the test tests from the filename
        test_subject = name.replace("test_", "").replace("_sylvanas.lua", "").replace(".lua", "")
        return "test", f"Regression tests: {test_subject}"

    # Shared libraries
    if path_lower.startswith("shared/"):
        if name == "dot_refresh_sylvanas.lua":
            return "shared", "DoT refresh helpers: pandemic window calculations, snapshot-aware refresh logic"
        if name == "dot_refresh.lua":
            return "shared", "Pure dot_refresh module: upstream helpers with dependency injection"
        if name == "execute_phase_sylvanas.lua":
            return "shared", "Execute phase helpers: execute-range ability gating and priority management"
        if name == "execute_phase.lua":
            return "shared", "Pure execute_phase module: upstream execute helpers with dependency injection"
        if name == "buff_refresh_helper_sylvanas.lua":
            return "shared", "Buff refresh helpers: pandemic-aware buff refresh with snapshot tracking"
        if name == "interrupt_manager_sylvanas.lua":
            return "shared", "Interrupt manager: automated kick/interrupt logic with cast tracking"
        if name == "racial_manager_sylvanas.lua":
            return "shared", "Racial manager: automated racial ability usage (Berserking, Blood Fury, etc.)"
        if name == "combat_forecast_gate_sylvanas.lua":
            return "shared", "Combat forecast gate: TTD (time-to-death) prediction for cooldown gating"
        if name == "trinket_manager_sylvanas.lua":
            return "shared", "Trinket manager: automated trinket usage with TTD and priority gating"
        if name == "burst_logic_sylvanas.lua":
            return "shared", "Burst logic: coordinated burst cooldown sequencing and timing"
        if name == "ooc_manager_sylvanas.lua":
            return "shared", "Out-of-combat manager: pre-combat buffing, pull sequences, utility handling"
        if name == "swing_timer_sylvanas.lua":
            return "shared", "Swing timer: melee swing tracking for weapon-sync and seal twisting"
        if name == "force_command_sylvanas.lua":
            return "shared", "Force command: keyboard shortcut override system for manual ability forcing"
        if name == "aspect_manager_sylvanas.lua":
            return "shared", "Aspect manager: Hunter aspect switching automation"
        if name == "auto_tremor_sylvanas.lua":
            return "shared", "Auto tremor: Shaman Tremor Totem automation for fear breaking"
        if name == "purge_manager_sylvanas.lua":
            return "shared", "Purge manager: automated dispel/purge of enemy buffs"
        if name == "weapon_imbue_sylvanas.lua":
            return "shared", "Weapon imbue: automatic weapon buff application (poisons, sharpening stones, oils)"
        if name == "consumable_manager_sylvanas.lua":
            return "shared", "Consumable manager: auto-use of potions, food, elixirs, and flasks"
        if name == "talent_inference_sylvanas.lua":
            return "shared", "Talent inference: detect talent build from learned spells and ranks"
        if name == "spell_validation_sylvanas.lua":
            return "shared", "Spell validation: validate spell IDs, cooldowns, and availability"
        if name == "strategy_factory_sylvanas.lua":
            return "shared", "Strategy factory: creates priority-list strategies from declarative definitions"
        if name == "profile_manager_sylvanas.lua":
            return "shared", "Profile manager: saves/loads rotation profiles and user settings"
        if name == "gear_score_sylvanas.lua":
            return "shared", "Gear score: item level and stat-weight evaluation for gear comparison"
        if name == "combat_log_parser_sylvanas.lua":
            return "shared", "Combat log parser: CLEU-based combat log event processing"
        if name == "combat_stats_sylvanas.lua":
            return "shared", "Combat stats: DPS/HPS tracking, uptime stats, performance metrics"
        if name == "combat_replay_sylvanas.lua":
            return "shared", "Combat replay: records and replays combat sequences for debugging"
        if name == "dr_tracker_sylvanas.lua":
            return "shared", "DR tracker: diminishing returns tracking for PvP crowd control"
        if name == "enemy_cd_tracker_sylvanas.lua":
            return "shared", "Enemy CD tracker: tracks enemy cooldown usage for PvP awareness"
        if name == "pvp_burst_window_sylvanas.lua":
            return "shared", "PvP burst window: detects enemy burst cooldowns for defensive timing"
        if name == "arena_priority_sylvanas.lua":
            return "shared", "Arena priority: target selection priority for arena combat"
        if name == "notification_sylvanas.lua":
            return "shared", "Notifications: in-game notification system for cooldowns and events"
        if name == "debug_console_sylvanas.lua":
            return "shared", "Debug console: interactive Lua console for runtime debugging"
        if name == "benchmarks_sylvanas.lua":
            return "shared", "Benchmarks: performance benchmarking for rotation logic"
        if name == "dps_simulator_sylvanas.lua":
            return "shared", "DPS simulator: simulates rotation DPS for gear comparison"
        if name == "mf_tick_compute_sylvanas.lua":
            return "shared", "MF tick compute: Mind Flay channel tick calculations for clipping optimization"
        if name == "mf_tick_compute.lua":
            return "shared", "Pure mf_tick_compute module: upstream tick calculation with dependency injection"
        if name == "idle_suggestion_sylvanas.lua":
            return "shared", "Idle suggestion: suggests actions when player is idle out of combat"
        if name == "find_dead_party_ally_sylvanas.lua":
            return "shared", "Find dead ally: detects dead party members for battle rez logic"
        if name == "custom_rotation_sylvanas.lua":
            return "shared", "Custom rotation: user-defined custom rotation scripting support"
        if name == "class_loader_sylvanas.lua":
            return "shared", "Class loader: dynamically loads spec modules based on player class/spec"
        if name == "apl_parser.lua":
            return "shared", "APL parser: parses Action Priority List (APL) scripts into executable rotation"
        if name == "telemetry_sylvanas.lua":
            return "shared", "Telemetry: usage statistics and performance data collection"
        return "shared", f"Shared library: {name.replace('_sylvanas.lua', '').replace('_sylvanas', '').replace('_', ' ').title()}"

    # Class spec files
    if "/" in path_lower or "\\" in path_lower:
        parts = re.split(r"[\\/]", path_lower)
        if parts[0] == "classes" and len(parts) >= 3:
            class_name = parts[1].capitalize()
            if name == "class_sylvanas.lua":
                return "class", f"{class_name} class module: shared spell tables, class-wide constants, common definitions"
            if name == "schema_sylvanas.lua":
                return "schema", f"{class_name} menu schema: settings definitions, menu tree structure, default values"
            if name == "middleware_sylvanas.lua":
                return "middleware", f"{class_name} middleware: shared pre-rotation logic, defensive checks, utility handling"
            
            # Spec files - extract spec name from filename
            spec_name = name.replace("_sylvanas.lua", "").replace(class_name.lower(), "").replace("_", " ").strip().title()
            if not spec_name:
                spec_name = class_name
            return "spec", f"{class_name} {spec_name}: TBC rotation priority list with full combat logic"

        if parts[0] == "community_profiles" and len(parts) >= 3:
            return "profile", f"Community profile: {parts[-1].replace('.lua', '')}"

    return "generic", None


# ---------------------------------------------------------------------------
# Header cleanup logic
# ---------------------------------------------------------------------------

def is_ai_boilerplate_line(line):
    """Check if a comment line matches known AI boilerplate patterns."""
    stripped = line.strip()

    # Match: -- Readability notes: or -- Decision notes:
    if re.match(r"^--\s*Readability notes:", stripped):
        return True
    if re.match(r"^--\s*Decision notes:", stripped):
        return True

    # Match: --   What: / --   When: / --   Why: / --   Safety: / --   Performance:
    if re.match(r"^--\s{2,}(What|When|Why|Safety|Performance):", stripped):
        return True

    # Match: --   Enhanced 2026-...
    if re.match(r"^--\s{2,}Enhanced\s+20\d{2}", stripped):
        return True

    # Match: -- Production
    if re.match(r"^--\s*Production\b", stripped):
        return True

    # Match: @codebuff
    if "@codebuff" in stripped:
        return True

    return False


def find_header_block(lines):
    """
    Find the AI boilerplate block at the top of the file.
    Returns (start_line, end_line) indices (0-based) or (0, 0) if none found.
    """
    start = None
    end = 0

    # Look for the block starting with Readability notes or Decision notes
    for i, line in enumerate(lines):
        stripped = line.strip()
        # Skip empty lines
        if not stripped:
            if start is not None:
                continue  # Empty line inside block
            else:
                end = i + 1  # Track trailing empties
                continue

        # Check if this line looks like AI boilerplate
        if is_ai_boilerplate_line(stripped):
            if start is None:
                start = i
            end = i + 1
        elif stripped.startswith("--"):
            # Could be continuation of the boilerplate (indented line following)
            if start is not None and stripped.startswith("--   "):
                end = i + 1
            elif start is not None:
                # Check if this is a section header like "==== Buff & Debuff ID tables ===="
                # These should stop the boilerplate
                break
            else:
                # Some other comment before the block - stop looking
                break
        else:
            # Non-comment line - stop
            if start is not None:
                break
            # Could be code like "local NS = _G.EaxRotations"
            # Check if we've passed any boilerplate
            if i > 0:
                break
            continue

    if start is not None:
        return (start, end)
    return (0, 0)


def generate_file_header(desc, category):
    """Generate a clean 2-3 line human-written file header."""
    if not desc:
        return None

    # Short description (first sentence)
    short = desc.split(":")[0] if ":" in desc else desc.split(".")[0]

    return [
        f"-- {desc}",
        "",
    ]


def has_code_after_index(lines, idx):
    """Check if there's actual Lua code after index idx."""
    for i in range(idx, min(idx + 15, len(lines))):
        stripped = lines[i].strip()
        if stripped and not stripped.startswith("--") and not stripped == "":
            return True
    return False


def cleanup_file(filepath):
    """Process a single file: strip AI boilerplate, add clean header."""
    with open(filepath, "r", encoding="utf-8") as f:
        content = f.read()

    lines = content.split("\n")
    if not lines:
        return False

    # Remove trailing empty lines (but keep at least one)
    while lines and lines[-1] == "":
        lines.pop()
    if lines:
        lines.append("")

    # Find and remove AI boilerplate
    start, end = find_header_block(lines)
    if start == end:
        return False  # No boilerplate found

    # Extract description from the boilerplate if available
    desc = None
    for i in range(start, end):
        stripped = lines[i].strip()
        m = re.match(r"^--\s{2,}What:\s*(.+)", stripped)
        if m:
            desc = m.group(1).strip()
            # Clean up common AI patterns in the description
            desc = re.sub(r"\s*\(TBC[^)]*\)", "", desc)
            desc = re.sub(r"\s*\(tbc[^)]*\)", "", desc)
            desc = re.sub(r"\s*production\s*", "", desc, flags=re.IGNORECASE)
            desc = desc.strip()
            break

    if not desc:
        # Use classification-based description
        rel_path = os.path.relpath(filepath, ROOT)
        cat, cls_desc = classify_file(rel_path)
        if cls_desc:
            desc = cls_desc

    if not desc:
        desc = f"EaxRotations module"

    # Get category for header style
    rel_path = os.path.relpath(filepath, ROOT)
    cat, _ = classify_file(rel_path)

    # Build new header
    new_header = []
    
    if cat == "skip":
        return False

    # Build the clean header
    if cat == "spec":
        # Clean spec header with section marker
        new_header = [
            f"-- {desc}",
            "",
        ]
    elif cat == "test":
        new_header = [
            f"-- {desc}",
            "",
        ]
    elif cat == "shared":
        new_header = [
            f"-- {desc}",
            "",
        ]
    elif cat == "schema":
        new_header = [
            f"-- {desc}",
            "",
        ]
    elif cat == "middleware":
        new_header = [
            f"-- {desc}",
            "",
        ]
    elif cat == "class":
        new_header = [
            f"-- {desc}",
            "",
        ]
    elif cat == "core":
        new_header = [
            f"-- {desc}",
            "",
        ]
    elif cat == "ui":
        new_header = [
            f"-- {desc}",
            "",
        ]
    elif cat == "debug":
        new_header = [
            f"-- {desc}",
            "",
        ]
    elif cat == "dashboard":
        new_header = [
            f"-- {desc}",
            "",
        ]
    elif cat == "api":
        new_header = [
            f"-- {desc}",
            "",
        ]
    elif cat == "profile":
        new_header = [
            f"-- {desc}",
            "",
        ]
    elif cat == "gear":
        new_header = [
            f"-- {desc}",
            "",
        ]
    elif cat == "exporter":
        new_header = [
            f"-- {desc}",
            "",
        ]
    elif cat == "loader":
        new_header = [
            f"-- {desc}",
            "",
        ]
    elif cat == "main":
        new_header = [
            f"-- {desc}",
            "",
        ]
    elif cat == "helpers":
        new_header = [
            f"-- {desc}",
            "",
        ]
    elif cat == "sim_constants":
        new_header = [
            f"-- {desc}",
            "",
        ]
    elif cat == "explain":
        new_header = [
            f"-- {desc}",
            "",
        ]
    elif cat == "header":
        new_header = [
            f"-- {desc}",
            "",
        ]
    elif cat == "optimizer":
        new_header = [
            f"-- {desc}",
            "",
        ]
    else:
        new_header = [
            f"-- {desc}",
            "",
        ]

    # Build new lines: new_header + content after boilerplate
    remaining = lines[end:]
    # Strip leading empty lines from remaining
    while remaining and remaining[0] == "":
        remaining.pop(0)

    new_lines = new_header + remaining

    # Add trailing newline
    if new_lines and new_lines[-1] != "":
        new_lines.append("")

    result = "\n".join(new_lines)
    
    # Also remove any inline @codebuff markers in the remaining code
    result = result.replace("@codebuff", "")

    # Write back
    with open(filepath, "w", encoding="utf-8") as f:
        f.write(result)

    return True


def main():
    changed = 0
    errors = 0
    skipped = 0

    for root, dirs, files in os.walk(ROOT):
        # Skip backup directories
        dirs[:] = [d for d in dirs if d not in SKIP_DIRS]
        for f in files:
            if not f.endswith(".lua"):
                continue
            filepath = os.path.join(root, f)
            try:
                if cleanup_file(filepath):
                    rel_path = os.path.relpath(filepath, ROOT)
                    print(f"  Cleaned: {rel_path}")
                    changed += 1
                else:
                    skipped += 1
            except Exception as e:
                rel_path = os.path.relpath(filepath, ROOT)
                print(f"  ERROR: {rel_path}: {e}", file=sys.stderr)
                errors += 1

    print(f"\nDone: {changed} changed, {skipped} skipped, {errors} errors")


if __name__ == "__main__":
    main()
