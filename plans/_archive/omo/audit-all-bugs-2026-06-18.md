# EaxRotations Comprehensive Bug Audit — 2026-06-18

## TL;DR (For humans)

This plan exhaustively audits the EaxRotations rotation engine for 17 bug classes (A-Q) across ~60 spec files, ~50 shared modules, and 4 core files. The seed bug classes (wrong power enum, invalid GUID crash, Travel Form ping-pong, per-frame scan) are extended to systematic sweeps.

**Bottom line**: ~51 findings across ~28 files. 6 crash-risk, 19 wrong-behavior, 3 loop-risk, 11 perf, 10 integration, 5 maintainability. Execution is 5 parallel blocks of surgical fixes (1-5 lines each). ~180-250 total LoC.

## Executive Summary

| Class | Description | Findings | Risk Distribution |
|-------|------------|----------|------------------|
| A | Wrong Enum / Magic Number | 2 | WRONG (1), PERF (1) |
| B | Raw Unit Comparison | 3 | CRASH (3) |
| C | Form/Stance Ping-Pong | 1 | LOOP (1) |
| D | Per-Frame Scan in build_state | 2 | PERF (2) |
| E | Bare State-Field Comparison | 20 | WRONG (18), PERF (2) |
| F | Menu Nil-Guard Void | 0 | — |
| G | math.sqrt in Hot Path | 0 | — |
| H | Garbage-Creating Table | 3 | PERF (3) |
| I | Uncached Hot-Path API | 2 | PERF (2) |
| J | Snapshot Without GUID Check | 4 | CRASH (1), WRONG (3) |
| K | Cast Without Guard | 0 | — (NS.try_cast central guard) |
| L | Missing pcall Require | 10 | INTEGRATION (10) |
| M | Spell-ID vs DBC | 1 (fixed) | CRASH (1) |
| N | Healer Target No Class Filter | 0 | — |
| O | Talent Build Detection Gap | 1 | WRONG (1) |
| P | Orphan Module | TBD | MAINTAINABILITY |
| Q | Test Coverage Gap | 4 | MAINTAINABILITY (4) |

- **Total confirmed**: ~51
- **Files touched**: ~28 (≤32 target)
- **Fix LoC**: ~180-250
- **Risk dist**: 6 CRASH / 18 WRONG / 1 LOOP / 11 PERF / 10 INTEGRATION / 5 MAINTAINABILITY

---

## Findings Per Class

### Class A — Wrong Enum / Magic Number Lookup

| # | File | Line | Snippet | Risk | Canonical Helper | Proposed Fix |
|---|------|------|---------|------|-----------------|--------------|
| 1 | classes/warrior/leveling_sylvanas.lua | 147,203,258,275,297 | `me:get_power(1)` | WRONG | NS.POWER_RAGE or named constant | Replace `1` with `NS.POWER_RAGE` |
| 2 | classes/warrior/leveling_vanilla.lua | 141,239 | `me:get_power(1)` | WRONG | NS.POWER_RAGE or named constant | Replace `1` with `NS.POWER_RAGE` |

**Context**: `get_power(1)` is power type 1 = Rage. The value 1 is correct for the Rage power type enum, but per AGENTS.md Pattern A, all numeric power-type literals must use named constants. The seed bug (`get_power(me, 4)` == HAPPINESS, not combo points for TBC) is **already fixed** at `main_sylvanas.lua:359` — it now uses `get_power(me, 8)` (combo points power type on 2.5.5 client). `heal_helper_sylvanas.lua:155` uses `get_power(0)` for Mana (0 is correct).

**Test to add**: `test_leveling_warrior_enum.lua`

---

### Class B — Raw Unit Comparison Without NS.same_unit

| # | File | Line | Snippet | Risk | Proposed Fix |
|---|------|------|---------|------|--------------|
| 1 | classes/warrior/protection_sylvanas.lua | 469 | `if ok and enemy_target == me then` | CRASH | `NS.same_unit(enemy_target, me)` |
| 2 | classes/druid/bear_sylvanas.lua | 330 | `if unit ~= state.target` (in scan_pack) | CRASH | `not same_unit(unit, state.target)` |
| 3 | classes/druid/bear_vanilla.lua | 291 | same as #2 | CRASH | Same fix |

**Context**: #1 is the confirmed seed bug. #2/#3: bear_sylvanas already defines a local `same_unit()` helper (line 202) that wraps `NS.same_unit`, but line 330 uses bare `~=` instead. Fix is trivial: wrap with `same_unit()`.

