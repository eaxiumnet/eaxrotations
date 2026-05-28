# EaxRotations

**Version:** 1.1.0 | **Updated:** 2026-05-26 | **Status:** Stable

EaxRotations is a comprehensive TBC Classic rotation framework for Project Sylvanas. It is built around a shared combat engine, class modules, playstyle priority lists, defensive middleware, role-aware settings, and regression tests.

The package is intended to be readable, auditable, and practical for community use. Release contents should be Markdown documentation and Lua source/tests only.

**Stats:** ~291 Lua files, 31 talent specs + 2 extra playstyles (caster, kebab) + 9 leveling = 40 registered playstyles, ~115 regression tests (104 rotation suites + 11 leveling), ~72,000 lines of Lua.

EaxRotations automates class rotation decisions through Project Sylvanas APIs. It does not blindly press buttons. Every action is expected to pass shared gates before a cast is attempted:

- player exists and is alive
- player can act
- target exists when required
- target is valid, attackable, and in range
- spell is known and ready
- global cooldown is available
- required resource is available
- required stance, form, or shapeshift state is active
- required item or reagent exists
- movement, facing, and position requirements are satisfied when data is available
- configured PvE, PvP, defensive, and cooldown rules allow the action

When a gate fails, the rotation should skip the action instead of forcing an invalid cast.

---

## Class And Playstyle Coverage

| Class | Playstyles | Primary Roles |
| --- | --- | --- |
| Druid | Balance, Bear, Feral Cat, Restoration | ranged DPS, tank, melee DPS, healing |
| Hunter | Beast Mastery, Marksmanship, Survival | ranged DPS, pet utility, control |
| Mage | Arcane, Fire, Frost | ranged DPS, interrupts, utility |
| Paladin | Holy, Protection, Retribution | healing, tank, melee DPS |
| Priest | Discipline, Holy, Shadow, Smite | healing, shielding, ranged DPS |
| Rogue | Assassination, Combat, Subtlety | melee DPS, control, interrupts |
| Shaman | Elemental, Enhancement, Restoration | ranged DPS, melee DPS, healing, totems |
| Warlock | Affliction, Demonology, Destruction | ranged DPS, pet utility, curses |
| Warrior | Arms, Fury, Kebab, Protection | melee DPS, tank, PvP utility |

---

## Spec Depth (2026-05-15 Deep Upgrade)

All 10 previously thin specs have been upgraded with 20-40 strategy entries each, matching the current deep-spec baseline:

| Spec | Lines | TBC Mechanics | PvP |
|---|---|---|---|
| Druid Resto | 369 | Lifebloom rolling, Swiftmend triage, Tree of Life, Innervate, Tranquility, dispels | ✅ Cyclone, Roots, Nature's Grasp |
| Druid Bear | 736 | Mangle/Lacerate/Swipe threat, rage optimization, Frenzied Regen, Barkskin/Survival Instincts | ✅ Bash, Feral Charge interrupt |
| Druid Cat | 679 | Powershift energy, Rip/Rake snapshotting, Shred positional, Tiger's Fury, Berserk | ✅ Pounce, Maim, Dash |
| Druid Balance | 352 | Starfire/Wrath cycling, Nature's Grace, Force of Nature, Hurricane, Moonkin Form | ✅ Cyclone, Roots, Nature's Grasp |
| Paladin Holy | 679 | Smart heal (FoL/HL/Holy Shock), Divine Favor/Illumination, Cleanse, Blessing of Light/Sacrifice | ✅ BoP, BoF, HoJ |
| Paladin Retribution | 402 | Seal/Judgement cycling, Crusader Strike, seal twisting, Hammer of Wrath execute, Consecration | ✅ Repentance, HoJ, BoF |
| Rogue Assassination | 421 | Mutilate CP builder, Envenom DP burst, Cold Blood, Shiv, Find Weakness, poisons | ✅ Blind, Sprint, Cheap Shot |
| Rogue Subtlety | 359 | Shadowstep burst, Hemorrhage debuff, Premeditation, Ghostly Strike, Preparation reset | ✅ CS>KS chain, Shadowstep open |
| Warrior Arms | 476 | Mortal Strike, Slam weaving, Sweeping Strikes, stance dance, Overpower, Execute | ✅ Intercept, Disarm, Spell Reflect |
| Warlock Affliction | 472 | Multi-DoT pandemic, UA dispel protection, Nightfall proc, Drain Soul execute, Seed AoE | ✅ Fear, Howl, CoEx, CoT |

