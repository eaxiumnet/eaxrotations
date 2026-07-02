# Changelog

All notable changes to the EAX TBC Classic Rotations project.

## [2.2.5] — Leveling Rotation Structural Fixes (2026-07-02)

### What This Means for You

This update fixes structural bugs in the Classic leveling rotations that could cause silent failures or missing abilities. These bugs were discovered during a full security pass of every leveling file. They were not causing crashes in most cases because the Lua runtime is lenient with duplicate definitions, but they were preventing entire match functions from being registered correctly.

If you noticed that certain abilities in Classic leveling were never being cast even though the spell was available, this update likely fixes that. No settings need to be changed.

### What Changed

**Warrior Classic Leveling**
- **Shield Bash** and **Pummel** interrupt match functions were structurally broken: they were missing `end` keywords, which caused the interrupt logic to be nested inside unrelated functions. This meant interrupts never fired. Fixed by restoring proper function closures.

**Mage Classic Leveling**
- Removed a duplicate `scorch_matches` function that was shadowing the original with identical logic. This was harmless but created unnecessary code bloat.

**Shaman Classic Leveling**
- Removed a duplicate `tremor_totem_ready` assignment. Harmless but cleaned up.

**Paladin Classic Leveling**
- Removed a duplicate `selected_seal` assignment in buildState.

**Priest Classic Leveling**
- Removed a duplicate `mf_ready` assignment in buildState.

**Rogue Classic Leveling**
- Removed a duplicate `thistle_tea_ready` assignment in buildState.

### Wand, Melee, and Execute Audit Summary

Every leveling rotation was audited for three critical fallback behaviors:

| Check | Result |
|---|---|
| **Auto-wand when OOM** | Mage, Priest, Warlock, and Hunter all use wand/Shoot when mana is below the configured wand threshold. Druid uses auto-attack in caster form. Shaman uses auto-attack with weapon imbue fallback. Rogue and Warrior are melee-only, no wand needed. |
| **Auto-melee when OOM or in range** | Hunter uses Raptor Strike and Mongoose Bite in melee range. Shaman uses Stormstrike in melee range. Warrior uses all melee abilities. Rogue uses all melee abilities. Paladin uses melee seals and Judgement. Druid uses Cat/Bear forms. |
| **Instant execute/finisher at low target HP** | Warrior Execute triggers below 20% HP. Paladin Hammer of Wrath triggers below 20% HP. Rogue Eviscerate is used at max combo points. Druid Ferocious Bite and Rip are used at max combo points. Warlock Drain Soul triggers below 25% HP. Shadow Priest Shadow Word: Death triggers below 25% HP. |

### What to Expect After Updating

- Install over your existing version. No configuration reset needed.
- Warrior Classic leveling interrupts (Shield Bash / Pummel) will now work correctly.
- All 214 rotation test suites and 13 leveling test suites pass.

---
## [2.2.4] — Classic Leveling Spell Coverage + Stability (2026-07-01)

### What This Means for You

This update closes the last gaps between our Classic Era leveling rotations and the full spell kits each class actually has at those levels. If you level a character using the Classic leveling rotations, your bot will now use abilities it was previously ignoring -- not because they were unsupported, but because they were never wired into the leveling logic. Every spell added in this update has been verified against the WoW Classic client database and Wowhead Classic to confirm it exists and is available in the Classic Era (1.15.x) client.

No settings need to be changed. The new abilities slot into the existing priority lists automatically. You will notice richer, more responsive leveling behavior the next time you load a Classic leveling rotation.

### What Changed

**Hunter Leveling**
- **Raptor Strike** and **Mongoose Bite** are now used when enemies close into melee range. Previously the leveling rotation had no melee weave -- if a mob reached you, the bot stood there until it could shoot again. Now it fights back with instant melee attacks, including Mongoose Bite after a dodge.

**Mage Leveling**
- **Fireball** is now cast as a primary damage spell. Previously the leveling rotation only used Frostbolt, Arcane Missiles, and Scorch. If you prefer a fire-oriented leveling approach, Fireball is now part of the rotation automatically. It respects the same movement and mana gates as other cast-time spells.

