<h1 align="center">
  EaxRotations
</h1>
<p align="center">
  <strong>TBC Classic Anniversary rotation framework for <a href="https://github.com/aicore/sylvanas">Project Sylvanas</a></strong>
</p>
<p align="center">
  <img src="https://img.shields.io/badge/version-2.26.2-blue" alt="Version 2.26.2">
  <img src="https://img.shields.io/badge/specs-172%20rated%20(5%20eras)-brightgreen" alt="172 Specs Rated Across 5 Eras (live-gated)">
  <img src="https://img.shields.io/badge/tests-588%2F588%20passing-brightgreen" alt="588/588 Tests Passing (rotation suite fully green)">
  <img src="https://img.shields.io/badge/license-CC--BY--4.0-lightgrey" alt="CC-BY-4.0">
</p>

---

## What Is This?

**EaxRotations** is a comprehensive rotation automation framework for **World of Warcraft** on Project Sylvanas: **TBC Classic Anniversary**, **WotLK**, **Vanilla (Classic)**, **Season of Discovery** and **WoW Forever**. Across the 5 eras it ships **172 rated spec rotations** (31 TBC · 41 WotLK · 40 Vanilla · 20 SoD · 40 Forever), plus class leveling rotations, built on one shared combat engine and safety middleware. Every spec is behavior-verified by a **588-suite release battery** with zero unreachable rules — see [docs/ACCURACY.md](docs/ACCURACY.md), the player-facing accuracy report regenerated and gate-checked on every release.

Every action passes shared safety gates before casting:
- ✅ Player exists, is alive, and can act
- ✅ Target is valid, attackable, and in range
- ✅ Spell is known, off cooldown, and affordable
- ✅ Stance / form requirements are met
- ✅ PvE / PvP / defensive rules allow the action

> **"First successful action wins"** — predictable, safe, and fast.

---

## Season of Discovery Support

SoD is an explicit runtime mode. It selects only the native `_sod.lua` modules, exposes normalized phase and rune context, and fails closed when optional rune or phase data is missing. Existing TBC, Vanilla, and WotLK modes retain their own loader paths.

The complete 20-rotation inventory, source package mapping, pinned simulator commit, local client/DBC path, and refresh/audit procedure are maintained in [docs/SOD_ROTATIONS.md](docs/SOD_ROTATIONS.md).

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
    tests/                  # 627 test suites (588 rotation + 39 leveling)
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
| 🎯 **172 Rated Spec Rotations** | 5 eras, every decision rule exercised by the release battery (0 unreachable rules) |
| 📈 **9 Leveling Rotations** | Auto-loaded for characters under level 70 |
| ⚔️ **PvP Support** | DR tracking, enemy CD monitoring, burst window detection, arena priority |
| 🛡️ **Defensive Middleware** | Auto healthstones, potions, and class-specific defensive CDs |
| ⚙️ **Role-Aware Settings** | PvE / PvP modes with customizable thresholds per spec |
| 🧪 **627 Test Suites** | 588 rotation + 39 leveling registered; 588 rotation passing at runtime (all rotation suites green incl. the 3 `check_*` static-analysis audits; `test_sod_source_audit` self-provisions its `.omo/evidence` via the tracked generator) |
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
    ├── run_rotation_tests.lua    # 588 rotation suites
    ├── run_leveling_tests.lua    # 39 leveling suites
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

### Migration state (spec_kit adoption)

**✅ ALL 9 CLASSES FULLY MIGRATED (2026-07-29)** — All 29 sylvanas spec files + all 40 vanilla spec files now use `spec_kit.safe_state()` for structural Pattern 14 nil-guard enforcement.

| Status | Scope | Files | Count |
|--------|-------|-------|-------|
| ✅ Done | Sylvanas spec files (TBC + leveling + adjuncts) | All `*_sylvanas.lua` spec files | 31 |
| ✅ Done | Vanilla spec files (all 9 classes) | All `*_vanilla.lua` spec files | 40 |
| ✅ Done | WotLK spec files (all 9 classes) | All `*_wotlk.lua` spec files | ~20 |
| **Total** | | | **~91** |

Each vanilla file now has a `<SPEC>_VANILLA_SCHEMA` table with Pattern 14 nil-guard defaults and wraps all `build_state` return paths (including cache-hit early returns) in `spec_kit.safe_state(state, SCHEMA)`.

> Enforced by `tests/test_spec_layout_compliance.lua`. To mark a spec as converted, add it to the `CONVERTED` table in that test after conversion + full test gate.
> Convert a spec **only when already editing it** — never big-bang.

---

## 🧪 Testing

Run syntax checks on all Lua files:

```bash
find EaxRotations -name "*.lua" -exec luac -p {} \;
```

Run the full rotation regression suite (**588 suites**):

```bash
lua EaxRotations/tests/run_rotation_tests.lua
```

Run the leveling test suite (**39 suites**):

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

> ⚠️ *Claim precision:* the phase titles above are marketing shorthand, not measured rankings. What is actually **measured**: spec cast order is sim-conformant against pinned wowsims APLs — **50/50** pinned specs pass, computed live by `tools/apl_status.lua` (see `docs/scorecard.md` and the plain-language `docs/ACCURACY.md`), **including WotLK holy/disc priest** — wowsims/wotlk has a real, executed healing-priest sim (`sim/priest/healing/healing_priest_test.go` runs `TestDisc`/`TestHoly` with `IsHealer: true` against its APL JSONs, now pinned here). The remaining healers (holy paladin, resto druid/shaman, TBC-era) are validated **internally** (behavioral battery never=0 + regression suites) — those wowsims trees carry engine scaffolding but no implemented rotation, so there is no comparative benchmark for them in or out of this repo. See `docs/scorecard.md` "Why some healer rows show APL = `pending`" for the full rationale.

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
| [docs/ACCURACY.md](docs/ACCURACY.md) | Player-facing accuracy report — what every spec is proven to do, live-gated |
| [docs/DEBUGGING_TRACE_CASTS.md](docs/DEBUGGING_TRACE_CASTS.md) | Debugging guide for the Trace Casts diagnostics — how to read why a spell did (not) fire |
| [docs/PER_CLASS_RESEARCH.md](docs/PER_CLASS_RESEARCH.md) | Per-class research provenance, mechanic-by-mechanic code verification, and the honest limits |
| [CHANGELOG.md](CHANGELOG.md) | Full release history with bug fixes, features, and perf wins |
| [CONTRIBUTING.md](CONTRIBUTING.md) | Code style, conventions, and how to submit changes |
| [docs/TECHNICAL_GUIDE.md](docs/TECHNICAL_GUIDE.md) | Boot sequence, tick trace, runtime boundary, legacy and SoD playstyles |
| [docs/SOD_ROTATIONS.md](docs/SOD_ROTATIONS.md) | SoD rotation inventory, runtime behavior, and source provenance |
| [docs/API_ADOPTION_ANALYSIS.md](docs/API_ADOPTION_ANALYSIS.md) | API compliance audit and adoption status |

---

## 📝 License

[CC-BY-4.0](LICENSE) — You are free to use, modify, and distribute this software for any purpose, including commercial use, provided you give appropriate credit to the original author.

---

<p align="center">
  Built for <a href="https://github.com/aicore/sylvanas"><strong>Project Sylvanas</strong></a> — TBC Classic automation framework
</p>
