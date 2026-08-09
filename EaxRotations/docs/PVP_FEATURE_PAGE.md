# EaxRotations - PvP Features

TBC Classic Anniversary rotation framework for Project Sylvanas. PvP logic activates automatically in Arenas and Battlegrounds via `context.is_arena` and `context.is_battleground` flags. Covers 29 primary specializations across 9 classes (31 entries including 2 adjunct specs: Druid Caster and Priest Healing).

---

## Core PvP Systems

### Mode Detection
The engine detects instance type on each tick in `main_sylvanas.lua`:
- `is_arena` — set when `instance_type == "arena"`
- `is_battleground` — set when `instance_type == "pvp"`
- `is_pvp` — true in arena, battleground, or PvP-flagged zones (checked via `NS.is_pvp_zone()`)

### Arena Priority Targeting
`shared/arena_priority_sylvanas.lua` provides:
- Target scoring based on HP percentage, class (healer bonus), armor type (cloth bonus), casting state, and defensive buffs
- Separate kill target and CC target rankings
- Target switch threshold (default 30 point difference)
- Healer detection via `get_class()`

### Diminishing Returns Tracking
`core_sylvanas.lua` populates `context.target_dr_stun` per tick. The following abilities gate on `NS.DRTracker.is_dr_immune()`:
- Polymorph (Mage) — gated on `incapacitate` DR
- Repentance (Paladin Retribution) — gated on `disorient` DR
- Wyvern Sting (Hunter Survival) — gated on `incapacitate` DR
- Hammer of Justice (Paladin Holy/Protection) — gated on `stun` DR
- Cheap Shot (Rogue Combat) — gated on `stun` DR
- Kidney Shot (Rogue Combat/Subtlety) — gated on `stun` DR

### PvP Trinket Awareness
`core_sylvanas.lua` wraps `pvp_helper.is_trinket_used()` to provide `NS.pvp_trinket_used_recently(unit, window)`. Polymorph and Repentance strategies check this before casting.

### Burst Window Scoring
`shared/pvp_burst_window_sylvanas.lua` computes a 0-100 score each tick based on target HP, defensive buffs, casting state, player HP, offensive cooldown availability, and DR immunity status.

`shared/burst_logic_sylvanas.lua` provides `should_auto_burst()` which gates offensive cooldowns on:
- `burst_in_combat`
- `burst_on_pull` (< 5s)
- `burst_on_execute` (target <= 20% HP)
- `burst_on_bloodlust` (with 45-second timeout fallback)
- `cd_min_ttd` (do not burst on dying targets)

### Offensive Dispel Priority
`shared/offensive_dispel_sylvanas.lua` maintains a tiered database of enemy buffs:
- Critical: Divine Shield, Ice Block, Blessing of Protection, Pain Suppression
- High: Bloodlust, Heroism, Power Infusion, Innervate, Recklessness, Arcane Power, Bestial Wrath, Icy Veins, Adrenaline Rush, Death Wish
- Medium: Fortitude, Mark of the Wild, Arcane Intellect
- Low: Thorns, Inner Fire

### Trinket Manager
`shared/trinket_manager_sylvanas.lua` handles on-use trinkets:
- Offensive trinkets fire during burst windows when `use_trinket_offensive` is enabled
- Defensive trinkets fire at configurable HP threshold (`trinket_defensive_hp`, default 40%)
- Respects `cd_min_ttd`

### Auto-Consumables
Class middleware files wire `consumable_manager.should_check()` for healthstones and potions. Thresholds are per-spec and configurable via schema sliders.

---

## Defensive Features

| Feature | Classes | Implementation |
|---------|---------|----------------|
| Fear break | Warrior | Berserker Rage auto-casts when `is_feared_sapped_or_incapacitated()` returns true (Arms, Fury, Protection); Death Wish also breaks fear (Arms, Fury) |
| Preemptive CC break | Paladin | Divine Shield / Blessing of Freedom when enemy casts Polymorph/Fear/Repentance at player |
| Preemptive CC break | Druid | Shapeshift when enemy casts Polymorph/Cyclone/Hibernate; break roots/snares |
| Preemptive CC break | Rogue | Cloak of Shadows / Vanish when enemy casts Polymorph/Fear/Blind at player |
| Preemptive CC break | Warlock | Death Coil when enemy casts Polymorph/Fear/Cyclone at player |
| CC break (dispel) | Priest | Shadow Word: Death self-cast when enemy casts preemptive CC (detection logic exists in `offensive_dispel_sylvanas.lua`; strategy wiring in priest specs is unverified) |
| Cloak of Shadows | Rogue | Auto-cast at configurable HP (`rogue_cloak_hp`, default 45%) |
| Ice Barrier | Mage | Auto-cast at configurable thresholds. Toggle via `use_ice_barrier` |
| Barkskin | Druid | Auto-cast when HP drops below `barkskin_hp` (Resto default: 55%) |
| Grounding Totem | Shaman | Cast when `grounding_totem_ready` in Enhancement spec only |
| Tremor Totem | Shaman | Auto-drop when targeting a fear boss or a nearby ally is feared (`shared/auto_tremor_sylvanas.lua`) |
| Shield Slam Purge | Warrior Prot | Dispels 1 magic buff on enemy players when `use_shield_slam_purge` enabled |

