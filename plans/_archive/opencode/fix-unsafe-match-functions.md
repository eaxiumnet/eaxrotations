# Plan: Fix Unsafe Match Functions (~77 fixes across 12 files)

**Created:** 2026-06-12
**API Surface:** `NS.spell_ready()`, `NS.spell_exists()`, `NS.try_cast()`
**Docs:** AGENTS.md, core_sylvanas.lua

## Overview

Fix ~77 match functions that return `true` without checking spell readiness. Causes TRACE log spam + wasted CPU.

Fix Patterns:
- **Type A**: Debuff timer — add `_known` flag in build_state via `NS.spell_exists()`
- **Type B**: Self-buff — add `_ready` flag in build_state via `NS.spell_ready()`
- **Type C**: No check — add inline `NS.spell_ready()` guard
- **Type D**: Warlock direct cast — add inline `NS.spell_ready(action.spell, target)`

## Task Dependency Graph

| Task | Depends | Reason |
|------|---------|--------|
| Tasks 1-10 | None | Each file is independent |
| Task 11 (validation) | Tasks 1-10 | Must run after all fixes |

## Parallel Execution

```
Wave 1 (All Start Immediately):
├── Task 1: Priest Shadow TBC — 16 fixes in shadow_sylvanas.lua
├── Task 2: Priest Shadow Classic — 11 fixes in shadow_vanilla.lua
├── Task 3: Priest Holy TBC — 5 fixes in holy_sylvanas.lua
├── Task 4: Priest Holy Classic — 5 fixes in holy_vanilla.lua
├── Task 5: Priest Middleware — 1 fix in middleware_sylvanas.lua
├── Task 6: Mage Frost — 6 fixes in frost_sylvanas.lua
├── Task 7: Mage Arcane — 9 fixes in arcane_sylvanas.lua
├── Task 8: Warlock Destruction — 17 fixes in destruction_sylvanas.lua
├── Task 9: Warlock Demonology — 3 fixes in demonology_sylvanas.lua
├── Task 10: Paladin Protection — 4 fixes in protection_sylvanas.lua

Wave 2 (After Wave 1):
└── Task 11: Final validation — luac -p + 118 rotation tests + 11 leveling tests
```

No-fix files (confirmed safe during audit): `classes/mage/fire_sylvanas.lua`, `classes/druid/balance_sylvanas.lua`.

---

## Tasks

### Task 1: `classes/priest/shadow_sylvanas.lua` — 16 unsafe
**Category**: `unspecified-high` — mechanical pattern work, 1 file
**Skills**: none

| Match | Fix |
|-------|-----|
| `shadowfiend_matches` (L315) | Add `NS.spell_ready(SPELLS.Shadowfiend, context.target)` |
| `shadow_swp_spread_matches` (L324) | Add `s.swp_known` check (populate in build_state) |
| `shadow_vt_spread_matches` (L339) | Add `s.vt_known` check |
| `inner_fire_matches` (L354) | Add `s.inner_fire_known` check |
| `flash_heal_matches` (L371) | Add `NS.spell_ready(SPELLS.FlashHeal, me, {skip_range=true})` |
| `racial_matches` (L387) | Add inline NS.spell_ready per racial spell |
| `vampiric_touch_matches` (L396) | Add `s.vt_known` check |
| `shadow_word_pain_matches` (L412) | Add `s.swp_known` check |
| `vampiric_embrace_matches` (L428) | Add `s.ve_known` check |
| `devouring_plague_matches` (L434) | Add `s.dp_known` check |
| `inner_focus_matches` (L446) | Add `s.inner_focus_known` check |
| `mind_flay_matches` (L515) | Add `NS.spell_ready(SPELLS.MindFlay, context.target)` |
| `starshards_matches` (L558) | Add `NS.spell_ready(SPELLS.Starshards, context.target)` |
| `MovingSWP` inline (L585) | Add `s.swp_known` check |
| `shadowfiend_matches` (CD) | Add `NS.spell_ready(SPELLS.Shadowfiend, context.target)` |
| `pre_combat_pull_matches` (L304) | Already safe — has NS.spell_ready |

**QA**: `luac -p classes/priest/shadow_sylvanas.lua`

---

### Task 2: `classes/priest/shadow_vanilla.lua` — 11 unsafe
**Category**: `unspecified-low` — same pattern as Task 1, fewer fixes
**Skills**: none

Same fix pattern as Task 1 but for Classic spells. All match functions identical in structure.

**QA**: `luac -p classes/priest/shadow_vanilla.lua`

---

### Task 3: `classes/priest/holy_sylvanas.lua` — 5 unsafe
**Category**: `unspecified-low`
**Skills**: none

