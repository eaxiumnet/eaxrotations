# Implementation Plan: Flux Hunter Adaptive Rotation for EaxRotations

**Created:** 2026-06-11
**Source:** `tbc-main/rotation/source/aio/hunter/adaptive.lua` (949 lines)
**Target:** `EaxRotations/shared/hunter_adaptive_sylvanas.lua` (new file)
**API Surface:** Raw WoW globals + `NS.spell_ready`, `NS.gcd_remains`, `NS.mana_pct`, `NS.SwingTimer.get_ranged_time_until`, `NS.HunterSpells`

## API Mapping (Flux → Sylvanas)

| Flux API | Sylvanas Equivalent | File:Line |
|----------|-------------------|-----------|
| `UnitRangedAttackPower("player")` | `_G.UnitRangedAttackPower("player")` | raw WoW API |
| `UnitRangedDamage("player")` | `_G.UnitRangedDamage("player")` | raw WoW API |
| `GetRangedCritChance()` | `_G.GetRangedCritChance("player")` | raw WoW API |
| `UnitBuff("player", i)` | `_G.UnitBuff("player", i)` | raw WoW API |
| `GetTime()` | `_G.GetTime()` | raw WoW API |
| `GetCVar("SpellQueueWindow")` | `_G.GetCVar("SpellQueueWindow")` | raw WoW API |
| `CombatLogGetCurrentEventInfo()` | `_G.CombatLogGetCurrentEventInfo()` | raw WoW API |
| `UnitGUID("player")` | `_G.UnitGUID("player")` | raw WoW API |
| `GetSpellInfo(id)` | `_G.GetSpellInfo(id)` | raw WoW API |
| `A.MultiShot:IsReady(unit)` | `NS.spell_ready(NS.HunterSpells.MultiShot, target)` | core_sylvanas.lua |
| `A.ArcaneShot:IsReady(unit)` | `NS.spell_ready(NS.HunterSpells.ArcaneShot, target)` | core_sylvanas.lua |
| `GetCurrentGCD()` | `NS.gcd_remains()` or `NS.get_global_cooldown()` | core_sylvanas.lua |
| `Player:GetSwingShoot()` | `NS.SwingTimer.get_ranged_time_until()` | shared/swing_timer:141 |
| `Player:ManaPercentage()` | `NS.mana_pct()` | core_sylvanas.lua |
| `GetLatency()` | `core.get_ping()` in `api/core.lua` | api/core.lua |
| `A.MortalShots:GetTalentRank()` | `select(5, GetTalentInfo(tab, index))` raw WoW | raw WoW API |
| `Listener:Add(_, event, fn)` | `core.event.attach(core.event.UNIT_AURA, fn)` etc. | api/core.lua |
| `TMW.time` | `GetTime()` | drop TMW dependency |
| `TMW.UPD_INTV` | Drop (debug only) | N/A |

## Core Math (Unchanged — Pure Arithmetic)

All damage formulas, DPS rate computation, clip budgeting, and decision logic are framework-independent. They port with zero changes:
- `critFactor()` — line 351
- `recomputeDamageEstimates()` — lines 356-401
- `chooseAction()` decision logic — lines 757-913
- `clipBudgetForSpeed()` — lines 452-467
- `resolveShootRemaining()` — lines 581-615

## Files to Create/Modify

| File | Action |
|------|--------|
| `EaxRotations/shared/hunter_adaptive_sylvanas.lua` | **CREATE** — port of adaptive.lua with Sylvanas API bindings |
| `EaxRotations/classes/hunter/class_sylvanas.lua` | MODIFY — require + init the adaptive module |
| `EaxRotations/classes/hunter/beast_mastery_sylvanas.lua` | MODIFY — integrate ChooseAction into rotation |
| `EaxRotations/classes/hunter/marksmanship_sylvanas.lua` | MODIFY — integrate ChooseAction into rotation |
| `EaxRotations/classes/hunter/survival_sylvanas.lua` | MODIFY — integrate ChooseAction into rotation |
| `EaxRotations/tests/test_hunter_adaptive.lua` | CREATE — test engine math |

## Task List

### Phase 1: Create Shared Module
- [ ] Task 1: Create `shared/hunter_adaptive_sylvanas.lua` with ported math engine
  - Copy all stat readers, damage formulas, DPS computation, clip budgets
  - Replace GGL API calls with Sylvanas equivalents (see mapping above)
  - Export `NS.HunterAdaptive.ChooseAction(unit, opts)` API
  - Wire CLEU events for auto-shot tracking

### Phase 2: Integrate into Rotation
- [ ] Task 2: Add `require("shared/hunter_adaptive_sylvanas")` to class_sylvanas.lua
- [ ] Task 3: Add adaptive rotation strategy to BM spec (setting-gated, opt-in)
- [ ] Task 4: Add adaptive rotation strategy to MM spec
- [ ] Task 5: Add adaptive rotation strategy to Survival spec

### Phase 3: Verification
- [ ] Task 6: `luac -p` on all modified files
- [ ] Task 7: Full rotation + leveling test suites
- [ ] Task 8: LSP diagnostics
