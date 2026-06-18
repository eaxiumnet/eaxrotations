# Remaining Gaps — June 2026

## ✅ Completed (prior session)

- Removed dead `NS.get_spell_damage()` stub + cleaned 11 spec files
- Wired PvP context: `cc_target`, `cc_safe`, `fear_nearby`, `enemy_healer`, `melee_on_you`
- Wired scorch maintenance: `scorch_stacks`, `scorch_remains`, `pyroblast_ready`
- Wired `context.enemies` (array) and `context.group_injured`
- Loaded `pvp_trinket_tracker_sylvanas.lua` at runtime
- Cleaned unused `_pvp_trinket_ok` variable

## ✅ Completed (this session — June 7, 2026)

- **DR tracker case mismatch:** `NS.dr_tracker` → `NS.DRTracker` in `build_context()`. Module (`dr_tracker_sylvanas.lua`) was loaded by `main.lua` but queried with wrong key — Lua case-sensitivity made it nil. `target_dr_stun` was always 0.
- **DR tracker nil guard comment:** Added explicit comment noting `target_dr_stun` stays 0 if `NS.DRTracker` module failed to load.
- **`context.enemy_list` / `context.targets` aliases:** Both set to `context.enemies` in `build_context()`. 4 paladin specs now have consistent fallback chains.
- **`context.attack_power`:** Wired via `unit_number(me, "get_attack_power")` in `build_context()`. Cat druid specs (`cat_sylvanas.lua`, `cat_vanilla.lua`) now hit context first instead of falling through 4-step fallback chain.
- **Cat druid AP simplification:** Removed the 3-step fallback chain (`NS.attack_power()` → `NS.get_attack_power()` → `me:get_attack_power()`) from both cat druid `get_attack_power()` functions. Now just returns `context.attack_power` or 0.
- **`context.crit_chance`:** Wired via `unit_number(me, "get_spell_crit_chance")` in `build_context()`. Paladin `heal_helper_sylvanas.lua` now gets real crit data for Illumination mana-return calculations. Includes format comment noting expected percentage (0-100).
- **Full NS module case audit:** Cross-referenced all 39 module registrations against 150+ consumer references. Only mismatch was the `NS.dr_tracker` bug above. No additional issues found.

---

## Remaining Context Field Gaps

### 1. `context.spell_damage` — 8 specs, no API available
- **Consumers:** warlock (destruction, affliction, demonology), priest (shadow), shaman (elemental), druid (balance ×2)
- **Fallback:** `context.spell_damage or 0` in all specs — functionally zero, never populated
- **API status:** `core.spell_book.get_spell_damage()` was deprecated and removed from the engine
- **Verdict:** Cannot be wired. Harmless dead code. The `or 0` pattern is defensive — no benefit to removing.

### 2. `context.state.*` — priest leveling dead legacy
- **Consumers:** `priest/leveling.lua`, `leveling_sylvanas.lua`, `leveling_vanilla.lua`
- **Expected fields:** `state.target_creature_type`, `state.threat_status`, `state.enemy_count`, `state.hp_pct`
- **Status:** `context.state` is never created by `build_context()`. These are legacy patterns from before context was centralized.
- **Verdict:** Priest leveling specs always get nil from `context.state` and fall back to their own computation. Harmless dead code. Low priority.

---

## All shared modules — loaded and verified

All 39 NS-registered shared modules are loaded (via `main.lua` or on-demand by class middleware). Full case-mismatch audit completed — zero bugs found beyond the `NS.dr_tracker` fix above. No loading gaps remain.

---

## Ship Constraint — wowhead_data JSON files

### Status: All 5 consuming modules fall back gracefully

| Module | Degradation |
|---|---|
| `spell_corpus_sylvanas.lua` | Returns nil/empty — spell searches don't work |
| `spell_rank_resolver_sylvanas.lua` | Returns empty rank tables — rank resolution doesn't work |
| `spell_flag_checker_sylvanas.lua` | **Fully functional** — 240+ druid forms hardcoded |
| `dot_refresh_sylvanas.lua` | Tick-based refresh returns nil — basic formula still works |
| `gear_sets_sylvanas.lua` | **Fully functional** — 133 sets hardcoded, JSON only for cross-ref |

### Action items:
- **`spell_rank_resolver`**: Specs hardcode their spell ID tables (e.g., `class_sylvanas.lua` files). The resolver is a nice-to-have for dynamic rank resolution. If no spec relies on it in hot paths, ship-safe.
- **`spell_corpus`**: Same — spell searches/cost lookups are supplementary. No spec uses these in hot rotation paths.
- **Verdict:** Ship-safe without JSON embedding. If rank resolution is needed later, embed the spell list data as Lua tables.

---

## .api — Available but unused engine APIs

### APIs confirmed unavailable in TBC/Vanilla:
- `game_object:get_specialization_id()` — retail only
- `core.object_manager.get_arena_opponent_spec()` — retail only

### APIs that could add value:
- `game_object:get_armor()` — sunder/faerie fire value assessment (PvE)
- `core.object_manager.get_boss_frames()` — enhanced boss detection
- `game_object:is_tap_denied()` — skip gray/tapped mobs in leveling rotations
- `game_object:has_item(item_id)` — trinket/consumable detection on enemies (PvP)

---

## Priority Summary

| # | Item | Impact | Effort | Status |
|---|---|---|---|---|
| 1 | DR tracker case fix (`NS.dr_tracker` → `NS.DRTracker`) | DR tracking was dead in PvP | 1 line | ✅ Done |
| 2 | `context.enemy_list` / `context.targets` aliases | 4 paladin files get consistent fallback | 2 lines | ✅ Done |
| 3 | `context.spell_damage` cleanup | Code hygiene, zero functional impact | ~16 lines | ❌ Skipped (defensive code) |
| 4 | `context.state.*` for priest leveling | Dead code removal or wiring | Investigation | Open |
| 5 | `context.attack_power` for cat druid | Was missing, now wired | 1 line | ✅ Done |
| 6 | `context.crit_chance` for paladin | Was nil, now wired via unit method | 1 line | ✅ Done |
| 7 | Full NS module case audit | Verify no more silent nil bugs | Investigation | ✅ Done |
| 8 | Embed `spell_list_tbc.json` as Lua table | Needed if rank resolution is required in prod | ~1 day | Open |
