# Execution Plan: Warlock Remaining Tests, Polish & Closure

**Created:** 2026-06-23
**Parent:** `plans/_archive/warlock-imp-sac-backdraft-fix.md` (archived 2026-06-23, commit 3a5bf13)
**Scope:** Add test coverage for what's already fixed + 1 missing helper + close out orphan RED test.
**API Surface:** `NS.buff_up`, `NS.GetPet`, `NS.unit_alive`, `NS.try_cast`, `NS.is_spell_learned`
**Verification Baseline:** luac -p clean, 166 rotation + 11 leveling tests green.

---

## State Assessment — What's Already Done

Everything below existed in production code BEFORE this plan. No implementation work needed for these tasks:

| Original Task | Status | Evidence |
|--------------|--------|----------|
| **2.1** Destruction constants | ✅ Done | `DEMONIC_SACRIFICE_AURA_ALL` at line 24, actions at lines 27-45 |
| **2.2** has_backdraft in build_state | ✅ Done | Hardcoded `false` at line 70 — correct for TBC |
| **2.3** BackdraftSoulBolt | ✅ Skip | Backdraft is Wrath-only, not in TBC DBC |
| **2.4** Summon predicate DS gate | ✅ Done | Line 302: `if state.has_demonic_sacrifice then return false end` |
| **2.5** 5 separate summon actions | ✅ Functional | All share `summon_pet_matches` (line 387-388). Not elegant but no loop bug. |
| **2.6** destruction_vanilla parity | ✅ Done | `has_backdraft` at line 80 |
| **4.1** Affliction SummonFelhunter | ✅ Done | Lines 913-925 with DS aura gate at line 919 |
| **4.2** Demonology Imp fallback | ✅ Done | `needs_imp_fallback` at line 145 with DS gate at line 151 |
| **4.4** Leveling summon OOC gate | ✅ Done | Lines 180-198: allows OOC, checks DS aura, checks Imp free, shard gate |
| **4.5** Affliction pet_alive audit | ✅ Done | build_state at line 189 uses `pcall` safely |
| **5.1/5.2** DS test fixture | ✅ Done | `test_destruction_demonic_sacrifice.lua` (193 lines, comprehensive) |
| **5.6** Leveling summon OOC tests | ✅ Done | `test_leveling_warlock.lua` lines 1702-1739 covers OOC summon |
| **6.1** pet_manager header | ✅ Done | Commit 3a5bf13: "Hunter" → "Hunter + Warlock" |
| **6.4** _active.md update | ✅ Done | Already marked "complete → archived" |

---

## What Remains

### 1. Orphan RED test: `test_warlock_imp_machine_gun_2026_06.lua` — ✅ RESOLVED (Option B)

**Resolution:** File was deleted in commit 93f96ae9 ("feat(audit): omnibus perfection audit v3").
The test was never registered in `run_rotation_tests.lua` and asserted an unimplemented
`imp_firebolt_pacing` strategy. Option B (remove) was the correct choice — the feature was
speculative and not a bug fix. Zero references remain in the tests directory.

### 2. Missing helper: `M.get_current_pet_type()` (Task 6.2)

**File:** `EaxRotations/shared/pet_manager_sylvanas.lua`

**What's missing:** A function like:
```lua
function M.get_current_pet_type()
    local me = ...  -- context or global
    if not me then return "unknown" end
    local ok, pet = pcall(function() return me:get_pet() end)
    if not ok or not pet then return "unknown" end
    local ok2, id = pcall(function() return pet:get_creature_family() end)
    if not ok2 or not id then return "unknown" end
    -- map creature family ID → pet type string
    local PET_FAMILIES = { [3] = "imp", [33] = "felhunter", [38] = "felguard", [24] = "succubus", [25] = "voidwalker" }
    return PET_FAMILIES[id] or "unknown"
end
```

This would let specs detect `is_imp` vs `is_felguard` without raw API calls. Right now, no spec uses this pattern (they all use `is_spell_learned` + `has_pet` logic, which is sufficient).

**Recommendation:** Low priority. Only implement if another task needs it. For pure "tests + polish" scope, **defer**.

### 3. Missing tests for existing code (optional)

| What | Test Coverage | Gap |
|------|--------------|-----|
| Affliction SummonFelhunter | No separate test file | Strategy exists at line 913 but no test asserts it exists |
| Demonology SummonImp fallback | Covered implicitly in demonology test | No test for `needs_imp_fallback` specifically |
| Destruction DemonicSacrifice | ✅ `test_destruction_demonic_sacrifice.lua` | Comprehensive (193 lines) |
| Leveling summon OOC | ✅ `test_leveling_warlock.lua` lines 1702-1739 | Good coverage |
| Middleware emergency DS | No test | Simple HP-gated defensive — low risk |

**Recommendation:** Low priority. The code is working and the summon loop was the critical bug. The existing tests cover the core DS/summon behavioral invariant.

---

## Execution Plan

### Wave 1 (Parallel — Independent)

- [x] **1.1 Resolve orphan RED test** — Option B (remove) completed in commit 93f96ae9
  - **Files:** `EaxRotations/tests/test_warlock_imp_machine_gun_2026_06.lua` — DELETED
  - **Verify:** File no longer exists; 0 references to `imp_firebolt_pacing`/`imp_machine_gun` in tests/

- [ ] **1.2 Add affliction SummonFelhunter test** (optional, low priority — deferred)

### Wave 2 (Sequential — after Wave 1)

- [ ] **2.1 Wire new test into test runner** (if 1.2 was done)
  - **Files:** `EaxRotations/tests/run_rotation_tests.lua`
  - **Action:** Add `dofile("test_affliction_summon_felhunter.lua")` or equivalent registration
  - **Verify:** `lua EaxRotations/tests/run_rotation_tests.lua` → all suites pass

- [ ] **2.2 Final validation**
  - **Action:** `luac -p` on all touched files, run rotation + leveling suites
  - **Verify:** 166 rotation + 11 leveling tests green, LSP zero errors

---

## Recommended Shortcut (Minimum Viable Closure)

Given the parent plan is already archived and all production bugs are fixed:

1. **Delete** `test_warlock_imp_machine_gun_2026_06.lua` — it's an orphan RED test for an unimplemented feature
2. **Write** `test_affliction_summon_felhunter.lua` (20 lines) to cover the existing strategy
3. **Wire** into `run_rotation_tests.lua`
4. **Run** full validation

This gives test coverage for all 3 warlock specs' summon behavior without implementing a new feature.

**Total effort:** ~15 minutes for option B (delete) + optional test additions.
