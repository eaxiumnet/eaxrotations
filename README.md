# EaxRotations

WoW TBC Classic rotation plugins for **Project Sylvanas** — built and tested against the
**TBC Classic Anniversary (2.5.5.x)** client.

## Features

- 29 TBC Classic specializations (all classes), one self-contained `_sylvanas.lua` file per spec
- Priority-list strategy engines with per-strategy unit-test coverage
- Shared module library: interrupts, consumables, cooldown planners, hit-cap tracking,
  trinket manager, aspect/stance handlers and more
- Nil-guarded menus and API calls — no crashes on missing settings
- 400+ rotation unit-test suites plus leveling suites, runnable with a stock Lua 5.1 interpreter

## Requirements

- Project Sylvanas client for TBC Classic Anniversary (2.5.5.x)

## Installation

1. Copy the `EaxRotations` folder into the rotations/plugin folder of your Project
   Sylvanas setup.
2. Enable the rotation in-game.

## Repository layout

```
EaxRotations/
├── main_sylvanas.lua          # Main rotation engine / dispatcher
├── core_sylvanas.lua          # Shared helpers (buff points, readiness, cooldowns, targets)
├── classes/<class>/           # One _sylvanas.lua file per spec (29 total)
├── shared/                    # Cross-class modules
└── tests/                     # Unit-test suites
```

## Development

```bash
luac -p EaxRotations/classes/hunter/beast_mastery_sylvanas.lua
lua EaxRotations/tests/run_rotation_tests.lua
lua EaxRotations/tests/run_leveling_tests.lua
```

## Notes

Spell data is validated against the 2.5.5.x client spell database. A few Wrath-era
spells were backported into the Anniversary client (e.g. Ice Lance, Seal of Blood)
and are intentionally supported.
