# GLM 5.2 Burst Optimization Session — Work Plan

**Created:** 2026-06-24
**Window:** 2-hour GLM 5.2 burst session
**Status:** READY — awaiting OpenCode restart to pick up GLM 5.2 config
**Config:** `oh-my-openagent.json` updated: 20 GLM 5.2 primary refs, 5 concurrent agents, max reasoning

---

## Execution Strategy

**5 parallel waves**, each gated by `luac -p` + test suite. GLM 5.2's 1M context + max reasoning
handles complex multi-file analysis; the 5-agent concurrency maximizes throughput.

- **Wave 1**: Critical bug fixes + cleanup (self-contained, high-confidence)
- **Wave 2**: Performance/GC fixes + hot-path optimizations
- **Wave 3**: Reference project porting (Sonah/NAG/NextActionTBC patterns)
- **Wave 4**: LibHealComm-4.0 integration + healing improvements
- **Wave 5**: Architecture refactor (core_sylvanas.lua split, spec_kit conversion)

Each wave has independent tasks that can run as **parallel `deep` category subagents**.
Verification gate between waves: `luac -p` + `lua EaxRotations/tests/run_rotation_tests.lua`
+ `lua EaxRotations/tests/run_leveling_tests.lua`.

---

## Wave 1 — Critical Fixes & Data Cleanup (5 parallel tasks)

### Task 1.1: Fix try_cast IZI bypass bug
**Priority:** CRITICAL
**Files:** `EaxRotations/core_sylvanas.lua` (try_cast function), `EaxRotations/tests/debug_cast_fallback.lua`
**Issue:** When IZI returns nil, `try_cast` falls through to raw `core.input.cast_target_spell`, bypassing `cast_safe` validation.
**Fix:** Make the IZI-unavailable path fail-closed — return false with a reason instead of raw-casting.
**Verify:** `lua EaxRotations/tests/debug_cast_fallback.lua` passes; `luac -p core_sylvanas.lua` passes.
**Delegate:** `category="deep"` — needs careful analysis of all `try_cast` call sites.

### Task 1.2: Remove dead DRTracker/EnemyCDTracker references
**Priority:** CRITICAL
**Files:** `EaxRotations/shared/pvp_burst_window_sylvanas.lua` (lines 92-100, 138)
**Issue:** References `NS.DRTracker.is_dr_immune` and `NS.EnemyCDTracker` — both modules deleted in Task 1.3 cleanup. Nil-guarded so won't crash, but burst scoring always misses DR immunity checks.
**Fix:** Remove dead references or replace with inline DR immunity check using available API. Check if `aura_cache_sylvanas.lua` can provide DR-like data.
**Verify:** `luac -p pvp_burst_window_sylvanas.lua`; run `test_arena_priority.lua`.
**Delegate:** `category="quick"` — surgical removal.

### Task 1.3: Strip 35 DEBUG/placeholder entries from data bridges
**Priority:** HIGH
**Files:**
- `EaxRotations/shared/wowhead_data_bridge_sylvanas.lua` (18 entries)
- `EaxRotations/shared/wowhead_data_bridge_spell_index_tbc_sylvanas.lua` (2 entries)
- `EaxRotations/shared/wowhead_data_bridge_spell_index_vanilla_sylvanas.lua` (3 entries)
- `EaxRotations/shared/wowhead_data_bridge_item_index_sylvanas.lua` (12 entries)
**Issue:** DEBUG test items ("ALEX BUG TEST ITEM" id 17122, "QR XXXX" placeholders, "DEBUG Create Samophlange Manual", "DEBUG - Headless Horseman Fire Node" id 32965, "Complimentary Brewfest Sampler DEBUG" id 33288) bloat data and indicate incomplete scraping.
**Fix:** Remove all entries matching pattern `DEBUG`, `XXXX`, `ALEX BUG`, `QR XXXX`. Verify none are referenced by rotation code via grep.
**Verify:** `luac -p` on all 4 files; grep rotation files for removed item IDs; run `test_tbc_consumable_data.lua`.
**Delegate:** `category="quick"` — mechanical removal with grep verification.

