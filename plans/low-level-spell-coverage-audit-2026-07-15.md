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
- [ ] Audit Vanilla Druid specs for same issues
- [x] Run full test suites and commit

**Verification (after commit `bcbc1a1e`):**
- `lua EaxRotations/tests/run_rotation_tests.lua -q` → 275/275 pass
- `lua EaxRotations/tests/run_leveling_tests.lua -q` → 18/18 pass
- `lua EaxRotations/tests/run_wotlk_tests.lua -q` → 3/3 pass

## 6. Progress

| Class | Status | Key fixes |
|-------|--------|-----------|
| Druid | Done | Shred Mangle gate, Faerie Fire armor/TTD, Rip/Bite CP, WotLK cat FF/Ravage |
| Warrior | Done | Sunder Armor armor gate, Execute stance dance |
| Hunter | Done | BM pre-Steady Shot silent gate, MM Wing Clip ready state |
| Rogue | In progress | — |
| Paladin | Pending | — |
| Shaman | Pending | — |
| Mage | Pending | — |
| Warlock | Pending | — |
| Priest | Pending | — |
| Death Knight | Pending | WotLK only |

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
