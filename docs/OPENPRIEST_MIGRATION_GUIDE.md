# OpenPriest → EaxRotations Migration Guide

**Last updated**: 2026-05-21

---

## 1. Overview

This guide helps OpenPriest users migrate from the **Flux** rotation engine to **EaxRotations** (Project Sylvanas). EaxRotations is the successor architecture — all four Priest specs (Discipline, Holy, Shadow, Smite) have been rebuilt as flat `_sylvanas.lua` files with shared middleware and healing modules.

### Key Architectural Differences

| Aspect | Flux (OpenPriest) | EaxRotations |
|--------|-------------------|--------------|
| **Engine** | Flux rotation framework | Project Sylvanas (`main_sylvanas.lua` dispatcher) |
| **File structure** | `aio/priest/{discipline,holy,shadow}.lua` + `schema.lua` | `classes/priest/{discipline,holy,shadow,smite}_sylvanas.lua` + shared modules |
| **Settings** | Flux schema table (`flux.rotation.flags`) | EaxRotations schema (`schema_sylvanas.lua`) + `context.settings` |
| **Spell casting** | `try_heal_cast_fmt`, `A.SpellName`, `icon` object model | `NS.try_cast(spell, target, label, opts)`, `SPELLS.SpellName` |
| **Targeting** | `triage_unit`, `context.target` via healing engine | `s.lowest`, `s.tank` via `build_state()` scan + `NS.GetPartyMembers()` |
| **PvP** | Separate `pvp.lua` module (Flux-only) | Integrated into `middleware_sylvanas.lua` (offensive dispel, Mass Dispel, Mana Burn, SW:D CC break) |
| **Extra spec** | 3 specs (Disc, Holy, Shadow) | 4 specs (Disc, Holy, Shadow, **Smite**) |

---

## 2. Spec Mapping

| Flux OpenPriest | EaxRotations | Notes |
|-----------------|--------------|-------|
| `priest/discipline.lua` | `classes/priest/discipline_sylvanas.lua` | Tank-shield-only, absorbs, Penance priority |
| `priest/holy.lua` | `classes/priest/holy_sylvanas.lua` | Serendipity-aware, Prayer of Healing gating |
| `priest/shadow.lua` | `classes/priest/shadow_sylvanas.lua` | DoT priority, execute phase SW:D, PvP CC break |
| *(no Flux equivalent)* | `classes/priest/smite_sylvanas.lua` | **New** — Smite DPS spec (Holy DPS via Surge of Light) |

**Shared modules** (no Flux equivalent):
- `classes/priest/healing_sylvanas.lua` — Cross-spec healing helpers (`pws_absorb_remaining`, smart PW:S targeting)
- `classes/priest/middleware_sylvanas.lua` — PvP strategies, reaction delay, party dispels, consumables
- `classes/priest/class_sylvanas.lua` — Class bootstrapping + spell tables

---

## 3. Configuration Migration

### 3.1 Setting Name Mappings

Flux settings use `schema.lua` keys accessed via `context.settings.<key>`. EaxRotations uses the same pattern with renamed/restructured keys:

#### Discipline

| Flux Key | EaxRotations Key | Type | Notes |
|----------|-----------------|------|-------|
| `disc_shield_tank_only` | `disc_shield_tank_only` | checkbox | **Identical** — ported 1:1 |
| `disc_pws_hp` | `discipline_pws_hp` | slider (0-100) | Renamed — same function, HP threshold for emergency PW:S |
| `disc_penance_heal` | *(inline strategy)* | — | Penance always casts when ready; no toggle needed |
| `disc_pain_suppression_hp` | `discipline_pain_suppression_hp` | slider (0-100) | Renamed — tank HP threshold for Pain Suppression |
| `disc_pwbarrier_targets` | — | — | **Not available** — Power Word: Barrier is a Cataclysm spell |
| `disc_proactive_shield` | *(always active)* | — | Proactive tank shielding is built into the tank PW:S strategy |
| `disc_atonement` | — | — | **Not available** — Atonement is not in TBC |
| `disc_power_infusion_mode` | — | — | **Not available** — configurable via shared trinket/cooldown manager in future |
| `disc_reaction_delay_ms` | `reaction_delay_ms` | slider (0-400ms) | **Renamed** — moved to shared Performance section (applies to all healing specs) |

