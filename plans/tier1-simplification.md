# Implementation Plan: Tier 1 Simplification

**Created:** 2026-06-11
**API Surface:** `core_sylvanas.lua` (NS.*), `class_sylvanas.lua` (NS.<Class>Constants), `shared/leveling_sylvanas.lua`
**Docs References:** `AGENTS.md`, `apidocs/pages/dev/api/core.md`
**Status:** ✅ COMPLETED — 115/116 rotation + 11/11 leveling tests pass (1 pre-existing failure)

## Overview

Five low-risk, high-impact cleanup actions targeting the most egregious code duplication in EaxRotations. Zero behavior change. Estimated savings: **~790 lines of dead/duplicate code across 40+ files**.

## Baseline Verification (run BEFORE any changes)

```powershell
# Syntax check ALL files
Get-ChildItem -Path EaxRotations -Recurse -Filter '*.lua' | ForEach-Object { luac -p $_.FullName }

# Rotation tests (95 suites)
lua EaxRotations/tests/run_rotation_tests.lua

# Leveling tests (11 suites)
lua EaxRotations/tests/run_leveling_tests.lua
```

---

## Action 1: Remove 3 Dead/Deprecated NS Stubs

**Files:** `core_sylvanas.lua`, `classes/priest/smite_sylvanas.lua`, `classes/priest/smite_vanilla.lua`

### What

Three NS.* functions are dead/deprecated with zero or trivial callers:

| Function | Lines | Callers | Action |
|----------|-------|---------|--------|
| `NS.get_setting_cached(key, default)` | ~1203-1207 | **0 callers** | Remove entirely |
| `NS.register_izi_buff_events()` | ~1209-1212 | **0 callers** | Remove entirely |
| `NS.match_fail(reason)` | ~4337-4339 | **2 callers** (smite_sylvanas, smite_vanilla) | Replace callers with `false` then remove |

### NOT removing (stubs with active consumers):
- `NS.player_control_locked()` — called by `interrupt_manager_sylvanas.lua`, `racial_manager_sylvanas.lua`, `kebab_sylvanas.lua`, `kebab_vanilla.lua`. Kept as future hook point.
- `NS.has_breakable_cc_nearby()` — called by `main_sylvanas.lua`, `kebab_sylvanas.lua`, `kebab_vanilla.lua`. Kept as future hook point.

### Task 1.1: Remove dead stubs from core_sylvanas.lua

**Files:** `core_sylvanas.lua`

- Remove `NS.get_setting_cached()` function (lines ~1203-1207)
- Remove `NS.register_izi_buff_events()` function (lines ~1209-1212)
- Remove `NS.match_fail()` function (lines ~4337-4339)
- **Acceptance:** `luac -p core_sylvanas.lua` passes, grep for removed names returns 0 results
- **Verify:** `luac -p core_sylvanas.lua`

### Task 1.2: Replace match_fail callers with `false`

**Files:** `classes/priest/smite_sylvanas.lua`, `classes/priest/smite_vanilla.lua`

In both files, find all `return NS.match_fail("...")` calls and replace with:
```lua
return false  -- was NS.match_fail(reason); match_fail removed (always returned false)
```

Count: 4 occurrences in smite_sylvanas.lua, ~4 in smite_vanilla.lua.

- **Acceptance:** `luac -p` passes on both files, no `match_fail` references remain
- **Verify:** `luac -p classes/priest/smite_sylvanas.lua`, `luac -p classes/priest/smite_vanilla.lua`

---

## Action 2: Consolidate 17 NS Alias Wrappers

**File:** `core_sylvanas.lua`

### What

17 NS.* functions are pure aliases — `function NS.alias(args) return NS.real(args) end`. Convert to simple table assignments to eliminate ~60 lines of redundant wrapper code.

### Aliases to consolidate

Convert these verbose functions to one-line assignments:

