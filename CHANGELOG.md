# Changelog

All notable changes to this project will be documented in this file.

## [1.2.0] - 2026-03-16

### Added — New Shared Modules (`common/eax_shared/`)
- **`racial_manager.lua`** — Unified racial ability system for all TBC races:
  - Offensive: Blood Fury (Orc), Berserking (Troll)
  - Utility/Interrupt: Arcane Torrent (Blood Elf), War Stomp (Tauren)
  - Defensive: Stoneform (Dwarf), Escape Artist (Gnome), Will of the Forsaken (Undead)
  - Wired into all 23 combat plugins via `racial_manager.try_offensive()` and `racial_manager.try_utility()`
- **`ttd_tracker.lua`** — Per-target rolling time-to-death estimator:
  - 10-second sliding window, HP loss rate calculation
  - `ttd_tracker.update(target)` wired into 20 DPS spec rotations
  - `ttd_tracker.is_dying(target, threshold_s)` for execute-phase gating
- **Updated `__init__.lua`** — exports all 9 shared modules

### Added — Spec-Specific Rotation Improvements
- **Warrior Arms**: Charge (pre-combat opener), Death Wish, Recklessness, Sweeping Strikes,
  Enraged Regeneration (≤70% HP), Pummel interrupt wired into rotation
- **Paladin Retribution**: Divine Storm, Avenging Wrath (syncs with burst window)
- **Shaman Enhancement**: Lava Lash (talent-gated), Feral Spirit (talent-gated),
  weapon imbue maintenance (Windfury MH + Flametongue OH, throttled 30s)
- **Druid Feral**: Demoralizing Roar (bear, debuff-checked), Maim (cat, interrupt fallback)
- **Rogue Combat**: Killing Spree (wired after Adrenaline Rush)
- **Mage Arcane**: interrupt call wired (was imported but not called)
- **Hunter Survival**: interrupt call wired (was imported but not called)

### Fixed
- Systematic mangled-code bug across all plugins: racial_manager injection had been
  merged into the interrupt_manager.try_interrupt() call, creating invalid Lua.
  All 15 affected plugins repaired.
- HunterSurvival: TTD tracker was inserted inside the defensive_manager block
  (inside the `then...end`), causing it to only run when a defensive was triggered.
  Moved to correct position before defensive check.

---

## [1.1.0] - 2026-03-16

### Added
- **Comprehensive TBC Spell Database** - Complete spell ID mappings for all 29 specs
- **Racial Abilities** - Added to spells.lua across all classes
- **Consumables & Gear Support** - Potions, scrolls, engineering, trinkets
- **Pet System** - Hunter and Warlock pet coverage
- **Utility Spells** - Disengage, Feign Death, Traps, Weapon imbues, etc.
- **Shared Modules** (`common/eax_shared/`):
  - `interrupt_manager.lua` — priority-based interrupt system (all 23 combat plugins)
  - `defensive_manager.lua` — layered HP-threshold defensive system (all 27 plugins)
  - `spell_resolver.lua` — unified spell ID resolution with caching
  - `mode_detector.lua` — solo/dungeon/raid detection
  - `target_finder.lua` — consistent target selection
  - `pet_manager.lua` — Hunter/Warlock pet helpers
  - `talents.lua` — talent detection helpers

### Fixed
- 5 critical bugs from v1.0.0:
  1. WarlockAffliction: `try_apply_curse()` — undefined `me` variable
  2. WarlockAffliction: Shadow Bolt filler — inverted conditional
  3. MageArcane/Fire/Frost: `try_ice_block` called but never defined
  4. RogueCombat: `try_evasion` called but never defined
  5. HunterSurvival/Marksmanship: `try_mend_pet` called but never defined

---

## [1.0.0] - 2026-03-16

### Added
- Initial EAX TBC rotation plugins — all 27 specs
- Base architecture: main.lua, menu.lua, spells.lua, utils.lua
- Focus target priority, self-emergency healing
- Mode detection (solo/dungeon/raid)

## [1.2.1] - 2026-03-17 (patch)

### Added
- **Hunter (all 3 specs)**: Disengage (kite when target ≤8yd) and Feign Death
  (emergency threat drop ≤30% HP) wired into all three Hunter rotations
- **Shaman Elemental**: Lava Burst wired — casts when Flame Shock is on target
  (guaranteed crit interaction)
- **Warlock Affliction**: Howl of Terror wired as AoE emergency fear (≤40% HP,
  ≥1 melee attacker)
- **Priest Shadow**: Devouring Plague added to DoT refresh cycle alongside
  Vampiric Touch and Shadow Word: Pain

### Fixed
- **TTD positioning bug** (affected 12 plugins): `ttd_tracker.update(target)` had
  been inserted *inside* the `defensive_manager.try_defensive` block during the
  prior patch, meaning TTD samples only collected when a defensive CD was triggered.
  Moved to correct position before the defensive check in all affected specs:
  WarlockAffliction, WarlockDemonology, WarlockDestruction, RogueAssassination,
  RogueCombat, RogueSubtlety, ShamanElemental, PaladinRetribution, MageFire,
  MageFrost, HunterBeastMastery, HunterMarksmanship, PriestShadow