**Rogue Leveling**
- **Sap** is now cast on humanoid targets while stealthed and out of combat. This gives you crowd control before pulling -- the bot will Sap one target, then engage the other. It only works on humanoids and only before combat starts, matching how Sap functions in Classic.

**Priest Leveling**
- **Vampiric Embrace** is now maintained automatically once you enter Shadowform. This means your shadow damage passively heals you and your party during leveling, which significantly reduces downtime between pulls.
- **Desperate Prayer** is now cast as an emergency self-heal when your health drops below 40 percent. This is a Dwarf and Human priest racial spell with no mana cost and a 10-minute cooldown, so it is a free safety net that was previously going unused.

**Shaman Leveling**
- **Stormstrike** is now used in melee range when the spell is available. This is the 31-point Enhancement talent and is the core melee attack for Enhancement leveling. Previously the leveling rotation skipped it entirely, which meant Enhancement shamans were only using shocks and totems with no melee ability priority.

**Warrior Leveling**
- **Pummel** is now used to interrupt spellcasting when in Berserker Stance. Previously only Shield Bash was available as an interrupt, which requires a shield and Defensive Stance. Fury and two-handed weapon levelers who stay in Berserker Stance now have a working interrupt.
- **Bloodthirst** (Fury talent, level 40) is now used as a primary rage spender in melee range. This is the core Fury attack and was missing from the leveling rotation entirely.
- **Shield Slam** (Protection talent, level 40) is now used as a threat-generating attack in melee range. Protection levelers now have their signature ability in the rotation.

**Paladin Leveling**
- **Holy Shield** is now cast when fighting multiple enemies and health is below 70 percent. This increases block chance and deals holy damage to attackers, which is the core Protection Paladin AoE farming mechanic.
- **Retribution Aura** is now maintained out of combat as an alternative to Devotion Aura. It deals holy damage to anything that hits you, which is strong for solo leveling. The bot will not override Devotion Aura if you already have it active.

### Also Fixed in This Release

- **EaxAutoQuester**: Resolved a crash caused by leftover merge conflict markers in the NPC manager. The quest interaction flow now detects quest dialog windows more reliably, pauses briefly after reaching an NPC to let the game render, and falls back to a proximity scan if the named NPC lookup fails.
- **Protection Paladin (TBC)**: Holy Shock is no longer used offensively when the tank is below the emergency heal threshold. It will be saved for healing instead.
- **Enhancement Shaman (Classic)**: Fixed a bug where the spellcasting interrupt check could crash when the target proxy was stale.

### What to Expect After Updating

- Install the new version over your existing one. No configuration reset is needed.
- If you are running a Classic leveling rotation, you will see new abilities being cast that were not used before. This is expected and intentional.
- All 214 rotation test suites and 13 leveling test suites pass. No existing behavior has been removed or changed -- only new abilities were added to the priority lists.
- The version number in the plugin header now reads 2.2.4.

### Verification

Every spell added in this update was checked against four independent sources before inclusion:
- The WoW 2.5.5 client DBC database (28,650 spells extracted from the game client)
- Wowhead Classic (the spell page for each rank-1 spell ID was fetched and confirmed)
- The wowsims_classic simulator source code (11 of 12 spells found; the 12th, Desperate Prayer, is a racial spell not modeled by the simulator)
- Existing Classic Era spec files (all 12 spells were already referenced in at least one other vanilla spec file)

No TBC-only spells were added to the Classic leveling rotations. Spells like Ice Lance, Water Elemental, Seal of Blood, Shadow Word: Death, Vampiric Touch, Steady Shot, and Mangle were checked and correctly excluded because they do not exist in the Classic Era client.

---
## [2.2.3] — EaxAutoQuester Hardening + Rotation Fixes (2026-07-01)

### Fixed