#### Holy

| Flux Key | EaxRotations Key | Type | Notes |
|----------|-----------------|------|-------|
| `holy_coh_hp` | `holy_circle_of_healing_hp` | slider (0-100) | Renamed — HP threshold for Circle of Healing |
| `holy_poh_hp` | `holy_prayer_of_healing_hp` | slider (0-100) | Same function, renamed for clarity |
| `holy_renew_hp` | `holy_renew_hp` | slider (0-100) | Same key |
| `holy_flash_heal_hp` | `holy_flash_heal_hp` | slider (0-100) | Same key |
| `holy_binding_heal_hp` | `holy_binding_heal_hp` | slider (0-100) | Same key |
| `holy_greater_heal_hp` | `holy_greater_heal_hp` | slider (0-100) | Same key |
| `holy_serendipity_stacks` | *(inline state tracking)* | — | Serendipity stacks tracked in `build_state()`, not configurable |
| `holy_lightwell_hp` | — | — | **Not available** — Lightwell is a WotLK spell |
| `holy_guardian_spirit_hp` | `holy_guardian_spirit_hp` | slider (0-100) | Same function |

#### Shadow

| Flux Key | EaxRotations Key | Type | Notes |
|----------|-----------------|------|-------|
| `shadow_vt_refresh` | `shadow_vampiric_touch_refresh` | slider (seconds) | Renamed — refresh window for Vampiric Touch |
| `shadow_swp_refresh` | `shadow_shadow_word_pain_refresh` | slider (seconds) | Renamed — refresh window for SW:P |
| `shadow_dp_refresh` | `shadow_devouring_plague_refresh` | slider (seconds) | Renamed — refresh window for Devouring Plague |
| `shadow_mind_blast_cd` | *(always cast on CD)* | — | Mind Blast always used when available |
| `shadow_swd_execute_hp` | *(built-in)* | — | SW:D execute at ≤20% HP by default |
| `shadow_swd_cc_break` | *(built-in PvP)* | — | SW:D CC break integrated into middleware strategies |
| `shadow_dispersion_hp` | — | — | **Not available** — Dispersion is WotLK |
| `shadow_vampiric_embrace` | *(always active)* | — | Always maintained (0 downtime) |

#### Shared / Performance

| Flux Key | EaxRotations Key | Type | Notes |
|----------|-----------------|------|-------|
| `reaction_delay_ms` | `reaction_delay_ms` | slider (0-400, step 10) | Moved to Performance section — applies to all healing specs |
| `auto_dispel_magic` | *(middleware)* | — | Party dispel is a middleware strategy, always active |
| `auto_dispel_disease` | *(middleware)* | — | Abolish Disease is a middleware strategy, always active |
| `auto_fade` | *(middleware)* | — | Enhanced Fade is a middleware strategy (threat threshold) |
| `auto_fear` | *(middleware)* | — | Psychic Scream is a PvP middleware strategy |
| *(Flux pvp.lua)* | *(middleware_sylvanas.lua)* | — | PvP features are now integrated middleware strategies |

---

## 4. Feature Parity Table

### ✅ Fully Ported (Feature-complete)

