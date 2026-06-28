# Changelog

All notable changes to EaxRotations will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [1.1.2] - 2026-06-28

### Added
- Platform API adoption: `NS.get_aoe_cast_position(spell_id, target, radius, max_range, min_hits)` — dual-return with hit count gating for AoE spells (Blizzard, Volley, Rain of Fire, Hurricane)
- Platform API adoption: `NS.get_total_shield(unit)`, `NS.get_incoming_heals(unit)`, `NS.get_incoming_heals_from(unit, source)` — pcall-guarded native game_object wrappers
- Platform API adoption: `NS.health_prediction` exposure for spec consumption (tank detection, PvP detection, incoming damage)
- Paladin Holy: `holy_light_hp` slider (40-100%, default 70%) — prefer Holy Light over Flash below this threshold
- Paladin Holy: `holy_lights_grace_chaining` checkbox (default true) — cast cheap R4 Holy Light to refresh Light's Grace before expiry
- Paladin Holy: aura switch 3s throttle to prevent debuff-pulse flip-flop
- Test: `test_paladin_holy_custom_matches.lua` for aura throttle coverage

### Performance
- Frame-level `build_state` caching in 5 vanilla specs (Druid Bear, Warrior Arms/Fury/Prot) — prevents N× per-frame CPU burn using `context.now` timestamp guard
- Middleware CC-break scan throttling (0.3s intervals) across Mage, Rogue, Warlock, Paladin, Priest
- Priest middleware: fade scan throttled to 0.5s, mass dispel to 0.3s, SW:D preemptive scan to 0.3s

### Fixed
- **Priest ManaBurn**: Fixed non-existent `NS.unit_mana_pct` → raw `get_power`/`get_max_power` pcall
- **Paladin Forbearance**: Removed invalid `me.debuff_remains` guard (always nil, silently skipped check)
- **Hunter ViperSting**: pcall-wrapped `target:get_power_type()` / `get_class()` to prevent nil crash
- **Hunter FeedPet**: Fixed `pcall(pet.is_alive)` missing `self` argument
- **Warrior SmartHSDequeue**: Fixed pcall unpacking bug (got boolean instead of spell_id)
- **Shared pet_manager**: Nil-guarded `core.spell_book` / `core.input` accesses to prevent startup crash
- **Shared auto_tremor**: Fixed `NS.get_party_members` → `NS.GetPartyMembers` capitalization (Tremor Totem now drops for allies)
- **Shared consumable_manager**: Fixed role classification for Enhancement Shaman and Feral Druid (were "caster", now "melee")
- **Core**: Store `is_group` in state table for 12 specs to enable group-aware defensive thresholds

### Changed
- `main_sylvanas.lua`: expose `NS.health_prediction` following `NS.spell_queue` pattern

## [1.1.1] - 2026-05-28

### Added
- APL (Action Priority List) parser for configurable rotation logic
- Expansion-aware class loaders for Classic vanilla rotations
- Control panel quick toggles for runtime settings changes
- Vanilla-era Warrior spec files (Arms, Fury, Kebab, Protection)
- NS.get_any_setting, NS.setting_number, NS.setting_bool helpers
- Broken API throttling and PS detection
- SP-aware DoT gating for Druid Balance, Warlock Destruction, Shaman Elemental
- ShivPurge and Disarm ported to all 5 Rogue specs

### Changed
- Migrated get_setting to centralized NS.setting() across all shared modules
- Pre-cached hot-path modules for improved performance
- Tank-alive check throttled for performance
- Debug log output rate-limited to prevent spam

### Fixed
- Nil-guard numeric state fields across all 29 spec match functions
- Nil-guard numeric state fields across all 9 leveling files
- Soul Shard reagent check for Warlock Shadowburn and CreateHealthstone
- Mutual exclusion toggle for Warlock armors and Shaman shields
- Fel Armor and Summon Imp cast spam
- Mana bypass issues across multiple specs
- Dashboard crash on load

## [1.1.0] - 2026-04-15

### Added
- Unified dispatcher with context building and strategy iteration
- Middleware framework for class-wide behavior
- Defensive middleware for automatic healthstones, potions, and cooldowns
- Interrupt manager with target-aware casting
- Consumable manager for automatic item usage
- Racial ability manager
- Trinket manager with equip/use tracking
- Swing timer for melee spec optimization
- DoT refresh timing module
- Burst logic for cooldown alignment
- OOC (out-of-combat) manager
- Targeting and threat management
- Dashboard HUD overlay
- Schema-based settings UI for all specs

### Changed
- All 9 class modules rewritten with consistent structure
- Settings moved to schema files with menu widget definitions

## [1.0.3] - 2026-03-20

### Fixed
- Immolate debuff IDs corrected (removed 3 non-Immolate spells, added 2 missing ranks)
- Drain Life spell IDs corrected (Drain Soul IDs replaced with correct Drain Life IDs)
- Protection Warrior Demo Shout and Thunder Clap debuff IDs corrected
- Fury Warrior Battle Shout buff detection expanded from 3 ranks to all 8 TBC ranks
- All spell IDs cross-validated against class registry

## [1.0.2] - 2026-03-10

### Fixed
- Hunter Aspect of the Hawk rank IDs to prevent repeated recasts

## [1.0.0] - 2026-03-01

### Added
- Initial release
- Rotation framework with shared combat engine
- 29 playstyles across 9 classes
- Basic spell casting, buff/debuff management, and resource tracking