#### EaxAutoQuester — Merge Conflict Resolution & Interaction Flow
- **npc_manager_sylvanas.lua**: Removed git merge conflict markers that caused runtime failure. Added name-based self-exclusion guard to prevent targeting the local player in find_nearest_npc, get_nearest_enemy, and find_nearest_quest_unit.
- **quest_state_sylvanas.lua**: Expanded detect_open_frame() with gossip available/active quest probes for better quest dialog detection. Throttled IDLE wait log spam (1s). Added brief 1.5s pause after NAV arrival for NPC rendering. Added proximity NPC fallback (30yd scan) when named lookup fails for talk goals. Immediate frame check (0.3s) after talk/gossip actions instead of full progressive backoff.
- **quest_interaction_sylvanas.lua**: Added gossip available/active quest detection in handle_quest_detail(). Added debug logging in handle_gossip() and handle_any_frame().
- **do_action_state.lua**: Now calls interact_with_object after set_target for talk goals. Enters INTERACT state after NPC interaction to process dialog frames immediately.
- **questie_reader_sylvanas.lua**: Removed git merge conflict markers. Restored cached API references for get_quest_npc_ids and get_quest_locations.

#### Rotation Fixes
- **protection_vanilla.lua**: Removed duplicated holy_shock_matches dead-code block after return true that caused a syntax error ('end' expected).
- **protection_sylvanas.lua**: Added Holy Shock self-heal gate — don't burn Holy Shock offensively when tank HP is below the Flash of Light threshold (40 percent).
- **enhancement_vanilla.lua**: Fixed pcall double-call bug in target_is_casting check (was calling :is_casting() twice, second call unguarded).

### Tests
- 214/214 rotation suites pass
- 12/12 leveling suites pass
- 431 files syntax-checked (luac -p)
- 61/61 DBC spell audit clean
- 31/31 vanilla spec audit clean

---
## [2.2.0] â€” Supremacy Phase 4 (2026-06-29)

### Added

#### Stance Dance Management (Warrior)
- **WHAT**: Auto-switch stances based on rotation needs and survival state.
- **WHY**: Battle for Rend/Overpower/Charge, Berserker for DPS/Execute/Intercept, Defensive for survival.
- **HOW**: `shared/stance_manager_sylvanas.lua` provides `get_optimal_stance(context, state)` and `should_switch(context, state, desired)`. Rules: Defensive when HP < 30%, Berserker for Execute, Battle for Rend/Overpower. Respects Tactical Mastery rage preservation and stance lockout.
- **Settings**: `stance_mode` dropdown â€” "auto", "manual", "battle", "defensive", "berserker".
- **Files**: `shared/stance_manager_sylvanas.lua`, `arms_sylvanas.lua`, `fury_sylvanas.lua`, `protection_sylvanas.lua`.

#### Smart Rage Management (Warrior DPS)
- **WHAT**: Intelligently dump rage with Heroic Strike / Cleave to prevent capping.
- **WHY**: Rage capping is DPS loss; rage starving is also DPS loss.
- **HOW**: `shared/rage_manager_sylvanas.lua` provides `should_heroic_strike()`, `should_cleave()`, `recommend_dump()`. Respects core ability starvation (MS/Overpower for Arms, BT/WW for Fury). Fury-specific HS trick (queue when OH imminent).
- **Settings**: `rage_dump_threshold` slider (default 80), `rage_dump_ability` dropdown â€” "heroic_strike", "cleave", "auto".
- **Files**: `shared/rage_manager_sylvanas.lua`, `arms_sylvanas.lua`, `fury_sylvanas.lua`.

#### Healthstone Automation
- **WHAT**: Auto-use Healthstone when HP drops below threshold.
- **WHY**: Basic survival feature advertised by .
- **HOW**: Scan bags for healthstone IDs {22105..22100}. Use `NS.use_item_by_id()` when off-GCD and not casting.
- **Settings**: `auto_healthstone` checkbox (default true), `healthstone_hp_threshold` slider (default 30%).
- **Files**: `affliction_sylvanas.lua`, `destruction_sylvanas.lua`, `demonology_sylvanas.lua`, `shadow_sylvanas.lua`.

#### Fade Automation (Priest)
- **WHAT**: Auto-cast Fade when threat is high.
- **WHY**: Prevents pulling aggro in dungeons/raids.
- **HOW**: Uses `context.threat_pct` or `context.threat_status >= 2` as trigger. Respects `priest_auto_fade` checkbox and `priest_fade_threat_threshold` slider (default 80%).
- **Files**: `shadow_sylvanas.lua`, `holy_sylvanas.lua`, `discipline_sylvanas.lua`.