| Feature | Flux | EaxRotations | Notes |
|---------|------|--------------|-------|
| PW:S emergency shielding | ✅ | ✅ | Tank/non-tank split, absorb tracking |
| Tank-shield-only mode | ✅ | ✅ | 1:1 port |
| Penance priority | ✅ | ✅ | Always first in discipline rotation |
| Pain Suppression | ✅ | ✅ | Tank HP-gated |
| Prayer of Mending | ✅ | ✅ | Smart bounce tracking |
| Circle of Healing | ✅ | ✅ | Party HP threshold gating |
| Prayer of Healing | ✅ | ✅ | Serendipity-aware |
| Binding Heal | ✅ | ✅ | Self+target HP gating |
| Greater Heal | ✅ | ✅ | Serendipity haste bonus tracked |
| Renew maintenance | ✅ | ✅ | Smart refresh window |
| Vampiric Touch | ✅ | ✅ | Refresh window configurable |
| Shadow Word: Pain | ✅ | ✅ | Refresh window configurable |
| Devouring Plague | ✅ | ✅ | Refresh window configurable |
| SW:D execute | ✅ | ✅ | Sub-20% HP threshold |
| SW:D CC break | ❌ (Flux pvp.lua) | ✅ (middleware) | Ported from OpenPriest PvP module |
| Offensive Dispel | ❌ (Flux pvp.lua) | ✅ (middleware) | Priority-based dispel database |
| Mass Dispel | ❌ (Flux pvp.lua) | ✅ (middleware) | Purges Divine Shield/Ice Block |
| Mana Burn | ❌ (Flux pvp.lua) | ✅ (middleware) | Healer class targeting |
| Reaction delay tuning | ✅ | ✅ | Slider 0-400ms, burst-bypass |
| Party dispel (Magic) | ✅ | ✅ | Middleware strategy |
| Abolish Disease | ✅ | ✅ | Middleware strategy |
| Inner Focus | ✅ | ✅ | Used before Greater Heal |
| Shadowfiend | ✅ | ✅ | Mana-gated |
| Consumables (Healthstone, pots) | ✅ | ✅ | Shared consumable manager |
| Weakened Soul tracking | ✅ | ✅ | 15s lockout respected |

### ⚠️ Partial / Different Implementation

| Feature | Flux | EaxRotations | Notes |
|---------|------|--------------|-------|
| Proactive tank shielding | Dedicated pre-pull strategy | Built into tank PW:S strategy | Always shields tank when not in combat and no Weakened Soul |
| Power Infusion | Separate config | Via shared cooldown manager | Use on self or target; configurable in future |
| Fade (threat drop) | Configurable threshold | Middleware strategy (fixed 80% threat) | Hardcoded threshold; slider planned |
| Silence (interrupt) | Flux interrupt system | Shared `interrupt_manager_sylvanas.lua` | Same functionality, different registration |

### ❌ Not Available (TBC-era limitations)

| Feature | Reason |
|---------|--------|
| Power Word: Barrier | Cataclysm spell (level 68+ in Cata) |
| Atonement (Smite healing) | Not available in TBC |
| Archangel / Evangelism | Cataclysm mechanics |
| Lightwell | WotLK spell |
| Dispersion | WotLK spell (Shadow 51-pt) |
| Leap of Faith | Cataclysm spell |
| Divine Hymn | WotLK spell |
| Hymn of Hope | WotLK spell |

### 🆕 New in EaxRotations (No Flux Equivalent)

| Feature | Notes |
|---------|-------|
| **Smite spec** | Full Holy DPS rotation with Surge of Light procs, Holy Fire, Smite priority |
| **PW:S absorb tracking** | `pws_absorb_remaining()` prevents overwriting healthy shields (threshold: 200 absorb) |
| **Burst window bypass** | Reaction delay automatically disabled during `should_burst` |
| **Control panel integration** | `disc_shield_tank_only` exposed on Sylvanas control panel |
| **Leveling rotations** | Separate leveling spec files for Discipline, Holy, Shadow |

---

## 5. Spell ID Reference

Both codebases use TBC spell IDs. Key spell mappings if you were referencing Flux spell names:

