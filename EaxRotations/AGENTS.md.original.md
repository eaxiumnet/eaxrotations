# EaxRotations Knowledge Base

**Generated:** 2026-05-21 | **Version:** 2.0.0-Tier4 | **Files:** ~273 Lua (~72K lines) | **Tests:** 106 passing

---

## Scope

- Applies to everything under `EaxRotations/`.
- Inside this subtree, only `.md` and `.lua` files belong here.
- `api/` is runtime-owned and read-only. Never edit it from Eax work.
- This knowledge base covers Tier 2, 3, and 4 features in addition to core architecture.

---

## What This Project Is

- TBC rotation system built on native Project Sylvanas `api/`.
- Public-source identity and customer-facing brand: EaxRotations / Eax.
- 9 classes, ~29 playstyle strategies across `classes/`.
- **Tier 2-4 additions:** 15 new shared modules for PvP, profiles, metrics, and optimization.

---

## Hard Rules

- Use `NS.*` and `NS.GetAPIModule()` for Project Sylvanas API access.
- Keep class/spec modules behind the `NS.*` boundary.
- Keep TBC correctness. Do not add spells or semantics outside the TBC scope.
- Use `NS.time_now()` for timing and `NS.get_active_playstyle()` for playstyle resolution.
- Read settings from `context.settings`; do not capture live settings at load time.
- Do not add unrelated project names, links, or branding to public source.
- Customer-facing windows, menu labels, logs, plugin metadata, and export metadata must use EaxRotations or Eax branding.
- All new modules must include readability notes (What, When, Why, Safety, Decision notes).

---

## Entry Flow

- `header.lua` validates environment and class.
- `main.lua` is the bootstrap entry.
- `load_order_sylvanas.lua` is the canonical load-order map.
- `main_sylvanas.lua` is the live dispatcher and must load last.
- `core_sylvanas.lua` is the runtime boundary over `api/`.

---

## Tier 2-4 Module Architecture

### Tier 2 - PvP Foundation and Rotation Infrastructure

| Module | File | Purpose | Dependencies |
|--------|------|---------|--------------|
| DR Tracker | `shared/dr_tracker_sylvanas.lua` | Diminishing Returns tracking per target/category | NS.register_on_spell_cast |
| Enemy CD Tracker | `shared/enemy_cd_tracker_sylvanas.lua` | Enemy cooldown monitoring | NS.register_on_spell_cast |
| Arena Priority | `shared/arena_priority_sylvanas.lua` | Arena target priority scoring | NS.GetEnemiesInRange |
| PvP Burst Window | `shared/pvp_burst_window_sylvanas.lua` | Burst phase detection | Context.should_burst |
| Strategy Factory | `shared/strategy_factory_sylvanas.lua` | Strategy creation factory | NS.try_cast |
| Custom Rotation | `shared/custom_rotation_sylvanas.lua` | User-defined rotations | Strategy Factory |

**Tier 2 Class Middleware Updates:**
| Class | Middleware File | New Features |
|-------|-----------------|--------------|
| Hunter | `classes/hunter/middleware_sylvanas.lua` | Misdirection on focus target |
| Rogue | `classes/rogue/middleware_sylvanas.lua` | Emergency toolkit (Evasion, Cloak, Vanish, Thistle Tea) |
| Priest | `classes/priest/middleware_sylvanas.lua` | Party dispel, Abolish Disease, Shadowfiend, Enhanced Fade |
| Warrior | `classes/warrior/middleware_sylvanas.lua` | Spell Reflection, Cancel External Buff, PvP Defensive Stance |
| Shaman | `classes/shaman/schema_sylvanas.lua` | Purge/self-dispel settings |

### Tier 3 - Settings Profiles and Metrics

| Module | File | Purpose | Dependencies |
|--------|------|---------|--------------|
| Profile Manager | `shared/profile_manager_sylvanas.lua` | Per-character setting profiles | NS.core.read_data_file/write_data_file |
| Combat Stats | `shared/combat_stats_sylvanas.lua` | APM, downtime, DoT uptime | NS.register_on_combat_start/end |
| Gear Score | `shared/gear_score_sylvanas.lua` | Equipment quality scoring | NS.get_equipped_item_id |
| Swing Timer | `shared/swing_timer_sylvanas.lua` | Weapon swing tracking | core.time |
| Weapon Imbue | `shared/weapon_imbue_sylvanas.lua` | Weapon buff management | API probe for weapon enchant info |