---

## Class & Spec PvP Scores (TBC)

From `scorecard_data.md` (generated 2026-06-30):

| Class | Spec | Arena | Battleground |
|-------|------|:-----:|:------------:|
| Warrior | Arms | 5 | 5 |
| Warrior | Fury | 5 | 5 |
| Warrior | Protection | 5 | 5 |
| Warrior | Kebab | 4 | 5 |
| Hunter | Beast Mastery | 4 | 5 |
| Hunter | Marksmanship | 4 | 5 |
| Hunter | Survival | 5 | 5 |
| Mage | Arcane | 5 | 5 |
| Mage | Fire | 5 | 5 |
| Mage | Frost | 5 | 5 |
| Paladin | Holy | 5 | 5 |
| Paladin | Protection | 5 | 5 |
| Paladin | Retribution | 5 | 5 |
| Priest | Discipline | 4 | 5 |
| Priest | Holy | 3 | 3 |
| Priest | Shadow | 4 | 5 |
| Priest | Smite | 4 | 4 |
| Rogue | Assassination | 5 | 5 |
| Rogue | Combat | 5 | 5 |
| Rogue | Subtlety | 5 | 5 |
| Shaman | Elemental | 5 | 5 |
| Shaman | Enhancement | 5 | 5 |
| Shaman | Restoration | 5 | 5 |
| Warlock | Affliction | 5 | 5 |
| Warlock | Demonology | 5 | 5 |
| Warlock | Destruction | 4 | 4 |
| Druid | Balance | 5 | 5 |
| Druid | Bear | 4 | 5 |
| Druid | Cat | 4 | 4 |
| Druid | Caster | 4 | 4 |
| Druid | Restoration | 4 | 4 |

Note: "Caster" and "Healing" (Priest) are adjunct/leveling specs, not primary raid specs.

---

## Configurable Settings

Verified PvP-relevant settings found in schema files:

| Setting | Description | Classes |
|---------|-------------|---------|
| `use_cc_break` | Preemptively break incoming CC | Paladin, Druid, Rogue, Warlock, Mage |
| `use_pvp_cc_gating` | Skip AoE when nearby enemy is CC'd | Druid, Paladin, Rogue, Warrior |
| `use_pvp_defensives` | Enable PvP defensive logic | Warlock, Mage, Priest |
| `repentance_pvp_usage` | Enable Repentance in PvP | Paladin Retribution |
| `shadowstep_usage` | Always / Burst Only / Off | Rogue Subtlety |
| `viper_sting_hp_threshold` | Viper Sting HP threshold | Hunter |
| `viper_sting_priest` | Viper Sting on Priests | Hunter |
| `shield_slam_purge_pvp_only` | Only purge enemy players | Warrior Protection |
| `use_shield_slam_purge` | Shield Slam dispels magic buffs | Warrior Protection |
| `use_interrupt` | Enable interrupts | All classes |
| `use_cooldowns` | Enable offensive cooldowns | All classes |
| `burst_on_bloodlust` | Hold CDs for Bloodlust/Drums | All classes (via burst_logic) |
| `burst_in_combat` | Fire CDs on combat entry | All classes (via burst_logic) |
| `burst_on_execute` | Fire CDs at execute range | All classes (via burst_logic) |
| `cd_min_ttd` | Minimum TTD to use CDs | All classes (via burst_logic) |
| `purge_pvp_only` | Only purge in PvP | Shaman |
| `purge_min_mana_pct` | Minimum mana to purge | Shaman |
| `use_spellsteal` | Steal enemy magic buffs | Mage |
| `spellsteal_mana_floor` | Minimum mana to Spellsteal | Mage |
| `use_trinket_offensive` | Use offensive on-use trinkets | All classes (via trinket_manager) |
| `use_trinket_defensive` | Use defensive on-use trinkets | All classes (via trinket_manager) |
| `trinket_defensive_hp` | HP threshold for defensive trinkets | All classes (via trinket_manager) |

---

## Safety Gates

Every action passes shared gates in `core_sylvanas.lua` and `main_sylvanas.lua`:
- Player exists and is alive
- Target is valid, attackable, and in range
- Spell is known, off cooldown, and affordable
- Stance/form requirements are met
- PvP-specific gates (DR immunity, trinket status) allow the action

