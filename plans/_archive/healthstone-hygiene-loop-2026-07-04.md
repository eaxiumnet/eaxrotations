# Healthstone Rollout (Remaining) + Target-Switch Hygiene — Loop Session Plan
# Scope: Finish Track 5 healthstone gaps + Track 6 target-switch state reset
# Created: 2026-07-04
# Parent: Strategic roadmap Tracks 5 & 6

## Loop Session Protocol
Each chunk below is designed for ONE atomic execution pass.
After each chunk: `luac -p` on changed files + full 219+13 suite.
If any chunk loops >2 attempts, STOP and document the failure in this plan.

---

## Chunk 1: Hunter Healthstones (3 specs)
**Files:** `classes/hunter/beast_mastery_sylvanas.lua`, `marksmanship_sylvanas.lua`, `survival_sylvanas.lua`
**Pattern:** All three already import `potion_helper`. They already have state tables and `build_state()`.
**Steps per file:**
1. Add `local HEALTHSTONE_IDS = { 22105, 22104, 22103, 19013, 19012, 19011, 5512 }` + `first_ready_item()` helper after the MANA_GEM / constant block.
2. Add `healthstone_ready = 0,` to the state table.
3. Add `state.healthstone_ready = first_ready_item(HEALTHSTONE_IDS)` before `return state` in `build_state()`.
4. Insert Healthstone strategy after the ManaPotion strategy (or after defensives like IceBarrier for Frost pattern).
   - matches: `context.in_combat` + `(state.hp_pct or 100) <= 28` + `(state.healthstone_ready or 0) > 0`
   - execute: `first_ready_item(HEALTHSTONE_IDS)` ? `NS.use_item_by_id(item_id, context.me)`
**Validation:** `luac -p` all 3. Run 219+13 suites.

---

## Chunk 2: Shaman Healthstones (3 specs)
**Files:** `classes/shaman/elemental_sylvanas.lua`, `enhancement_sylvanas.lua`, `restoration_sylvanas.lua`
**Pattern:** Elemental/Enhancement have potion_helper; Restoration may not. All have state tables.
**Steps per file:**
1. Add HEALTHSTONE_IDS + first_ready_item() helper.
2. Add `healthstone_ready = 0,` to state table.
3. Add `state.healthstone_ready = first_ready_item(HEALTHSTONE_IDS)` before return.
4. Insert Healthstone strategy after defensives / ManaPotion.
**Validation:** `luac -p` all 3. Run 219+13 suites.

---

## Chunk 3: Warrior + Rogue + Priest Smite Healthstones (4 specs)
**Files:** `classes/warrior/kebab_sylvanas.lua`, `protection_sylvanas.lua`, `rogue/subtlety_sylvanas.lua`, `priest/smite_sylvanas.lua`
**Pattern:**
- Warrior kebab/protection already have potion_helper + DamagePotion. Just need HEALTHSTONE_IDS + state field + strategy.
- Rogue subtlety has DamagePotion. Same pattern.
- Priest smite has no consumables at all. Needs full helper + state + strategy.
**Steps per file:** Same 4-step pattern as Chunk 1.
**Validation:** `luac -p` all 4. Run 219+13 suites.

---

## Chunk 4: Track 6 — Target-Switch State Hygiene (1 file, high impact)
**File:** `main_sylvanas.lua`
**Problem:** TTD, debuff timers, swing remains are not reset on target switch. Causes wrong decisions on new targets.
**Fix:** In `build_context()`, after target resolution:
1. Compare `selected_target` GUID to `_last_target_guid`.
2. On change: call `ttd_ema.reset(target_or_guid)` + `ttd_tracker.reset(target_or_guid)` + reset any spec-specific cached target fields.
3. `_last_target_guid` already tracked at line 11 for manual-target lockout. Reuse it.
**Implementation sketch:**
```lua
local function reset_target_dependent_state(old_guid, new_guid)
    if old_guid == new_guid then return end
    if ttd_ema and ttd_ema.reset then ttd_ema.reset(old_guid) end
    if ttd_tracker and ttd_tracker.reset then ttd_tracker.reset(old_guid) end
    -- Swing timer module has no per-target state, but if it ever does, reset here
end
```
Call this after `_last_target_guid` is updated in `build_context()`.
**Validation:** `luac -p main_sylvanas.lua`. Run 219+13 suites.

---

## Chunk 5: Post-rollout Audit + Commit
**Steps:**
1. Run `python build_tools/audit_spells.py` or equivalent to verify no stale references.
2. Run full 219+13 suites one final time.
3. `git add EaxRotations/` + commit with message: `feat: healthstone automation + target-switch hygiene (Tracks 5 & 6)`
4. Move this plan to `plans/_archive/` and update `plans/_active.md`.

---

## Acceptance Criteria
- [ ] All 10 remaining spec files have healthstone strategy
- [ ] All 10 files pass `luac -p`
- [ ] 219 rotation suites pass
- [ ] 13 leveling suites pass
- [ ] Target-switch TTD reset is wired in main_sylvanas.lua
- [ ] Single commit with all changes (one concern per commit rule)

## Audit Reference: Current Healthstone Coverage (post 2026-07-04 session)
```
HS=Y: balance, bear, cat, resto, arcane, fire, frost, holy, protection, shadow, arms, fury, affliction, demonology, destruction, assassination, combat
HS=N: beast_mastery, marksmanship, survival, smite, subtlety, elemental, enhancement, restoration, kebab, warrior/protection
```