| Match | Fix |
|-------|-----|
| EmergencyFlashHeal inline (L374) | Add `spell_exists(SPELLS.FlashHeal) and spell_ready(SPELLS.FlashHeal, state.lowest.unit)` |
| PrayerOfHealing inline (L440) | Add `spell_exists(SPELLS.PrayerofHealing) and spell_ready(SPELLS.PrayerofHealing, NS.PLAYER_UNIT)` |
| GreaterHeal inline (L510) | Add `spell_exists(SPELLS.GreaterHeal) and spell_ready(SPELLS.GreaterHeal, state.lowest.unit)` |
| FlashHeal inline (L534) | Add `spell_exists(SPELLS.FlashHeal) and spell_ready(SPELLS.FlashHeal, state.lowest.unit)` |
| EncounterReactions (L838/L333) | Add `spell_exists(SPELLS.FlashHeal) and spell_ready(SPELLS.FlashHeal, state.tank.unit)` |

File already has `spell_exists` and `spell_ready` imported at L122. PreHeal (L260/L796) is already safe (returns `spell_exists(SPELLS.GreaterHeal) and spell_ready(SPELLS.GreaterHeal, ...)` at L274).

**QA**: `luac -p classes/priest/holy_sylvanas.lua`

---

### Task 4: `classes/priest/holy_vanilla.lua` — 5 unsafe
**Category**: `unspecified-low`
**Skills**: none

Same 5 fixes as Task 3. File imports `spell_exists` and `spell_ready` at L118.

**QA**: `luac -p classes/priest/holy_vanilla.lua`

---

### Task 5: `classes/priest/middleware_sylvanas.lua` — 1 unsafe
**Category**: `quick` — 1-line fix
**Skills**: none

**PvPPsychicScream** inline (L227-234):
```lua
-- After: if (NS.GetEnemiesCount and NS.GetEnemiesCount(8) or 0) < 2 then return false end
-- Add:
if not (NS.spell_ready and NS.spell_ready(SPELLS.PsychicScream, context.me, { skip_range = true })) then return false end
```

**QA**: `luac -p classes/priest/middleware_sylvanas.lua`

---

### Task 6: `classes/mage/frost_sylvanas.lua` — 6 unsafe
**Category**: `unspecified-low`
**Skills**: none

| Match | Fix |
|-------|-----|
| `ice_block_matches` (L37) | Refactor to check `s.ice_block_ready` — state field EXISTS at L178 |
| `cold_snap_matches` (L45) | Add check for `s.cold_snap_ready` — state field EXISTS at L179 |
| `frost_nova_matches` (L54) | Add check for `s.frost_nova_ready` — state field EXISTS at L182 |
| `cone_of_cold_matches` (L66) | Add check for `s.cone_of_cold_ready` — state field EXISTS at L184 |
| `mage_armor_matches` (L359) | Add `s.mage_armor_ready` field in build_state + check |
| `frostbolt_matches` clearcasting (L285) | Add `if not s.frostbolt_ready then return false end` |

Matches #1-4 don't accept state param. Either refactor to pass state or add inline `NS.spell_ready`. Inline is simpler and matches existing pattern.

**QA**: `luac -p classes/mage/frost_sylvanas.lua`

---

### Task 7: `classes/mage/arcane_sylvanas.lua` — 9 unsafe
**Category**: `unspecified-high`
**Skills**: none

| Match | Fix |
|-------|-----|
| `ice_barrier_matches` (L249) | Add `NS.spell_ready(SPELLS.IceBarrier, me, {skip_range=true})` |
| `mana_shield_matches` (L259) | Add `NS.spell_ready(SPELLS.ManaShield, me, {skip_range=true})` |
| `polymorph_matches` (L270) | Add `NS.spell_ready(SPELLS.Polymorph, context.cc_target or context.target)` |
| `frost_nova_matches` (L280) | Add `NS.spell_ready(SPELLS.FrostNova, context.target)` |
| `pom_matches` (L293) | Add `NS.spell_ready(SPELLS.PresenceOfMind, me, {skip_range=true})` |
| `arcane_power_matches` (L309) | Add `if not s.arcane_power_available then return false end` — state field EXISTS at L181 |
| `fire_blast_matches` (L396) | Add `NS.spell_ready(SPELLS.FireBlast, context.target)` |
| `low_level_bolt_matches` (L435) | Add `NS.spell_exists(SPELLS.Fireball) and NS.spell_ready(SPELLS.Fireball, context.target)` fallback |
| `Slow` inline (L471) | Add `NS.spell_ready(SPELLS.Slow, context.target)` |

**QA**: `luac -p classes/mage/arcane_sylvanas.lua`

---

### Task 8: `classes/warlock/destruction_sylvanas.lua` — 17 unsafe
**Category**: `unspecified-high` — largest file, 17 fixes
**Skills**: none

All matches take `(context, action, state)` — fix by adding `if not NS.spell_ready(action.spell, target) then return false end` at start.