**Tests to add**: `test_prot_unit_compare.lua`, `test_bear_unit_compare.lua`

---

### Class C — Form / Stance / State Ping-Pong

| # | File | Pairs | Existing Guard | Risk | Proposed Fix |
|---|------|-------|---------------|------|--------------|
| 1 | classes/druid/cat_sylvanas.lua | CatForm (L755) ↔ TravelForm (L756) | CatForm: `context.on_gcd` (L465). TravelForm: 3s throttle (L538). | LOOP | Add `if context.on_gcd then return false end` to travel_form_matches |

**Context**: CatForm correctly blocks on GCD. TravelForm's 3-second throttle prevents rapid flip-flop but the GCD check is absent. The seed cat Travel Form ping-pong is partially addressed but not fully consistent with project pattern.

---

### Class D — Per-Frame Scan Inside build_state()

| # | File | Scan Path | Existing Guard | Risk | Proposed Fix |
|---|------|-----------|---------------|------|--------------|
| 1 | classes/druid/bear_sylvanas.lua | `scan_pack()` via `NS.get_visible_units` | Already fixed: `lazy_scan_pack` + `SCAN_INTERVAL=0.2s` | SAFE | None needed |
| 2 | classes/warrior/protection_sylvanas.lua | `get_visible_units()` + `get_party_members()` in build_state | Gated by `in_combat` and `is_group`, but runs every frame | PERF | Add `utils.get_cached_combat_context(me)` 2s TTL |

**Context**: The bear seed fix is already applied. Protection warrior's party/enemy scans run every `build_state()` call (~every frame). With 2s TTL on the combat context, the scans would run at most every 2 ticks.

---

### Class E — Bare State-Field Numeric Comparison (Pattern 14 Violation)

| # | File | Line | Expression | Safe Default | Proposed Fix |
|---|------|------|-----------|-------------|--------------|
| 1 | classes/priest/holy_sylvanas.lua | 249 | `state.tank_hp < 50` | 100 | `(state.tank_hp or 100) < 50` |
| 2 | classes/priest/holy_sylvanas.lua | 338 | `state.tank_hp < 80` | 100 | `(state.tank_hp or 100) < 80` |
| 3 | classes/priest/holy_sylvanas.lua | 341 | `state.tank_hp < 45` | 100 | `(state.tank_hp or 100) < 45` |
| 4 | classes/priest/holy_sylvanas.lua | 468 | `state.lowest_hp < 95` | 100 | `(state.lowest_hp or 100) < 95` |
| 5-10 | classes/priest/holy_vanilla.lua | 235,239,256x2,328,331 | `state.lowest_hp < 30`, `state.tank_hp < 50/60>95/80/45` | 100 | Nil-guard all |
| 11-19 | classes/rogue/assassination_vanilla.lua | 286,309,330,349,368,387,471,488,505 | `state.combo < 5/4/2/4/3`, `state.combo > 3` | 0 | `(state.combo or 0) < N` |
| 20 | classes/paladin/holy_sylvanas.lua | 445 | `state.count > 1` | 0 | `(state.count or 0) > 1` |

**Context**: Fields are initialized in build_state() (tank_hp=100, lowest_hp=100, combo=0, count=0), so the bug surfaces only on stale state. All `assassination_sylvanas.lua` and `subtlety_vanilla.lua` comparisons already use `(field or default)`. `assassination_vanilla.lua` was missed.

---

### Class F — Menu Nil-Guard Void

**0 findings confirmed across 73 spec files, 61 shared modules, 4 core files.** The codebase has fully migrated to middleware settings access via `NS.get_setting(key, fallback)`. No production file uses bare `menu.X:get()`.

---

### Class G — Math.sqrt in Hot Path

**0 findings confirmed.** Only a comment in `tests/test_runner_lib.lua` mentions the rule.

---

### Class H — Garbage-Creating Table in Tight Loop

| # | File | Line | Pattern | Risk | Proposed Fix |
|---|------|------|---------|------|--------------|
| 1 | classes/druid/leveling_sylvanas.lua | 91 | `local state = {}` per-frame | PERF | Module-level `local _state = {n=0}`, reuse |
| 2 | classes/mage/leveling_sylvanas.lua | 88 | `local state = {}` per-frame | PERF | Same |
| 3 | shared/apl_parser.lua | 109 | `local tokens = {}` per-call | PERF | Module-level `_tokens` pattern |