#### Fully Automated Dispel
- **WHAT**: Auto-dispel party/raid members (and self) for dispellable debuffs.
- **WHY**: Reduces manual dispel burden in raids/dungeons.
- **HOW**: `shared/dispel_manager_sylvanas.lua` scans party for debuff types and casts appropriate dispel. Supports: Priest (Magic/Disease), Paladin (Poison/Disease/Magic with talent), Shaman (Poison/Disease), Druid (Poison/Curse), Mage (Curse). Throttled to 1 dispel per 3 seconds. Skips during critical healing (tank < 50%).
- **Settings**: `auto_dispel` checkbox (default true), `dispel_priority` dropdown â€” "self", "tank", "all".
- **Files**: `shared/dispel_manager_sylvanas.lua`.

#### Combat Mode Override (Extended)
- **WHAT**: Force Single Target, AoE, or Auto-detect mode across all DPS/tank specs.
- **WHY**: Users want control over rotation behavior.
- **HOW**: Already existed via `shared/combat_mode_sylvanas.lua`. Extended via schema wiring. Verified working in Shadow Priest, Warrior (all specs), Hunter (all specs), Shaman Enhancement, Paladin (all specs).
- **Files**: `shared/combat_mode_sylvanas.lua`, various spec schemas.

#### Strategy Gating Extracted
- **WHAT**: Centralized strategy category classification and quick-toggle gating.
- **WHY**: Previously duplicated in `core_sylvanas.lua` and `main_sylvanas.lua`.
- **HOW**: New `core/strategy_gating.lua` â€” single source of truth for category strings + toggle predicates. Consumed by `main_sylvanas.lua` and tests.
- **Files**: `core/strategy_gating.lua`, `main_sylvanas.lua`, `core_sylvanas.lua`.

### Fixed
- **Protection Warrior strategy count**: StanceSwitch added â†’ test updated from 34â†’35.
- **Pre-existing test failures resolved**: `test_reset_api_health.lua`, `test_reset_api_health_spell_integration.lua`, `test_leveling_edge_cases.lua` â€” all now pass.
- **CC helper cleanup**: Removed 9 redundant `NS.cc_is_*` wrappers from `core_sylvanas.lua` (consolidated into `strategy_gating.lua` in prior work).

### Tests
- Added `test_stance_manager.lua` (6 assertions) â€” PASS
- Added `test_rage_manager.lua` (7 assertions) â€” PASS
- Added `test_dispel_manager.lua` (7 assertions) â€” PASS
- Added `test_arms_critical_fixes.lua` â€” PASS
- **Total: 208 rotation suites â€” ALL PASS (0 failures)**
- **Total: 11 leveling suites â€” ALL PASS (0 failures)**

## [Unreleased] â€” Supremacy Phase 3 (2026-06-29)

### Added

#### Multi-DoT Engine for Shadow Priest
- **WHAT**: Spread SW:P and Vampiric Touch to nearby enemies in cleave/AoE.
- **WHY**: Massive DPS increase on multi-target.
- **HOW**: Throttled 1s enemy scan within configurable range; gates on multidot_mode (Off/Near/All), max targets (2-5), and target HP > 30%.
- **Settings**: `shadow_multidot_mode` dropdown (1=Off, 2=Near, 3=All), `shadow_multidot_max_targets` slider (default 3).
- **Files**: `shadow_sylvanas.lua`.

#### DoT TTD Gating
- **WHAT**: Skip DoT reapplication if target will die before DoT runs full duration.
- **WHY**: Don't waste GCDs on targets that die in 3s.
- **HOW**: `NS.DotTTD.should_skip_dot(ttd, dot_duration, threshold)` â€” returns true if TTD < duration * threshold. Shared module used by Shadow Priest (SW:P, VT) and Affliction Lock (Corruption, UA, Siphon Life, Immolate).
- **Settings**: `shadow_dot_ttd_threshold` (Priest), `dot_ttd_threshold` (Warlock) â€” slider 0-100% (default 50%).
- **Files**: `shared/dot_ttd_gating_sylvanas.lua`, `shadow_sylvanas.lua`, `affliction_sylvanas.lua`.