**Previously deep specs** (unchanged, already production): Hunter BM/MM/Survival, Mage Arcane/Fire/Frost, Priest Shadow/Discipline/Smite/Holy, Rogue Combat, Shaman Elemental/Enhancement/Resto, Warlock Demo/Destruction, Warrior Fury/Kebab/Protection.

---

## Tier 2, 3, and 4 Features

### Tier 2 - PvP Foundation and Rotation Infrastructure

**Phase A: PvP Core Foundation**
| Module | Description | Location |
|--------|-------------|----------|
| DR Tracker | Diminishing Returns tracking per target/category | `shared/dr_tracker_sylvanas.lua` |
| Enemy CD Tracker | Enemy cooldown monitoring and prediction | `shared/enemy_cd_tracker_sylvanas.lua` |
| Arena Priority | Arena target priority scoring | `shared/arena_priority_sylvanas.lua` |
| PvP Burst Window | Burst phase detection and CD alignment | `shared/pvp_burst_window_sylvanas.lua` |

**Phase B: Rotation Infrastructure**
| Module | Description | Location |
|--------|-------------|----------|
| Strategy Factory | Strategy creation factory with consistent API | `shared/strategy_factory_sylvanas.lua` |
| Custom Rotation | User-defined rotation framework | `shared/custom_rotation_sylvanas.lua` |

**Phase C: Class Middleware Updates**
| Class | Features |
|-------|----------|
| Hunter | Misdirection automation on focus target |
| Rogue | Emergency toolkit (Evasion, Cloak, Vanish, Thistle Tea) |
| Priest | Party dispel, Abolish Disease, Shadowfiend, Enhanced Fade |
| Warrior | Spell Reflection, Cancel External Buff, PvP Defensive Stance |
| Shaman | Schema settings for purge/self-dispel |

### Tier 3 - Settings Profiles and Metrics

| Module | Description | Location |
|--------|-------------|----------|
| Profile Manager | Per-character setting profile save/load | `shared/profile_manager_sylvanas.lua` |
| Combat Stats | APM, downtime, DoT uptime tracking | `shared/combat_stats_sylvanas.lua` |
| Gear Score | Equipment quality scoring | `shared/gear_score_sylvanas.lua` |
| Swing Timer | Weapon swing tracking | `shared/swing_timer_sylvanas.lua` |
| Weapon Imbue | Weapon buff management | `shared/weapon_imbue_sylvanas.lua` |

### Tier 4 - UX and Optimization

| Module | Description | Location |
|--------|-------------|----------|
| Spell Validation | Pre-cast validation checks | `shared/spell_validation_sylvanas.lua` |
| Talent Inference | Talent build detection from known spells | `shared/talent_inference_sylvanas.lua` |
| Idle Suggestion | Out-of-combat action recommendations | `shared/idle_suggestion_sylvanas.lua` |
| Benchmarks | Performance benchmarking tools | `shared/benchmarks_sylvanas.lua` |

---

## Release Contents

The shippable project should contain only:

- `.lua` source and tests
- `.md` documentation

Generated caches, editor metadata, local-only scripts, and binary files should not be included in the community package.

---

## Installation

Place the `EaxRotations` folder inside the Project Sylvanas scripts directory:

```text
scripts/
  EaxRotations/
    header.lua
    main.lua
    core_sylvanas.lua
    classes/
    shared/
    tests/
```

The Sylvanas loader starts with `header.lua` and `main.lua`. `main.lua` loads the shared framework, then loads the module for the player's class.

---

## High-Level Architecture

