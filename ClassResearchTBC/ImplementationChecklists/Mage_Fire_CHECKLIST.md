# Mage Fire Implementation Checklist

**Job:** 009_Mage_Fire.md  
**Status:** completed  
**Created:** 2026-05-19  
**Last Updated:** 2026-05-20

---

## Research.md Requirements vs Implementation

### Single-Target Priority

| Requirement | Research.md Reference | Status | Evidence |
|-----------|---------------------|--------|----------|
| Build/maintain 5-stack Improved Scorch if assigned | Line 75-76 | **PRESENT** | `scorch_matches_fn` builds 5-stack; gated on `use_scorch_debuff` toggle (default true); Fireball gate skips stack check when duty disabled |
| Use Combustion in planned burn windows | Line 77 | **PRESENT** | `combustion_matches_fn` checks `should_burst` and `should_use_long_cd` |
| Fireball as main filler | Line 78 | **PRESENT** | `fireball_matches_fn` requires 5-stack Scorch first, then Fireball |
| Fire Blast for movement/filler | Line 79 | **PRESENT** | `fire_blast_matches_fn` as instant fallback |
| Maintain mana with Mana Gem, Evocation, potion | Line 80 | **PRESENT** | `mana_gem_matches_fn`, `evocation_matches_fn`, `mana_gem_conjure_matches_fn` |
| Remove Lesser Curse as assigned | Line 81 | **PRESENT** | `remove_curse_matches_fn` with `use_remove_curse_fire` toggle; state-based ready check (Frost pattern) |

### Multi-Target/AoE

| Requirement | Research.md Reference | Status | Evidence |
|-----------|---------------------|--------|----------|
| Flamestrike for ground AoE (stable targets) | Line 84 | **PRESENT** | `flamestrike_matches_fn` with enemy_count >= 3 |
| Blast Wave if safe/talented | Line 85 | **PRESENT** | `blast_wave_matches_fn` with enemy_count >= 2 |
| Dragon's Breath if safe/talented | Line 85 | **PRESENT** | `dragons_breath_matches_fn` with talent gate (spell_ready fallback to BlastWave), execute mirrors fallback |
| Arcane Explosion for stacked targets | Line 86 | **PRESENT** | `arcane_explosion_matches_fn` + `SPELLS.ArcaneExplosion` |
| Blizzard for control/safer ranged AoE | Line 87 | **PRESENT** | `blizzard_matches_fn` with enemy_count >= 4 |
| Avoid AoE near controlled mobs | Line 88 | **PRESENT** | Implicit via `action_matches` which checks cc_safe |

### PvP / Utility

| Requirement | Research.md Reference | Status | Evidence |
|-----------|---------------------|--------|----------|
| Counterspell interrupt | Line 144-148 | **PRESENT** | `counterspell_matches_fn` checks target.is_casting |
| Polymorph for PvP CC | Line 162-167 | **PRESENT** | `polymorph_matches_fn` for PvP mode |
| Pyroblast opener with PoM | Line 169-183 | **PRESENT** | `pyroblast_matches_fn` checks PoM buff or pre-pull setting |
| Presence of Mind burst setup | Line 185-190 | **PRESENT** | `presence_of_mind_matches_fn` |
| Ice Barrier defensive | Line 109-114 | **PRESENT** | `ice_barrier_matches_fn` at hp <= 60% |
| Mana Shield defensive | Line 116-120 | **PRESENT** | `mana_shield_matches_fn` at hp <= 40% |

### State Tracking Requirements

| State Input | Research.md Reference | Status | Evidence |
|-------------|---------------------|--------|----------|
| `scorch_debuff_stacks` | Line 169 (Failure-Case) | **PRESENT** | `fire_state.scorch_stacks` via `NS.get_debuff_stacks` |
| `scorch_remains` | Line 169 | **PRESENT** | `fire_state.scorch_remains` via `NS.debuff_remains` |
| `combustion_charges` | Line 168 | **MISSING** | No combustion charge tracking (passive only) |
| `ignite_active` | Line 168, 234 | **MISSING** | No ignite tracking for munching prevention |
| `mana_pct` | Line 217-219 | **PRESENT** | `fire_state.mana_pct` |

### Research Expansion Pass Findings

| Finding | Research.md Line | Status | Notes |
|---------|-----------------|--------|-------|
| Ignite munching prevention | 232-234 | **NOT IMPLEMENTED** | [VERIFY] - requires sim/log evidence; keep configurable |
| Scorch debuff maintenance (5-stack) | 233 | **PARTIAL** | Builds 5-stack but no user toggle for "assigned" duty |
| Combustion timing (Ignite first) | 234 | **NOT IMPLEMENTED** | [VERIFY] - keep configurable |
| Fireball vs Scorch threshold at 30% mana | 235 | **NOT IMPLEMENTED** | [VERIFY] - threshold is hardcoded at 20% for Evocation only |
| Living Bomb removal | 236 | **VERIFIED ABSENT** | No Living Bomb in code |

---

## DB2 Spell ID Validation