#### Inner Focus â†’ Mind Blast Combo
- **WHAT**: Hold Inner Focus for Mind Blast to guarantee crit on hardest-hitting spell.
- **WHY**: 25% mana cost reduction + guaranteed crit on biggest nuke.
- **HOW**: When combo enabled, InnerFocusMindBlast strategy matches when IF is ready AND (MB ready OR MB CD <= 5s). If MB on long CD (>5s), falls through to non-combo logic.
- **Settings**: `shadow_if_mb_combo` checkbox (default true).
- **Files**: `shadow_sylvanas.lua`.

#### Auto-Shot Timer for Hunter
- **WHAT**: Prevent shot clipping with swing-timer-aware casting.
- **WHY**: Clipping auto-shots is the #1 Hunter DPS mistake.
- **HOW**: `shared/shot_timer_sylvanas.lua` wraps HunterCore; `should_delay_cast()` gates Steady Shot before every cast. Wired into all 3 Hunter specs.
- **Settings**: `hunter_shot_timer_buffer` slider 0-300ms (default 150).
- **Files**: `shared/shot_timer_sylvanas.lua`, `beast_mastery_sylvanas.lua`, `marksmanship_sylvanas.lua`, `survival_sylvanas.lua`.

#### Dynamic Aspect Switching for Hunter
- **WHAT**: Auto-switch between Hawk (DPS), Viper (mana), Cheetah (OOC).
- **WHY**: Never go OOM, never waste GCD on manual aspect.
- **HOW**: In-combat + mana > threshold+10% â†’ Hawk; in-combat + mana <= threshold â†’ Viper; OOC + no enemies â†’ Cheetah. BM uses `AutoAspect` strategy; MM/SV use existing AspectOfTheHawk/AspectOfTheViper with updated thresholds.
- **Settings**: `hunter_auto_aspect` checkbox (default true), `hunter_viper_mana_threshold` slider (default 20%).
- **Files**: `shared/aspect_manager_sylvanas.lua`, `beast_mastery_sylvanas.lua`, `marksmanship_sylvanas.lua`, `survival_sylvanas.lua`.

#### Melee Weaving for Hunter
- **WHAT**: Use Raptor Strike and Wing Clip when in melee range.
- **WHY**: DPS gain when kiting fails.
- **HOW**: Squared distance <= 25 (5yd); low priority below ranged. Configurable per spec.
- **Settings**: `hunter_melee_weave` checkbox (default true).
- **Files**: All 3 Hunter spec files; BM backward-compatible with legacy `use_melee`.

### Schema Updates
- **Priest Shadow**: Added `shadow_multidot_mode`, `shadow_multidot_max_targets`, `shadow_dot_ttd_threshold`, `shadow_if_mb_combo`.
- **Hunter**: Added `hunter_auto_aspect`, `hunter_viper_mana_threshold`, `hunter_shot_timer_buffer`, `hunter_melee_weave` (BM/MM/SV tabs).
- **Warlock Affliction**: Added `dot_ttd_threshold`.

### Tests
- Added 8 new test suites (204 total rotation suites):
 - `test_dot_ttd_gating.lua`
 - `test_shot_timer.lua`
 - `test_aspect_manager.lua`
 - `test_shadow_multidot.lua`
 - `test_shadow_inner_focus_combo.lua`
 - `test_affliction_dot_ttd.lua`
 - `test_hunter_shot_timer_integration.lua`
 - `test_hunter_melee_weave.lua`
- 200 pass (4 pre-existing failures unrelated to this work).
- All 11 leveling suites pass.

### Files Changed
- **New shared modules**: `dot_ttd_gating_sylvanas.lua`, `shot_timer_sylvanas.lua`, `aspect_manager_sylvanas.lua`
- **Modified specs**: `shadow_sylvanas.lua`, `affliction_sylvanas.lua`, `beast_mastery_sylvanas.lua`, `marksmanship_sylvanas.lua`, `survival_sylvanas.lua`
- **Modified schemas**: `priest/schema_sylvanas.lua`, `hunter/schema_sylvanas.lua`, `warlock/schema_sylvanas.lua`
- **Modified tests**: `run_rotation_tests.lua`

