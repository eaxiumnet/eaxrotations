# EaxRotations

TBC Classic rotation framework for [Project Sylvanas](https://github.com/aicore/sylvanas). Automated spell/ability sequencing for all 9 classes with optimized DPS/HPS/TPS rotations, defensive middleware, and role-aware settings.

## Installation

Copy the `EaxRotations` folder into your Project Sylvanas scripts directory:

```
scripts/
  EaxRotations/
    header.lua
    main.lua
    core_sylvanas.lua
    classes/
    shared/
    tests/
```

The loader starts at `header.lua` and `main.lua`. It automatically detects your class and loads the appropriate rotation module.

## Supported Classes

| Class | Specs | Roles |
|-------|-------|-------|
| Druid | Balance, Bear, Feral Cat, Restoration | Ranged DPS, Tank, Melee DPS, Healing |
| Hunter | Beast Mastery, Marksmanship, Survival | Ranged DPS |
| Mage | Arcane, Fire, Frost | Ranged DPS |
| Paladin | Holy, Protection, Retribution | Healing, Tank, Melee DPS |
| Priest | Discipline, Holy, Shadow, Smite | Healing, Shielding, Ranged DPS |
| Rogue | Assassination, Combat, Subtlety | Melee DPS |
| Shaman | Elemental, Enhancement, Restoration | Ranged DPS, Melee DPS, Healing |
| Warlock | Affliction, Demonology, Destruction | Ranged DPS |
| Warrior | Arms, Fury, Protection | Melee DPS, Tank |

## Features

- **29 spec rotations** with 20-40+ strategy entries each
- **9 leveling rotations** for low-level play
- **PvP support** - DR tracking, enemy cooldowns, burst windows, arena priority
- **Defensive middleware** - automatic healthstones, potions, defensive cooldowns
- **Role-aware settings** - PvE/PvP modes, customizable thresholds per spec
- **Performance-focused** - cached API calls, squared-distance checks, sub-20ms strategy evaluation

## How It Works

Every action passes shared safety gates before casting:

- Player exists, is alive, and can act
- Target is valid, attackable, and in range
- Spell is known, off cooldown, and resource is available
- Stance/form requirements are met
- PvE/PvP/defensive rules allow the action

When a gate fails, the rotation skips the action instead of forcing an invalid cast.

## Settings

Each spec provides configurable settings through the in-game menu:

- **Spell toggles** - Enable/disable individual abilities
- **Thresholds** - HP, rage, mana, energy thresholds for abilities
- **Cooldown control** - When to use offensive and defensive cooldowns
- **PvP options** - Interrupt behavior, CC usage, burst gates

## Testing

Run syntax checks:

```powershell
Get-ChildItem -Path EaxRotations -Recurse -Filter *.lua | ForEach-Object {
    luac -p $_.FullName
}
```

Run regression tests:

```powershell
Get-ChildItem EaxRotations\tests -Filter test_*.lua | ForEach-Object {
    lua $_.FullName
}
```

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines. Contributions should preserve the existing structure:

- Shared behavior in `shared/`
- Class-wide behavior in `classes/<class>/middleware_sylvanas.lua`
- Spec-specific priorities in `classes/<class>/<spec>_sylvanas.lua`
- Settings in `classes/<class>/schema_sylvanas.lua`

## License

[MIT](LICENSE)