### Tier 4 - UX and Optimization

| Module | File | Purpose | Dependencies |
|--------|------|---------|--------------|
| Spell Validation | `shared/spell_validation_sylvanas.lua` | Pre-cast validation | NS.is_spell_learned |
| Talent Inference | `shared/talent_inference_sylvanas.lua` | Talent build detection | NS.is_spell_learned |
| Idle Suggestion | `shared/idle_suggestion_sylvanas.lua` | OOC recommendations | OOC Manager |
| Benchmarks | `shared/benchmarks_sylvanas.lua` | Performance benchmarking | NS.time_now |

---

## New Tier 2-4 APIs

### NS.GetFocus()
Returns the current focus target unit object.

**Implementation:** `core_sylvanas.lua:258-275`
- Tries `core.input.get_focus()` first (documented API)
- Falls back to player:get_focus()
- Falls back to core.object_manager.get_focus_target()
- Falls back to IZI helper

### NS.GetPartyMembers()
Returns table of party member unit objects.

**Implementation:** `core_sylvanas.lua:277-312`
- Tries core.object_manager.get_party_members
- Falls back to player:get_party_members_in_range(100, true)
- Falls back to visible units scan with is_party_member check

### NS.register_on_combat_start(callback)
Registers callback for combat start detection.

**Implementation:** `core_sylvanas.lua:502-527`
- Manual detection via context.in_combat transition
- Fires callbacks in main_sylvanas.lua dispatcher

### NS.register_on_combat_end(callback)
Registers callback for combat end detection.

**Implementation:** Same as above, tracks was_in_combat state.

---

## Structural Sync Rules

- Keep runtime-facing file roles aligned with `load_order_sylvanas.lua`; if load order or module tiers change, update that file first.
- Keep supported-class changes aligned with `header.lua`; if a class is added, renamed, or removed, update its validation and class-name mapping there.
- When docs and live code disagree, prefer current code plus `load_order_sylvanas.lua`, then update the stale doc.
- **Tier 2-4 modules must be registered in `load_order_sylvanas.lua` to load.**

---

## Where To Look

### Core Files
| Task | File | Notes |
|------|------|-------|
| Load order and module tiers | `load_order_sylvanas.lua` | First source of truth for file roles |
| Runtime boundary and shared API | `core_sylvanas.lua` | `NS.*`, registry, wrappers, helpers (~2,300 lines) |
| Dispatcher / context | `main_sylvanas.lua` | Middleware, playstyle dispatch, per-tick flow, combat detection |
| Bootstrap / menu sync | `main.lua` | Loads class module and schema UI |
| Shared helper aliases | `helpers_sylvanas.lua` | `NS.import_helpers()` |
| Sim-derived mechanics | `sim_constants_sylvanas.lua` | Re-extract from sim, do not hand-tune |

### Tier 2-4 Shared Modules
| Task | File | Notes |
|------|------|-------|
| DR tracking | `shared/dr_tracker_sylvanas.lua` | TBC DR categories, 18s reset timer |
| Enemy cooldowns | `shared/enemy_cd_tracker_sylvanas.lua` | Tracks observed enemy casts |
| Arena priority | `shared/arena_priority_sylvanas.lua` | Score-based target selection |
| Burst detection | `shared/pvp_burst_window_sylvanas.lua` | Bloodlust/Drums detection |
| Strategy factory | `shared/strategy_factory_sylvanas.lua` | Consistent strategy creation API |
| Custom rotations | `shared/custom_rotation_sylvanas.lua` | User-defined strategy sets |
| Profile management | `shared/profile_manager_sylvanas.lua` | Save/load setting profiles |
| Combat statistics | `shared/combat_stats_sylvanas.lua` | APM, DoT uptime, cooldown usage |
| Gear scoring | `shared/gear_score_sylvanas.lua` | Equipment quality estimation |
| Swing timer | `shared/swing_timer_sylvanas.lua` | Auto-attack timing |
| Weapon imbues | `shared/weapon_imbue_sylvanas.lua` | Weapon buff management |
| Spell validation | `shared/spell_validation_sylvanas.lua` | Pre-cast checks |
| Talent inference | `shared/talent_inference_sylvanas.lua` | Build detection from spells |
| Idle suggestions | `shared/idle_suggestion_sylvanas.lua` | OOC recommendations |
| Benchmarks | `shared/benchmarks_sylvanas.lua` | Performance metrics |