### Task 1.4: Fix duplicate spell ID 28176 conflict (Fel Armor / Spellstone)
**Priority:** MEDIUM
**File:** `EaxRotations/shared/offensive_dispel_sylvanas.lua` (line 105)
**Issue:** Fel Armor (28176) and Spellstone (28176) share the same spell ID in the HIGH tier dispel data. One overwrites the other.
**Fix:** Verify against DBC which spell 28176 actually is. If both exist with different IDs, correct the data. If it's truly shared, add a note and handle both cases.
**Verify:** `luac -p`; `lua EaxRotations/tests/run_rotation_tests.lua`.
**Delegate:** `category="quick"` — data correction.

### Task 1.5: Register orphan test files in runner
**Priority:** MEDIUM
**Files:** `EaxRotations/tests/run_rotation_tests.lua`, `EaxRotations/tests/test_reset_api_health.lua`, `EaxRotations/tests/test_reset_api_health_spell_integration.lua`
**Issue:** Two test files exist on disk but are not registered in the test runner.
**Fix:** Add both to the `run_rotation_tests.lua` registration list in the correct alphabetical position.
**Verify:** `lua EaxRotations/tests/run_rotation_tests.lua` — both new tests run and pass.
**Delegate:** `category="quick"` — 2-line additions.

---

## Wave 2 — Performance & Hot-Path Fixes (4 parallel tasks)

### Task 2.1: Fix pvp_burst_window GC garbage
**Priority:** HIGH
**File:** `EaxRotations/shared/pvp_burst_window_sylvanas.lua` (line 158, 82, 118)
**Issue:** `local reasons = {}` + 10x `table.insert()` allocated per frame in `M.score()`. Also `pairs(DEFENSIVE_BUFFS)` / `pairs(OFFENSIVE_BUFFS)` iterates full tables every call.
**Fix:**
1. Replace `local reasons = {}` with static `REASONS_BUF = { n = 0 }` at module level
2. Reset with `REASONS_BUF.n = 0` instead of allocating
3. Convert `DEFENSIVE_BUFFS`/`OFFENSIVE_BUFFS` to numeric-indexed arrays for `ipairs` (faster than `pairs`)
**Verify:** `luac -p`; `lua tests/test_arena_priority.lua`; `lua tests/test_pvp_burst_window.lua` if exists.
**Delegate:** `category="deep"` — hot-path optimization needs careful analysis.

### Task 2.2: Fix Balance hot-path require() pattern
**Priority:** HIGH
**Files:** `EaxRotations/classes/druid/balance_sylvanas.lua` (lines 190, 198), `EaxRotations/classes/druid/balance_vanilla.lua` (lines 155, 163)
**Issue:** Per-frame closures use `_fnd_mod` inline access pattern for `find_dead_party_ally` instead of module-level cached reference. Module-level require at line 17 exists but isn't used in these closures.
**Fix:** Replace `_fnd_mod` inline access with the module-level variable from line 17. Remove the per-frame `pcall(require, ...)` pattern in the closures.
**Verify:** `luac -p` on both files; `lua tests/test_balance_custom_matches.lua`; `lua tests/test_balance_faerie_fire.lua`.
**Delegate:** `category="quick"` — mechanical refactor.

### Task 2.3: Add Readiness (23989) to Hunter
**Priority:** HIGH (from post-audit-improvements.md Task 1.1)
**Files:** 3 hunter files (beast_mastery_sylvanas.lua, marksmanship_sylvanas.lua, survival_sylvanas.lua)
**Issue:** Hunter Readiness spell (23989) — resets all hunter cooldowns — not wired into any rotation.
**Fix:** Add Readiness as a high-priority strategy when major cooldowns (Bestial Wrath, Rapid Fire, etc.) are on cooldown. Gate behind a menu toggle `eaxhunter_use_readiness`.
**Reference:** NAG Hunter.lua has Readiness in its priority chain. Sonah HunterBeastMastery.lua also uses it.
**Verify:** `luac -p` on 3 files; `lua tests/test_hunter_aspect_matches.lua`; verify spell 23989 exists in DBC.
**Delegate:** `category="deep"` — needs cross-reference with NAG/Sonah hunter rotations.

### Task 2.4: Create validate.cmd gate
**Priority:** HIGH (from refactor plan Phase 3.1)
**File:** `EaxRotations/validate.cmd` (new)
**Issue:** No automated completion gate exists. Every task requires manual `luac -p` + test runs.
**Fix:** Create a single batch script that:
1. Runs `luac -p` on all modified `.lua` files (git diff)
2. Runs `lua EaxRotations/tests/run_rotation_tests.lua`
3. Runs `lua EaxRotations/tests/run_leveling_tests.lua`
4. Exits 0 only if all pass
**Verify:** Run the script itself; confirm exit code 0 on clean tree.
**Delegate:** `category="quick"` — single-file creation.

