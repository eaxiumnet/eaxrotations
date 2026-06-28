# Changelog

All notable changes to the EAX TBC Classic Rotations project.

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
