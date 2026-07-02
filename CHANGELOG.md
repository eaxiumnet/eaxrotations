# Changelog

All notable changes to the EAX TBC Classic Rotations project.

## [2.2.5] — Leveling Rotation Fixes (2026-07-02)

### Bug Fixes

- **Warrior Classic Leveling**: Shield Bash and Pummel interrupts were non-functional due to missing function closures. Fixed.
- **Mage Classic Leveling**: Removed duplicate `scorch_matches` function.
- **Mage Classic Leveling**: Removed duplicate `fireball_ready` and `scorch_ready` assignments in build_state.
- **Shaman Classic Leveling**: Removed duplicate `tremor_totem_ready` assignment.
- **Paladin Classic Leveling**: Removed duplicate `selected_seal` assignment.
- **Priest Classic Leveling**: Removed duplicate `mf_ready` assignment.
- **Rogue Classic Leveling**: Removed duplicate `thistle_tea_ready` assignment.

### Stability

- 214/214 rotation test suites pass.
- 13/13 leveling test suites pass.
- No settings reset required. Drop-in replacement over v2.2.4.

---

## [2.2.4] — Classic Leveling Spell Coverage + Stability (2026-07-01)

### Features

**Hunter Leveling**
- **Raptor Strike**: instant melee attack when enemies close into melee range.
- **Mongoose Bite**: instant melee attack after a dodge proc.

**Mage Leveling**
- **Fireball**: primary fire nuke, respects movement and mana gates.

**Rogue Leveling**
- **Sap**: cast on humanoid targets while stealthed and out of combat.

**Priest Leveling**
- **Vampiric Embrace**: maintained automatically in Shadowform for passive healing.
- **Desperate Prayer**: emergency self-heal below 40% HP (racial, no mana cost).

**Shaman Leveling**
- **Stormstrike**: instant melee attack in melee range.

**Warrior Leveling**
- **Pummel**: Berserker Stance interrupt.
- **Bloodthirst**: Fury talent rage spender (level 40).
- **Shield Slam**: Protection talent threat generator (level 40).

**Paladin Leveling**
- **Holy Shield**: cast when fighting multiple enemies below 70% HP.
- **Retribution Aura**: maintained OOC as alternative to Devotion Aura for solo DPS.

### Fixes

- **EaxAutoQuester**: Resolved crash from leftover merge conflict markers in NPC manager. Improved quest dialog detection, NPC rendering pause, proximity NPC fallback.
- **Protection Paladin (TBC)**: Holy Shock no longer burned offensively when tank HP below Flash of Light threshold.
- **Enhancement Shaman (Classic)**: Fixed crash in spellcasting interrupt check on stale target proxy.

### Verified

- 214/214 rotation suites pass.
- 13/13 leveling suites pass.
- All 12 spells verified against DBC + Wowhead Classic.
- Drop-in replacement over v2.2.3. No settings reset required.

---