---

### Class I — Uncached Hot-Path API Call

| # | File | Uncached Call | Proposed Fix |
|---|------|--------------|--------------|
| 1 | classes/warrior/leveling_sylvanas.lua | `core.spell_book.is_spell_learned` per-frame | Cache at module load: `local _is_spell_learned = core.spell_book.is_spell_learned` |
| 2 | classes/mage/leveling_sylvanas.lua | `core.object_manager.get_local_player()` per-frame | Cache at module load: `local _get_player = ...` |

---

### Class J — Snapshot State Without GUID Validity Check

| # | File | State Field | Has GUID Check? | Risk | Proposed Fix |
|---|------|------------|----------------|------|--------------|
| 1 | classes/druid/cat_sylvanas.lua | `snapshot_state.rip_target` | YES (L441-442: `NS.same_unit`) | SAFE | Already fixed |
| 2 | classes/druid/cat_vanilla.lua | `snapshot_state.rip_target` | NO | CRASH | Add `NS.same_unit` invalidation in build_state |
| 3 | classes/warlock/affliction_sylvanas.lua | `aff_state.snapshot_target` (string) | Partial (string key, not unit handle) | WRONG | Add DoT-remains zero-check as extra invalidation |
| 4 | classes/warlock/affliction_vanilla.lua | same | Partial | WRONG | Same fix |
| 5 | classes/priest/shadow_sylvanas.lua | `shadow_state.snapshot_target` (string) | Partial | WRONG | Same pattern |

**Context**: cat_sylvanas already has the seed fix (lines 441-442). Warlock/priest use string keys (`tostring(target)`) which avoids the crash but doesn't invalidate on death. DoT-remains zero-check at lines 196-199 (aff) and 246-248 (shadow) provides partial protection.

---

### Class K — Cast Path Without Invalid-GUID / Range / LOS Check

**0 findings.** `NS.try_cast` (core_sylvanas.lua:2592) central-guards through `NS.evaluate_cast()` (cooldown, resource, range, anti-flicker, reagent, immunity) and `NS.los_check()`. No direct `core.input.cast_target_spell` calls in production code. Item usage goes through `NS.use_item_by_id`.

---

### Class L — Missing pcall/Lazy-Require Wrapper

| # | File | Pattern | Proposed Fix |
|---|------|---------|--------------|
| 1-10 | shared/cast_bar_overlay_sylvanas.lua, hunter_adaptive_sylvanas.lua, leveling_sylvanas.lua, mf_tick_compute_sylvanas.lua, reagent_guard_sylvanas.lua, spell_flag_checker_sylvanas.lua, ttd_ema_tracker_sylvanas.lua, ttd_tracker_sylvanas.lua, wowhead_data_bridge_sylvanas.lua, apl_parser.lua | Bare `require("shared/X")` | `local ok, Mod = pcall(require, "shared/X")` |

---

### Class M — Spell-ID Validity vs DBC

**Known fix**: `d1df4742` removed Survival Instincts (61336) — Wrath-only.

**Existing coverage**: `e9b73122` added test for spell ID DBC existence. A full sweep against `wowheadScrape/dbc_extract/wowsims.db` (28,650 spells) is possible but deferred — requires SQLite tooling and should be its own plan.

---

### Class N — Healer-Targeting Without Class Filter

**0 findings.** `HEALER_CLASS_IDS` patterns used correctly in:
- `main_sylvanas.lua:47` — global definition
- `classes/druid/resto_sylvanas.lua:68` — smart innervate
- `shared/offensive_dispel_sylvanas.lua:220` — dispel targeting

---

### Class O — Talent Build Detection Gap

| # | Issue | Risk |
|---|-------|------|
| 1 | No spec currently reads `context.talent_build` | WRONG |

**Context**: `a55974a9` added `talent_build` to `build_context()` via `core.game_ui.get_talent_info()`. No spec uses it. Specs that branch on talent choices (shadow/affliction snapshots, elemental Lightning Overload, etc.) should use `context.talent_build.tree1/tree2/tree3`. No spec calls `get_talent_info()` directly. **Deferred** — requires its own design plan.

---

### Class P — Orphan Module / Dead-Code Path

**TBD**: Requires full cross-reference of all 61 shared module files against require() sites. Initial scan suggests all shared modules are referenced.

