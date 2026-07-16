# Low-Level Spell Coverage Audit (Vanilla/TBC/WotLK)

**Date:** 2026-07-15
**Status:** In Progress
**Scope:** All Vanilla, TBC (_sylvanas), and WotLK specs in EaxRotations

## 1. Quick Wins (Druid Feral Level 42)

- **Shred in `leveling_sylvanas.lua`**: Removed the hard Mangle-debuff requirement below level 50 (Mangle Cat is learned at 50). Shred now fires when behind target and energy available.
- **Shred in `cat_sylvanas.lua`**: Added `state.level` from context and gated the Mangle-debuff check on `level >= 50`.
- **Tests added in `test_leveling_druid.lua`**: Five new low-level level-42 tests for Faerie Fire (Feral), Shred, Ravage, Rip, and Ferocious Bite.

## 2. Risk/Blocker Matrix

| Gate | Keep Strict | Can Relax | Notes |
|------|-------------|-------------|-------|
| Shred behind requirement | Yes | No | Tooltip requires behind target |
| Shred Mangle debuff requirement | No | Yes (level < 50) | Mangle Cat not available below 50 |
| Ravage stealth requirement | Yes | No | Tooltip requires stealth |
| Ravage behind requirement | Yes | No | Tooltip requires behind target |
| Rip combo point requirement | Partial | Lower to 3 CP at low level | Rip scales with CP but 4-5 CP is ideal |
| Faerie Fire armor check | Partial | Skip if target has no armor at low level | Armor debuff still useful when available |
| Ferocious Bite energy/CP | Keep | No | Core finisher mechanics |

## 3. Architecture Recommendation

Create a shared helper `EaxRotations/shared/leveling_helpers_sylvanas.lua`:

```lua
local M = {}

function M.level_from_context(context)
    return (context and (context.level or context.player_level)) or 70
end

function M.level_scaled_threshold(level, base, per_level, floor_val, cap_val)
    return math.max(floor_val, math.min(cap_val, base + (level * per_level)))
end

function M.has_mangle_cat_available(level)
    return (level or 70) >= 50
end

return M
```

Specs should consume it via:

```lua
local leveling_helpers = require("shared/leveling_helpers_sylvanas")
local level = leveling_helpers.level_from_context(context)
```

## 4. Test Strategy

- Add low-level scenario tests to each class's leveling test file.
- Use `make_context({ level = 42 })` pattern.
- For each spec, assert core spells fire with appropriate low-level state (no high-rank debuffs, appropriate form, sufficient but realistic resources).
- Run `luac -p` on every modified file.
- Run full `run_rotation_tests.lua` and `run_leveling_tests.lua` after each class group.

## 5. Step-by-Step Druid Fix List

- [x] Reproduce bug with new low-level tests in `test_leveling_druid.lua`
- [x] Fix Shred Mangle-debuff gate in `leveling_sylvanas.lua`
- [x] Fix Shred Mangle-debuff gate in `cat_sylvanas.lua`
- [x] Relax Faerie Fire (Feral) armor/TTD gates in `cat_sylvanas.lua` when level < 50
- [x] Lower Rip/FB combo-point requirement to 4 when level < 50
- [x] Audit WotLK cat rotation missing Faerie Fire Feral / Ravage
- [x] Audit Vanilla Druid specs for same issues
  - [x] `cat_vanilla.lua`: added `leveling_helpers` require + `state.level` population
  - [x] `cat_vanilla.lua`: relaxed FaerieFireFeral / FaerieFireStealthLock armor gate when level < 50
  - [x] `cat_vanilla.lua`: added baseline `Rip` strategy (was only `RipSnapshot`, which never matched initially)
  - [x] `cat_vanilla.lua`: removed dead `RipSnapshot`; Vanilla Rip is refresh-only (no mid-DoT snapshot upgrade)
  - [x] `cat_vanilla.lua`: fixed `RavageOpener` inverted HP gate and added missing `is_behind` check
  - [x] `bear_vanilla.lua`: added `leveling_helpers` require + `state.level` population
  - [x] `bear_vanilla.lua`: relaxed FaerieFireFeral / FaerieFirePull armor gate when level < 50
  - [x] `caster_vanilla.lua`: added `leveling_helpers` require + `state.level` population
  - [x] `caster_vanilla.lua`: relaxed FaerieFire armor gate when level < 50
  - [x] Added `test_cat_vanilla_low_level_gating.lua` regression test
  - [x] Added `test_druid_vanilla_low_level_gating.lua` regression test
- [x] Run full test suites
- [ ] Commit this Vanilla Druid slice (pending explicit commit request)

**Verification (current working tree, uncommitted):**
- `luac -p` on all modified files → clean
- `lua EaxRotations/tests/run_rotation_tests.lua -q` → 272/272 pass
- `lua EaxRotations/tests/run_leveling_tests.lua -q` → 18/18 pass

## 6. Progress

| Class | Status | Key fixes |
|-------|--------|-----------|
| Druid | Done | Shred Mangle gate, Faerie Fire armor/TTD, Rip/Bite CP, WotLK cat FF/Ravage |
| Warrior | Done | Sunder Armor armor gate, Execute stance dance |
| Hunter | Done | BM pre-Steady Shot silent gate, MM Wing Clip ready state |
| Rogue | Done | Sinister Strike fallback, Eviscerate 4 CP dump, Evasion rank fix |
| Paladin | Done | JoW/SoW dual-seal fix, missing SoR rank-1, Cleanse gate |
| Shaman | Done | Leveling shock fallback (Earth Shock when Flame/Frost not ready), state.level population |
| Mage | Done | Leveling nuke cross-spell readiness gates removed; Fireball no longer gated behind 5-stack Scorch when Scorch unlearned |
| Warlock | Done | Destruction Immolate no longer gated by 400 SP threshold below level 40 |
| Priest | Done | No low-level silent gates found |
| Death Knight | Done | No low-level silent gates found (WotLK-only class) |

## 7. Next Classes

After Druid, audit in order:
1. Warrior (Heroic Strike leveling logic already exists; check other specs) ✅
2. Hunter (pet/shot low-level gates)
3. Rogue (combo builders, finishers)
4. Paladin (seal/judgement low ranks)
5. Shaman (totems, shocks)
6. Mage (spell ranks, mana thresholds)
7. Warlock (curse/DoT ranks)
8. Priest (heal ranks, smite)
9. Death Knight (WotLK only)