### Per-Class Logic
| Task | File / Dir | Notes |
|------|------------|-------|
| Per-class logic | `classes/` | Schema, class, middleware, spec files |
| Pure cross-class helpers | `shared/` | Testable extracted logic |
| Standalone tests | `tests/` | Lua harnesses using real production code |
| Architecture docs | `docs/` | Current docs only |
| Schema section factories | `common_sylvanas.lua` | Shared UI sections used by all class schemas |
| Settings / persistence | `main.lua`, `core_sylvanas.lua` | Schema sync plus `NS.get_setting` / `NS.set_setting` |
| Dashboard / HUD | `dashboard_sylvanas.lua` | In-game display overlay |
| Damage meter | `damage_meter_sylvanas.lua` | DPS/HPS tracking |
| Debug logging | `debug_log_sylvanas.lua` | Conditional debug output |
| API probe | `api_probe_sylvanas.lua` | API availability diagnostics |
| Exporter | `exporter.lua` | Rotation export to JSON for sim optimizer |
| Optimizer bridge | `optimizer_bridge.lua`, `optimizer.lua` | Go simulator integration |
| UI framework | `ui_sylvanas.lua` | Menu and widget helpers |

---

## Project-Specific Conventions

- `_sylvanas.lua` marks the Project Sylvanas edition.
- Prefer pre-allocated tables in hot paths; avoid per-frame `{}` churn.
- Shared extracted helpers should stay pure when possible.
- Keep comments honest about TBC semantics. No "Pandemic" wording for TBC DoT logic.
- **New for Tier 2-4:** All files must include readability notes header with What/When/Why/Safety/Decision notes.

---

## Documentation Policy

- Update existing docs before adding new ones.
- `docs/` contains current project-facing docs only; consult `docs/AGENTS.md` before editing there.
- Do not recreate removed review/handover Markdown unless it becomes an active project artifact again.
- **Keep README.md, AGENTS.md, and CLAUDE.md in sync** with code changes.

---

## Child Boundaries

- `classes/AGENTS.md` explains the class-folder contract and exceptions.
- `shared/AGENTS.md` explains pure helper rules.
- `tests/AGENTS.md` explains standalone Lua test conventions.
- `docs/AGENTS.md` explains the docs policy.

---

## Tier 2-4 Integration Notes

### CombatStats Integration
CombatStats requires combat start/end detection. The dispatcher in `main_sylvanas.lua` now:
1. Tracks `was_in_combat` state
2. Detects transitions: false→true (start), true→false (end)
3. Fires `NS._fire_combat_start/end` callbacks
4. Calls `CombatStats.on_update()` during combat

### Profile Manager Integration
Profile Manager uses `NS.core.read_data_file` and `NS.core.write_data_file` for persistence. Profiles are stored per-character in JSON format.

### Strategy Factory Pattern
All Tier 2-4 strategy creation should use `NS.StrategyFactory` for consistency:
```lua
local strategy = NS.StrategyFactory.create_combat_spell(spell_id, {
    setting_key = "use_spell_name",
    label = "[Class] Spell Name",
})
```

### Talent Inference
Talent inference works by checking if signature spells are learned. Example:
```lua
local has_mortal_strike = NS.TalentInference.has_talent("warrior", "mortal_strike")
```

### DR Tracker Usage
DR Tracker automatically registers on spell cast callback. Manual usage:
```lua
local multiplier = NS.DRTracker.get_dr_multiplier(target, "stun")
-- Returns: 1.0, 0.5, 0.25, or 0.0 (immune)
```

---

## Testing Tier 2-4 Features

Each Tier 2-4 module should have corresponding regression tests:
- `test_dr_tracker.lua` - DR state transitions
- `test_profile_manager.lua` - Profile save/load
- `test_talent_inference.lua` - Talent detection accuracy
- `test_combat_stats.lua` - APM calculation, DoT uptime

Test files should use mocks for NS.* dependencies when running outside game client.

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 2.0.0-Tier4 | 2026-05-11 | Tier 4 complete: Spell validation, talent inference, idle suggestions, benchmarks |
| 1.3.0-Tier3 | 2026-04-XX | Tier 3 complete: Profiles, combat stats, gear score, swing timer, weapon imbues |
| 1.2.0-Tier2 | 2026-04-XX | Tier 2 complete: DR tracking, enemy CDs, arena priority, burst windows, strategy factory |
| 1.1.0 | 2026-04-XX | Middleware framework, unified dispatcher |
| 1.0.0 | 2026-04-XX | Initial release |