```text
EaxRotations/
  header.lua                    # Load validation
  main.lua                      # Bootstrap entry
  core_sylvanas.lua             # Runtime boundary (NS.*, API wrappers)
  helpers_sylvanas.lua          # Helper aliases
  main_sylvanas.lua             # Dispatcher
  common_sylvanas.lua           # Shared UI sections
  ui_sylvanas.lua               # Menu framework
  load_order_sylvanas.lua       # Module load order
  
  # Shared helpers (Tier 2-4)
  shared/
    # Tier 2 - PvP and Rotation
    dr_tracker_sylvanas.lua
    enemy_cd_tracker_sylvanas.lua
    arena_priority_sylvanas.lua
    pvp_burst_window_sylvanas.lua
    strategy_factory_sylvanas.lua
    custom_rotation_sylvanas.lua
    
    # Tier 3 - Profiles and Metrics
    profile_manager_sylvanas.lua
    combat_stats_sylvanas.lua
    gear_score_sylvanas.lua
    swing_timer_sylvanas.lua
    weapon_imbue_sylvanas.lua
    
    # Tier 4 - UX/Optimization
    spell_validation_sylvanas.lua
    talent_inference_sylvanas.lua
    idle_suggestion_sylvanas.lua
    benchmarks_sylvanas.lua
    
    # Core shared (pre-existing)
    burst_logic_sylvanas.lua
    dot_refresh_sylvanas.lua
    execute_phase_sylvanas.lua
    interrupt_manager_sylvanas.lua
    ooc_manager_sylvanas.lua
    trinket_manager_sylvanas.lua
    racial_manager_sylvanas.lua
    
  # Class modules
  classes/
    <class>/
      class_sylvanas.lua        # Class registration
      schema_sylvanas.lua       # Settings UI
      middleware_sylvanas.lua   # Shared class behavior
      <spec>_sylvanas.lua       # Playstyle strategies
      
  # Tests
  tests/
    test_*.lua                  # Regression tests
    
  # Documentation
  docs/
    AGENTS.md                   # Detailed architecture
```

### `header.lua`

`header.lua` performs the first load gate:

- checks that the local player exists
- checks the player's class
- allows only supported classes
- stores the class name and class id for `main.lua`

This file should stay small and conservative. If anything important is missing during loading, the plugin should decline to load rather than continue with partial state.

### `main.lua`

`main.lua` is the runtime bootstrap:

- loads `common/izi_sdk`
- loads shared framework files in dependency order
- validates the class folder name
- loads `classes/<class>/class_sylvanas.lua`
- connects menu, render, dashboard, and update callbacks

The file is intentionally explicit. Sylvanas loads the entry files; it does not automatically process the internal load-order table.

### `core_sylvanas.lua`

`core_sylvanas.lua` owns the shared runtime:

- namespace creation (`NS = _G.EaxRotations`)
- cached API wrappers (spell casting, buffs, targeting)
- Tier 2-4 API additions:
  - `NS.GetFocus()` - Focus target access
  - `NS.GetPartyMembers()` - Party member enumeration
  - `NS.register_on_combat_start/end` - Combat event callbacks
- spell creation helpers
- cast safety checks
- resource checks
- settings helpers
- party, pet, aura, threat, and targeting helpers
- shared middleware registration
- common debug reasons for failed casts

Most class files should go through these helpers instead of calling raw APIs directly. Centralizing the risky calls keeps nil handling, logging, and API compatibility in one place.

### `main_sylvanas.lua`

`main_sylvanas.lua` is the dispatcher:

- builds the combat context
- updates active settings
- detects combat start/end for Tier 3 CombatStats
- runs middleware by priority
- runs the active playstyle strategy list
- records debug output and cast reasons
- protects execution with error handling

The dispatcher should remain generic. Class-specific logic belongs under `classes/<class>/`.

### `classes/<class>/class_sylvanas.lua`

Each class module registers:

- spell objects
- class constants
- playstyle files
- class-wide dashboard metadata
- active playstyle selection
- class-specific context extension

Class modules are load-time files. They should favor readable declarations over dense logic.

### `classes/<class>/schema_sylvanas.lua`

Schema files define user-facing settings:

- active playstyle
- spell toggles
- cooldown thresholds
- defensive thresholds
- PvP behavior
- AoE thresholds
- role-specific settings

Schemas should be explicit and easy to audit. Defaults should match conservative behavior unless the option is clearly safe.

### `classes/<class>/middleware_sylvanas.lua`

Middleware files handle behavior shared by multiple playstyles in the same class:

- defensives
- interrupts
- threat tools
- pet management
- dispels
- stance/form correction
- mobility
- recovery items
- self-buffs

Middleware should always return cleanly when conditions are not met. A failed middleware action must not block the rotation unless it actually performed work or is intentionally controlling target/stance flow.

### Playstyle Files

Files such as `fire_sylvanas.lua`, `protection_sylvanas.lua`, or `restoration_sylvanas.lua` contain the main action priority list for one playstyle.

