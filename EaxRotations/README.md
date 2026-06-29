<h1 align="center">
  ⚔️ EaxRotations
</h1>
<p align="center">
  <strong>TBC Classic Anniversary rotation framework for <a href="https://github.com/aicore/sylvanas">Project Sylvanas</a></strong>
</p>
<p align="center">
  <img src="https://img.shields.io/badge/version-2.2.2-blue" alt="Version 2.2.2">
  <img src="https://img.shields.io/badge/specs-29%20%2B%209%20leveling-brightgreen" alt="29 Specs + 9 Leveling">
  <img src="https://img.shields.io/badge/tests-208%2F208%20passing-success" alt="208/208 Tests Passing">
  <img src="https://img.shields.io/badge/license-CC--BY--4.0-lightgrey" alt="CC-BY-4.0">
</p>

---

## 🚀 What Is This?

**EaxRotations** is a comprehensive rotation automation framework for **World of Warcraft: The Burning Crusade Classic Anniversary** (client 2.5.5.x). It covers all **9 classes** across **29 specializations** plus **9 leveling rotations**, built on a shared combat engine with defensive middleware, role-aware settings, and full regression tests.

Every action passes shared safety gates before casting:
- ✅ Player exists, is alive, and can act
- ✅ Target is valid, attackable, and in range
- ✅ Spell is known, off cooldown, and affordable
- ✅ Stance / form requirements are met
- ✅ PvE / PvP / defensive rules allow the action

> **"First successful action wins"** — predictable, safe, and fast.

---

## 📦 Installation

1. Download or clone this repository
2. Copy the `EaxRotations` folder into your Project Sylvanas `scripts/` directory
3. Restart Project Sylvanas or reload the UI
4. Select your spec from the plugin menu — the loader auto-detects your class

```
scripts/
  EaxRotations/
    header.lua              # Plugin metadata & class detection
    main.lua                # Bootstrap entry
    core_sylvanas.lua       # Runtime boundary & NS.* helpers
    main_sylvanas.lua       # Update dispatcher
    classes/                # Per-class rotation modules
    shared/                 # ~50 reusable combat modules
    tests/                  # 208 regression test suites
```

---

## 🛡️ Supported Classes & Specs

| Class | Specs | Roles |
|:-----:|:-----:|:-----:|
| 🐻 **Druid** | Balance, Bear, Feral Cat, Restoration | Ranged DPS, Tank, Melee DPS, Healer |
| 🏹 **Hunter** | Beast Mastery, Marksmanship, Survival | Ranged DPS, Pet Utility |
| 🔮 **Mage** | Arcane, Fire, Frost | Ranged DPS, Interrupts, CC |
| ⚡ **Paladin** | Holy, Protection, Retribution | Healer, Tank, Melee DPS |
| ✝️ **Priest** | Discipline, Holy, Shadow, Smite | Healer, Shielding, Ranged DPS |
| 🗡️ **Rogue** | Assassination, Combat, Subtlety | Melee DPS, Control, Interrupts |
| 🌩️ **Shaman** | Elemental, Enhancement, Restoration | Ranged DPS, Melee DPS, Healer |
| 👹 **Warlock** | Affliction, Demonology, Destruction | Ranged DPS, Pet Utility, Curses |
| 🛡️ **Warrior** | Arms, Fury, Protection | Melee DPS, Tank, PvP Utility |

**Plus:** 9 leveling rotations (one per class) + 2 adjunct specs (Druid Caster, Warrior Kebab)

---

## ✨ Features

| Feature | Description |
|---------|-------------|
| 🎯 **29 Spec Rotations** | 20–40+ strategy entries per spec covering openers, AoE, execute, and defensives |
| 📈 **9 Leveling Rotations** | Auto-loaded for characters under level 70 |
| ⚔️ **PvP Support** | DR tracking, enemy CD monitoring, burst window detection, arena priority |
| 🛡️ **Defensive Middleware** | Auto healthstones, potions, and class-specific defensive CDs |
| ⚙️ **Role-Aware Settings** | PvE / PvP modes with customizable thresholds per spec |
| 🧪 **208 Regression Tests** | All rotation + leveling suites pass with zero failures |
| ⚡ **Performance-Focused** | Cached API calls, squared-distance checks, sub-20ms strategy evaluation |
| 🧠 **Smart Buff Upgrades** | Auto-detects and refreshes lower-rank party buffs |
| 🏥 **Healer Engine** | Predictive triage, overheal avoidance, tank bias, shield tracking |