---

## Test Coverage

Verified PvP-related test files:

| Test | Coverage |
|------|----------|
| `test_arena_priority.lua` | Arena target scoring and switching logic |
| `test_burst_window.lua` | PvP burst window 0-100 scoring |
| `test_burst_logic_integration.lua` | Offensive cooldown gating (bloodlust/execute/TTD) |
| `test_trinket_manager.lua` | On-use trinket activation logic |
| `test_interrupt_manager.lua` | Spell interrupt routing |
| `test_interrupt_manager_school_lock.lua` | School lockout handling |
| `test_interrupt_spec_integration.lua` | Per-spec interrupt wiring |
| `test_shadow_silence_interrupt.lua` | Priest Silence interrupt |

Total: 471 rotation suites + 31 leveling suites registered (471/471 rotation passing at runtime — incl. the 3 `check_*` static-analysis audits; `test_sod_source_audit` self-provisions its `.omo/evidence` via the tracked generator).

---

## Customer-Facing PvP Feature List

### Fully Implemented

**Targeting & Awareness**
- Automatic arena/battleground/world PvP mode detection
- Arena target priority scoring (healers first, cloth wearers, low HP, casters)
- Diminishing Returns tracking for select CC abilities (Polymorph, Repentance, Wyvern Sting)
- PvP trinket awareness — adjusts CC chains when enemy has trinket available

**Burst & Offense**
- Burst window scoring (0-100) based on target HP, defensive buffs, casting state, your cooldowns
- Offensive cooldown alignment with Bloodlust/Heroism/Drums + 45-second timeout
- Offensive dispel priority — strips Divine Shield, Ice Block, BoP, Pain Suppression, Bloodlust, PI, Innervate first
- On-use trinket automation with TTD gating

**Defensives**
- Auto healthstones and potions at configurable HP thresholds
- Warrior: Berserker Rage auto-cast when feared/sapped/incapacitated
- Paladin: Preemptive Divine Shield / Blessing of Freedom against incoming CC
- Druid: Shapeshift to break Polymorph, roots, and snares
- Rogue: Cloak of Shadows auto-cast at low HP; Vanish emergency option
- Warlock: Death Coil preemptive break
- Mage: Ice Barrier auto-cast at hardcoded HP thresholds
- Shaman: Grounding Totem (Enhancement); Tremor Totem auto-drop vs. fear bosses

**Control & Utility**
- CC gating — skips AoE/cleave when a nearby enemy is CC'd
- Interrupts with school lockout tracking
- Repentance PvP opener (Retribution)
- Shadowstep usage modes: Always / Burst Only / Off (Subtlety)
- Viper Sting targeting with HP threshold and class filter (Hunter)
- Spellsteal with mana floor (Mage)
- Shield Slam purge for magic buffs (Protection Warrior)

### Known Gaps & Limitations

| Feature | Status |
|---------|--------|
| Priest SW:D preemptive CC break | Detection logic exists but strategy wiring in specs is unverified |

---

## Priority List for PvP Players

Ranked by impact. Highest = most noticeable in arena/battleground performance.

| Priority | Feature | Why It Matters |
|:--------:|---------|----------------|
| P1 | DR Tracking + CC Gating | Not wasting a full-duration CC into an immune target is the single biggest PvP efficiency gain |
| P1 | Arena Target Priority | Switching to the healer or low-HP clothie wins games; scoring system does this automatically |
| P1 | Defensive Autopilot (CC Break + Healthstones) | Breaking a polymorph or using a healthstone faster than human reaction is often the difference between living and dying |
| P2 | Burst Window Scoring | Timing cooldowns to enemy defensive gaps and low HP moments increases kill pressure |
| P2 | Trinket Awareness | Avoiding CC into a fresh trinket prevents wasting setup opportunities |
| P2 | Interrupt Automation | Consistent interrupts via InterruptManager are high-value in PvP |
| P3 | Offensive Dispel Priority | Stripping a BoP or Ice Block at the right moment opens kill windows |
| P3 | Bloodlust/CD Alignment | Holding cooldowns for lust then auto-firing after the 45s timeout prevents wasted burst windows |
| P4 | PvP CC Gating (AoE skip) | Prevents accidentally breaking nearby CC with cleave — important in rated arena but situational |
| P4 | Grounding/Tremor Totem | High impact when relevant, but only affects specific matchups (casters / fear classes) |

---

## Installation

1. Copy `EaxRotations` into your Project Sylvanas `scripts/` directory
2. Restart or reload
3. Select your spec — PvP logic activates automatically in Arenas and Battlegrounds

---

EaxRotations v2.20.0 — CC-BY-4.0 License — Built for TBC Classic Anniversary