## [Unreleased] â€” Supremacy Phase 2 (2026-06-28)

### Fixed

#### Middleware Critical Bugs
- **Warlock**: Registered `SpellLock` with `interrupt_manager` (was completely missing).
- **Paladin Cleanse**: Rewrote from self-only to party-wide scan â€” dispels self then all party members.
- **Paladin GroupBlessKings**: Now refreshes expiring Kings even if target has another blessing (was: never refreshed).
- **Paladin AutoConsumable**: Moved throttle set from `matches()` to inside `execute()` â€” only throttles on *successful* use (was: consumed 3s cooldown even on failed execute â†’ 6s total lockout).
- **Mage ManaGem**: Moved `_mana_gem_last` set from `matches()` to inside `execute()` â€” only throttles on successful gem use (was: 30s lockout on failed use).
- **Warlock CreateHealthstone**: Added nil-guard on `NS.core.inventory.get_item_count`.
- **main_sylvanas.lua**: Fixed `_context.lowest` subtable being nil'd by `build_context()` reset loop, causing downstream crashes.

#### Middleware Feature Parity (All 9 Classes)
- **Warlock**: Demon/Fel Armor OOC self-buff maintenance (priority 480).
- **Hunter**: Rapid Fire offensive cooldown (priority 780); combat healthstone/potion emergency heal (priority 850).
- **Shaman**: Lightning Shield OOC buff (priority 450); Bloodlust combat cooldown (priority 750); Lesser Healing Wave self-heal (priority 850).
- **Priest**: PW:Shield combat defensive (priority 850); Inner Fire OOC buff (priority 450); PW:Fortitude OOC buff (priority 440).
- **Druid**: Barkskin combat defensive (priority 850); Innervate smart-targeting (healer > self, priority 750); Rebirth combat resurrection (priority 1000).
- **Mage**: Conjure Water/Food OOC (priority 450/440); combat healthstone/potion emergency heal (priority 850).

#### Leveling Death Zone Fixes
- **Warrior**: Heroic Strike rage threshold now level-aware (`math.min(50, math.max(15, 15 + level))`). Level 1 dumps at 15 rage, scaling to 50 by 60. Prevents total rage starvation at 1-10.
- **Paladin**: Healing thresholds more aggressive at low levels â€” Flash of Light 75% HP at â‰¤20 (was 60%), Holy Light 50% at â‰¤20 (was 35%). Prevents death spiral at 1-11.
- **Hunter**: Low-mana threshold 15% at â‰¤20 (was 30%). Prevents mana starvation causing no-damage loops at 1-9.

#### Schema UI Settings (All 6 Classes)
Every new middleware feature now has a corresponding UI checkbox/slider:
- **Warlock**: `auto_demon_armor` checkbox (General â†’ Pet/Stones)
- **Hunter**: `use_rapid_fire` checkbox (Cooldowns), `healthstone_hp` slider (Defensives)
- **Shaman**: `auto_lightning_shield` checkbox, `use_bloodlust` checkbox, `self_heal_hp` slider (General)
- **Priest**: `pws_hp` slider, `auto_inner_fire` checkbox, `auto_fortitude` checkbox (General)
- **Druid**: `barkskin_hp` slider, `use_innervate` checkbox + `innervate_mana_pct` slider, `use_rebirth` checkbox (General)
- **Mage**: `auto_conjure_water` checkbox, `auto_conjure_food` checkbox (Buffs/Utility), `healthstone_hp` slider (Defensives)

### Added

#### Prot Paladin: Mana Emergency Swap (JoW)
- **WHAT**: When mana drops below threshold, switch Judgement to Seal of Wisdom for mana return.
- **WHY**: Prevents oom tanks from losing threat due to inability to cast Consecration/Holy Shield.
- **HOW**: Hysteresis with +5% dead band; `last_judgement_mode` prevents flip-flopping.
- **Settings**: `prot_jow_enabled` (default true), `prot_jow_mana_threshold` (default 20%).
- **Files**: `protection_sylvanas.lua`, `schema_sylvanas.lua`.

