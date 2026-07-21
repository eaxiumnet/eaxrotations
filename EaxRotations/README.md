<h1 align="center">
  EaxRotations
</h1>
<p align="center">
  <strong>TBC Classic Anniversary rotation framework for <a href="https://github.com/aicore/sylvanas">Project Sylvanas</a></strong>
</p>
<p align="center">
  <img src="https://img.shields.io/badge/version-2.10.0-blue" alt="Version 2.10.0">
  <img src="https://img.shields.io/badge/specs-29%20%2B%2013%20leveling-brightgreen" alt="29 Specs + 13 Leveling">
  <img src="https://img.shields.io/badge/tests-342%2F342%20passing-success" alt="346/346 Tests Passing">
  <img src="https://img.shields.io/badge/license-CC--BY--4.0-lightgrey" alt="CC-BY-4.0">
</p>

---

## What Is This?

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
    tests/                  # 346 regression test suites
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
| 🧪 **346 Regression Tests** | All rotation + leveling suites pass with zero failures |
| ⚡ **Performance-Focused** | Cached API calls, squared-distance checks, sub-20ms strategy evaluation |
| 🧠 **Smart Buff Upgrades** | Auto-detects and refreshes lower-rank party buffs |
| 🏥 **Healer Engine** | Predictive triage, overheal avoidance, tank bias, shield tracking |
| 💰 **Auto-Loot** | Background corpse looting with humanized timing, combat awareness, and bag safety |

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
    ├── run_rotation_tests.lua    # 346 rotation suites
    ├── run_leveling_tests.lua    # 21 leveling suites
    └── test_*.lua                # Individual test files
```

---

## 📖 How to Read a Spec (for Contributors)

Every spec file follows the same 9-part layout. Start with the **reference implementation**:

> **`classes/warrior/arms_sylvanas.lua`** — the first spec converted to the canonical template.

### The 9-part spec structure

| Part | What | Why |
|------|------|-----|
| 1. Header | Pattern 15 `WHAT/WHEN/WHY/SAFETY` comment block | Understand the file without reading it all |
| 2. NS guard | `local NS = _G.EaxRotations; if not NS then return nil end` | Safe no-op when engine isn't loaded (unit tests) |
| 3. spec_kit + requires | `require("shared/spec_kit_sylvanas")` + shared modules | Centralized action resolver + nil-guard proxy |
| 4. ACTION table | `spec_kit.define_action_for_class(SPELLS)` | One spell resolver, not 29 copy-pasted helpers |
| 5. ID tables | Buff/debuff spell-ID lists + constants | TBC spell rank chains |
| 6. build_state | `local function build_state(context)` then `spec_kit.safe_state(raw)` | Compute per-tick state once; nil-guarded reads |
| 7. Match functions | `local function x_matches(context, state)` | One per strategy — returns true/false |
| 8. strategies | `{ name=, matches=, execute= }` ordered list | Dispatcher runs first match that returns true |
| 9. Register + return | Guarded `NS.rotation_registry:register(...)` + `return strategies` | Nil-safe registration + test-consumable return |

See `AGENTS.md` Pattern 16 for the full annotated skeleton.

### Migration state (spec_kit adoption)

| Status | Files | Count |
|--------|-------|-------|
| Converted | `arms_sylvanas.lua`, `fury_sylvanas.lua`, `protection_sylvanas.lua`, `kebab_sylvanas.lua`, `balance_sylvanas.lua`, `cat_sylvanas.lua`, `bear_sylvanas.lua`, `caster_sylvanas.lua`, `resto_sylvanas.lua`, `discipline_sylvanas.lua`, `holy_sylvanas.lua`, `shadow_sylvanas.lua`, `smite_sylvanas.lua`, `fire_sylvanas.lua`, `destruction_sylvanas.lua`, `frost_sylvanas.lua`, `restoration_sylvanas.lua`, `affliction_sylvanas.lua`, `combat_sylvanas.lua`, `demonology_sylvanas.lua`, `elemental_sylvanas.lua`, `enhancement_sylvanas.lua`, `assassination_sylvanas.lua`, `marksmanship_sylvanas.lua`, `retribution_sylvanas.lua`, `subtlety_sylvanas.lua`, `survival_sylvanas.lua`, `beast_mastery_sylvanas.lua`, `arcane_sylvanas.lua` | 31 |
| Pending | 9 leveling files + 1 adjunct (`healing_sylvanas.lua`) | 10 |

> Enforced by `tests/test_spec_layout_compliance.lua`. To mark a spec as converted, add it to the `CONVERTED` table in that test after conversion + full test gate.
> Convert a spec **only when already editing it** — never big-bang (AGENTS.md Pattern 16).

---

## 🧪 Testing

Run syntax checks on all Lua files:

```bash
find EaxRotations -name "*.lua" -exec luac -p {} \;
```

Run the full rotation regression suite (**346 suites**):

```bash
lua EaxRotations/tests/run_rotation_tests.lua
```

Run the leveling test suite (**21 suites**):

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
