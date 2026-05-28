# EaxRotations

**TBC Classic rotation framework for [Project Sylvanas](https://github.com/aicore/sylvanas)**

Automated spell and ability sequencing for all 9 World of Warcraft classes across 29 TBC Classic specializations. Built on a shared combat engine with defensive middleware, role-aware settings, and regression tests.

---

## Installation

1. Download or clone this repository
2. Copy the `EaxRotations` folder into your Project Sylvanas scripts directory:

```
scripts/
  EaxRotations/
    header.lua          # Load validation
    main.lua            # Bootstrap entry
    core_sylvanas.lua   # Runtime boundary
    classes/            # Per-class rotation modules
    shared/             # Reusable combat modules
    tests/              # Regression test suite
```

3. Restart Project Sylvanas or reload the UI
4. Select your spec's rotation from the plugin menu

The loader automatically detects your class and loads the appropriate rotation module.

---

## Supported Classes

| Class | Specs | Roles |
|-------|-------|-------|
| **Druid** | Balance, Bear, Feral Cat, Restoration | Ranged DPS, Tank, Melee DPS, Healing |
| **Hunter** | Beast Mastery, Marksmanship, Survival | Ranged DPS, Pet Utility |
| **Mage** | Arcane, Fire, Frost | Ranged DPS, Interrupts, Utility |
| **Paladin** | Holy, Protection, Retribution | Healing, Tank, Melee DPS |
| **Priest** | Discipline, Holy, Shadow, Smite | Healing, Shielding, Ranged DPS |
| **Rogue** | Assassination, Combat, Subtlety | Melee DPS, Control, Interrupts |
| **Shaman** | Elemental, Enhancement, Restoration | Ranged DPS, Melee DPS, Healing |
| **Warlock** | Affliction, Demonology, Destruction | Ranged DPS, Pet Utility, Curses |
| **Warrior** | Arms, Fury, Protection | Melee DPS, Tank, PvP Utility |

---

## Features

- **29 spec rotations** with 20-40+ strategy entries each, covering openers, AoE, execute phase, and defensive cooldowns
- **9 leveling rotations** for low-level play
- **PvP support** including DR tracking, enemy cooldown monitoring, burst window detection, and arena target priority
- **Defensive middleware** for automatic healthstones, potions, and class-specific defensive cooldowns
- **Role-aware settings** with PvE/PvP modes and customizable thresholds per spec
- **Performance-focused** with cached API calls, squared-distance checks, and sub-20ms strategy evaluation

---

## How It Works

Every action passes shared safety gates before casting:

- Player exists, is alive, and can act
- Target is valid, attackable, and in range
- Spell is known, off cooldown, and resource is available
- Stance/form requirements are met
- PvE/PvP/defensive rules allow the action

When a gate fails, the rotation skips the action instead of forcing an invalid cast. This "first successful action wins" model keeps rotations predictable and safe.

---

## Architecture

```
EaxRotations/
  header.lua              # Plugin metadata, class detection
  main.lua                # Bootstrap, loads shared framework
  core_sylvanas.lua       # NS.* helpers, API wrappers, spell casting
  main_sylvanas.lua       # Update dispatcher, context building
  common_sylvanas.lua     # Shared UI sections
  helpers_sylvanas.lua    # Helper aliases
  ui_sylvanas.lua         # Menu framework
  dashboard_sylvanas.lua  # In-game HUD overlay

  classes/<class>/
    class_sylvanas.lua        # Class registration, spell objects
    middleware_sylvanas.lua   # Class-wide behavior (defensives, interrupts)
    schema_sylvanas.lua       # Settings UI
    leveling_sylvanas.lua     # Leveling rotation
    <spec>_sylvanas.lua       # TBC spec rotation

  shared/                 # Reusable combat modules
    interrupt_manager_sylvanas.lua
    consumable_manager_sylvanas.lua
    racial_manager_sylvanas.lua
    trinket_manager_sylvanas.lua
    swing_timer_sylvanas.lua
    dot_refresh_sylvanas.lua
    burst_logic_sylvanas.lua
    dr_tracker_sylvanas.lua
    arena_priority_sylvanas.lua
    ... (50+ modules)

  tests/                  # Regression test suite
    run_rotation_tests.lua    # Runs 95 rotation test suites
    run_leveling_tests.lua    # Runs 11 leveling test suites
    test_*.lua                # Individual test files
```

---

## Settings

Each spec provides configurable settings through the in-game menu:

- **Spell toggles** - Enable or disable individual abilities
- **Thresholds** - HP, rage, mana, and energy thresholds for ability usage
- **Cooldown control** - When to use offensive and defensive cooldowns
- **PvP options** - Interrupt behavior, CC usage, burst gates
- **AoE settings** - Minimum target count for area-of-effect abilities

---

## Testing

Run syntax checks on all Lua files:

```bash
find EaxRotations -name "*.lua" -exec luac -p {} \;
```

Run the rotation regression test suite (95 suites):

```bash
lua EaxRotations/tests/run_rotation_tests.lua
```

Run the leveling test suite (11 suites):

```bash
lua EaxRotations/tests/run_leveling_tests.lua
```

Run a specific test file:

```bash
lua EaxRotations/tests/test_fury_custom_matches.lua
```

---

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

Contributions should preserve the existing structure:

- Shared behavior in `shared/`
- Class-wide behavior in `classes/<class>/middleware_sylvanas.lua`
- Spec-specific priorities in `classes/<class>/<spec>_sylvanas.lua`
- Settings in `classes/<class>/schema_sylvanas.lua`

---

## License

[CC-BY-4.0](LICENSE) - You are free to use, modify, and distribute this software for any purpose, including commercial use, provided you give appropriate credit to the original author.

---

## Acknowledgments

Built for [Project Sylvanas](https://github.com/aicore/sylvanas) - a TBC Classic automation framework.
