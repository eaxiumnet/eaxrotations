# FLUX AIO - Comprehensive Summary

## What is FLUX?

FLUX AIO is a multi-class WoW TBC (The Burning Crusade) rotation addon built on the GGL Action/Textfiles framework. It currently supports Druid (all forms) and Hunter, with architectural support for all 9 classes (Druid, Hunter, Mage, Paladin, Priest, Rogue, Shaman, Warlock, Warrior).

**Key Characteristics:**
- Built on the GGL Action/Textfiles framework (Lua-based automation for WoW Classic-era clients)
- Uses a modular Strategy Registry pattern with middleware + strategies architecture
- Features a Node.js build system that compiles per-class modules into a single TMW (TellMeWhen) profile
- Monorepo structure with three packages:
  - `rotation/` - Core WoW rotation addon (Lua source + Node.js build system)
  - `website/` - Static site for script distribution and documentation (Astro)
  - `discord-bot/` - Discord bot for personalized rotation tweaks via Claude AI

## Documentation Structure

### API Reference (`docs/reference/`)
Detailed documentation for TheAction framework helper functions:
- `TheAction_UnitLua_HelperFunctions.md` - Unit-related functions (health, buffs/debuffs, positioning, threat, casting)
- `TheAction_PlayerLua_HelperFunctions.md` - Player-specific functions (resources, stances, movement heuristics, inventory tracking)
- `TheAction_MultiUnitsLua_HelperFunctions.md` - Multi-unit tracking (nameplates, AoE logic, active enemies via CLEU)
- `TheAction_CombatLua_HelperFunctions.md` - Combat tracking (damage/healing, cooldowns, TTD, loss-of-control)
- `TheAction_ActionsLua_HelperFunctions.md` - Action object helpers (IsReady, Show, IsUsable, etc.)
- Additional references for Textfiles, TellMeWhen, GG, and FluxAIO APIs

### Class Research (`docs/`)
Per-class implementation research files containing:
- Spell IDs (max rank TBC) with detailed notes
- Rotation and strategies for each spec
- AoE rotations
- Shared utility and defensive strategies
- Resource management systems
- Cooldown management
- Proposed settings schema
- Strategy breakdown per playstyle
- Wowsims verified rotation logic
- Key implementation notes

Available for: Warrior, Warlock, Shaman, Rogue, Priest, Paladin, Mage, Hunter, Druid
Plus: `NEW_CLASS_GUIDE.md` (complete guide to adding a new class) and `BURST_DEFENSIVE_RESEARCH.md`

### Plans (`docs/plans/`)
Design documents for features like log analyzer, shared middleware, etc.

## Directory Structure

```
FLUX/
├── rotation/                 # Core rotation addon
│   ├── source/aio/          # Active modular source
│   │   ├── druid/           # Druid: caster, cat, bear, balance, resto
│   │   ├── hunter/          # Hunter: ranged
│   │   ├── mage/            # Mage: fire, frost, arcane
│   │   ├── paladin/         # Paladin: retribution, protection, holy
│   │   ├── priest/          # Priest: shadow, smite, holy
│   │   ├── rogue/           # Rogue: combat, assassination, subtlety
│   │   ├── shaman/          # Shaman: elemental, enhancement, restoration
│   │   ├── warlock/         # Warlock: affliction, demonology, destruction
│   │   └── warrior/         # Warrior: arms, fury, protection
│   ├── output/              # Compiled output (gitignored)
│   ├── build.js             # Build script
│   ├── dev-watch.js         # File watcher
│   ├── dev.ini              # Local dev config
│   └── tmw-template.lua     # TMW profile template
├── website/                 # Static distribution site (Astro)
│   ├── src/data/            # Talent data files
│   └── src/pages/guides/    # Class talent guides
├── discord-bot/             # Discord bot for Claude AI integration
└── docs/                    # Documentation (as detailed above)
```

## TBC Class/Spec Content

FLUX contains extensive TBC-specific information:

