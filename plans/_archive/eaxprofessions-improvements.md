# EaxProfessions Improvements Plan

**Date:** 2026-06-25
**Scope:** Multiple high-impact enhancements to EaxProfessions gathering bot

## Improvements

### 1. Hybrid Gather Mode (Herb + Mine)
- **Why:** Most gatherers have both Herbalism and Mining. Running two separate routes is inefficient.
- **What:** Add a menu toggle `hybrid_mode` that allows the bot to target both herb and mine nodes on the same route.
- **Files:** `config.lua`, `profession_constants.lua`, `idle_state.lua`, `cast_state.lua`, `ui/menu.lua`
- **Safety:** When hybrid mode is on, both profession spells are considered. The bot picks the nearest valid node regardless of profession type.

### 2. Player Detection / Safety System
- **Why:** Enemy players nearby = risk of ganking / reporting. Critical safety feature.
- **What:** New module `safety/player_detector.lua` scans for enemy players in configurable range. If found, bot pauses (IDLE state) for a cooldown.
- **Files:** `safety/player_detector.lua` (new), `config.lua`, `idle_state.lua`, `ui/menu.lua`, `core/state.lua`
- **Safety:** Pure read-only scan, no player interaction. Configurable range (10-100yd) and cooldown.

### 3. Expanded ZONE_TRANSFORM
- **Why:** Only 8 zones supported. Missing Shadowmoon Valley, Terokkar Forest complete, Isle of Quel'Danas, and many old-world zones.
- **What:** Add 15+ missing TBC and classic zones with verified transforms.
- **Files:** `navigation/route_loader.lua`
- **Safety:** New zones are additive; existing zones unchanged.

### 4. Auto-Equip Profession Tools
- **Why:** Menu already has the checkbox but no implementation exists. Mining requires pick, skinning requires knife.
- **What:** New module `gear/tool_equipper.lua` scans bags for profession tools and equips them before gathering.
- **Files:** `gear/tool_equipper.lua` (new), `config.lua`, `approach_state.lua`, `ui/menu.lua`
- **Safety:** Only equips if tool not already equipped. Uses api_surface inventory APIs.

### 5. Node Skill-Level Gating
- **Why:** Bot wastes time attempting nodes it can't gather (skill too low), leading to fail_count escalation and zone blacklisting.
- **What:** Add approximate skill requirement tables per node name. Skip nodes that require higher skill than player has.
- **Files:** `data/skill_requirements.lua` (new), `professions/herb.lua`, `professions/mine.lua`, `idle_state.lua`
- **Safety:** Approximate data (conservative estimates). Falls back to allowing all if data missing.

### 6. Node Statistics / Yield Tracking
- **Why:** Users want to know which zones/routes are most profitable.
- **What:** Enhanced session stats tracking node type, zone, and estimated yield. New render panel in UI.
- **Files:** `data/node_statistics.lua` (new), `core/state.lua`, `loot_state.lua`, `ui/render.lua`
- **Safety:** Read-only stats, no file writes during runtime.

## Implementation Status

| # | Improvement | Status | Files |
|---|-------------|--------|-------|
| 1 | Hybrid Gather Mode | ✅ Done | `config.lua`, `ui/menu.lua`, `idle_state.lua` |
| 2 | Player Detection / Safety | ✅ Done | `safety/player_detector.lua` (new), `config.lua`, `ui/menu.lua`, `idle_state.lua`, `ui/render.lua`, `core/state.lua` |
| 3 | Expanded ZONE_TRANSFORM | ✅ Done | `navigation/route_loader.lua` — +28 zones |
| 4 | Auto-Equip Profession Tools | ✅ Done | `gear/tool_equipper.lua` (new), `approach_state.lua` |
| 5 | Node Skill-Level Gating | ✅ Done | `data/skill_requirements.lua` (new), `idle_state.lua`, `professions/herb.lua`, `professions/mine.lua` |
| 6 | Node Statistics / Yield Tracking | ✅ Done | `data/node_statistics.lua` (new), `loot_state.lua`, `ui/render.lua` |

## Tests Added
- `tests/test_skill_requirements.lua` — 7 assertions, ALL PASS
- `tests/test_node_statistics.lua` — 9 assertions, ALL PASS
- `tests/test_player_detector.lua` — 4 assertions, ALL PASS
- `tests/test_tool_equipper.lua` — 5 assertions, ALL PASS

## Test Results
- `luac -p` passes on ALL 18 modified/new files
- Full suite: **18/20 pass** (2 pre-existing failures in `test_discover_state.lua` and `test_header.lua` — unrelated to this work)

## Pre-existing Failures (not addressed)
- `test_discover_state.lua`: `_atan2` nil upvalue in `discover_state.lua:107`
- `test_header.lua`: `core` global nil in `header.lua:13`
