<h1 align="center">
  ⚔️ EAX — TBC Classic Anniversary Rotations & AutoQuester
</h1>
<p align="center">
  <strong>Rotation engine + questing automation for <a href="https://github.com/aicore/sylvanas">Project Sylvanas</a></strong>
</p>
<p align="center">
  <img src="https://img.shields.io/badge/TBC%20Specs-29-brightgreen" alt="29 TBC Specs">
  <img src="https://img.shields.io/badge/Rotation%20Tests-373%2F373%20passing-success" alt="373 Tests Passing">
  <img src="https://img.shields.io/badge/Leveling%20Tests-21%2F21%20passing-success" alt="21 Leveling Tests Passing">
  <img src="https://img.shields.io/badge/license-CC--BY--4.0%20(EaxRotations)-lightgrey" alt="CC-BY-4.0">
</p>

---

## 📦 What's in This Repo

| Product | Path | Description |
|---------|------|-------------|
| **EaxRotations** | `EaxRotations/` | 29 TBC spec rotation plugins + shared combat engine |
| **EaxAutoQuester** | `EaxAutoQuester/` | Smart questing automation with navigation & NPC lookup |
| **Build Tools** | `build_tools/` | Python pipeline for spell/item data from WoW client DBC |

---

## 🎯 EaxRotations

### What It Does

EaxRotations is a **priority-list rotation engine** for World of Warcraft: The Burning Crusade Classic Anniversary Edition (**2.5.5.x client**). It runs inside the **Project Sylvanas** addon framework and decides which spell to cast next, every frame, based on:

- **Combat state** — health, mana, rage, energy, combo points
- **Buff/debuff status** — your buffs, target debuffs (via AuraCache)
- **Cooldown tracking** — spell CDs, trinkets, racial abilities
- **Enemy analysis** — enemy count, melee pressure, casting interrupts
- **Group context** — party/raid healing targets, tank assignment

### Supported Classes & Specs

| Class | TBC Specs | Vanilla Variants |
|:-----:|:---------:|:----------------:|
| 🛡️ **Warrior** | Arms, Fury, Protection, Kebab | Arms, Fury, Protection, Kebab |
| ⚡ **Paladin** | Holy, Protection, Retribution | Holy, Protection, Retribution |
| 🏹 **Hunter** | Beast Mastery, Marksmanship, Survival | Beast Mastery, Marksmanship, Survival |
| 🗡️ **Rogue** | Assassination, Combat, Subtlety | Assassination, Combat, Subtlety |
| ✝️ **Priest** | Discipline, Holy, Shadow, Smite | Discipline, Holy, Shadow, Smite |
| 🔮 **Mage** | Arcane, Fire, Frost | Arcane, Fire, Frost |
| 👹 **Warlock** | Affliction, Demonology, Destruction | Affliction, Demonology, Destruction |
| 🐻 **Druid** | Balance, Feral Cat, Feral Bear, Restoration | Balance, Feral Cat, Feral Bear, Restoration, Caster |
| 🌩️ **Shaman** | Elemental, Enhancement, Restoration | Elemental, Enhancement, Restoration |

**Total: 29 TBC specs + 2 adjunct (Caster, Kebab) + 9 leveling rotations**

### Architecture

```
EaxRotations/
├── header.lua              # Plugin metadata, class detection
├── main.lua                # Bootstrap, loads shared framework
├── core_sylvanas.lua       # NS.* helpers, API wrappers, spell casting
├── main_sylvanas.lua       # Update dispatcher, context building
├── core/                   # Domain-extracted modules
│   ├── strategy_gating.lua # Single source of truth for strategy categories
│   ├── cooldowns.lua       # Cooldown tracker
│   ├── diagnostics.lua     # API health + debug
│   ├── items.lua           # Item data helpers
│   ├── settings.lua        # Menu middleware
│   └── units.lua           # Unit queries
├── classes/<class>/
│   ├── <spec>_sylvanas.lua     # Flat file: spells → state → strategies → register
│   ├── middleware_sylvanas.lua # Class-wide behavior (defensives, interrupts)
│   ├── schema_sylvanas.lua     # Settings UI
│   └── leveling_sylvanas.lua   # Leveling rotation
├── shared/                 # ~50 reusable combat modules
│   ├── interrupt_manager_sylvanas.lua
│   ├── consumable_manager_sylvanas.lua
│   ├── trinket_manager_sylvanas.lua
│   ├── arena_priority_sylvanas.lua
│   ├── healer_engine_sylvanas.lua
│   ├── burst_logic_sylvanas.lua
│   └── ... (50+ modules)    └── tests/                  # 373 rotation suites + 21 leveling suites
    ├── run_rotation_tests.lua
    └── run_leveling_tests.lua
```

### Key Features

| Feature | Description |
|---------|-------------|
| **Slam Weaving** | Arms Warrior: swing-timer-aware Slam casting |
| **Seal Twisting** | Retribution Paladin: Blood/Martyr seal twist window tracking |
| **Predictive Healing** | All healers: `HealerDeficit` estimates future HP using damage-rate sampling |
| **Smart Stop-Cast** | Cancel in-flight heals when target recovers above threshold |
| **Pet Healing** | Include Hunter/Warlock pets in healing target scan |
| **Tank HP Bias** | Configurable triage priority for tanks and focus targets |
| **Snap Threat** | Immediate Judgement/Shield Slam on combat entry |
| **Combat Mode Override** | Force Single Target, AoE, or Auto-detect mode |
| **Friendly-Target Healing** | Manual friendly target override with emergency-safe gating |
| **Overheal Protection** | `gate_overheal` skips heals when incoming heals cover deficit |
| **AuraCache** | 50ms TTL buff/debuff cache to avoid per-frame API thrash |
| **Berserker Rage Break** | Warrior: auto-casts on fear, sap, incapacitate (v2.2.1) |
| **Strategy Gating Deduplication** | Single `core/strategy_gating.lua` source of truth (v2.2.0) |
| **Enemy Cache** | Multi-range per-tick cache eliminates cache thrashing (v2.2.0) |
| **Buff Rank Upgrades** | Auto-detects and refreshes lower-rank party buffs (v2.1.0) |

