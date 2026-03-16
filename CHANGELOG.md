# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- **Comprehensive TBC Spell Database** - Added complete spell ID mappings for all 29 specs with all ranks
  - Accurate spell IDs from official TBC Classic sources
  - Complete buff/debuff tracking tables
  - Proper ability categorization (rotation, cooldowns, utilities)
- **Racial Abilities** - Added racial spells to appropriate races:
  - Orc/Troll: Blood Fury (33697, 20572), Berserking (26297), War Stomp (20549)
  - Blood Elf: Arcane Torrent (28730, 25046, 23160, 15533, 50613)
  - Night Elf: Shadowmeld (58984, 1784), Perception (20600, 1130)
  - Draenei: Heroic Presence (28878)
- **Consumables & Gear Support**:
  - Potions: Haste Potion (28508, 22832), Super Mana Potion (28499, 22828)
  - Scrolls: Intellect (22732, 10291), Agility (22730, 10290), Stamina (22733, 10292)
  - Engineering: Goblin Rocket Boots (8896), Gnomish Rocket Helmet (13028)
  - Warlock items: Firestone ranks, Soulstone ranks, Demonic Dreadlord (32044-32053)
  - Trinkets: Dragon Slayer series (34775-34760)
- **Pet System** - Full pet ability coverage for Hunters and Warlocks:
  - Hunter: Kill Command, Bestial Wrath, Mend Pet, Revive Pet, Call Pet, Aspect spells
  - Warlock: Pet summoning, pet abilities, healthstone/soulstone items
- **Utility Spells** - Added missing key abilities:
  - Hunter: Disengage, Feign Death, Wing Clip, Concussive Shot, Scatter Shot, Counter Shot, all Traps
  - Warrior: Berserker Rage
  - Rogue: Ghostly Strike, Kidney Shot, Sap, Blind
  - Druid: All forms (Bear, Cat, Moonkin, Travel, Aquatic), Mangle, Rake, etc.
  - Shaman: Weapon imbues (Windfury, Flametongue, Rockbiter, Earthliving), shocks, totems
  - Paladin: Auras, Blessings, Lay on Hands, Divine Shield
  - Priest: Dispel magic, cure disease, inner fire/will
- **Quality Improvements**:
  - All 29 spells.lua files now have proper `return spells` statements
  - Nested Hunter specs (Beast Mastery under Marksmanship/Survival) fully populated
  - Consistent formatting and ordering across all specs
  - Complete rank tables for all abilities

### Fixed
- Missing return statements in several spells.lua files
- Incomplete Hunter Beast Mastery nested spec files
- Missing utility abilities across all classes

### Documentation
- Updated AGENTS.md with complete spell database overview
- Updated CHANGELOG.md with comprehensive additions

---

## [1.0.0] - 2026-03-16

### Added
- Initial EAX TBC rotation plugins - all 27 specs
- Base architecture: main.lua, menu.lua, spells.lua, utils.lua
- Focus target priority, self-emergency healing
- Mode detection (solo/dungeon/raid)