1. **Class Research Files**: Each `*_RESEARCH.md` file provides:
   - Complete spell ID listings with max rank TBC information
   - Detailed rotation strategies for each specialization
   - AoE rotation approaches
   - Resource management specifics (rage, energy, focus, mana)
   - Cooldown management priorities
   - Settings schema proposals
   - Verified rotation logic from wowsims simulator
   - Critical TBC-specific mechanics and limitations

   Example insights from Warrior research:
   - Arms: Mortal Strike + stance dancing (Battle/Berserker) with Overpower procs
   - Fury: Bloodthirst + Whirlwind + rage dumping with Heroic Strike queuing
   - Protection: Threat priority + Shield Block uptime for crush prevention
   - Specific mechanics: Tactical Mastery rage retention, stance swap costs, Execute phase damage formulas

2. **Website Talent Data**: 
   - `website/src/data/*-talents.js` files contain talent tree data
   - `website/src/pages/guides/*-talents.astro` provide talent guides

3. **Implemented Rotations**:
   - Actual rotation logic in `rotation/source/aio/<class>/<playstyle>.lua` files
   - Uses FLUX's strategy registry system with priority-based execution

## Integration Potential with EAX Rotations

Based on analysis of both systems, FLUX offers several valuable concepts that could enhance EAX:

### 1. Strategy Registry Pattern
FLUX's clean separation of:
- **Middleware** (shared logic: recovery, cooldowns, buffs, dispels - runs first)
- **Strategies** (playstyle-specific rotations - ordered by priority)
This is more structured than EAX's current approach and could improve maintainability.

### 2. Context Management System
- Reusable context table (avoids per-frame allocation)
- Class-specific `extend_context()` callback for adding fields
- Context builder pattern for expensive state computation (cached per frame)
- Automatic cache invalidation flags (`ctx._<name>_valid = false`)

### 3. Advanced Features
- **Burst Context System**: Schema-configurable automatic burst conditions (bloodlust, pull, execute, always in combat)
- **Force-Bypass Dispatch**: `/flux burst`/`/flux def` commands with proper spell readiness checking
- **Gap Handler System**: `/flux gap` for gap closing abilities
- **Suggestion System**: A[1] icon showing recommended idle-form ability
- **Combat Dashboard**: Declarative config-driven shared overlay

### 4. Technical Systems Worth Considering
- **Spell Validation**: Sophisticated `is_spell_known`/`check_spell_availability` system
- **Immunity/Dispel Helpers**: `has_phys_immunity`, `has_magic_immunity`, `A.AuraIsValid` for smart dispelling
- **Combat Tracking**: `CombatTracker` (damage/healing/TTD) and `UnitCooldown` (cooldown/in-flight tracking)
- **Multi-unit Tracking**: Nameplate-based AoE detection via `A.MultiUnits`
- **Predictive Healing**: Effective deficit calculation incorporating incoming heals/HoTs/absorbs
- **Settings System**: Schema-driven automatic UI generation with live updates

### 5. Data & Reference Value
- TBC-accurate spell IDs and mechanics research in `*_RESEARCH.md` files
- Talent data for spec detection
- Verified rotation logic from wowsims simulator
- Implementation examples of TBC-specific mechanics (stance dancing, rage normalization, etc.)

### 6. Architectural Benefits
- Clear separation: shared modules (core.lua, main.lua, ui.lua, settings.lua, dashboard.lua) vs class-specific
- Build system that auto-discovers class modules and compiles to single TMW profile
- Strict load order enforcement via ORDER_MAP in build.js
- File naming conventions (lowercase single words only) enforced by build system

## Recommended Integration Approach

1. **Adopt the Strategy Registry Pattern** for organizing rotation priorities with clear middleware/strategy separation
2. **Implement FLUX's context building/caching system** to reduce per-frame allocations and expensive API calls
3. **Consider the burst context system** for more sophisticated automatic cooldown usage
4. **Evaluate FLUX's immunity and dispel helpers** for improved smart dispel logic
5. **Review the multi-unit tracking system** for potential AoE target selection improvements
6. **Use the class research files** as reference for ensuring TBC accuracy in spell IDs and mechanics
7. **Consider the schema-driven settings system** for more dynamic configuration UI

The most valuable aspects would be the strategy registry pattern for better organization, the context management system for performance, and the TBC-specific research for accuracy validation. FLUX's systems are designed specifically for TBC and have been validated against wowsims simulator data, making them excellent references for ensuring authenticity in EAX rotations.