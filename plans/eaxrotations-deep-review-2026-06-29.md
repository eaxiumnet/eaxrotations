# EaxRotations Deep Review & Improvement Plan

**Status**: Active
**Started**: 2026-06-29
**Phase**: Phases 1-5 complete, Phase 2 (architecture extraction) in progress

## Summary

A deep multi-agent review of the EaxRotations codebase identified 46 findings across
the core engine, spec files, shared modules, tests, and documentation. This plan tracks
the execution of fixes across 6 phases.

## Completed Work

### Phase 1: Critical Bug Fixes ✅
- [x] Arms `stance_swap_safe` typo fix
- [x] Arms `ARMS_SCHEMA` scoping fix (moved before `build_state`)
- [x] Arms `mortal_strike_matches` dead rage-cap bypass fix
- [x] `get_spell_id` per-frame table allocation fix (use static buffer)
- [x] `spell_helper_castable` pcall wrapping
- [x] Duplicate `_settings_cache` declarations removed
- [x] `filter_spell_ids_for_expansion` `if true then` no-op → real vanilla filtering
- [x] Dead code: `spell_exists` if-false branch, cooldown buffer, `if true then` guards
- [x] `NS.isfalse()` → `NS.is_api_health_broken()` (alias preserved)
- [x] `_context.lowest` per-frame allocation eliminated
- [x] Enhancement debug logging removed
- [x] BM Hunter global function leak fixed

### Phase 2: Architecture Refactoring (partial) ✅
- [x] `core/strategy_gating.lua` extracted — deduplicated strategy_category tables
- [x] Dead code cleanup: VANILLA_HIGH_SPELL_ALLOWLIST, _last_cast_time_cooldown, _settings_manager, EnemyCDTracker stubs, get_spell_damage, match_fail stubs
- [x] Generated `cc_is_*` bridge functions from table (13 functions, ~80 lines boilerplate eliminated)
- [x] Generated `unit_is_*` bridge functions from table (7 functions, ~50 lines boilerplate eliminated)
- [ ] Extract `core/auras.lua` from core_sylvanas (-400 lines)
- [ ] Extract `core/spell_safety.lua` (-600 lines)
- [ ] Extract `core/pvp.lua` + `core/cc_immunity.lua` (-420 lines)
- [ ] Extract `core/healing.lua` + `core/targeting.lua` (-550 lines)
- [ ] Extract `core/registry.lua` (-500 lines)
- [ ] Refactor `build_context()` into sub-builders
- [ ] Refactor `action_matches` into predicate table

### Phase 3: Spec Layer Cleanup ✅
- [x] Warrior shared helpers extracted (`shared_helpers_sylvanas.lua`)
- [x] `potion_helper_sylvanas.lua`: added HEALTHSTONE_IDS + find_ready_healthstone()
- [x] `match_helpers_sylvanas.lua`: added shared cooldowns_enabled helper
- [x] Balance Druid dead Nature's Grace logic fixed
- [x] Balance Druid namespace alias standardized to NS
- [x] Frost Mage Fire/Arcane spells gated behind opt-in settings
- [x] Discipline Priest duplicate PW:S strategy removed
- [x] Fury Warrior dead thunder_ready field removed
- [x] BM Hunter global function leak fixed
- [x] Affliction snapshot nil-guard added
- [ ] Create shared HealthPotion/DamagePotion strategies
- [ ] Reset target-dependent state fields on target-switch

### Phase 4: Performance Hardening ✅
- [x] Enemy cache: multi-range per-tick cache (eliminates thrashing)
- [x] Immunity buff cache in evaluate_cast (eliminates 6 buff_up calls per cast)
- [x] collect_healing_units: static output buffer
- [x] is_item_equipped: per-tick equipped set cache (O(N) vs O(19×N))
- [x] count_equipped_set: uses same cache
- [x] items.lua: safe/safe_field captured at install time (eliminates per-call pcalls)
- [x] get_spell_id: uses static buffer
- [x] _context.lowest: pre-allocated, mutated in place
- [x] is_hostile_unit: short-circuits on definitive can_attack false (eliminates up to 6 redundant API checks)
- [ ] Cache NS.GetPlayer() per-frame in upvalue

### Phase 5: Test & Documentation ✅
- [x] Fixed hardcoded path in test_leveling_druid.lua
- [x] Wired 14 orphaned test files into run_rotation_tests.lua
- [x] Added assert_true/assert_eq to test_runner_lib.lua
- [x] Created test_arms_critical_fixes.lua (regression tests for 3 Arms bugs)
- [x] Updated TECHNICAL_GUIDE.md version to 2.2.0
- [x] Updated status_audit.md staleness note
- [x] Created docs/CONTRIBUTING.md
- [x] Updated CHANGELOG.md with full v2.2.0 entry
- [ ] Add integration test for full pipeline
- [ ] Add test coverage for Arms Warrior (critical bugs had no tests)

### Phase 6: Shared Module Cleanup (not started)
- [ ] Standardize module export pattern
- [ ] Consolidate setting() helper
- [ ] Consolidate get_player() to use player_helpers everywhere
- [ ] Clarify TTD: pick one tracker as authoritative
- [ ] Merge leveling_helpers into leveling or clarify separation

## Verification
- 416 Lua files, 0 syntax errors
- Version bumped to 2.2.0
- 3 new files created (strategy_gating.lua, shared_helpers_sylvanas.lua, CONTRIBUTING.md)
- ~25 files modified across core, specs, shared, tests, and docs
