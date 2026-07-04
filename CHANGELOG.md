# Changelog

All notable changes to the EAX TBC Classic Rotations project.

## [2.3.9] — Hotfix: Shadow Priest Mind Flay Opener Fix (2026-07-03)

### Bug Fixes

- **Shadow Priest**: Fixed Mind Flay firing as the opening spell on fresh targets. Every other damage spell (Shadow Word: Pain, Mind Blast, Shadow Word: Death, Devouring Plague, Vampiric Embrace, Starshards) checks `_engaged_with_player()` to prevent casting on a mob that hasn't targeted you yet. Mind Flay was missing this gate, so it became the default opener when SW:P and MB were blocked. Added the missing check.

### What to Expect

- Shadow Priest: No more "Mind Flay opener" on fresh pulls. The rotation now correctly opens with Shadow Word: Pain → Mind Blast → Mind Flay, or auto-attacks first to establish aggro if needed.
- Drop-in replacement. Delete your old `EaxRotations` folder and replace with this one.
- All your settings carry over automatically.
- No settings reset needed.

---

## [2.3.3] — Hotfix: Settings Nil-Guard Sweep (2026-07-03)

### Bug Fixes

- **Priest Holy (TBC + Classic)**: All settings reads now nil-guarded. Previously accessing `context.settings.holy_use_pws`, `holy_use_coh`, `holy_use_binding_heal`, `holy_use_poh`, `holy_use_inner_focus`, `holy_use_lightwell`, `holy_use_desperate_prayer`, `use_party_dispel`, `disc_shield_tank_only`, and `use_shadowfiend` without checking if `context.settings` existed could crash during API hiccups or load race conditions.
- **Priest Smite (TBC + Classic)**: All settings reads now nil-guarded. Fixed `smite_use_shadowfiend`, `smite_use_power_infusion`, `smite_use_inner_focus`, `smite_use_starshards`, `smite_use_devouring_plague`, `smite_use_mb`, and `smite_use_swd`.
- **Priest Discipline (Classic)**: Fixed `disc_use_friendly_target` settings access.
- **Priest Middleware (TBC)**: Fixed `use_threat_drop` settings access.
- **Druid Restoration (Classic)**: Fixed `resto_use_friendly_target` settings access.
- **Druid Middleware (TBC)**: Fixed `use_threat_drop` settings access.
- **Paladin Holy (Classic)**: Fixed `holy_use_friendly_target` settings access.
- **Warlock Middleware (TBC)**: Fixed `use_threat_drop` settings access.

### What to Expect

- Drop-in replacement. Delete your old `EaxRotations` folder and replace with this one.
- All your settings carry over automatically.
- No settings reset needed.

---

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