---

## Wave 3 — Reference Project Porting (5 parallel tasks)

### Task 3.1: Port TTD-gated DoT/cast decisions
**Priority:** HIGH
**Source:** NAG (Warlock.lua, Mage.lua), NextActionTBC (State.lua UpdateTargetTtd)
**Target:** `EaxRotations/shared/ttd_tracker_sylvanas.lua`, all DoT-using specs
**Pattern:** `if ttd < 5 then skip_long_cast end` — prevents wasting UA/Corruption on dying targets.
**Fix:** Enhance `ttd_tracker_sylvanas.lua` with a `can_sustain_until_end(spell_cast_time, ttd)` helper. Wire into affliction, shadow, balance, hunter specs.
**Verify:** `luac -p`; `lua tests/test_ttd_tracker.lua`; `lua tests/test_ttd_normalization.lua`.
**Delegate:** `category="deep"` — cross-cutting enhancement.

### Task 3.2: Port swing timer integration for melee/hunter
**Priority:** HIGH
**Source:** Sonah (WarriorCore.lua slam weaving, HunterCore.lua auto-shot weave, PaladinCore.lua seal twist), NextActionTBC (SwingTimerBridge, HunterTbcWeave.lua)
**Target:** `EaxRotations/shared/melee_combat_math_sylvanas.lua`, `EaxRotations/shared/hunter_adaptive_sylvanas.lua`, warrior/paladin/hunter specs
**Pattern:** `if swing_remaining < cast_time then delay_cast end` — prevents clipping auto-attacks.
**Fix:** Add `get_swing_remaining()` integration to melee_combat_math. Wire into Arms (Slam), Fury (Slam weave), Ret (seal twist), Hunter (Steady Shot weave).
**Verify:** `luac -p`; `lua tests/test_melee_combat_math.lua`; `lua tests/test_hunter_steady_shot_weave.lua`.
**Delegate:** `category="deep"` — needs API verification for swing timer access.

### Task 3.3: Port assignment/toggle system from NAG
**Priority:** MEDIUM
**Source:** NAG (Warlock.lua lines 91-145 — curse duties, scorch, mana management)
**Target:** New `EaxRotations/shared/assignment_manager_sylvanas.lua`
**Pattern:** Toggleable raid role assignments: `eaxassignment_curse_of_elements`, `eaxassignment_scorch_maintenance`, `eaxassignment_mana_management`
**Fix:** Create a shared module that registers menu toggles for common raid assignments. Specs check `NS.get_setting("assignment_xxx")` before executing assignment-gated strategies.
**Verify:** `luac -p`; new test file `test_assignment_manager.lua`.
**Delegate:** `category="deep"` — new module creation.

### Task 3.4: Port AutocastOtherCooldowns during burst
**Priority:** MEDIUM
**Source:** NAG (`NAG:AutocastOtherCooldowns()`)
**Target:** `EaxRotations/shared/trinket_manager_sylvanas.lua`
**Pattern:** `if burst_window_active then fire_all_on_use_trinkets end`
**Fix:** Add `autocast_cooldowns_during_burst()` to trinket_manager. Wire into specs that have burst windows (mage Icy Veins, hunter Bestial Wrath, warrior Death Wish, warlock Bloodlust).
**Verify:** `luac -p`; `lua tests/test_trinket_manager.lua`; `lua tests/test_burst_window.lua`.
**Delegate:** `category="quick"` — additive enhancement to existing module.

### Task 3.5: Port hysteresis enemy count smoothing
**Priority:** MEDIUM
**Source:** NextActionTBC (Engine.lua enemy count with 1s decrease delay)
**Target:** `EaxRotations/core_sylvanas.lua` (enemy_count calculation) or `EaxRotations/shared/targeting_sylvanas.lua`
**Pattern:** Increase count immediately when new enemy appears; delay decrease by 1s to prevent single-target/AoE mode oscillation.
**Fix:** Add `smoothed_enemy_count` with hysteresis. Specs read `state.smoothed_enemy_count` instead of raw `state.enemy_count`.
**Verify:** `luac -p`; `lua tests/test_boss_count.lua`; new edge test for count oscillation.
**Delegate:** `category="deep"` — cross-cutting state change.

