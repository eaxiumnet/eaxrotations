# Implementation Plan: EaxRotations Cross-Class Robustness Sweep

**Created:** 2026-06-18
**Source Trigger:** Cat "Invalid game object" + Travel Form spam + Bear lag complaints
**Follow-up:** "scan for similar issues" → 7 additional dangerous raw-unit comparisons found in 3 other specs

## Overview

After fixing the Druid Cat/Bear regressions (NS.same_unit crash, get_power(8) combo-points fix, TravelForm throttle, lazy_scan_pack), a parallel scan of all 9 classes revealed the **same anti-patterns recur in 3 other specs**:

| Risk Class | Already Fixed | Still Exposed |
|---|---|---|
| Raw `unit ~= target` / `unit == me` comparisons | Druid Cat (lines 441-442) | 7 sites in Warrior Prot (4), Paladin Prot (2), Priest Disc (1) |
| Wrong `get_power()` power-type constant | Druid Cat (main_sylvanas.lua:359) | Need to audit all power-type reads |
| Form-pingpong loop (no GCD/throttle) | Druid Cat (cat/travel forms) | Any spec with multiple form strategies |
| Unthrottled expensive scans in build_state | Druid Bear (scan_pack) | Any spec that calls get_visible_units in build_state |
| Empty `.lua`-violating files in EaxRotations/ | "632" stray file | Audit whole tree |

This plan executes a systematic sweep to eliminate all four classes of bugs uniformly, with TDD coverage so regressions cannot resurface.

## API Surface

| Pattern | API Used | Source |
|---------|----------|--------|
| Safe unit equality | `NS.same_unit(a, b)`, `NS.not_same_unit(a, b)` | `EaxRotations/core_sylvanas.lua:457-475` |
| Power type constants | `common/enums.power_type.COMBOPOINTS`, `.ENERGY`, `.RAGE`, `.FOCUS`, `.MANA`, `.HAPPINESS` | `api/common/enums.lua` |
| Form/stance awareness | `NS.has_form()`, `context.on_gcd`, `context.in_combat` | `EaxRotations/core_sylvanas.lua`, `apidocs/game-object.md` |
| Scan throttling | `state.now` + cached `_last_scan_time` | Pattern from bear scan_pack fix |

## Files to Touch

| File | Change | Priority |
|------|--------|----------|
| `EaxRotations/classes/warrior/protection_sylvanas.lua` | 5 sites replace `~= target` / `== me` with NS.same_unit/not_same_unit | HIGH |
| `EaxRotations/classes/paladin/protection_sylvanas.lua` | 2 sites same fix | HIGH |
| `EaxRotations/classes/priest/discipline_sylvanas.lua` | 1 site same fix | HIGH |
| `EaxRotations/main_sylvanas.lua` | Audit all `get_power` calls for correct power-type constant | MEDIUM |
| All spec files | Audit `build_state` for unthrottled expensive scans | MEDIUM |
| All spec files with form actions | Add `on_gcd`/`in_combat` guards to form matches | MEDIUM |
| `EaxRotations/` tree | Audit for non-`.lua`/`.md` files (plugin archive constraint) | LOW |

## Task List

### Phase 1: Confirm NS.same_unit / NS.not_same_unit exist (Foundation)

- [ ] Task 1.1: Verify NS.same_unit / NS.not_same_unit signatures in core_sylvanas.lua
  - **Files:** `EaxRotations/core_sylvanas.lua:457-475`
  - **Acceptance:** Both functions exist, pcall-wrapped, return false on nil/stale
  - **Verify:** `grep -n "function NS.same_unit"` returns ≥1 match
  - **Verified at plan time:** Confirmed via scan agent

### Phase 2: Fix Raw Unit Comparisons (Crash Risk)

- [ ] Task 2.1: Warrior Protection — fix 4 raw comparisons
  - **Files:** `EaxRotations/classes/warrior/protection_sylvanas.lua`
  - **Sites:** lines 87, 262, 307, 469 (per scan report)
  - **API:** `NS.not_same_unit(a, b)`, `NS.same_unit(a, b)`
  - **Acceptance:**
    1. No `obj ~= target`, `enemy_target ~= me`, `member ~= me`, `enemy_target == me` patterns remain
    2. All replacements use `NS.not_same_unit` / `NS.same_unit`
  - **Verify:** `luac -p <file>`, `lua EaxRotations/tests/test_protection_paladin_custom_matches.lua` + grep confirms no raw comparisons

- [ ] Task 2.2: Paladin Protection — fix 2 raw comparisons
  - **Files:** `EaxRotations/classes/paladin/protection_sylvanas.lua`
  - **Sites:** lines 151, 169 (per scan report)
  - **API:** `NS.not_same_unit(a, b)`
  - **Acceptance:**
    1. No `ally ~= me`, `enemy ~= target` patterns remain
  - **Verify:** `luac -p`, `lua EaxRotations/tests/test_protection_paladin_custom_matches.lua`

- [ ] Task 2.3: Priest Discipline — fix 1 raw comparison
  - **Files:** `EaxRotations/classes/priest/discipline_sylvanas.lua:164`
  - **Site:** `entry.unit ~= me`
  - **API:** `NS.not_same_unit(entry.unit, me)`
  - **Verify:** `luac -p`, `lua EaxRotations/tests/test_discipline_*`