| Current (verbose) | → Replace with |
|---|---|
| `function NS.has_buff(unit, ids) return NS.buff_up(unit, ids) end` | `NS.has_buff = NS.buff_up` |
| `function NS.has_player_buff(ids) return NS.buff_up(NS.GetPlayer(), ids) end` | Keep as wrapper (GetPlayer() call) |
| `function NS.has_debuff(unit, ids) return NS.debuff_up(unit, ids) end` | `NS.has_debuff = NS.debuff_up` |
| `function NS.has_player_debuff(ids) return NS.debuff_up(NS.GetPlayer(), ids) end` | Keep as wrapper |
| `function NS.has_target_debuff(target, ids) return NS.debuff_up(target, ids) end` | `NS.has_target_debuff = NS.debuff_up` |
| `function NS.get_debuff_stacks(unit, ids) return NS.debuff_stacks(unit, ids) end` | `NS.get_debuff_stacks = NS.debuff_stacks` |
| `function NS.spell_exists(spell) return NS.is_spell_learned(spell) ... end` | `NS.spell_exists = NS.is_spell_learned` (if no extra logic) |
| `NS.get_spell_cooldown_remaining` (alias variable) | Already an alias — OK |
| `NS.cast_position` (alias variable) | Already an alias — OK |
| `NS.get_distance` (alias variable) | Already an alias — OK |
| `NS.use_item` (alias variable) | Already an alias — OK |
| `NS.get_pet` (alias variable) | Already an alias — OK |
| `NS.spell_in_range` (alias variable) | Already an alias — OK |
| `function NS.is_melee_target(target, me) return is_melee_target(target, me) end` | `NS.is_melee_target = is_melee_target` |
| `function NS.unit_distance(unit, other) return unit_distance(unit, other) end` | `NS.unit_distance = unit_distance` |
| `function NS.vanilla_spell_id_allowed(id) return vanilla_spell_id_allowed(id) end` | `NS.vanilla_spell_id_allowed = vanilla_spell_id_allowed` |
| `function NS.gate_overheal(spell_key, ...) return NS.HealerDeficit.gate_spell_overheal(...) end` | Keep if HealerDeficit may not exist at load time |

**Important**: For aliases where the target is a private local function (not yet exported), keep the wrapper unless the private function is hoisted above the alias. For aliases like `gate_overheal` that indirect through a conditional module, keep the wrapper.

- **Acceptance:** `luac -p core_sylvanas.lua` passes, all tests pass
- **Verify:** `luac -p core_sylvanas.lua`, `lua EaxRotations/tests/run_rotation_tests.lua`

---

## Action 3: Replace Spec-Level NS Wrappers with Direct NS.* Calls

**Files:** 30+ spec files across all 9 classes

### What

Every spec file defines local wrappers that do nothing but nil-guard NS.* calls. NS.* already nil-guards internally. Replace each local wrapper with direct NS.* calls in the match functions that use them.

### Wrapper Inventory

| Wrapper | Files | Replacement |
|---------|-------|-------------|
| `local function buff_up(unit, ids)` → `NS.buff_up(unit, ids) or false` | 8 files (warrior arms/fury/kebab/protection, druid bear/cat, + vanilla) | Direct `NS.buff_up(unit, ids) or false` |
| `local function debuff_up(unit, ids)` → `NS.debuff_up(unit, ids) or false` | 3 files (fury_vanilla, cat, bear) | Direct `NS.debuff_up(unit, ids) or false` |
| `local function debuff_remains(unit, ids)` → `NS.debuff_remains(unit, ids) or 0` | 5 files | Direct `NS.debuff_remains(unit, ids) or 0` |
| `local function buff_remains(unit, ids)` → `NS.buff_remains(unit, ids) or 0` | 5 files | Direct `NS.buff_remains(unit, ids) or 0` |
| `local function debuff_stacks(unit, ids)` → `NS.debuff_stacks(unit, ids) or 0` | 4 files | Direct `NS.debuff_stacks(unit, ids) or 0` |
| `local function cooldown(spell, fallback)` → `NS.cooldown_remains(spell, fallback) or 0` | 2 files | Direct `NS.cooldown_remains(spell, fallback) or 0` |
| `local function ready(spell, target, opts)` → `NS.spell_ready(spell, target, opts) or false` | 3 files | Direct `NS.spell_ready(spell, target, opts) or false` |
| `local function setting(context, key, fallback)` → 4-line get_setting wrapper | 7 files | Inline: `(context.settings and context.settings[key]) or NS.get_setting(key, fallback) or fallback` |
| `local function player_unit()` → `context.me or NS.GetPlayer()` | 4 files | Inline `context.me or NS.GetPlayer()` |

