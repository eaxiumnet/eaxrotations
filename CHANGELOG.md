# Changelog

All notable changes to the EAX TBC Classic Rotations project.

## [2.3.16] — Wowsims APL Alignment: Arcane Mage + Affliction Execute (2026-07-05)

### Features

- **Mage Arcane — wowsims-aligned burn/conserve rotation**
  - Conserve phase: AB3→Frostbolt to maintain buff cheaply (matches wowsims `ConserveRotation` group).
  - Mana Gem: fires when `maxMana > currentMana + gemRestore + regen` (3100 with Serpent-Coil Braid, 2500 without).
  - Evocation: fires only when Arcane Power AND Icy Veins are inactive and mana < 20%.
  - Presence of Mind: fires at end of AP window (AP remaining ≤ AB cast time) for one more instant AB.
  - Fire Blast execute: fires when target TTD < AB cast time (instant > casting).
  - Arcane Missiles: Clearcasting consumer ONLY — removed obsolete conserve filler role.

- **Warlock Affliction — wowsims-aligned execute phase**
  - Drain Soul: fires at target HP ≤ 5% (wowsims `remainingTimePercent <= 5%`) alongside existing shard capture.
  - Shadowburn: new execute strategy at target HP ≤ 5%, above Shadow Bolt filler priority.

### Technical
- All 220 rotation + 13 leveling suites green.

---

## [2.3.17] — Hunter Viper/Hawk Thresholds + Aimed Shot Opener (2026-07-05)

### Features

- **Hunter (all specs) — wowsims-aligned Viper/Hawk thresholds**
  - Aspect of the Viper: enters at 5% mana (was 20%).
  - Aspect of the Hawk: recovers at 25% mana (was 30% or viper_threshold+10).
  - Applies to Beast Mastery, Marksmanship, and Survival.
  - Shared `aspect_manager_sylvanas.lua` defaults updated to match.

- **Hunter Marksmanship — Aimed Shot opener**
  - Fires Aimed Shot at ≤ 0.5s into combat when Serpent Sting is not active.
  - Matches wowsims APL: `currentTime <= 0.5s` + `not dotIsActive(SerpentSting)`.
  - Replaces the old hard-disable (`return false`) that never allowed in-combat Aimed Shot.

### Technical
- All 220 rotation + 13 leveling suites green.

---

## [2.3.21] — Balance Mana Gem + Feral/Ret Verification (2026-07-05)

### Features
- **Druid Balance — mana gem strategy**
  - New ManaGem strategy fires when `maxMana > currentMana + 2400 + regen` (wowsims-aligned: `currentMana + 1500 < maxMana`).
  - Serpent-Coil Braid-aware restore (3100 vs 2500).
  - Placed before ManaPotion so gem fires first.

### Verification
- **Retribution Paladin**: seal twisting already implemented (`SealTwistBlood` + `SealTwistPrepCommand`) and matches wowsims APL concept.
- **Feral Cat**: Rip/FB/Shred/Mangle/Powershift logic already matches wowsims APL; snapshot tricks exceed wowsims fidelity.

### Technical
- All 220 rotation + 13 leveling suites green.

---

## [2.3.22] — Balance Nuke Fix + Cat Powershift Threshold (2026-07-05)

### Features
- **Druid Balance — Starfire is now the primary nuke (was Wrath)**
  - Wowsims APL defaults to Starfire (higher DPCT); Wrath is mana-conservation only.
  - Wrath now only fires when mana < `balance_starfire_mana` floor (default 40%).
  - Nature's Grace proc still forces Starfire for burst.
- **Druid Feral Cat — Powershift energy threshold raised from 20 to 25**
  - Wowsims APL powershifts at ≤30 energy; our default was 20 (conservative).
  - New default of 25 is a middle ground that's closer to wowsims without risking
    excessive mana burn on live (configurable via `cat_powershift_energy`).

### Technical
- All 220 rotation + 13 leveling suites green.

---

## [2.3.20] — Affliction Immolate Priority + Audit Updates (2026-07-05)

### Features
- **Warlock Affliction — wowsims-aligned Immolate priority**
  - Immolate moved from priority #13 to #8 (right after Siphon Life, matching wowsims APL: Corruption > UA > Siphon Life > Immolate).
  - Previously Immolate was buried below Drain Life and curses, causing significant uptime loss.

### Technical
- All 220 rotation + 13 leveling suites green.

---

