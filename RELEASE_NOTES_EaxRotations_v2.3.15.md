# EaxRotations v2.3.15 Release Notes

**Release Date**: 2026-07-05

## Summary

This release rolls the cooldown planner’s power-window alignment out to every DPS spec that has a personal offensive cooldown or racial. Instead of firing major abilities on cooldown, the rotation now waits for Bloodlust/Heroism, TBC drums, or another major offensive buff whenever practical, then layers all available cooldowns on top of each other. Timeout and TTD fallbacks ensure CDs are never held forever.

## What's New

### Major-CD Window Alignment

| Spec / Ability | Behavior |
|----------------|----------|
| **Warrior Fury — Death Wish** | Aligns with Bloodlust/Drums/major CDs; 45s timeout / 15s TTD fallback. |
| **Warrior Fury — Recklessness** | Aligns with major power windows; 60s timeout / 20s TTD fallback. |
| **Shaman Enhancement — Shamanistic Rage** | Now fires offensively during power windows while keeping low-mana/low-HP defensive use. |
| **Mage Fire — Combustion** | Aligns with power windows; waits for 5-stack Scorch unless burst is forced; 45s timeout / 15s TTD fallback. |
| **Hunter Beast Mastery — Bestial Wrath** | Aligns with power windows; 45s timeout / 15s TTD fallback. |
| **Priest Shadow — Racials** | Berserking, Blood Fury, Arcane Torrent align with power windows. |
| **Warlock Affliction — Racials** | Blood Fury, Berserking, Arcane Torrent align with power windows. |

All timeout/TTD values are intentionally conservative so speed kills and dungeon pulls still benefit from the cooldown.

### Bug Fix

- **Hunter Marksmanship**: the `BestialWrath` strategy is now correctly gated on `NS.is_spell_learned(SPELLS.BestialWrath)`. Marksmanship builds no longer attempt to cast the 31-point Beast Mastery talent.

## Upgrade Notes

- No settings reset required.
- No action required by users.
- All affected logic respects the existing `use_cooldowns` toggle.

## Test Results

- 220 / 220 rotation suites passing
- 13 / 13 leveling suites passing
- All Lua files pass `luac -p`
- Sylvanas spell ID audit: all 61 sylvanas files clean against DBC `2.5.5.68101`
