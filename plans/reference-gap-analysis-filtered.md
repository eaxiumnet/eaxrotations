# Filtered Reference Gap Analysis
## tbc-main vs EAX — What's Real vs What's Noise

**Date**: 2026-06-29 
**Raw gaps found**: 75 
**Real gaps after filtering**: ~15 

---

## I. NOISE — Already Superseded by EAX Architecture

These aren't gaps. EAX handles them at a higher level via shared modules.

| Feature | Why It's Not a Gap | EAX Equivalent |
|---------|-------------------|----------------|
| `use_arcane_intellect` | Buff automation | `buff_manager_sylvanas.lua` |
| `use_auto_bandage` | Consumable | `consumable_manager_sylvanas.lua` |
| `use_auto_freedom` | CC break | `CC Break` in middleware (preemptive DS/Freedom) |
| `use_auto_tremor` | Totem automation | `auto_tremor_sylvanas.lua` |
| `use_bash_interrupt` | Interrupt | `interrupt_manager_sylvanas.lua` |
| `use_desperate_prayer` | Emergency heal | Already in priest middleware |
| `use_fade` | Threat drop | Added Phase 4 |
| `use_hammer_of_justice` | Stun | Already in paladin specs |
| `use_healing_potion` | Consumable | `consumable_manager_sylvanas.lua` |
| `use_healthstone` | Consumable | Added Phase 4 |
| `use_hl` | Heal spell | Already in holy paladin |
| `use_ice_barrier` | Defensive | Already in mage specs |
| `use_inner_fire` | Self-buff | Already in shadow priest |
| `use_interrupt` | Interrupt | `interrupt_manager_sylvanas.lua` |
| `use_mana_gem` | Mana restore | Already in mage specs |
| `use_mana_potion` | Consumable | `consumable_manager_sylvanas.lua` |
| `use_motw` | Buff | `buff_manager_sylvanas.lua` |
| `use_purge` | Dispel | Already in shaman |
| `use_rapid_fire` | CD | Already in hunter specs |
| `use_readiness` | CD reset | Already in hunter specs |
| `use_scorpid_sting` | Debuff | Already in hunter |
| `use_serpent_sting` | DoT | Already in hunter |
| `use_shadow_protection` | Buff | `buff_manager_sylvanas.lua` |
| `use_shadowfiend` | Mana | Already in priest |
| `use_thorns` | Buff | `buff_manager_sylvanas.lua` |
| `use_viper_sting_pve` | Mana drain | Already in hunter |

**Count**: 25 features are NOT gaps. They're handled by shared modules or already exist.

---

## II. NOISE — Internal Constants / Botting Features

These are internal implementation details, not user-facing features.

| Feature | What It Actually Is |
|---------|---------------------|
| `auto_attack_spell_id` | Internal spell ID constant |
| `auto_shot_spell_ids` | Internal spell ID list |
| `auto_shot_spell_names` | Internal name mapping |
| `auto_tab_execute` | Tab targeting (botting) |
| `enable_tab_targeting` | Tab targeting (botting) |
| `use_auto_charge` | Movement automation (botting) |
| `use_auto_tab` | Tab targeting (botting) |
| `use_target_focus_behind` | Position hack (botting) |
| `use_bite_execute` / `use_bite_trick` | Pet command micromanagement |

**Count**: 9 features are botting/internal — not rotation features.

---

## III. REAL GAPS — Implement These

### 🔴 Critical (High User Impact)

| # | Feature | Class | Why | ? | Effort |
|---|---------|-------|-----|------------|--------|
| 1 | **Cliptracker** | Hunter | 1360-line module; prevents auto-shot clipping | ✅ Yes | **High** |
| 2 | **Powershifting** | Druid Cat | Energy management via form dancing | ❌ No (unique to tbc-main) | **High** |
| 3 | **Dashboard overlay** | All | In-game swing timer / CD tracker UI | ✅ Yes | **High** |
| 4 | **Auto-sync CDs** | All | Trinket/racial alignment with burst windows | ✅ Yes | **Medium** |

### 🟠 Medium (Nice to Have)

| # | Feature | Class | Why | ? | Effort |
|---|---------|-------|-----|------------|--------|
| 5 | `use_barkskin` | Druid | Defensive CD | ❌ No | Low |
| 6 | `use_berserker_rage` | Warrior | Fear break | ❌ No | Low |
| 7 | `use_bestial_wrath` | Hunter | BM burst CD management | ❌ No | Low |
| 8 | `use_bloodrage` | Warrior | Rage generation | ❌ No | Low |
| 9 | `use_counterspell` | Mage | Silence interrupt | ❌ No | Low |
| 10 | `use_dark_rune` | Caster | Mana consumable | ❌ No | Low |
| 11 | `use_feign_death` | Hunter | Threat drop / trap weaving | ❌ No | Medium |
| 12 | `use_frenzied_regen` | Druid Bear | Emergency heal | ❌ No | Low |
| 13 | `use_haste_potion` | Physical | DPS consumable | ❌ No | Low |
| 14 | `use_innervate_self` | Druid | Mana CD | ❌ No | Low |
| 15 | `use_opener` | All | Pull rotation logic | ❌ No | Medium |
| 16 | `use_racial` | All | Racial CD automation | ❌ No | Low |
| 17 | `use_soulshatter` | Warlock | Threat drop | ❌ No | Low |
| 18 | `use_spell_reflection` | Warrior | PvP defensive | ❌ No | Low |
| 19 | `use_tigers_fury` | Druid Cat | Burst energy | ❌ No | Low |
| 20 | `use_vanish_emergency` | Rogue | Survival | ❌ No | Low |