## [2.3.19] — Fury Overpower Weaving (2026-07-05)

### Features
- **Warrior Fury — wowsims-aligned Overpower weaving (opt-in)**
  - Added `Overpower` strategy back to Fury (was previously removed as "Arms-only").
  - Wowsims APL includes an "Overpower Weaving" group: swap to Battle Stance when Overpower procs and both BT/WW are on CD ≥1.5s, cast Overpower, swap back.
  - Gated behind `fury_use_overpower` setting (default off) — opt-in for advanced users.
  - Conditions match wowsims: Delay Check (BT+WW ≥1.5s away), not in execute phase, rage 5-100.

### Technical
- All 220 rotation + 13 leveling suites green.

---

## [2.3.18] — Shadow Priest Shadowfiend Timing (2026-07-05)

### Features

- **Priest Shadow — wowsims-aligned Shadowfiend timing**
  - Short fight (<120s): fire early at <=45% mana for maximum mana return.
  - Long fight (>=120s): fire only when Vampiric Touch is active and remaining >= 1.5s (Shadowfiend GCD).
  - Emergency: always fire at <=15% mana regardless of fight length.
  - Replaces old flat <45% gate that ignored fight context.

### Technical
- All 220 rotation + 13 leveling suites green.

---

## [2.3.15] — Major-CD Window Rollout: Fury, Enhancement, Fire, BM, Shadow, Affliction (2026-07-05)

### Features

- **Warrior Fury**: Death Wish and Recklessness now align with Bloodlust/Heroism/Drums/other major CDs; timeout/TTD fallbacks prevent them from rotting.
- **Shaman Enhancement**: Shamanistic Rage now fires during major power windows in addition to the existing low-mana/low-HP defensive paths.
- **Mage Fire**: Combustion now waits for a major power window; prefers 5-stack Scorch before popping in non-burst mode; burst/manual override skips the Scorch gate.
- **Hunter Beast Mastery**: Bestial Wrath now aligns with major power windows.
- **Priest Shadow**: Racial cooldowns (Berserking, Blood Fury, Arcane Torrent) now align with major power windows.
- **Warlock Affliction**: Racial cooldowns now align with major power windows.

### Bug Fixes

- **Hunter Marksmanship**: Bestial Wrath is now gated on `NS.is_spell_learned` — a MM build can no longer attempt to cast the BM 31-point talent.

### What to Expect

- DPS specs now overlap personal offensive CDs and racials with Bloodlust/Heroism/Drums/windows instead of firing them immediately.
- Each affected CD still fires by timeout (45–60s) or when the target is dying, so nothing is held forever.
- No settings changes needed; behavior upgrades automatically.

---

## [2.3.14] — Cooldown Planner: Stack Trinkets with Bloodlust & Major CDs (2026-07-05)

### Features

- **New shared module: `shared/cooldown_planner_sylvanas.lua`**
  - Detects Bloodlust/Heroism and TBC drums on the player.
  - Detects major offensive cooldowns: Arcane Power, Icy Veins, Avenging Wrath, Bestial Wrath, Shamanistic Rage, Elemental Mastery, Power Infusion, Death Wish, Recklessness.
  - `should_fire_offensive()` aligns offensive trinkets/abilities with these power windows.
  - Timeout fallback (45s into combat) and TTD fallback (≤15s) stop trinkets from being held forever.
  - `trinket_align_with_cds = false` setting restores legacy "fire on cooldown" behavior.

- **Trinket Manager:** added `Berserker's Call` (item 33853) to the offensive on-use database.
- **Mage Arcane:** Arcane Power now also fires when Icy Veins or another major offensive CD is active, not just during bloodlust/burn.
- **Paladin Retribution:** Avenging Wrath now waits for Bloodlust/Drums/major CDs unless the target is dying or 45s timeout has passed.

### What to Expect

- DPS specs will overlap offensive trinkets and major abilities with Bloodlust/Heroism and other temporary power buffs instead of firing them randomly.
- No regression for users who prefer legacy behavior (`trinket_align_with_cds = false`).
- Drop-in replacement. Delete your old `EaxRotations` folder and replace with this one.
- All your settings carry over automatically.
- No settings reset needed.

---

## [2.3.13] — Hotfix: Hunter Serpent Sting Refresh + Marksmanship Aimed Shot (2026-07-05)

### Bug Fixes