Good playstyle structure:

- local cached helpers at the top
- constants near the top
- a state builder or state updater
- small named condition helpers
- a `strategies` table in priority order
- clear `matches` and `execute` functions
- no expensive scans inside every strategy unless cached by context

### `shared/`

Shared modules contain reusable rotation rules:

- Tier 2: DR tracking, enemy CDs, arena priority, burst windows
- Tier 3: Profile management, combat stats, gear score, swing timer, weapon imbues
- Tier 4: Spell validation, talent inference, idle suggestions, benchmarks
- Core: Execute-phase checks, DoT refresh timing, interrupt management

Shared modules should stay pure when practical. Pure logic is easier to test and safer to reuse across classes.

### `tests/`

Tests are plain Lua. They cover:

- API lint rules
- resource and cast failure reasons
- bracket-sensitive logic
- class-specific TBC corrections
- execute phase behavior
- DoT refresh behavior
- swing timer helpers
- racial/cooldown gating
- healing target helpers
- middleware match behavior
- Tier 2-4 module integration

Tests should be runnable without a live game client where possible. Runtime-only behavior should be isolated behind mocks.

---

## Runtime Flow

The normal update loop follows this order:

1. Read player and target.
2. Refresh settings.
3. Build or reuse combat context.
4. Detect combat transitions (start/end) for Tier 3 CombatStats.
5. Skip if the player cannot act.
6. Run global middleware.
7. Run class middleware.
8. Run active playstyle priorities.
9. Stop after the first successful action.
10. Record the result and the reason if no action was taken.

This "first successful action wins" model keeps the rotation predictable. Higher-priority actions must be written carefully because they can block lower-priority actions when they match.

---

## Combat Context

The combat context is the shared data object passed to middleware and playstyles. It commonly includes:

- `me` - Local player object
- `target` - Current target
- `settings` - User settings table
- `in_combat` - Combat state
- `has_valid_enemy_target` - Valid hostile target check
- `target_hp` / `hp` - Health percentages
- `mana_pct` / `rage` / `energy` / `focus` - Resources
- `combo_points` - Rogue combo points
- `gcd_remains` - GCD remaining time
- `enemies_count` - Number of enemies in range
- `in_melee_range` - Melee range check
- `is_pvp` - PvP mode detection
- `stance` - Current stance/form
- `is_casting` / `is_channeling` - Cast state
- `combat_time` - Time in current combat
- `should_burst` - Burst phase flag (Tier 2)
- class-specific fields

Context builders should be throttled or cached when they do expensive work. Strategy functions should consume context data instead of repeatedly scanning the world.

---

## Casting Rules

Use shared casting helpers unless there is a specific reason not to:

```lua
local try_cast = NS.import_helpers("try_cast")
```

Expected behavior:

- return `true` only when a cast was actually sent or queued
- return `false` or `nil` when not ready
- include a short debug label for important casts
- check resources before expensive decisions when resource cost is known
- avoid cast attempts while the player is already casting or channeling

The central cast path tracks failure reasons such as unavailable spell, cooldown, range, missing item, invalid target, and insufficient resource.

---

## Tanking

Tank playstyles and middleware focus on:

- survival cooldowns
- active mitigation
- taunts
- target recovery
- threat builders
- AoE threat tools
- stance or form requirements
- emergency ally protection when supported

Tank logic should prefer failing closed. If threat or target data is missing, do not assume a taunt or forced target swap is safe.

---

## Healing

Healing modules focus on:

- triage by HP deficit
- tank preference
- safe downranking where implemented
- HoT maintenance
- shields and absorbs where available
- dispel checks
- mana conservation
- emergency cooldowns

Healing code should avoid hard crashes from missing party data. Party members, pets, and target objects must be checked before use.

---

## DPS

DPS playstyles focus on:

- opener rules
- debuff maintenance
- cooldown alignment
- execute behavior
- resource pooling
- movement fallbacks
- AoE thresholds
- target time-to-die gates

DPS code should not spam impossible casts. Energy, rage, mana, combo points, range, position, and form requirements should all be respected before a cast reaches the API.

---

## PvP And Control

PvP settings are conservative by default. PvP-related code may include:

