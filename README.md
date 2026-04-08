# EAX TBC Classic Rotations

**Automated rotation plugins for World of Warcraft: The Burning Crusade Classic**

[![Version](https://img.shields.io/badge/version-1.0.0-blue.svg)](CHANGELOG.md)
[![Specs](https://img.shields.io/badge/specs-29-green.svg)](#available-specs)
[![Platform](https://img.shields.io/badge/platform-Sylvanas-orange.svg)](https://github.com/Dreamslash/sylvanas)

## Overview

EAX provides 29 specialized rotation plugins for TBC Classic, covering all classes and specializations. Each plugin delivers optimized spell/ability sequencing for maximum DPS, healing, or tanking performance.

## Available Specs

| Class | Specs | Status |
|-------|-------|--------|
| **Druid** | Balance, Bear, Feral, Restoration | ✅ Complete |
| **Hunter** | Beast Mastery, Marksmanship, Survival | ✅ Complete |
| **Mage** | Arcane, Fire, Frost | ✅ Complete |
| **Paladin** | Holy, Protection, Retribution | ✅ Complete |
| **Priest** | Discipline, Holy, Shadow, Smite | ✅ Complete |
| **Rogue** | Assassination, Combat, Subtlety | ✅ Complete |
| **Shaman** | Elemental, Enhancement, Restoration | ✅ Complete |
| **Warlock** | Affliction, Demonology, Destruction | ✅ Complete |
| **Warrior** | Arms, Fury, Protection | ✅ Complete |

## Features

- 🎯 **Optimized Rotations** - TBC-accurate spell priorities based on simulation data
- ⚡ **Real-time Decision Making** - Dynamic ability selection based on combat context
- 🛡️ **Defensive Management** - Automatic cooldown usage for survivability
- 🔥 **Burst & Cooldowns** - Intelligent timing of major abilities
- 📊 **PvP Support** - Detection and rotation adjustments for player combat
- 🎮 **Sylvanas Integration** - Native support for Project Sylvanas platform

## Installation

1. Download the latest release from [Releases](https://github.com/eaxiumnet/eax-tbc-classic-rotations/releases)
2. Extract to your Sylvanas rotations folder
3. Select your spec in the Sylvanas UI
4. Configure settings via the in-game menu

## Project Structure

```
EAX<Class><Spec>/
├── main.lua              # Core rotation engine
├── header.lua            # Plugin metadata & validation
├── plugin_info.lua       # Load configuration
└── libraries/
    ├── spells.lua        # Spell ID tables
    ├── utils.lua         # Helper functions
    ├── menu.lua          # Settings UI
    └── ...
```

## Configuration

Each spec includes customizable settings:
- **Mode**: Auto / PvE / PvP
- **Cooldown Usage**: Defensive / Offensive / All
- **Healing Thresholds**: Health % for emergency heals
- **Utility Options**: Buffs, dispels, interrupts

Access settings via the Sylvanas menu system (`/sylvanas` or keybind).

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for version history and detailed changes.

## Requirements

- World of Warcraft: The Burning Crusade Classic
- [Project Sylvanas](https://github.com/Dreamslash/sylvanas) runtime

## Author

**Eax** - [@eaxiumnet](https://github.com/eaxiumnet)

## License

This project is proprietary software. All rights reserved.

---

<p align="center">
  <sub>Built with precision for TBC Classic</sub>
</p>