### Approach per file

1. Remove the local function definition
2. Find all call sites (e.g., `buff_up(me, IDS)`)
3. Replace with direct NS call (e.g., `NS.buff_up(me, IDS) or false`)
4. If the function has a different fallback pattern than NS, preserve the spec's intent

### Per-file summary

| File | Wrappers to Remove |
|------|-------------------|
| `warrior/arms_sylvanas.lua` | buff_up, debuff_up, debuff_remains, debuff_stacks, cooldown, ready, setting, player_unit |
| `warrior/arms_vanilla.lua` | buff_up, debuff_remains, debuff_stacks, cooldown, ready, setting |
| `warrior/fury_sylvanas.lua` | buff_up, debuff_remains, debuff_stacks, cooldown, ready, setting, player_unit |
| `warrior/fury_vanilla.lua` | buff_up, debuff_up, debuff_remains, debuff_stacks |
| `warrior/protection_sylvanas.lua` | setting |
| `warrior/protection_vanilla.lua` | setting |
| `warrior/kebab_sylvanas.lua` | setting |
| `warrior/kebab_vanilla.lua` | setting |
| `druid/bear_sylvanas.lua` | buff_up, debuff_up, debuff_remains, buff_remains, debuff_stacks |
| `druid/cat_sylvanas.lua` | buff_up, debuff_up, debuff_remains, buff_remains |
| `druid/resto_sylvanas.lua` | buff_remains |
| `druid/balance_sylvanas.lua` | buff_remains |
| `druid/caster_sylvanas.lua` | (check) |
| `mage/arcane_sylvanas.lua` | setting |
| `paladin/retribution_sylvanas.lua` | ready |
| `priest/holy_sylvanas.lua` | setting |
| `priest/holy_vanilla.lua` | setting |
| `warrior/middleware_sylvanas.lua` | player_unit |
| `mage/middleware_sylvanas.lua` | player_unit |

- **Acceptance:** All wrapper definitions removed, call sites updated, `luac -p` passes on all changed files
- **Verify:** `luac -p` on every changed file, rotation + leveling test suites

---

## Action 4: Create shared/leveling_helpers_sylvanas.lua

**New file:** `shared/leveling_helpers_sylvanas.lua`
**Modified files:** 10 leveling files (5 sylvanas + 5 vanilla)

### What

All leveling files contain identical helper functions. Extract into a shared module:
- `has_buff(buff_ids)` — 100% identical across all 10 files
- `spell_ready(spell_action)` — near-identical across 7 files
- `try_cast(spell_action, ...)` — near-identical across 9 files
- `buff_remains(buff_ids)` — in 2 leveling files
- `debuff_stacks(unit, ids)` — in 2 leveling files

### Module API

```lua
-- shared/leveling_helpers_sylvanas.lua
local M = {}

function M.has_buff(buff_ids)
    local player = core.object_manager.get_local_player()
    if not player then return false end
    if type(buff_ids) == "number" then buff_ids = { buff_ids } end
    local ok, result = pcall(core.spell_book.get_buff, player, buff_ids)
    return ok and result ~= nil and result or false
end

function M.spell_ready(spell_action)
    if not spell_action then return false end
    return spell_action:is_ready() and spell_action:get_cooldown_remaining() == 0
end

function M.try_cast(spell_action, target)
    if not spell_action then return false end
    if not spell_action:is_ready() then return false end
    if spell_action:get_cooldown_remaining() > 0 then return false end
    return spell_action:cast(target)
end

return M
```

### Per-file changes