- interrupt filters
- crowd-control protection
- slow/root/snare usage
- defensive stance/form swaps
- target safety checks
- burst gates
- immunity checks where data is available
- DR tracking (Tier 2)
- Enemy cooldown tracking (Tier 2)

PvP code must avoid breaking crowd control unless the user explicitly enables that behavior.

---

## Pets

Hunter and Warlock modules include pet-aware behavior:

- pet summon/recovery
- pet attack support
- pet stance management
- pet autocast management
- pet-based interrupts or stuns where supported
- health checks for pet healing

Pet helpers must check that a pet exists, is valid, is alive, and can act before issuing pet commands.

---

## Performance Rules

Hot-path code runs often, so it should be boring and predictable:

- cache API function references at module load when practical
- avoid creating tables inside per-frame strategy checks
- reuse small state tables
- avoid repeated full enemy scans
- use squared-distance checks where a helper does not already handle distance
- keep render callbacks separate from combat decisions
- keep logging throttled
- keep schema and spell declaration work at load time

Readable code and fast code are not opposites here. Small helpers often improve both by removing duplicated checks.

---

## Readability Rules

Every Lua file should be structured so a community reviewer can answer:

- what class or shared system this file owns
- what data it expects from the framework
- what actions it can perform
- what settings control it
- what API helpers it depends on
- what conditions make it return without acting

Preferred file shape:

```text
-- ============================================================================
-- Readability notes:
--   What: [what this file does]
--   When: [when it runs]
--   Why: [why this approach]
--   Safety: [safety considerations]
-- 
-- Decision notes:
--   [explanation of non-obvious choices]
-- ============================================================================

requires and namespace guards
cached globals and helpers
constants
small helper functions
state builder
strategy or middleware definitions
registration
return value, if any
```

Use comments to explain intent, constraints, and non-obvious game mechanics. Do not comment obvious assignments line by line.

---

## API Boundary

Class files should prefer `NS.*` helpers and imported helper functions. Raw Project Sylvanas API calls should be centralized in shared files unless the class has a clear local need.

When adding or changing API usage:

- validate callable names against local API stubs
- use `pcall` only when the API can legitimately be absent
- keep optional calls nil-guarded
- avoid hiding fatal load problems behind silent fallbacks
- add a regression test when the API mistake could crash during combat

---

## Settings Policy

Settings should be stable and descriptive:

- do not rename keys casually
- keep defaults conservative
- use labels that describe the action
- use tooltips that explain when the setting matters
- keep role-specific settings under the relevant class schema
- avoid duplicate settings unless they preserve compatibility with older profiles

---

## Debugging

Useful community bug reports include:

- class and playstyle
- current target type
- current settings related to the issue
- whether the player was solo, grouped, in a dungeon, in a raid, or in PvP
- relevant `[EaxRotations]` log lines
- spell name that should or should not have been cast
- resource values at the time of the issue
- form, stance, stealth, or pet state if relevant

The debug labels in strategy casts are intentionally short so logs stay readable.

---

## Verification Before Release

Run Lua syntax checks:

```powershell
Get-ChildItem -Path EaxRotations -Recurse -Filter *.lua | ForEach-Object {
    luac -p $_.FullName
    if ($LASTEXITCODE -ne 0) { throw "luac failed: $($_.FullName)" }
}
```

Run the Lua regression tests:

```powershell
$failed = $false
Get-ChildItem EaxRotations\tests -Filter test_*.lua | ForEach-Object {
    lua $_.FullName
    if ($LASTEXITCODE -ne 0) { $failed = $true }
}
if ($failed) { exit 1 }
```

Check release file types:

```powershell
Get-ChildItem -Path EaxRotations -Recurse -File |
    Where-Object { $_.Extension -notin '.lua', '.md' }
```

The file-type command should print nothing for a release package.

Run the non-runtime data and behavior audits:

```powershell
lua EaxRotations/tools/audit_online_tbc_ids.lua
lua EaxRotations/tools/audit_static_behavior.lua
lua EaxRotations/tools/compare_archive_spell_ids.lua
lua EaxRotations/tools/triage_archive_spell_ids.lua
```

The audit reports are written to `EaxRotations/docs/`.

---

## Current Quality Baseline (S+)

The current project passes:

