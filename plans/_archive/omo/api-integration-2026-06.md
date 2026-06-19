# Implementation Plan: Autonomous API Integration

**Created:** 2026-06-16
**Scope:** 8 Sylvanas engine APIs → EaxRotations integration
**Principle:** 100% autonomous — zero player input required

---

## Overview

Integrate 8 underutilized Sylvanas engine APIs into EaxRotations to reduce silent failures, improve PvP reactivity, and auto-adapt to game state without player interaction.

---

## API Integration Matrix

| # | API | Files to Touch | Autonomous Behavior |
|---|-----|---------------|---------------------|
| 1 | `game_object:los_to()` | `core_sylvanas.lua`, `shared/los_guard_sylvanas.lua` | Skip cast if target not in LOS |
| 2 | `get_all_missiles()` | `shared/missile_tracker_sylvanas.lua`, class PvP specs | Auto-pre-immune incoming CC projectiles |
| 3 | `get_override_spell_id()` / `get_base_spell_id()` | `shared/spell_resolver_sylvanas.lua` | Auto-resolve talent-modified spell IDs |
| 4 | `get_spell_range_data()` | `core_sylvanas.lua` (range helper) | Hunter dead-zone auto-switch to melee |
| 5 | `get_pet_happiness()` | `classes/hunter/middleware_sylvanas.lua` | Auto-feed pet when unhappy |
| 6 | `is_tap_denied()` | `shared/targeting_sylvanas.lua` | Skip gray-bar mobs in leveling |
| 7 | `get_boss_count()` | `shared/targeting_sylvanas.lua` | Efficient boss detection |
| 8 | `get_talent_info()` | `core_sylvanas.lua` (diagnostic), spec files | Rotation adapts to talent build |

---

## Phase 1: Foundation (Parallel Wave 1)

### Task 1.1: LOS Guard Module
- **Files:** `EaxRotations/shared/los_guard_sylvanas.lua` (new), `EaxRotations/core_sylvanas.lua`
- **API:** `game_object:los_to()` (IZI SDK), `core.graphics.is_line_of_sight()` (fallback)
- **Acceptance:**
  - Module loads via pcall in `main.lua`
  - `NS.los_check(target)` returns boolean, never crashes on nil
  - `NS.try_cast()` skips cast when `skip_los=false` and target not in LOS
  - Test: `test_los_guard.lua` — mock target without LOS, assert cast is skipped
- **Verify:** `luac -p`, `lua test_los_guard.lua`
- **Risk:** LOS check adds CPU cost. Mitigation: throttle to 100ms cache.

### Task 1.2: Spell Range Data Helper
- **Files:** `EaxRotations/core_sylvanas.lua`
- **API:** `core.spell_book.get_spell_range_data(spell_id)`
- **Acceptance:**
  - `NS.get_spell_range(spell_id)` returns `{min=number, max=number}` or nil
  - Hunter specs can detect dead zone: `range.min > 0 and distance <= range.min`
  - Nil-safe: returns nil if API unavailable
  - Test: `test_spell_range_data.lua` — mock range {min=5, max=35}, assert dead-zone at 3yd
- **Verify:** `luac -p`, hunter rotation tests still pass
- **Risk:** TBC client may not expose range data for all spells. Mitigation: fallback to hardcoded ranges.

### Task 1.3: Boss Count Optimization
- **Files:** `EaxRotations/shared/targeting_sylvanas.lua`
- **API:** `core.object_manager.get_boss_count()`
- **Acceptance:**
  - Replace `get_boss_frames()` iteration with `get_boss_count()` where only count is needed
  - `context.is_boss_fight` uses count > 1 instead of frame iteration
  - Backward compatible: falls back to frame iteration if API nil
  - Test: `test_boss_count.lua` — mock count=2, assert is_boss_fight=true
- **Verify:** `luac -p`, targeting tests pass

---

## Phase 2: PvP & Pet (Parallel Wave 2)

### Task 2.1: Missile Tracker
- **Files:** `EaxRotations/shared/missile_tracker_sylvanas.lua` (new)
- **API:** `core.object_manager.get_all_missiles()`
- **Acceptance:**
  - Module registers on_spell_cast callback, tracks missiles targeting player
  - Exposes `NS.missile_tracker.is_incoming_cc()` — true if projectile is CC spell
  - Used by PvP specs to pre-trinket or pre-ice-block
  - Test: `test_missile_tracker.lua` — mock missile with polymorph spell_id, assert detection
- **Verify:** `luac -p`, `lua test_missile_tracker.lua`
- **Risk:** Missile API may not return data on TBC. Mitigation: module self-disables if nil.

### Task 2.2: Pet Happiness Auto-Feed
- **Files:** `EaxRotations/classes/hunter/middleware_sylvanas.lua`, `shared/pet_manager_sylvanas.lua`
- **API:** `core.spell_book.get_pet_happiness()`
- **Acceptance:**
  - Hunter middleware checks happiness in `build_state()`
  - If happiness < 2 (unhappy), trigger Feed Pet if available and not in combat
  - `context.pet_happiness` exposed to spec files
  - Test: `test_pet_happiness.lua` — mock happiness=1, assert Feed Pet queued
- **Verify:** `luac -p`, hunter tests pass

---

## Phase 3: Spell Resolution & Talent Awareness (Parallel Wave 3)

### Task 3.1: Spell Override Resolver
- **Files:** `EaxRotations/shared/spell_resolver_sylvanas.lua`
- **API:** `core.spell_book.get_override_spell_id()`, `get_base_spell_id()`
- **Acceptance:**
  - `NS.resolve_talent_spell(base_id)` returns override_id if talent modifies it
  - Integrated into existing `spell_resolver_sylvanas.lua` cache
  - Only activates if API available; no change to hardcoded tables if unavailable
  - Test: `test_override_spell.lua` — mock override_id, assert resolution