| Match | Target | skip_range |
|-------|--------|------------|
| `immolate_matches` (L123) | context.target | no |
| `conflagrate_matches` (L137) | context.target | no |
| `curse_of_doom_matches` (L154) | context.target | no |
| `backlash_matches` (L163) | context.target | no |
| `soul_fire_matches` (L186) | context.target | no |
| `corruption_matches` (L191) | context.target | no |
| `drain_life_matches` (L208) | context.target | no |
| `health_funnel_matches` (L216) | pet | yes |
| `dark_pact_matches` (L223) | me | yes |
| `fel_armor_matches` (L230) | me | yes |
| `demon_armor_matches` (L238) | me | yes |
| `shadow_ward_matches` (L247) | me | yes |
| `create_healthstone_matches` (L255) | me | yes |
| `life_tap_matches` (L262) | me | yes |
| `summon_pet_matches` (L270) | me | yes |
| `death_coil_matches` (L278) | context.target | no |
| ShadowBolt fallback (L348) | context.target | no |

Already safe (no change needed): `shadowburn_matches`, `incinerate_matches`, `searing_pain_matches`, `curse_of_agony_matches`, `fear_matches`, `aoe_matches`.

**QA**: `luac -p classes/warlock/destruction_sylvanas.lua`

---

### Task 9: `classes/warlock/demonology_sylvanas.lua` — 3 unsafe
**Category**: `unspecified-low`
**Skills**: none

| Match | Fix |
|-------|-----|
| `needs_felguard` (L113) | Add `if not NS.spell_ready(SPELLS.SummonFelguard, me, {skip_range=true}) then return false end` |
| `death_coil_matches` (L150) | Add `if not s.death_coil_ready then return false end` — state field EXISTS at L40 |
| `health_funnel_matches` (L159) | Add `if not NS.spell_ready(SPELLS.HealthFunnel, me, {skip_range=true}) then return false end` |

**QA**: `luac -p classes/warlock/demonology_sylvanas.lua`

---

### Task 10: `classes/paladin/protection_sylvanas.lua` — 4 unsafe
**Category**: `unspecified-low`
**Skills**: none

| Match | Fix |
|-------|-----|
| `righteous_fury_matches` (L195) | Add `s.righteous_fury_known` in build_state via `NS.spell_exists(SPELLS.RighteousFury)` |
| `seal_righteousness_matches` (L251) | Add `s.seal_righteousness_ready` in build_state via `NS.spell_ready(SPELLS.SealRighteousness, me, {skip_range=true})` |
| `devotion_aura_matches` (L373) | Add `s.devotion_aura_known` in build_state |
| `blessing_of_sanctuary_matches` (L385) | Add `s.blessing_sanctuary_known` in build_state |

**QA**: `luac -p classes/paladin/protection_sylvanas.lua`

---

### Task 11: Final Validation
**Category**: `unspecified-low`
**Skills**: none

Run on ALL modified files:
```powershell
luac -p classes/priest/shadow_sylvanas.lua
luac -p classes/priest/shadow_vanilla.lua
luac -p classes/priest/holy_sylvanas.lua
luac -p classes/priest/holy_vanilla.lua
luac -p classes/priest/middleware_sylvanas.lua
luac -p classes/mage/frost_sylvanas.lua
luac -p classes/mage/arcane_sylvanas.lua
luac -p classes/warlock/destruction_sylvanas.lua
luac -p classes/warlock/demonology_sylvanas.lua
luac -p classes/paladin/protection_sylvanas.lua
lua EaxRotations/tests/run_rotation_tests.lua
lua EaxRotations/tests/run_leveling_tests.lua
```

## Commit Strategy

10 atomic commits, one per file, each independently verifiable via `luac -p`:

| Order | Commit Message |
|-------|----------------|
| 1 | `fix(priest): add spell readiness guards to 16 shadow match functions` |
| 2 | `fix(priest): add spell readiness guards to 11 shadow vanilla match functions` |
| 3 | `fix(priest): add spell readiness guards to 5 holy TBC match functions` |
| 4 | `fix(priest): add spell readiness guards to 5 holy classic match functions` |
| 5 | `fix(priest): add spell_ready guard to PvPPsychicScream match` |
| 6 | `fix(mage): add spell readiness guards to 6 frost match functions` |
| 7 | `fix(mage): add spell readiness guards to 9 arcane match functions` |
| 8 | `fix(warlock): add spell readiness guards to 17 destruction match functions` |
| 9 | `fix(warlock): add spell readiness guards to 3 demonology match functions` |
| 10 | `fix(paladin): add spell readiness guards to 4 protection match functions` |

## Success Criteria

1. `luac -p` passes on all 10 modified files
2. All 118 rotation test suites PASS
3. All 11 leveling test suites PASS
4. No behavior change when spells ARE learned
5. Zero TRACE spam for unlearned/unready spells