### Class Q — Test Coverage Gap

| Commit | Description | Lock Test | Status |
|--------|-------------|-----------|--------|
| `54268cde` | Energy tick tracker state refactor | **MISSING** | MUST ADD |
| `5b28c93f` | Rank-chain ID repair | **MISSING** | MUST ADD |
| `149390c2` | Core spell_helper guard | **MISSING** | MUST ADD |
| `8cc84db0` | 9 hyperplan bugs | **MISSING** | MUST ADD |

Tests to create: `test_combat_energy_state.lua`, `test_shared_rank_chain.lua`, `test_core_spell_helper_guard.lua`, `test_hyperplan_bugs_pass2.lua`

---

## Execution Order

### Block 0: Verify Foundation (verify, no change)
- core_sylvanas.lua: confirm NS.same_unit (L457), NS.buff_points exist
- main_sylvanas.lua: confirm get_power(me,8) uses named constant

### Block 1: CRASH Fixes (independent, parallel)
1. `classes/warrior/protection_sylvanas.lua` — B#1 (enemy_target == me)
2. `classes/druid/bear_sylvanas.lua` — B#2 (unit ~= state.target in scan_pack)
3. `classes/druid/bear_vanilla.lua` — B#3 (same)
4. `classes/druid/cat_vanilla.lua` — J#2 (snapshot without GUID check)
5. 10 shared modules — L#1-10 (pcall require wrappers)

### Block 2: WRONG Behavior Fixes (independent, parallel)
1. `classes/priest/holy_sylvanas.lua` — E#1-4 (tank_hp/lowest_hp nil-guards)
2. `classes/priest/holy_vanilla.lua` — E#5-10 (same)
3. `classes/rogue/assassination_vanilla.lua` — E#11-19 (combo nil-guards)
4. `classes/paladin/holy_sylvanas.lua` — E#20 (count nil-guard)
5. `classes/warlock/affliction_sylvanas.lua` — J#3 (snapshot invalidation)
6. `classes/warlock/affliction_vanilla.lua` — J#4 (same)
7. `classes/priest/shadow_sylvanas.lua` — J#5 (snapshot invalidation)
8. `classes/priest/shadow_vanilla.lua` — J#6 (same)

### Block 3: PERF + LOOP Fixes (independent, parallel)
1. `classes/druid/cat_sylvanas.lua` — C#1 (GCD guard on travel_form_matches)
2. `classes/warrior/leveling_sylvanas.lua` — A#2, I#1
3. `classes/warrior/leveling_vanilla.lua` — A#3
4. `classes/warrior/protection_sylvanas.lua` — D#2
5. `classes/priest/middleware_sylvanas.lua` — D#3
6. `classes/druid/leveling_sylvanas.lua` — H#1
7. `classes/mage/leveling_sylvanas.lua` — H#2, I#2
8. `shared/apl_parser.lua` — H#3

### Block 4: New Regression Tests
1. `tests/test_prot_unit_compare.lua`
2. `tests/test_bear_unit_compare.lua`
3. `tests/test_cat_vanilla_snapshot.lua`
4. `tests/test_combat_energy_state.lua`
5. `tests/test_shared_rank_chain.lua`
6. `tests/test_core_spell_helper_guard.lua`
7. `tests/test_hyperplan_bugs_pass2.lua`

---

## Verification Per Fix

1. `luac -p <file>` exits 0
2. `lua EaxRotations/tests/run_rotation_tests.lua`: 0 failures
3. `lua EaxRotations/tests/run_leveling_tests.lua`: 0 failures
4. `lsp_diagnostics <file>`: 0 errors
5. New regression test passes

---

## Out of Scope

- `api/`, `apidocs/` — reference material
- `EaxAutoQuester/`, `wowheadScrape/`, `build_tools/`
- Full talent_build integration (Class O — separate plan needed)
- Full DBC spell-ID audit (Class M — requires SQLite tooling)

---

## References

- AGENTS.md Patterns 1-14
- `core_sylvanas.lua:457` — `NS.same_unit`
- `core_sylvanas.lua:2592` — `NS.try_cast` (central cast guard)
- `EaxRotations/tests/test_state_field_nil_guards_2026_06.lua`
- `EaxRotations/tests/test_invalid_target_guid_crash.lua`
- `EaxRotations/tests/test_cat_combo_points_fix.lua`
