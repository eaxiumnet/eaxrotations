# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Fixed
- EAXWarlockAffliction: undefined `me` variable in try_apply_curse()
- EAXWarlockAffliction: inverted Shadow Bolt filler logic
- EAXMageArcane: unimplemented try_ice_block()
- EAXRogueCombat: unimplemented try_evasion()
- EAXHunterSurvival: unimplemented try_mend_pet()

### Added
- Shared modules (common/eax_shared/):
  - spell_resolver.lua - Unified spell ID resolution
  - mode_detector.lua - Auto-detect solo/dungeon/raid
  - target_finder.lua - Target selection with focus priority
  - interrupt_manager.lua - Priority-based interrupts
  - defensive_manager.lua - Layered HP defensives
  - talents.lua - Talent detection
  - pet_manager.lua - Pet management
- Emergency abilities: Ice Block, Evasion, Mend Pet

### Planned
- Missing core spells (~20-30 per spec)
- Integration of shared modules into all specs
- Boss detection, racials, set bonuses

---

## [1.0.0] - 2026-03-16

### Added
- Initial EAX TBC rotation plugins - all 27 specs
- Base architecture: main.lua, menu.lua, spells.lua, utils.lua
- Focus target priority, self-emergency healing
- Mode detection (solo/dungeon/raid)