---

## 🏗️ Architecture

```
EaxRotations/
├── header.lua              # Plugin metadata, class detection
├── main.lua                # Bootstrap, loads shared framework
├── core_sylvanas.lua       # NS.* helpers, API wrappers, spell casting
├── main_sylvanas.lua       # Update dispatcher, context building
├── common_sylvanas.lua     # Shared UI sections
├── helpers_sylvanas.lua    # Helper aliases
│
├── classes/<class>/
│   ├── class_sylvanas.lua        # Class registration, spell objects
│   ├── middleware_sylvanas.lua   # Class-wide behavior (defensives, interrupts)
│   ├── schema_sylvanas.lua       # Settings UI
│   ├── leveling_sylvanas.lua     # Leveling rotation
│   └── <spec>_sylvanas.lua       # TBC spec rotation
│
├── shared/                 # ~50 reusable combat modules
│   ├── interrupt_manager_sylvanas.lua
│   ├── consumable_manager_sylvanas.lua
│   ├── racial_manager_sylvanas.lua
│   ├── trinket_manager_sylvanas.lua
│   ├── dot_refresh_sylvanas.lua
│   ├── burst_logic_sylvanas.lua
│   ├── arena_priority_sylvanas.lua
│   ├── healer_engine_sylvanas.lua
│   └── ... (50+ modules)
│
└── tests/                  # Regression test suite
    ├── run_rotation_tests.lua    # 208 rotation suites
    ├── run_leveling_tests.lua    # 11 leveling suites
    └── test_*.lua                # Individual test files
```

---

## 🧪 Testing

Run syntax checks on all Lua files:

```bash
find EaxRotations -name "*.lua" -exec luac -p {} \;
```

Run the full rotation regression suite (**208 suites**):

```bash
lua EaxRotations/tests/run_rotation_tests.lua
```

Run the leveling test suite (**11 suites**):

```bash
lua EaxRotations/tests/run_leveling_tests.lua
```

Run a specific test file:

```bash
lua EaxRotations/tests/test_fury_custom_matches.lua
```

---

## 📋 Release History

| Phase | Date | Highlights |
|:-----:|:----:|:-----------|
| **Phase 1** | Jun 2026 | Healer Supremacy — predictive triage, tank bias, shield tracking, fade/dispel |
| **Phase 2** | Jun 2026 | Tank & Melee Supremacy — JoW swap, post-swing judge, totem twist, smart shield |
| **Phase 3** | Jun 2026 | Ranged & Caster Supremacy — MultiDoT, TTD gating, shot timer, melee weave |
| **Phase 4** | Jun 2026 | Warrior & Polish — stance dance, rage dump, healthstone parity, strategy gating dedup |

See [CHANGELOG.md](CHANGELOG.md) for the full release history.

---

## 🤝 Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

Quick rules:
- Shared behavior → `shared/`
- Class-wide behavior → `classes/<class>/middleware_sylvanas.lua`
- Spec priorities → `classes/<class>/<spec>_sylvanas.lua`
- Settings → `classes/<class>/schema_sylvanas.lua`

All contributions must pass `luac -p` and the full test suite.

---

## 📖 Documentation

| Document | What You'll Find |
|----------|-----------------|
| [CHANGELOG.md](CHANGELOG.md) | Full release history with bug fixes, features, and perf wins |
| [CONTRIBUTING.md](CONTRIBUTING.md) | Code style, conventions, and how to submit changes |
| [docs/TECHNICAL_GUIDE.md](docs/TECHNICAL_GUIDE.md) | Boot sequence, tick trace, runtime boundary, all 40 playstyles |
| [docs/API_ADOPTION_ANALYSIS.md](docs/API_ADOPTION_ANALYSIS.md) | API compliance audit and adoption status |

---

## 📝 License

[CC-BY-4.0](LICENSE) — You are free to use, modify, and distribute this software for any purpose, including commercial use, provided you give appropriate credit to the original author.

---

<p align="center">
  Built for <a href="https://github.com/aicore/sylvanas"><strong>Project Sylvanas</strong></a> — TBC Classic automation framework
</p>