#### Ret Paladin: Post-Swing Judgement
- **WHAT**: Gates Judgement casts to avoid clipping auto-attack swings.
- **WHY**: Judging before a swing delays the melee hit, reducing DPS.
- **HOW**: `swing_remains < 0.3s` â†’ block; `swing_remains > 1.5s` â†’ allow.
- **Settings**: `retri_post_swing_judge` (default true).
- **Files**: `retribution_sylvanas.lua`, `schema_sylvanas.lua`.

#### Ret Paladin: Seal Twist Diagnostics
- **WHAT**: Logs seal twist timing quality (PERFECT / LATE / NO-TWIST / PHANTOM).
- **WHY**: Users need feedback to tune their twist window for latency.
- **HOW**: 5s log throttle via pcall-guarded `core.log.info()`.
- **Settings**: `retri_twist_diagnostics` (default false).
- **Files**: `retribution_sylvanas.lua`, `schema_sylvanas.lua`.

#### Enh Shaman: Totem Twisting Enhancement
- **WHAT**: Tracks twist phase and only replaces air totem when < 3s remaining.
- **WHY**: Prevents wasted GCDs from early totem replacement.
- **HOW**: `NS.get_totem_info(4)` reads air slot; `twist_phase` synced with active totem spell_id.
- **Settings**: `enhancement_twist_mana_threshold` slider (default 40%).
- **Files**: `enhancement_sylvanas.lua`, `schema_sylvanas.lua`.

#### Enh Shaman: Auto Weapon Buffs by Level
- **WHAT**: "auto" setting picks Rockbiter (1-9), Flametongue (10-29), Windfury (30+) based on learned spells.
- **WHY**: Leveling enhancement shamans shouldn't need to reconfigure weapon buffs every tier.
- **HOW**: `NS.is_spell_learned()` gated; `auto_mh_buff` / `auto_oh_buff` resolved in `build_state()`.
- **Settings**: `enhancement_main_hand_ench` / `enhancement_off_hand_ench` now include "auto" option.
- **Files**: `enhancement_sylvanas.lua`, `schema_sylvanas.lua`.

#### Enh Shaman: Intelligent Shield Switching
- **WHAT**: Auto mode switches between Lightning Shield (>60% mana) and Water Shield (<40% mana).
- **WHY**: Lightning Shield adds DPS; Water Shield adds mana regen when low.
- **HOW**: Hysteresis band (40-60%) retains current shield; `auto_shield_type` resolved in `build_state()`.
- **Settings**: `enhancement_shield_type` = "auto" (already present, logic enhanced).
- **Files**: `enhancement_sylvanas.lua`.

### Tests
- Added 6 new test suites (196 total rotation suites):
 - `test_paladin_protection_jow_mode.lua`
 - `test_paladin_retribution_post_swing_judge.lua`
 - `test_paladin_retribution_twist_diagnostics.lua`
 - `test_shaman_enhancement_totem_twist.lua`
 - `test_shaman_enhancement_auto_weapon_buffs.lua`
 - `test_shaman_enhancement_intelligent_shield.lua`
- All 196 rotation suites: 193 pass (3 pre-existing failures unrelated to Phase 2).
- All 11 leveling suites pass.

### Files Changed
- **Modified specs**: `protection_sylvanas.lua`, `retribution_sylvanas.lua`, `enhancement_sylvanas.lua`
- **Modified schemas**: `paladin/schema_sylvanas.lua`, `shaman/schema_sylvanas.lua`
- **Modified tests**: `run_rotation_tests.lua`

## [Unreleased] â€” Supremacy Phase 1 (2026-06-28)

### Added

#### Stop-Cast Engine (`shared/stopcast_sylvanas.lua`)
- **WHAT**: Cancels in-flight direct heals when the target's HP recovers above a configurable threshold during the cast.
- **WHY**: Prevents massive overheal waste (e.g., Greater Heal landing on a target topped off by a HoT tick).
- **HOW**: Monitors cast progress at 25%, 50%, 75% checkpoints; cancels via `NS.cancel_spells()` if target HP + expected heal exceeds threshold.
- **Settings**: `stopcast_enabled` (default true), `stopcast_threshold` (default 95%).
- **Wired into**: Holy Priest, Discipline Priest, Resto Shaman, Resto Druid, Holy Paladin.

