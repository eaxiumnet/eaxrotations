# EaxRotations Bugfix Plan — 2026-06-13

**Scope:** Fix verified production-code bugs and one test-runner compliance issue in `EaxRotations/`.
**Baseline:** 119 rotation suites pass, 11 leveling suites pass, `luac -p` clean on all files.

## Verified Bugs

### BUG-1: `bear_vanilla.lua` Pattern 14 nil-guard violations
**File:** `EaxRotations/classes/druid/bear_vanilla.lua`
**Lines:** 542, 544, 554, 561, 562
**Issue:** `state.enemy_count`, `state.aoe_threshold`, `state.rage`, `state.maul_rage` compared without `or 0` / `or 3` guards. Line 569 already correctly uses `(state.rage or 0)`, so the file is inconsistent.
**Fix:** Apply guards matching AGENTS.md Pattern 14 defaults.

### BUG-2: `subtlety_vanilla.lua` Pattern 14 nil-guard violations
**File:** `EaxRotations/classes/rogue/subtlety_vanilla.lua`
**Lines:** 340, 350, 413, 421
**Issue:** `state.hp` compared without `or 100`; `state.energy` compared without `or 0`.
**Fix:** Apply guards matching AGENTS.md Pattern 14 defaults.

### BUG-3: `combat_sylvanas.lua` tick-tracker state not grouped with combat state
**File:** `EaxRotations/classes/rogue/combat_sylvanas.lua`
**Lines:** 44–71
**Issue:** `_last_energy` and `_last_tick_time` are module-level mutable statics, separate from the intentional module-level `combat_state` table. This groups state poorly and makes the tick tracker easy to miss in refactor/review.
**Fix:** Move `_last_energy` and `_last_tick_time` into `combat_state` fields (`last_energy_tick`, `last_tick_time`). Preserve the exact original `[19,21]` heuristic and desync fallback. No behavior change.

### BUG-4: Test runners use banned API `io.popen`
**Files:** `EaxRotations/tests/run_rotation_tests.lua`, `EaxRotations/tests/run_leveling_tests.lua`
**Lines:** 195, 35
**Issue:** `io.popen` is banned per AGENTS.md. The runners use it to spawn a fresh `lua` process per test for isolation.
**Fix:** Refactor to in-process execution using `loadfile`/`dofile` + `pcall` while preserving the existing pass/fail reporting and exit-code behavior. Validate that the full suites still pass. If isolation loss causes failures, fix the state leaks rather than reintroducing `io.popen`.

## Out of Scope

- `EaxRotations/shared/apl_parser.lua` `loadstring`+`setfenv`: module is test-only (only referenced by `test_apl_parser.lua`). Documented as compliance risk, not fixed here.
- `test_cross_expansion_spell_validation.lua` line 43 `io.popen`: documented as compliance risk for a future sweep.
- `test_reset_api_health*.lua` `debug.*` usage: documented as compliance risk for a future sweep.
- Style-only issues (`_G_E` vs `NS`, magic numbers, vanilla boilerplate): not bugs.

## Implementation Order

1. **T1** — Fix BUG-1 + extend `test_state_field_nil_guards_2026_06.lua`
2. **T2** — Fix BUG-2 + extend `test_state_field_nil_guards_2026_06.lua`
3. **T3** — Fix BUG-3 (preserve behavior)
4. **T4** — Fix BUG-4 (refactor runners)
5. **T5** — Full validation: `luac -p`, `run_rotation_tests.lua`, `run_leveling_tests.lua`, LSP diagnostics
6. **T6** — Atomic commits (one per bug)

T1, T2, T3, T4 are independent and can run in parallel.

## Exact Code Changes

### T1: bear_vanilla.lua
```lua
-- L542
if (state.enemy_count or 0) < (state.aoe_threshold or 3) then return false end
-- L544
if (state.rage or 0) < RAGE_SWIPE then return false end
-- L554
if (state.rage or 0) < RAGE_SWIPE then return false end
-- L561
if (state.enemy_count or 0) >= (state.aoe_threshold or 3) and (state.rage or 0) < HIGH_RAGE then return false end
-- L562
if (state.rage or 0) < (state.maul_rage or 40) then return false end
```

### T2: subtlety_vanilla.lua
```lua
-- L340
if (state.hp or 100) <= setting(context, "rogue_vanish_hp", 20) and ...
-- L350
if (state.hp or 100) > setting(context, "subtlety_prep_hp", 40) then return false end
-- L413
if (state.energy or 0) < ENERGY_FINISHER then return false end
-- L421
if (state.energy or 0) < ENERGY_FINISHER then return false end
```

### T3: combat_sylvanas.lua
- Delete module locals `_last_energy` and `_last_tick_time`.
- Add to `combat_state` table: `last_energy_tick = 0, last_tick_time = 0`.
- Change `get_next_tick_in(energy, settings)` to `get_next_tick_in(state, energy)` and read/write `state.last_energy_tick` / `state.last_tick_time`.
- Update call sites in `should_pool_energy` and `should_spend_energy` to pass `combat_state`.

### T4: test runners
- Extract a shared `EaxRotations/tests/test_runner_lib.lua` or inline a `run_test_file(path, mode)` helper in each runner.
- Replace `io.popen(lua_bin .. " " .. quote(path))` with `pcall(dofile, path)`.
- Capture output by temporarily replacing `print` and `io.write` if verbose mode needs it; otherwise rely on the test's own `print` output.
- Preserve pass/fail counting, verbose/quiet modes, and exit code 1 on failure.

## Verification Commands

```bash
# Syntax
luac -p EaxRotations/classes/druid/bear_vanilla.lua
luac -p EaxRotations/classes/rogue/subtlety_vanilla.lua
luac -p EaxRotations/classes/rogue/combat_sylvanas.lua
luac -p EaxRotations/tests/run_rotation_tests.lua
luac -p EaxRotations/tests/run_leveling_tests.lua

# Test suites
lua EaxRotations/tests/run_rotation_tests.lua
lua EaxRotations/tests/run_leveling_tests.lua

# Banned-API sweep on touched production files
grep -nE "io\.popen|os\.execute|debug\.|ffi\.C|math\.sqrt\(" \
    EaxRotations/classes/druid/bear_vanilla.lua \
    EaxRotations/classes/rogue/subtlety_vanilla.lua \
    EaxRotations/classes/rogue/combat_sylvanas.lua
# Expected: zero output

# LSP diagnostics
lsp_diagnostics EaxRotations/classes/druid/bear_vanilla.lua
lsp_diagnostics EaxRotations/classes/rogue/subtlety_vanilla.lua
lsp_diagnostics EaxRotations/classes/rogue/combat_sylvanas.lua
lsp_diagnostics EaxRotations/tests/run_rotation_tests.lua
lsp_diagnostics EaxRotations/tests/run_leveling_tests.lua
```

## Commit Messages

1. `fix(bear_vanilla): Pattern 14 nil-guards for 5 numeric state comparisons`
2. `fix(subtlety_vanilla): Pattern 14 nil-guards for hp/energy comparisons`
3. `refactor(combat_sylvanas): group energy tick tracker state into combat_state`
4. `refactor(tests): replace io.popen with portable pcall/dofile runner`

## Risks

- T3 preserves exact heuristic; behavior unchanged.
- T4 loses process isolation. If tests leak global state, failures must be fixed at the source, not by re-adding `io.popen`.
- If T4 proves unstable, fallback is to document `io.popen` as a necessary exception and leave runners unchanged.