### 🟡 Low (Already Partially Done or Niche)

| # | Feature | Class | Status |
|---|---------|-------|--------|
| 21 | `auto_abolish_disease` | Druid | `dispel_manager` exists, Druid not wired |
| 22 | `auto_dispel_magic` | Priest | `dispel_manager` exists, verify wired |
| 23 | `auto_remove_poison` | Druid/Shaman | `dispel_manager` exists, verify wired |
| 24 | `use_challenging_roar` | Druid Bear | Niche — AoE taunt |
| 25 | `use_cloak_of_shadows` | Rogue | Already in middleware? Verify |
| 26 | `use_cure_disease` | Shaman/Priest | Already in dispel_manager? Verify |
| 27 | `use_cure_poison` | Shaman/Druid | Already in dispel_manager? Verify |
| 28 | `use_divine_spirit` | Priest | Buff — already in buff_manager? |
| 29 | `use_enrage` | Druid Bear | Already in bear spec? Verify |
| 30 | `use_evasion` | Rogue | Already in combat spec? Verify |
| 31 | `use_fear_ward` | Priest | Buff — already in buff_manager? |
| 32 | `use_feint` | Rogue | Threat drop — verify |
| 33 | `use_fel_armor` | Warlock | Already in specs? Verify |
| 34 | `use_force_of_nature` | Druid Balance | Treants — verify |
| 35 | `use_fortitude` | Priest | Buff — already in buff_manager? |
| 36 | `use_fresh_mana` | Caster | Mana potion — consumable_manager? |
| 37 | `use_goblin_sapper` / `use_sappers` / `use_super_sapper` | All | Engineering bombs — consumable_manager? |
| 38 | `use_growl` | Druid Bear | Already in bear spec? |
| 39 | `use_kick` | Rogue | Already in interrupt_manager? |
| 40 | `use_loc_breaker` | — | No idea what this is — ignore |
| 41 | `use_mana_rune` | Caster | Consumable — verify |
| 42 | `use_mangle_builder` / `opener` / `trick` | Druid Cat | Already in cat spec? |
| 43 | `use_ooc` | All | Out-of-combat handler — already exists |
| 44 | `use_priority_interrupt` | All | Already in interrupt_manager? |
| 45 | `use_retaliation` | Warrior | Already in warrior specs? |
| 46 | `use_shiv` | Rogue | Already in rogue specs? |
| 47 | `use_thistle_tea` | Rogue | Already in rogue specs? |
| 48 | `use_wing_clip` | Hunter | Already in melee_weave |

---

## IV. LARGE FILES ANALYSIS

| File | Lines | What It Is | Should We Port? |
|------|-------|------------|-----------------|
| `tmw-template.lua` | 6,466 | TellMeWhen template generator | ❌ No — different addon framework |
| `warrior/middleware.lua` | 1,519 | Warrior middleware (healthstone, bandage, potions, stance) | ⚠️ Partial — check for gaps |
| `dashboard.lua` | 1,428 | In-game UI overlay (swing timers, CD bars) | ✅ Yes — has this |
| `hunter/cliptracker.lua` | 1,360 | Shot timing / weaving math | ✅ Yes — critical DPS feature |
| `warrior/schema.lua` | 1,191 | Warrior settings UI | ❌ No — EAX schema is different architecture |
| `druid/bear.lua` | 1,145 | Bear rotation | ⚠️ Partial — compare with EAX bear |
| `core.lua` | 1,130 | Framework core (callbacks, state, context) | ⚠️ Partial — check for useful patterns |
| `druid/cat.lua` | 1,097 | Cat rotation with powershifting | ✅ Yes — powershifting is unique |
| `hunter/adaptive.lua` | 949 | Hunter adaptive rotation | ⚠️ Partial — may have useful logic |
| `shaman/enhancement.lua` | 854 | Enhancement rotation | ⚠️ Partial — compare with EAX enh |
| `hunter/meleeweave.lua` | 675 | Hunter melee weaving | ⚠️ Partial — we have basic version |

---

## V. VERDICT

**Raw gaps**: 75 
**Noise (superseded)**: 25 
**Noise (botting/internal)**: 9 
**Real gaps**: ~15-20 
**Critical to implement**: 4 

### Priority Order

1. **Cliptracker** — Only one that has AND users expect
2. **Druid powershifting** — Unique to tbc-main, high skill expression
3. **Auto-sync CDs** — Competitive advantage (has it)
4. **Dashboard overlay** — Nice UX (has it)
5. **Verify existing features** — Many "gaps" are actually already done (cloaks, evasion, feint, etc.)

### What NOT to Implement

- Tab targeting (`auto_tab`, `enable_tab_targeting`) — Botting feature
- Position hacks (`use_target_focus_behind`) — Botting feature
- TMW template generator — Different addon framework
- Schema files — EAX has different UI architecture

---

*Analysis by: Agent self-audit* 
*Date: 2026-06-29*