- **Verify:** `luac -p`, spell resolver tests pass

### Task 3.2: Talent Build Detection
- **Files:** `EaxRotations/core_sylvanas.lua`, `main_sylvanas.lua` `build_context()`
- **API:** `core.game_ui.get_talent_info()`
- **Acceptance:**
  - `context.talent_build` = hash of invested talent points by tree
  - Spec files can branch: `if context.talent_build.affliction > 30 then ...`
  - Already used in diagnostic dump (core_sylvanas.lua:6358) — promote to context field
  - Test: `test_talent_context.lua` — mock talent table, assert build detected
- **Verify:** `luac -p`, context completeness test passes

---

## Phase 4: Leveling Quality (Parallel Wave 4)

### Task 4.1: Tap Denied Filter
- **Files:** `EaxRotations/shared/targeting_sylvanas.lua`
- **API:** `game_object:is_tap_denied()`
- **Acceptance:**
  - `NS.is_valid_enemy()` excludes units where `is_tap_denied()` returns truthy
  - Only active in leveling rotations (context.is_leveling or setting toggle)
  - PvE/PvP boss fights skip this filter (bosses are never tap-denied in instances)
  - Test: `test_tap_denied.lua` — mock tap_denied=true, assert target skipped
- **Verify:** `luac -p`, leveling tests pass

---

## Phase 5: Integration & Regression

### Task 5.1: Hunter Dead-Zone Logic
- **Files:** `classes/hunter/*_sylvanas.lua`
- **Acceptance:**
  - When `get_spell_range_data()` shows min>0 and target inside min range, auto-prefer melee/Raptor Strike over ranged shots
  - Only affects hunter specs; other classes unchanged
  - Test: `test_hunter_dead_zone.lua` — mock target at 3yd with min_range=5, assert melee ability chosen

### Task 5.2: Full Regression
- **Acceptance:**
  - All 111 rotation tests pass
  - All 11 leveling tests pass
  - `luac -p` clean on all changed files
  - LSP zero errors on changed files

---

## Test-First Contract (per API)

| API | RED Test | GREEN Evidence |
|-----|---------|----------------|
| los_to | `test_los_guard.lua` fails with "cast should be skipped when no LOS" | After module creation, test passes |
| get_spell_range_data | `test_spell_range_data.lua` fails with "should detect dead zone" | After helper creation, test passes |
| get_boss_count | `test_boss_count.lua` fails with "should use count API" | After targeting update, test passes |
| get_all_missiles | `test_missile_tracker.lua` fails with "should detect incoming CC" | After module creation, test passes |
| get_pet_happiness | `test_pet_happiness.lua` fails with "should feed unhappy pet" | After middleware update, test passes |
| get_override_spell_id | `test_override_spell.lua` fails with "should resolve talent-modified ID" | After resolver update, test passes |
| get_talent_info | `test_talent_context.lua` fails with "should expose talent build" | After context wiring, test passes |
| is_tap_denied | `test_tap_denied.lua` fails with "should skip tapped mob" | After targeting update, test passes |

---

## Risks Summary

| Risk | Impact | Mitigation |
|------|--------|------------|
| LOS check too expensive | Frame drop | 100ms cache, skip in non-PvP |
| Missile API returns empty on TBC | New module useless | Self-disable if nil |
| Range data missing for spells | Dead-zone logic fails | Fallback to hardcoded ranges |
| Talent API shape differs by client | Build detection wrong | Pcall + type check on return |
| Tap denied on bosses in raids | Boss targeting broken | Exclude instance/raid contexts |

---

## Execution Order

```
Wave 1 (Parallel):
  ├─ Task 1.1: LOS Guard
  ├─ Task 1.2: Spell Range Data
  └─ Task 1.3: Boss Count

Wave 2 (Parallel, after Wave 1):
  ├─ Task 2.1: Missile Tracker
  └─ Task 2.2: Pet Happiness

Wave 3 (Parallel, after Wave 1):
  ├─ Task 3.1: Spell Override
  └─ Task 3.2: Talent Build

Wave 4 (after Wave 1):
  └─ Task 4.1: Tap Denied

Wave 5 (after all above):
  ├─ Task 5.1: Hunter Dead-Zone
  └─ Task 5.2: Full Regression
```

---

## Files Summary

### New Files
- `shared/los_guard_sylvanas.lua`
- `shared/missile_tracker_sylvanas.lua`
- `tests/test_los_guard.lua`
- `tests/test_spell_range_data.lua`
- `tests/test_missile_tracker.lua`
- `tests/test_pet_happiness.lua`
- `tests/test_override_spell.lua`
- `tests/test_talent_context.lua`
- `tests/test_tap_denied.lua`
- `tests/test_boss_count.lua`

### Modified Files
- `core_sylvanas.lua` (LOS check, range helper, talent context)
- `main_sylvanas.lua` `build_context()` (talent build, boss count)
- `shared/targeting_sylvanas.lua` (boss count, tap denied)
- `shared/spell_resolver_sylvanas.lua` (override resolution)
- `shared/pet_manager_sylvanas.lua` (happiness integration)
- `classes/hunter/middleware_sylvanas.lua` (happiness, dead-zone)
- `classes/hunter/*_sylvanas.lua` (dead-zone logic)

---

*Plan created by Sisyphus. Execute with `/do` or manually via todo list.*