### Phase 3: Audit get_power / Power-Type Constants

- [ ] Task 3.1: Inventory all get_power callsites
  - **Files:** grep across `EaxRotations/**/*.lua`
  - **Acceptance:** Every get_power call passes a power_type constant that matches its semantic purpose
  - **Verify:** Cross-reference each against `api/common/enums.lua` power_type table

- [ ] Task 3.2: Fix any misclassified power reads
  - **Risk:** Combo points (was wrongly reading type 4=HAPPINESS in Druid Cat; likely others)
  - **Verify:** Spot-check Rogue, Warrior, Hunter specs for similar bugs

### Phase 4: Form/Buff Loop Guards

- [ ] Task 4.1: Audit all specs with form actions
  - **Files:** `EaxRotations/classes/druid/*`, `EaxRotations/classes/paladin/aura_*`, any spec with multiple mutually-exclusive forms
  - **Acceptance:** Every form `matches` function has either:
    - `NS.has_form("name")` check to skip if already in that form, OR
    - `context.on_gcd` guard, OR
    - Cast-while-in-combat exclusion
  - **Verify:** `grep -n "form" EaxRotations/classes/*/_sylvanas.lua | grep matches` and review each

### Phase 5: Unthrottled Build_Sate Scans

- [ ] Task 5.1: Inventory unthrottled expensive calls in build_state
  - **Pattern:** `get_visible_units`, `GetEnemiesInRange`, `GetPartyMembers`, any `for` loop over >10 objects
  - **Acceptance:** Each call either (a) is throttled to >=0.2s interval, (b) caches result per frame, or (c) only runs when strategy that needs it is being evaluated (lazy)
  - **Verify:** grep + manual review

### Phase 6: Plugin Archive File Constraint

- [ ] Task 6.1: Confirm no non-`.lua`/`.md` files exist in EaxRotations/
  - **Files:** whole `EaxRotations/` tree
  - **Acceptance:** `Get-ChildItem EaxRotations -Recurse -File | Where-Object { $_.Extension -notin '.lua','.md' }` returns empty
  - **Verify:** Powershell command above returns zero rows

### Phase 7: Test Coverage

- [ ] Task 7.1: Add regression test for NS.same_unit safety
  - **Files:** New `EaxRotations/tests/test_safe_unit_comparison_sweep_2026_06.lua`
  - **Asserts:** comparison against stale/dead/missing unit returns false (not crash) for each protected site
  - **Verify:** `lua <new_test>` exits 0

- [ ] Task 7.2: Add regression test for cat "Invalid game object" scenario
  - **Files:** `EaxRotations/tests/test_cat_snapshot_target_change.lua`
  - **Asserts:** build_state survives when target GUID changes mid-rotation (snapshot_state.rip_target → new target, no crash)
  - **Verify:** RED before fix reproduction, GREEN after fix

### Phase 8: Full Validation

- [ ] Final validation
  - **Verify:**
    1. `luac -p` on every modified `_sylvanas.lua` file
    2. `lua EaxRotations/tests/run_rotation_tests.lua` → all suites PASS (currently 162)
    3. `lua EaxRotations/tests/run_leveling_tests.lua` → all suites PASS (currently 14)
    4. Manual smoke: no files outside `.lua`/`.md` in `EaxRotations/`
    5. No raw `unit == me` / `unit ~= target` patterns remain anywhere in `EaxRotations/classes/`

## Risk Matrix

| Risk | Impact | Mitigation |
|------|--------|-----------|
| NS.same_unit not in core_sylvanas | Cat fix breaks | Already verified by scan agent; tests will catch regression |
| False positive: legitimate ref check | Strategy falsely denies cast | Add negative test cases ensuring legitimate same-unit still passes |
| power_type constant drift across expansions | Wrong readings | Only check TBC constant set per spec |
| Removing scan_pack throttling breaks other specs | Pack pack data stale | Restore derived flags from enemy_count only — no pack data needed for them |
| Existing tests mock NS but lack same_unit | Test breakage | Add `NS.same_unit` mock to test namespaces (already done for cat) |

## Acceptance Contract

- All 4 bug classes eliminated across all 9 classes
- Same tests pass (162 rotation + 14 leveling)
- New regression tests for each fix
- No `obj ~= target`, `enemy_target == me`, `unit ~= me`, etc. raw comparisons in classes/
- `EaxRotations/` contains only `.lua` and `.md` files
- All modified files: `luac -p` exit 0, `lsp_diagnostics` clean

## Out of Scope

- Performance optimization beyond fixing the specific bugs
- Adding new strategy features
- Refactoring specs beyond the bug fix sites
- Modifying `EaxRotations/core_sylvanas.lua` (NS.same_unit already exists)
- Adding new shared modules

## Sequences and Parallelism

Phases 2-3 can run in parallel (different files, no dependencies).
Phase 1 must complete first; Phase 7-8 are final.

Suggested file grouping for parallel agents:
- **Group A:** Warrior Prot (Task 2.1)
- **Group B:** Paladin Prot + Priest Disc (Tasks 2.2-2.3)
- **Group C:** Audit scans (Tasks 3.1, 4.1, 5.1, 6.1) — read-only
- **Group D:** Test add (Task 7)

Each group ends with verification per task; final convergence run_rotation_tests.lua gates the whole plan.