- **Hunter (Beast Mastery / Survival)**: Serpent Sting was applied once and then never refreshed, letting the DoT fall off for the rest of the fight.
  - BM: Added a `SerpentStingRefresh` strategy that re-applies Serpent Sting when it has ≤ 3 seconds remaining.
  - Survival: Added the same `SerpentStingRefresh` behavior using the spec's native debuff tracking.
- **Hunter (Marksmanship)**: Disabled in-combat `AimedShot`. In TBC, Aimed Shot resets the auto-shot timer, so using it after the pull was a DPS loss. It remains available as the pre-pull opener (`AimedShotPrepull`) only.

### What to Expect

- Hunter BM/Survival: Serpent Sting now stays up on long fights and dungeon/raid bosses.
- Hunter Marksmanship: Cleaner Steady Shot / Arcane Shot / Multi-Shot rotation without the auto-shot reset from Aimed Shot.
- Drop-in replacement. Delete your old `EaxRotations` folder and replace with this one.
- All your settings carry over automatically.
- No settings reset needed.

---

## [2.3.12] — Auto-Loot Corpses (All Classes) + Shadow Priest Multi-DoT Fix (2026-07-05)

### Features

- **Auto-Loot Corpses** — Background service that automatically loots nearby corpses while your rotation runs. Humanized timing (random 50–200ms delay), combat-aware (OOC-only by default), burst protection (max 5 per 10s), bag-full pause, player-corpse skip, and configurable range (10–50y). Never blocks rotation casts. Disabled by default — opt-in via new "Auto-Loot" settings tab. Available in **all 9 class schemas** (Druid, Hunter, Mage, Paladin, Priest, Rogue, Shaman, Warlock, Warrior).
- **Auto-Loot Settings Tab** — 10 configurable options with self-explanatory labels and detailed tooltips: enable toggle, combat mode (OOC/Always), post-combat grace period (0–5s), min/max loot delay (0–300ms / 100–500ms), max loots per 10s (1–10), skip player corpses, stop when bags full, min free slots (0–20), loot range (10–50y).
- **Auto-Loot Stats** — Tracks corpses looted, last target name, and bag-full pause state per session.

### Bug Fixes

- **Shadow Priest**: Multi-DoT spread strategies (SWPSpread, VTSpread, MultiDotSWP, MultiDotVT) now correctly target enemies missing the debuff instead of recasting on the current target.

### What to Expect

- New "Auto-Loot" tab appears in your rotation settings. Enable it if you want automatic corpse looting.
- All settings carry over automatically — no reset needed.
- 219 rotation suites + 13 leveling suites all passing.

---

## [2.3.11] — Hotfix: Shadow Priest Multi-DoT Now Spreads to Real Targets (2026-07-05)

### Bug Fixes

- **Shadow Priest**: The Multi-DoT / Spread strategies (`SWPSpread`, `VTSpread`, `MultiDotSWP`, `MultiDotVT`) were recasting Shadow Word: Pain and Vampiric Touch on your current target instead of spreading them to nearby enemies that were actually missing the debuff. This made cleave and AoE damage fall behind on dungeon/raid packs.
  - Added a target picker that scans nearby enemies and selects one missing the DoT, preferring a target other than your current one.
  - Spread casts now apply their per-target lockout to the chosen enemy so the same target is not double-queued while a cast is in flight.

### What to Expect

- Shadow Priest: In cleave/AoE mode, your DoTs will now genuinely spread across multiple enemies instead of being wasted on the target that already has them.
- Drop-in replacement. Delete your old `EaxRotations` folder and replace with this one.
- All your settings carry over automatically.
- No settings reset needed.

---

## [2.3.10] — Hotfix: Hunter Aspect Manager Missing Middleware Strategies (2026-07-04)

### Bug Fixes

- **Hunter (all specs)**: Fixed `attempt to call field 'viper_middleware_strategy' (a nil value)` that caused the Hunter class module to fail loading entirely. The `aspect_manager_sylvanas.lua` shared module was missing the `viper_middleware_strategy()` and `hawk_middleware_strategy()` functions that the hunter middleware called directly into the strategies array. Added both with proper mana threshold gating, `settings.auto_aspect` guard, buff detection, and `skip_range` casting.

### What to Expect

- Hunter: The rotation loads and runs correctly again. Aspect switching between Hawk and Viper works as intended in combat.
- Drop-in replacement. Delete your old `EaxRotations` folder and replace with this one.
- All your settings carry over automatically.
- No settings reset needed.

---

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
