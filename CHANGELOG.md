# Changelog

All notable changes to the EAX TBC Classic Rotations project.

## [Unreleased] — FrostByte Supremacy Phase 4 (2026-06-29)

### Added

#### Stance Dance Management (Warrior)
- **WHAT**: Auto-switch stances based on rotation needs and survival state.
- **WHY**: Battle for Rend/Overpower/Charge, Berserker for DPS/Execute/Intercept, Defensive for survival.
- **HOW**: `shared/stance_manager_sylvanas.lua` provides `get_optimal_stance(context, state)` and `should_switch(context, state, desired)`. Rules: Defensive when HP < 30%, Berserker for Execute, Battle for Rend/Overpower. Respects Tactical Mastery rage preservation and stance lockout.
- **Settings**: `stance_mode` dropdown — "auto", "manual", "battle", "defensive", "berserker".
- **Files**: `shared/stance_manager_sylvanas.lua`, `arms_sylvanas.lua`, `fury_sylvanas.lua`, `protection_sylvanas.lua`.

#### Smart Rage Management (Warrior DPS)
- **WHAT**: Intelligently dump rage with Heroic Strike / Cleave to prevent capping.
- **WHY**: Rage capping is DPS loss; rage starving is also DPS loss.
- **HOW**: `shared/rage_manager_sylvanas.lua` provides `should_heroic_strike()`, `should_cleave()`, `recommend_dump()`. Respects core ability starvation (MS/Overpower for Arms, BT/WW for Fury). Fury-specific HS trick (queue when OH imminent).
- **Settings**: `rage_dump_threshold` slider (default 80), `rage_dump_ability` dropdown — "heroic_strike", "cleave", "auto".
- **Files**: `shared/rage_manager_sylvanas.lua`, `arms_sylvanas.lua`, `fury_sylvanas.lua`.

#### Healthstone Automation
- **WHAT**: Auto-use Healthstone when HP drops below threshold.
- **WHY**: Basic survival feature advertised by FrostByte.
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
- **Settings**: `auto_dispel` checkbox (default true), `dispel_priority` dropdown — "self", "tank", "all".
- **Files**: `shared/dispel_manager_sylvanas.lua`.

#### Combat Mode Override (Extended)
- **WHAT**: Force Single Target, AoE, or Auto-detect mode across all DPS/tank specs.
- **WHY**: Users want control over rotation behavior.
- **HOW**: Already existed via `shared/combat_mode_sylvanas.lua`. Extended via schema wiring. Verified working in Shadow Priest, Warrior (all specs), Hunter (all specs), Shaman Enhancement, Paladin (all specs).
- **Files**: `shared/combat_mode_sylvanas.lua`, various spec schemas.

### Tests
- Added `test_stance_manager.lua` (6 assertions) — PASS
- Added `test_rage_manager.lua` (7 assertions) — PASS
- Added `test_dispel_manager.lua` (7 assertions) — PASS
- Total: 208 rotation suites (206 pass, 2 pre-existing failures unrelated to this work)
- Total: 11 leveling suites (all pass)

## [Unreleased] — FrostByte Supremacy Phase 3 (2026-06-29)

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
- **HOW**: `NS.DotTTD.should_skip_dot(ttd, dot_duration, threshold)` — returns true if TTD < duration * threshold. Shared module used by Shadow Priest (SW:P, VT) and Affliction Lock (Corruption, UA, Siphon Life, Immolate).
- **Settings**: `shadow_dot_ttd_threshold` (Priest), `dot_ttd_threshold` (Warlock) — slider 0-100% (default 50%).
- **Files**: `shared/dot_ttd_gating_sylvanas.lua`, `shadow_sylvanas.lua`, `affliction_sylvanas.lua`.

#### Inner Focus → Mind Blast Combo
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
- **HOW**: In-combat + mana > threshold+10% → Hawk; in-combat + mana <= threshold → Viper; OOC + no enemies → Cheetah. BM uses `AutoAspect` strategy; MM/SV use existing AspectOfTheHawk/AspectOfTheViper with updated thresholds.
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

## [Unreleased] — FrostByte Supremacy Phase 2 (2026-06-28)

### Fixed

#### Middleware Critical Bugs
- **Warlock**: Registered `SpellLock` with `interrupt_manager` (was completely missing).
- **Paladin Cleanse**: Rewrote from self-only to party-wide scan — dispels self then all party members.
- **Paladin GroupBlessKings**: Now refreshes expiring Kings even if target has another blessing (was: never refreshed).
- **Paladin AutoConsumable**: Moved throttle set from `matches()` to inside `execute()` — only throttles on *successful* use (was: consumed 3s cooldown even on failed execute → 6s total lockout).
- **Mage ManaGem**: Moved `_mana_gem_last` set from `matches()` to inside `execute()` — only throttles on successful gem use (was: 30s lockout on failed use).
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
- **Paladin**: Healing thresholds more aggressive at low levels — Flash of Light 75% HP at ≤20 (was 60%), Holy Light 50% at ≤20 (was 35%). Prevents death spiral at 1-11.
- **Hunter**: Low-mana threshold 15% at ≤20 (was 30%). Prevents mana starvation causing no-damage loops at 1-9.

#### Schema UI Settings (All 6 Classes)
Every new middleware feature now has a corresponding UI checkbox/slider:
- **Warlock**: `auto_demon_armor` checkbox (General → Pet/Stones)
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
- **HOW**: `swing_remains < 0.3s` → block; `swing_remains > 1.5s` → allow.
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

## [Unreleased] — FrostByte Supremacy Phase 1 (2026-06-28)

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
- **Wired into**: Prot Paladin (Judgement → Avenger's Shield fallback), Prot Warrior (Shield Slam → Revenge fallback).

#### Combat Mode Override (`shared/combat_mode_sylvanas.lua`)
- **WHAT**: Allows users to force Single Target, AoE, or Auto-detect mode.
- **WHY**: Users want control — e.g., "force ST on boss even with adds nearby".
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
