# Thin Specs Selected for Phase 1 Deepening

## Overview

These three specs were chosen because they are **high-impact, high-usage** classes in TBC Classic but currently have the thinnest implementations (boilerplate spell lists with no custom state builder or spec-specific nuance).

| Spec | File | Lines | Why It Needs Deepening |
|------|------|-------|----------------------|
| **Mage Frost** | `classes/mage/frost_sylvanas.lua` | 41 | No custom state builder; lacks Water Elemental management, Frostbolt shatter combo logic, or Winter's Chill stack tracking. |
| **Warlock Affliction** | `classes/warlock/affliction_sylvanas.lua` | 52 | No custom state builder; lacks UA lockout awareness, Shadow Embrace stack tracking, or Nightfall proc handling. |
| **Hunter Beast Mastery** | `classes/hunter/beast_mastery_sylvanas.lua` | ~60 | No custom state builder; lacks pet happiness/loyalty tracking, Intimidation sync, or Kill Command crit-proc windows. |

---

## Mage Frost — Target Depth

### Current State
- 5-6 spells in a simple priority loop: Water Elemental, Icy Veins, Frostbolt, Ice Lance, Blizzard, Cone of Cold
- No state builder
- No shatter combo tracking (Frostbolt + Ice Lance on frozen target)
- No Winter's Chill maintenance logic

### Phase 1 Goals
1. **build_frost_state()** — Track:
   - `water_elemental_active` and `we_duration_remaining`
   - `target_frozen` (Frost Nova, Freeze, Improved Blizzard slow)
   - `winters_chill_stacks` on target
   - `shatter_window_open` (frozen + next spell will crit)
2. **Shatter combo** — Cast Frostbolt, then Ice Lance immediately after if target is still frozen
3. **Winter's Chill maintenance** — Ensure 5-stack Winter's Chill debuff is maintained on the target
4. **Water Elemental micro** — Auto-cast Freeze (Nova) when multiple enemies are clustered; recall if mana is low

---

## Warlock Affliction — Target Depth

### Current State
- 6-8 spells in priority loop: Curse of Agony, Corruption, Siphon Life, Unstable Affliction, Drain Life, Life Tap, Fear
- No custom state builder
- No UA lockout awareness (can't re-cast UA while it's on target)
- No Shadow Embrace stack tracking
- No Nightfall (Shadow Trance) proc handling

### Phase 1 Goals
1. **build_affliction_state()** — Track:
   - All active DoTs on target with remaining duration
   - `shadow_embrace_stacks` (0-5)
   - `nightfall_ready` (Shadow Trance proc)
   - `ua_lockout` (can't cast UA if already on target)
2. **DoT refresh optimization** — Refresh Corruption/CoA/SL within the safe clip window (per `shared/dot_refresh_sylvanas.lua`)
3. **Nightfall handling** — Queue instant Shadowbolt when Nightfall procs; don't overwrite with Drain Life
4. **Life Tap discipline** — Tap only when mana deficit justifies the health cost and healers are stable

---

## Hunter Beast Mastery — Target Depth

### Current State
- 6-8 spells: Bestial Wrath, Rapid Fire, Kill Command, Steady Shot, Arcane Shot, Serpent Sting, Multi-Shot
- No custom state builder
- No pet-specific logic (pet target, pet buffs, pet cooldowns)
- No Kill Command crit-window tracking (Kill Command is only usable after pet crits)
- No aspect management (Viper vs Hawk based on mana)

### Phase 1 Goals
1. **build_bm_state()** — Track:
   - `pet_active` and `pet_target_valid`
   - `kill_command_ready` (proc-based, not cooldown-based)
   - `aspect_should_be_viper` (mana < 30% and not in combat opener)
   - `bestial_wrath_duration_remaining`
2. **Kill Command windows** — Only suggest KC when the proc is active; don't waste it on non-damaging spells
3. **Pet management** — Ensure pet is on target; recall if it's about to die; cast Intimidation on CD in PvP
4. **Aspect dancing** — Swap to Viper when mana is low and not in burst window; return to Hawk when mana recovers

---

## Success Criteria

Each spec will be considered "deepened" when:
- [ ] It has a custom `build_*_state()` function with at least 5 spec-specific fields
- [ ] At least one strategy uses state-dependent logic that the thin implementation couldn't express
- [ ] The spec passes `luac -p` and existing regression tests
- [ ] A brief combat log excerpt demonstrates the new logic in action (e.g., "Shatter combo fired: Frostbolt → Ice Lance on frozen target")

---

*Selected based on class popularity in TBC Classic and the gap between current boilerplate and theorycrafted potential. Phase 1 begins when Phase 0 is complete.*