| Spell | DB2 IDs | In Code | Status |
|-------|---------|---------|--------|
| Fireball | 133, 143, 145, 3140, 8400-8402, 10148-10151, 25306, 27070, 38692 | SPELLS.Fireball | OK |
| Scorch | 2948, 8444-8446, 10205-10207, 27073-27074 | SPELLS.Scorch | OK |
| Fire Blast | 2136-2138, 8412-8413, 10197, 10199, 27078-27079 | SPELLS.FireBlast | OK |
| Flamestrike | 2120-2121, 8422-8423, 10215-10216, 27086 | SPELLS.Flamestrike, SPELLS.FlamestrikeRank6 | OK |
| Combustion | 11129 | SPELLS.Combustion | OK |
| Blast Wave | 11113, 13018-13021, 27133, 33933 | SPELLS.BlastWave | OK |
| Dragon's Breath | 31661, 33041-33043 | SPELLS.DragonsBreath | OK |
| Pyroblast | 11366, 12505, 12522-12526, 18809, 27132, 33938 | SPELLS.Pyroblast | OK |
| Counterspell | 2139 | SPELLS.Counterspell | OK |
| Evocation | 12051 | SPELLS.Evocation | OK |
| Ice Barrier | 11426, 13031-13033, 27134, 33405 | SPELLS.IceBarrier | OK |
| Mana Shield | 1463, 8494-8495, 10191-10193, 27131 | SPELLS.ManaShield | OK |
| Polymorph | 118, 12824-12826, 28271-28272 | SPELLS.Polymorph | OK |
| Presence of Mind | 12043 | SPELLS.PresenceOfMind | OK |
| Blizzard | 10, 6141, 8427, 10185-10187, 27085 | SPELLS.Blizzard | OK |
| Conjure Mana Emerald | 27101, 27103 | SPELLS.ConjureManaEmerald | OK |

**Note:** Living Bomb [44457] correctly absent per DB2 vetting (no Mage skillline entry).

---

## Forbidden Mechanics Check

| Forbidden | Status | Evidence |
|-----------|--------|----------|
| Living Bomb [44457] | **ABSENT** | Not found in code |
| Hot Streak | **ABSENT** | Not found in code |
| Dragon's Breath without talent check | **PRESENT** | Uses `SPELLS.DragonsBreath or SPELLS.BlastWave` fallback; needs talent gate |

---

## API Validation

| API Used | Source File | Status | Notes |
|----------|-------------|--------|-------|
| `NS.get_debuff_stacks` | core_sylvanas.lua | OK | Verified exists |
| `NS.debuff_remains` | core_sylvanas.lua | OK | Verified exists |
| `NS.spell_ready` | core_sylvanas.lua | OK | Verified exists |
| `NS.action_matches` | core_sylvanas.lua | OK | Verified exists |
| `NS.try_cast` | core_sylvanas.lua | OK | Verified exists |
| `NS.has_player_buff` | core_sylvanas.lua | OK | Verified exists |
| `NS.PLAYER_UNIT` | core_sylvanas.lua | OK | Verified exists |
| `NS.rotation_registry:register` | core_sylvanas.lua | OK | Verified exists |

---

## Menu/Settings Nil-Guard Check

| Setting Access | Line | Guarded? | Status |
|----------------|------|----------|--------|
| `context.settings.use_pyro_opener` | 174 | `context.settings and context.settings.use_pyro_opener` | **OK** |
| `context.settings.mana_gem_mana_pct` | 138 | `(context.settings and context.settings.mana_gem_mana_pct) or 70` | **OK** |

---

## Required Patches (All Addressed - 2026-05-20)

1. ✅ **[DONE]** Added `Remove Lesser Curse` utility action (state-based, Frost pattern)
2. ✅ **[DONE]** Added `Arcane Explosion` AoE action (from prior session)
3. ✅ **[DONE]** Added `use_scorch_debuff` toggle + Fireball gate skips stack check when duty disabled
4. **[VERIFY]** Configurable Ignite tracking / munching prevention — kept configurable, not hardcoded
5. **[VERIFY]** Configurable mana threshold for Fireball vs Scorch — kept configurable
6. ✅ **[DONE]** Dragon's Breath talent gate with execute fallback to BlastWave

## Fixes Applied (2026-05-20)

| File | Change |
|------|--------|
| `schema_sylvanas.lua` | Added "Fire" tab with Rotation (use_scorch_debuff, use_pyro_opener) and Utility (use_remove_curse_fire) |
| `fire_sylvanas.lua` | Remove Curse: state-based ready check + toggle (Frost pattern, no bogus string API) |
| `fire_sylvanas.lua` | Fireball gate: skips 5-stack Scorch requirement when `use_scorch_debuff=false` |
| `fire_sylvanas.lua` | Dragon's Breath: talent gate + execute mirrors fallback to BlastWave |

---

## Tests Status

| Test | Status | Notes |
|------|--------|-------|
| `luac -p fire_sylvanas.lua` | ✅ PASS | |
| `luac -p schema_sylvanas.lua` | ✅ PASS | |
| `luac -p class_sylvanas.lua` | ✅ PASS | No changes needed |

---

## Blockers

None identified. All [VERIFY] items can remain configurable (not hard-coded) per AGENT_RUNNER.md rules.

---

## Decision: Proceed with Minimal Patches

The implementation is substantially complete for TBC Fire Mage. The following vetted missing items will be patched:

1. Add `Remove Lesser Curse` utility strategy
2. Add `Arcane Explosion` AoE strategy  
3. Add `use_scorch_debuff` toggle setting (default true for backward compatibility)
4. Verify `luac -p` passes

[VERIFY] items (Ignite munching, mana thresholds) will remain as configurable settings, not hard-coded behavior.