Each leveling file changes from:
```lua
local function has_buff(buff_ids) ... end
local function spell_ready(spell_action) ... end
local function try_cast(spell_action, target) ... end
```

To:
```lua
local L = require("shared/leveling_helpers_sylvanas")
-- Use: L.has_buff(...), L.spell_ready(...), L.try_cast(...)
```

Then replace all call sites: `has_buff(X)` → `L.has_buff(X)`, etc.

- **Acceptance:** All 10 files updated, `luac -p` passes, no remaining `local function has_buff` in leveling files
- **Verify:** `luac -p shared/leveling_helpers_sylvanas.lua`, `lua EaxRotations/tests/run_leveling_tests.lua`

---

## Action 5: Leveling Files Read Buff ID Tables from NS.<Class>Constants

**Files:** 8 of 9 leveling files (all except hunter which already does this)

### What

Leveling files manually duplicate buff/debuff spell ID rank arrays that already exist in `class_sylvanas.lua` as `NS.<Class>Constants`. Replace the local copies with references to the authoritative source.

### Example (warrior leveling)

Before:
```lua
local BATTLE_SHOUT_BUFF = { 25289, 2048, 11551, 11550, 11549, 6192, 5242, 6673 }
```

After:
```lua
local BATTLE_SHOUT_BUFF = NS.WarriorConstants.BATTLE_SHOUT_IDS
```

### Per-class inventory

Each leveling file has 3-10 buff/debuff ID arrays duplicated from the corresponding `class_sylvanas.lua` CONSTANTS. The exact arrays vary by class but include things like REND_DEBUFF, DEMORALIZING_SHOUT_DEBUFF, THUNDER_CLAP_DEBUFF, etc.

### Important: Vanilla-only ranks

Some vanilla leveling files use shorter arrays (omitting TBC-only ranks like 25289). These need special handling:
- Option A: Keep vanilla-specific arrays local (simplest, no behavior change)
- Option B: Add vanilla-specific constant tables to class_sylvanas.lua

**Recommendation: Option A** for Tier 1. Only replace in sylvanas leveling files. Vanilla files are lower priority.

- **Acceptance:** 5 sylvanas leveling files updated to reference `NS.<Class>Constants.*`, `luac -p` passes on all, leveling tests pass
- **Verify:** `lua EaxRotations/tests/run_leveling_tests.lua`

---

## Execution Order

All 5 actions are independent and can run in parallel:

```
Action 1 ─┐
Action 2 ─┤
Action 3 ─┼── Parallel ──► Final validation (all tests)
Action 4 ─┤
Action 5 ─┘
```

### Final Validation (after all actions)

```powershell
# Syntax check ALL files
Get-ChildItem -Path EaxRotations -Recurse -Filter '*.lua' | ForEach-Object { luac -p $_.FullName }

# Rotation tests (95 suites)
lua EaxRotations/tests/run_rotation_tests.lua

# Leveling tests (11 suites)
lua EaxRotations/tests/run_leveling_tests.lua
```

---

## Risks

| Risk | Impact | Mitigation |
|------|--------|------------|
| NS alias collapse breaks callers expecting function identity | Type errors | Verify no caller does `if NS.alias == some_ref` |
| Removing spec-level buff_up changes fallback value | Rotation behavior change | NS.buff_up already returns false for nil; `or false` is redundant |
| Leveling helper module API mismatch | Leveling tests fail | Verify exact behavior match before switching |
| Buff ID array reference misses vanilla/TBC rank differences | Wrong rank detected | Only replace in sylvanas files; keep vanilla local |

---

## Estimated Impact

| Action | Lines Saved | Files Changed |
|--------|------------|---------------|
| 1. Dead stubs | ~20 | 3 |
| 2. Alias consolidation | ~60 | 1 |
| 3. NS wrapper replacement | ~300 | ~30 |
| 4. Leveling helpers module | ~200 | 11 (1 new + 10 modified) |
| 5. Buff ID dedup | ~150 | 5 |
| **Total** | **~730** | **~50** |