---

## Wave 4 — LibHealComm-4.0 Integration & Healing (4 parallel tasks)

### Task 4.1: Create LibHealComm bridge module
**Priority:** HIGH
**Source:** LibHealComm-4.0 (https://github.com/Azilroka/LibHealComm-4.0)
**Target:** New `EaxRotations/shared/healcomm_bridge_sylvanas.lua`
**API Surface to Bridge:**
- `HealComm:GetHealAmount(guid, bitFlag, time, casterGUID)` — incoming heal amount on a unit
- `HealComm:GetNextHealAmount(guid, bitFlag, time)` — next heal landing time
- `HealComm:GetOthersHealAmount(guid, bitFlag, time)` — heals from OTHER healers (exclude self)
- `HealComm:GetNumHeals(guid, time)` — number of direct heals on target
- Constants: `DIRECT_HEALS=0x01`, `CHANNEL_HEALS=0x02`, `HOT_HEALS=0x04`, `ABSORB_SHIELDS=0x08`, `ALL_HEALS`
- Callbacks: `HealComm:RegisterCallback("HealComm_HealStarted", fn)`, `HealComm_HealStopped`, `HealComm_HealDelayed`, `HealComm_HealUpdated`, `HealComm_ModifierChanged`
**Fix:** Create bridge that:
1. Lazy-loads LibHealComm via `LibStub("LibHealComm-4.0")` with pcall
2. Exposes `NS.get_incoming_heal(unit, exclude_self)` → returns number
3. Exposes `NS.get_others_heal_amount(unit)` → returns number (heals from other healers)
4. Registers callbacks to invalidate aura_cache on heal start/stop
5. Nil-guards everything — if LibHealComm not installed, returns 0
**Verify:** `luac -p`; new test `test_healcomm_bridge.lua` with mock LibHealComm.
**Delegate:** `category="deep"` — new module, needs API mapping.

### Task 4.2: Integrate HealComm into preemptive_heal
**Priority:** HIGH
**File:** `EaxRotations/shared/preemptive_heal_sylvanas.lua`
**Issue:** Current preemptive healing doesn't account for heals from OTHER healers in the raid, causing overhealing.
**Fix:** In the preemptive heal scoring, subtract `get_others_heal_amount(target)` from the deficit calculation. If `deficit - others_heal < threshold`, skip the heal (someone else is already healing this target).
**Verify:** `luac -p`; `lua tests/test_healer_deficit.lua`; `lua tests/test_healer_deficit_overheal.lua`.
**Delegate:** `category="deep"` — healing logic enhancement.

### Task 4.3: Integrate HealComm into healer_deficit
**Priority:** HIGH
**File:** `EaxRotations/shared/healer_deficit_sylvanas.lua`
**Fix:** Modify `calculate_deficit(unit)` to return `effective_deficit = raw_deficit - incoming_heal_from_others`. Add `get_effective_deficit(unit)` that uses the HealComm bridge.
**Verify:** `luac -p`; `lua tests/test_healer_deficit.lua`; `lua tests/test_aoe_heal_best_target.lua`.
**Delegate:** `category="quick"` — additive enhancement.

### Task 4.4: Add shield absorb data to HealPredict
**Priority:** MEDIUM (from post-audit Task 2.2)
**File:** `EaxRotations/shared/incoming_heal_predictor_sylvanas.lua`
**Issue:** Shield absorbs (PW:S, Power Word: Shield) not accounted for in heal prediction.
**Fix:** Use `HealComm:GetHealAmount(guid, ABSORB_SHIELDS)` to get active absorb amounts. Subtract from incoming damage prediction. Already partially done in `discipline_sylvanas.lua` via `pws_absorb_remaining()` — generalize it.
**Verify:** `luac -p`; `lua tests/test_restoration_shield_tracking.lua`.
**Delegate:** `category="quick"` — data integration.

---

## Wave 5 — Architecture Refactor (3 parallel tasks)

### Task 5.1: Extract TTD domain from core_sylvanas.lua
**Priority:** HIGH (from refactor plan Phase 2)
**Files:** `EaxRotations/core_sylvanas.lua` → new `EaxRotations/core/ttd.lua`
**Issue:** core_sylvanas.lua is 5,981 lines. TTD logic (~200 lines) should be in its own module.
**Fix:** Extract TTD-related functions to `core/ttd.lua`. Wire via `require("core/ttd")` in core_sylvanas.lua. Follow the pattern already established by `core/settings.lua`, `core/units.lua`, `core/items.lua`, `core/cooldowns.lua`.
**Verify:** `luac -p` on both files; `lua tests/test_ttd_tracker.lua`; `lua tests/test_ttd_ema_tracker.lua`; full rotation suite.
**Delegate:** `category="deep"` — god-file surgery.

### Task 5.2: Extract talents domain from core_sylvanas.lua
**Priority:** MEDIUM (from refactor plan Phase 2)
**Files:** `EaxRotations/core_sylvanas.lua` → new `EaxRotations/core/talents.lua`
**Fix:** Extract talent inference / detection functions to `core/talents.lua`. Wire via require.
**Verify:** `luac -p`; `lua tests/test_talent_context.lua`; full rotation suite.
**Delegate:** `category="deep"` — god-file surgery.

### Task 5.3: Convert Arms spec to spec_kit as proof
**Priority:** MEDIUM (from refactor plan Phase 4.2)
**Files:** `EaxRotations/classes/warrior/arms_sylvanas.lua`, `EaxRotations/shared/spec_kit_sylvanas.lua`
**Issue:** spec_kit exists and is tested but 0/29 specs use it. Need one proof conversion.
**Fix:** Convert arms_sylvanas.lua to use `spec_kit.safe_state(raw, schema)` for nil-guard elimination and `spec_kit.define_action_for_class(SPELLS)` for boilerplate reduction. Reference `eax_refactor/examples/arms_next.lua` for the shape.
**Verify:** `luac -p`; `lua tests/test_arms_custom_matches.lua`; `lua tests/test_arms_rage_gating.lua`; `lua tests/test_arms_hamstring_tactician.lua`; `lua tests/test_spec_kit.lua`; full rotation suite.
**Delegate:** `category="deep"` — careful migration with full test gate.

---

## Verification Gates

### Between Each Wave
1. `luac -p` on ALL modified files
2. `lua EaxRotations/tests/run_rotation_tests.lua` — all 167 suites pass
3. `lua EaxRotations/tests/run_leveling_tests.lua` — all 11 suites pass
4. `lsp_diagnostics` on changed files — 0 errors

### Final Gate (End of Session)
1. All 5 waves complete
2. Full test suite green
3. `git diff --stat` shows only intended changes
4. No reference-system clones modified (Sonah, NAG, tbc-new, _flux, tbc-main, eax_refactor, NextActionTBC)
5. AGENTS.md updated if patterns changed

---

## Risk Assessment

| Risk | Mitigation |
|------|------------|
| try_cast fix breaks cast fallback | Gate with debug_cast_fallback test; if fails, revert and write debugging note |
| Core split breaks require chain | Extract one domain at a time; run full suite after each |
| spec_kit conversion introduces nil-guard regressions | Full arms test suite gate; if any fail, revert |
| HealComm bridge fails if library not installed | All HealComm access pcall-guarded; returns 0 if unavailable |
| TTD gate changes skip spells that should cast | Add menu toggle `eaxttd_gating_enabled` defaulting to true; can disable |
| Swing timer API not available in Sylvanas | Check apidocs first; if unavailable, skip Task 3.2 |

---

## Delegation Strategy (GLM 5.2 Max Reasoning)

Each task delegates to a `deep` category subagent with:
- Full file paths and line numbers
- Reference project paths for cross-referencing
- AGENTS.md coding pattern requirements
- Verification commands
- "One concern per commit" enforcement

**Parallelism:** 5 concurrent GLM 5.2 agents per wave (config allows 5).
**Total tasks:** 21 across 5 waves.
**Estimated time:** ~90-110 minutes for all waves with 5x parallelism.

---

## File Impact Summary

| Category | Files Touched | New Files |
|----------|--------------|-----------|
| Wave 1 (Critical) | 8 | 0 |
| Wave 2 (Perf) | 8 | 1 (validate.cmd) |
| Wave 3 (Porting) | 12 | 1 (assignment_manager) |
| Wave 4 (HealComm) | 4 | 2 (healcomm_bridge, test) |
| Wave 5 (Refactor) | 5 | 2 (core/ttd.lua, core/talents.lua) |
| **Total** | **37** | **6** |