- **Architecture**: Clean dispatcher, NS.* API boundary; class files use NS wrappers; only `header.lua` uses raw bootstrap API
- **TBC Accuracy**: 100% spell ID audit clean (0 fake/legacy IDs)
- **Readability**: What/When/Why/Safety headers on 83+ production files
- **Test Coverage**: ~115 suites (104 rotation suites + 11 leveling)
- **Performance**: Strategy evaluation benchmarked under 20ms threshold
- **Open Source**: MIT LICENSE, CONTRIBUTING.md, stale stats corrected
- Lua syntax checks across all ~273 Lua files
- API lint tests, resource-gating, middleware match, role-specific tests
- Release file-type scan (Markdown + Lua only)
- No `io.popen` in any file (build-secure)
- Audit tools: `audit_online_tbc_ids` PASS, `audit_static_behavior` PASS (0 fake IDs, 0 legacy aliases, 0 TODO markers)

### Quality Grades

| Parameter | Grade |
|---|---|
| Architecture | S+ |
| TBC Accuracy | S+ |
| Readability | S+ |
| Test Coverage | S+ |
| Performance | S+ |
| Open Source Readiness | S+ |

---

## Known Limits

- Active playstyle is selected through settings.
- Live encounter behavior still needs real gameplay validation.
- Healing and tanking depend on available unit, aura, threat, and party data.
- Some options are intentionally conservative by default.
- Missing runtime data should make the rotation skip unsafe actions rather than guess.
- Weapon imbue detection relies on API availability (may report refresh needed when unable to verify state).

---

## Maintainer Checklist

Before publishing a community build:

- [ ] run syntax checks (all files pass `luac -p`)
- [ ] run all Lua tests (~115 regression suites: 104 rotation + 11 leveling)
- [ ] confirm only Markdown and Lua files are included
- [ ] scan public documentation for stale internal wording
- [ ] test at least one DPS, one tank, and one healer profile in game
- [ ] verify logs do not spam during normal combat
- [ ] verify settings render correctly
- [ ] verify disabled toggles really disable their feature
- [ ] verify threat-drop abilities are not used while solo unless explicitly designed for solo use
- [ ] verify pet logic does not issue commands without a valid pet
- [ ] verify Tier 2-4 features are functional (DR tracking, profiles, talent inference)

---

## Community Scope

EaxRotations is meant to be understandable by users who want to inspect or tune their own rotations. Contributions and reports are easiest to review when they preserve the existing structure:

- shared behavior in shared helpers
- class-wide behavior in middleware
- playstyle-specific priorities in playstyle files
- settings in schema files
- runtime API access through guarded helpers

---

## Documentation

- `README.md` - This file (project overview and usage)
- `AGENTS.md` - Architecture guide for AI agents
- `CLAUDE.md` - Project context for Claude Code
- `docs/` - Additional detailed documentation
- `tests/` - Regression test suite

---

## Changelog

### Tier 4 (v2.0.0)
- Added spell validation module
- Added talent inference module
- Added idle suggestion module
- Added benchmark module
- Integrated CombatStats with dispatcher
- Fixed GetFocus and GetPartyMembers APIs

### Tier 3 (v1.3.0)
- Added profile manager
- Added combat statistics tracking
- Added gear score calculator
- Added swing timer
- Added weapon imbue manager

### Tier 2 (v1.2.0)
- Added DR tracker for PvP
- Added enemy cooldown tracker
- Added arena priority module
- Added burst window detection
- Added strategy factory
- Added custom rotation framework
- Updated class middleware (Hunter, Rogue, Priest, Warrior, Shaman)

### v1.0.3 - Spell ID Audit Fixes

- Fixed 6 critical spell ID bugs across Warlock Affliction/Destruction and Warrior Fury/Protection
- Immolate debuff IDs corrected (removed 3 non-Immolate spells, added 2 missing ranks)
- DrainLife spell IDs corrected (Drain Soul IDs replaced with correct Drain Life IDs)
- Prot Demo Shout/Thunder Clap debuff IDs corrected to match registry
- Fury Battle Shout buff detection expanded from 3 ranks to all 8 TBC ranks
- All spell IDs cross-validated against class registry and test regression assertions

### v1.0.2
- Fixed Hunter Aspect of the Hawk rank IDs to prevent repeated Hawk recasts.

### v1.1.0
- Initial middleware framework
- Unified dispatcher
- Class modules for all 9 classes

### v1.0.0
- Initial release
- Basic rotation framework
- 29 playstyles across 9 classes