### Data Sources

- **Spell data**: Extracted directly from WoW **2.5.5.68101 client DBC** → `wowheadScrape/dbc_extract/wowsims.db` (28,650 spells)
- **Item data**: cMaNGOS extraction → `wowhead_data/lua/item_db.lua` (29,881 items)
- **Cross-verification**: lexxer.org API + Wowhead scrape as supplementary detail

### Testing

```bash
# Requires Lua 5.1 (not 5.4!)
# Syntax check all Lua files
find EaxRotations -name "*.lua" -exec luac -p {} \;

# Run rotation test suite (373 suites)
lua EaxRotations/tests/run_rotation_tests.lua

# Run leveling test suite (21 suites)
lua EaxRotations/tests/run_leveling_tests.lua
```

**Current status:**
- 🟢 373 rotation suites: **PASS**
- 🟢 21 leveling suites: **PASS**
- 🟢 Spell audit (all IDs verified against DBC): **PASS**

---

## 🗺️ EaxAutoQuester

### What It Does

EaxAutoQuester is a **smart questing automation system** for TBC/Vanilla WoW. It reads quest databases, navigates to objectives, interacts with NPCs, and manages quest state automatically.

### Features

- **Quest State Machine** — Idle → Interact → Navigate → Do Action → Wait → Dead
- **NPC Database** — 18,799 NPCs with spawn points, drops, vendors (cMaNGOS sourced)
- **Navigation** — Pathfinding with chunk-based waypoint system
- **Loot Management** — Auto-loot with bag-full detection and vendor trips
- **Combat Helper** — Handles unexpected aggro during questing
- **Death Recovery** — Corpse run + resurrection automation
- **Safe API Wrapper** — Nil-guards all game API calls to prevent crashes

### Testing

```bash
lua EaxAutoQuester/tests/run_quester_tests.lua
```

**Current status:** 37/37 passing (`lua EaxAutoQuester/tests/run_quester_tests.lua`)

---

## 🔧 Build Tools

| Tool | Purpose |
|------|---------|
| `json_to_lua_data.py` | **PRIMARY**: wowhead_data + DBC → `wowhead_data_bridge_sylvanas.lua` |
| `convert_db_to_lua_v4.py` | DBC SQLite → verified Lua spell/item tables |
| `build_spell_resolver.py` | LEGACY: lexxer.org spell ID table generator |
| `fetch_all_lexxer_data.py` | LEGACY: downloads vanilla spell/item indexes |

---

## 🚀 Installation

1. Clone this repo
2. Copy `EaxRotations/` into your Sylvanas addon folder
3. (Optional) Copy `EaxAutoQuester/` for questing automation
4. In-game: select your class + spec from the rotation menu

---

## 📋 Release History

| Version | Date | Highlights |
|:-------:|:----:|:-----------|
| **v2.2.1** | 2026-06-29 | Warrior fear break (Berserker Rage auto-cast), Arms polish |
| **v2.2.0** | 2026-06-27 | Strategy gating dedup, perf hardening (enemy cache, immunity cache, item cache), critical bug fixes |
| **v2.1.0** | 2026-06-06 | Debug cleanup, buff rank upgrade system, spell ID corrections, APL registry bridge |
| **v1.1.0** | 2026-05-26 | Healing engine verified, debug log fixes, core action_execute routing fix |
| **v1.0.0** | 2026-05-15 | Initial release |

---

## 🏗️ Development

### Requirements
- **Lua 5.1.5** (NOT 5.4 — tests will silently fail)
- Python 3.x (for build_tools)
- SQLite3 (for DBC verification)

### Adding a New Spec
1. Copy `EaxRotations/classes/warrior/arms_sylvanas.lua` as template
2. Replace spell tables, buff IDs, strategy priorities
3. Add test in `EaxRotations/tests/`
4. Register in `run_rotation_tests.lua`
5. Run `luac -p` on all changed files + full test suite

### Coding Standards (AGENTS.md)
- **Pattern 14**: nil-guard ALL numeric state comparisons — `(state.rage or 0) < 25`
- **Pattern 15**: every file has a What/When/Why/Safety header
- Squared distances: `dx*dx + dy*dy < 100` (never `math.sqrt`)
- Static table reuse in tight loops (`{ n = 0 }`)
- No banned APIs: `ffi.C`, `io.popen`, `os.execute`, `debug.*`

---

## 📄 License

- **EaxRotations** (`EaxRotations/`): [CC-BY-4.0](EaxRotations/LICENSE) — free to use, modify, and distribute with attribution
- **EaxAutoQuester** (`EaxAutoQuester/`): Proprietary — all rights reserved

---

## 🤝 Credits

- **Spell data**: WoW 2.5.5.68101 client DBC extraction
- **Item/NPC data**: cMaNGOS open-source database
- **Guide references**: Wowhead, IcyVeins, SimulationCraft APLs
- **Framework**: Project Sylvanas API

---

<p align="center">
  <em>Built with obsessive attention to frame-budget performance and nil-safety.</em>
</p>
