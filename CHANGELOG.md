# Changelog

All notable changes to the EAX TBC Classic Rotations project.

## [2.3.2] — Hotfix: Holy Priest Crash + Dispel Spam (2026-07-03)

### Bug Fixes

- **Holy Priest (TBC + Classic)**: Fixed a crash that spammed the error log during combat. The rotation now runs smoothly without flooding your console.
- **Holy Priest (TBC + Classic)**: Fixed Dispel Magic and Cure Disease firing repeatedly on party members who had no debuffs. Now only casts when someone actually needs cleansing.
- **Shadow Priest (Classic)**: Dispel Magic now only casts when YOU have a magic debuff (Polymorph, Silence, Mind Control, etc.) instead of wasting it on cooldown.
- **Smite Priest (TBC + Classic)**: Fixed the same combat crash as Holy Priest.
- **Kebab Warrior (TBC + Classic)**: Fixed the same combat crash.

### What to Expect

- Drop-in replacement. Delete your old `EaxRotations` folder and replace with this one.
- All your settings carry over automatically.
- No settings reset needed.

---

## [2.2.5] — Leveling Rotation Fixes (2026-07-02)

### Bug Fixes

- **Warrior Classic Leveling**: Shield Bash and Pummel interrupts now work correctly.
- **Mage Classic Leveling**: Removed duplicate logic causing erratic Scorch and Fireball behavior.
- **Shaman Classic Leveling**: Cleaned up duplicate totem checks.
- **Paladin Classic Leveling**: Cleaned up duplicate seal selection.
- **Priest Classic Leveling**: Cleaned up duplicate Mind Flay checks.
- **Rogue Classic Leveling**: Cleaned up duplicate Thistle Tea checks.

### What to Expect

- 214/214 rotation test suites pass.
- 13/13 leveling test suites pass.
- Drop-in replacement over v2.2.4. No settings reset.

---

## [2.2.4] — Classic Leveling Spell Coverage + Stability (2026-07-01)

### New Features

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
- **Retribution Aura**: maintained out-of-combat as alternative to Devotion Aura for solo DPS.

### Fixes

- **EaxAutoQuester**: Fixed crash from merge conflict markers. Better quest dialog detection and NPC rendering.
- **Protection Paladin (TBC)**: Holy Shock no longer wasted offensively when tank health is low.
- **Enhancement Shaman (Classic)**: Fixed crash on spell interrupt check.

### What to Expect

- 214/214 rotation suites pass.
- 13/13 leveling suites pass.
- Drop-in replacement over v2.2.3. No settings reset.