| Flux `A.*` constant | Spell ID (max rank) | EaxRotations equivalent |
|---------------------|---------------------|------------------------|
| `A.PowerWordShield` | 25348 | `SPELLS.PowerWordShield` |
| `A.Penance` | 31943 | `SPELLS.Penance` |
| `A.PainSuppression` | 33206 | `SPELLS.PainSuppression` |
| `A.PrayerOfMending` | 33077 | `SPELLS.PrayerOfMending` |
| `A.FlashHeal` | 25314 | `SPELLS.FlashHeal` |
| `A.GreaterHeal` | 25316 | `SPELLS.GreaterHeal` |
| `A.BindingHeal` | 32546 | `SPELLS.BindingHeal` |
| `A.Renew` | 25315 | `SPELLS.Renew` |
| `A.CircleOfHealing` | 34865 | `SPELLS.CircleOfHealing` |
| `A.InnerFocus` | 14751 | `SPELLS.InnerFocus` |
| `A.MassDispel` | 32375 | `SPELLS.MassDispel` |
| `A.DispelMagic` | 988 | `SPELLS.DispelMagic` |
| `A.ManaBurn` | 8129 | `SPELLS.ManaBurn` |
| `A.VampiricTouch` | 34917 | `SPELLS.VampiricTouch` |
| `A.ShadowWordPain` | 25368 | `SPELLS.ShadowWordPain` |
| `A.DevouringPlague` | 25467 | `SPELLS.DevouringPlague` |
| `A.MindBlast` | 25376 | `SPELLS.MindBlast` |
| `A.ShadowWordDeath` | 32996 | `SPELLS.ShadowWordDeath` |
| `A.VampiricEmbrace` | 15286 | `SPELLS.VampiricEmbrace` |
| `A.Silence` | 15487 | `SPELLS.Silence` |
| `A.PsychicScream` | 10890 | `SPELLS.PsychicScream` |
| `A.Fade` | 25431 | `SPELLS.Fade` |
| `A.Shadowfiend` | 34433 | `SPELLS.Shadowfiend` |
| `A.AbolishDisease` | 793 | `SPELLS.AbolishDisease` |

---

## 6. Quick Start Checklist

### Before switching:
1. **Note your current Flux settings** — especially HP thresholds and refresh windows
2. **Run both rotations side-by-side** on a target dummy to compare behavior
3. **Verify spell IDs** match your TBC client version (EaxRotations uses patch 2.4.3 spell IDs)

### After loading EaxRotations:
1. **Open the control panel** and enable the Priest rotation toggle
2. **Configure HP thresholds** for each healing spell to match your Flux preferences
3. **Set `reaction_delay_ms`** (Performance section) — recommended: 50-150ms for healing, 0ms for DPS
4. **Enable `disc_shield_tank_only`** if you only want PW:S on the tank
5. **Check PvP settings** — offensive dispel, Mass Dispel, and Mana Burn are auto-enabled with no UI toggles yet
6. **Verify DoT refresh windows** for Shadow (Vampiric Touch, SW:P, Devouring Plague)

---

## 7. Troubleshooting

| Symptom | Likely Cause | Fix |
|---------|-------------|-----|
| PW:S not casting on non-tank | `disc_shield_tank_only` is enabled | Disable in schema settings |
| Rotation feels too fast/mechanical | `reaction_delay_ms` too low | Increase to 100-200ms for more human-like feel |
| No spells during burst | Reaction delay bypassed during burst by design | Expected — delay only applies outside burst windows |
| Mass Dispel not working | No PvP target detected with priority buffs | Verify enemy has Divine Shield/Ice Block/Bloodlust active |
| Smite DPS not casting | Surge of Light not procced; Holy Fire on cooldown | Smite filler will cast when no procs available |
| Mana Burn not targeting healers | Enemy team has no healer-class targets | Mana Burn requires Paladin/Priest/Shaman/Druid targets |

---

## 8. Architecture Reference

### File Structure Comparison

```
# Flux OpenPriest
flux/rotation/source/aio/priest/
├── schema.lua          # All settings
├── discipline.lua      # Disc rotation
├── holy.lua            # Holy rotation
├── shadow.lua          # Shadow rotation
└── pvp.lua             # PvP module (Flux engine only)

# EaxRotations
EaxRotations/classes/priest/
├── schema_sylvanas.lua       # All settings (renamed keys)
├── discipline_sylvanas.lua   # Disc rotation (tank/non-tank PW:S split)
├── holy_sylvanas.lua         # Holy rotation (same HP thresholds)
├── shadow_sylvanas.lua       # Shadow rotation (+ SW:D CC break)
├── smite_sylvanas.lua        # 🆕 Smite DPS spec
├── healing_sylvanas.lua      # Cross-spec healing (PW:S absorb tracking)
├── middleware_sylvanas.lua    # PvP + reaction delay + dispels
├── class_sylvanas.lua        # Class bootsrapping + spell tables
├── leveling_sylvanas.lua     # Leveling rotation dispatcher
├── holy_sylvanas.lua
└── shadow_sylvanas.lua
```

---

*This guide covers all features as of EaxRotations v1.0.30. Future updates will add Power Infusion targeting, Fade threshold sliders, and PvP toggles for offensive dispel/Mana Burn.*