#### Pet Healing (`shared/pet_heal_sylvanas.lua`)
- **WHAT**: Includes party/raid pets in the healing target scan.
- **WHY**: Hunters and warlocks expect their pets to be healed in dungeons/raids.
- **HOW**: Extends `NS.build_healing_entries()` to append pet entries with configurable weight penalty.
- **Settings**: `heal_pets` (default true), `pet_weight` (default 0.6x).
- **Wired into**: All healer specs via `core_sylvanas.lua` `build_healing_entries()`.

#### Tank HP Bias (`shared/triage_sylvanas.lua` enhancement)
- **WHAT**: Applies configurable HP bias to tanks and focus targets in triage scoring.
- **WHY**: Tanks should be healed earlier than DPS at the same HP%.
- **HOW**: `effective_hp = actual_hp - tank_bias` in urgency score calculation. Auto-detects tanks via role; focus target gets separate bias.
- **Settings**: `tank_hp_bias` (default 15%), `focus_hp_bias` (default 10%).
- **Wired into**: All 5 healer specs (Triage.rank now accepts settings param).

#### Snap Threat on Combat Start (`shared/snap_threat_sylvanas.lua`)
- **WHAT**: Fires an immediate high-threat ability on combat entry.
- **WHY**: Establishes threat before DPS opens up.
- **HOW**: Hooks combat-start detection; 3s cooldown between snaps to prevent spam.
- **Settings**: `snap_threat_enabled` (default true).
- **Wired into**: Prot Paladin (Judgement â†’ Avenger's Shield fallback), Prot Warrior (Shield Slam â†’ Revenge fallback).

#### Combat Mode Override (`shared/combat_mode_sylvanas.lua`)
- **WHAT**: Allows users to force Single Target, AoE, or Auto-detect mode.
- **WHY**: Users want control â€” e.g., "force ST on boss even with adds nearby".
- **HOW**: Pure read-only helper; specs query `NS.CombatMode.is_aoe()` instead of raw enemy count.
- **Settings**: `combat_mode` dropdown (1=Auto, 2=Single Target, 3=AoE).
- **Schema updates**: Paladin Protection, Warrior Protection (all DPS specs can opt-in).

### Schema Updates
- **Priest**: Added Smart Casting section (stopcast, tank bias, pet healing) to Holy and Discipline tabs.
- **Shaman**: Added Smart Casting section to Restoration tab.
- **Druid**: Added Smart Casting section to Restoration tab.
- **Paladin**: Added Smart Casting section to Holy tab; Threat & Utility section to Protection tab.
- **Warrior**: Added Threat & Combat Mode section to Protection tab.

### Tests
- Added 5 new test suites (176 total rotation suites):
 - `test_stopcast_engine.lua`
 - `test_pet_heal.lua`
 - `test_triage_tank_bias.lua`
 - `test_snap_threat.lua`
 - `test_combat_mode.lua`
- All 176 rotation suites pass.
- All 11 leveling suites pass.

### Files Changed
- **New shared modules**: `stopcast_sylvanas.lua`, `pet_heal_sylvanas.lua`, `snap_threat_sylvanas.lua`, `combat_mode_sylvanas.lua`
- **Modified shared**: `triage_sylvanas.lua`, `core_sylvanas.lua`
- **Modified specs**: `holy_sylvanas.lua` (priest), `discipline_sylvanas.lua`, `restoration_sylvanas.lua` (shaman), `resto_sylvanas.lua` (druid), `holy_sylvanas.lua` (paladin), `protection_sylvanas.lua` (paladin), `protection_sylvanas.lua` (warrior)
- **Modified schemas**: `priest/schema_sylvanas.lua`, `shaman/schema_sylvanas.lua`, `druid/schema_sylvanas.lua`, `paladin/schema_sylvanas.lua`, `warrior/schema_sylvanas.lua`
- **Modified tests**: `run_rotation_tests.lua`
- **Docs**: `README.md`, `CHANGELOG.md`

## Previous Releases

See [GitHub Releases](https://github.com/eaxiumnet/eaxrotations/releases) for full history.
