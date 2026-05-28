# Changelog

All notable changes to EaxRotations will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

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
