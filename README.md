# EAX — WoW TBC Classic Anniversary Rotations & AutoQuester

> **Rotation engine + questing automation for Project Sylvanas**  
> Targeting **TBC Classic Anniversary (2.5.5.x)** and **Vanilla Anniversary (1.15.x)**  
> Lua 5.1 / LuaJIT — 176 rotation test suites, 11 leveling suites, all green.

| Quality | TBC | Vanilla | Overall |
|---------|-----|---------|---------|
| **Score** | 4.6/5 (35 specs) | 3.9/5 (31 specs) | **4.3/5** |
| **S-Tier** | 23 | 0 | 23 |
| **A-Tier** | 9 | 29 | 38 |
| **B-Tier** | 3 | 2 | 5 |

> 📊 [Full Scorecard](SCORECARD.md) | 📖 [Rotation Guides](docs/rotations/README.md)

---

## 📦 What's in This Repo

| Product | Path | Description |
|---------|------|-------------|
| **EaxRotations** | `EaxRotations/` | 29 class specialization rotation plugins + shared engine |
| **EaxAutoQuester** | `EaxAutoQuester/` | Smart questing automation with navigation, NPC lookup, state machine |
| **Build Tools** | `build_tools/` | Python generator for spell/item data bridge from WoW client DBC |

---

## 🎯 EaxRotations

### What It Does

EaxRotations is a **priority-list rotation engine** for World of Warcraft: The Burning Crusade Classic Anniversary Edition (2.5.5.x client). It runs inside the **Project Sylvanas** addon framework and decides which spell to cast next, every frame, based on:

- **Combat state** (health, mana, rage, energy, combo points)
- **Buff/debuff status** (your buffs, target debuffs, via AuraCache)
- **Cooldown tracking** (spell CDs, trinkets, racial abilities)
- **Enemy analysis** (enemy count, melee pressure, casting interrupts)
- **Group context** (party/raid healing targets, tank assignment)

### Supported Classes & Specs

| Class | Specs (TBC) | Vanilla Variants | Guide |
|-------|-------------|------------------|-------|
| **Warrior** | Arms, Fury, Protection, Kebab | Arms, Fury, Protection, Kebab | [📖 Warrior](docs/rotations/warrior.md) |
| **Paladin** | Holy, Protection, Retribution | Holy, Protection, Retribution | [📖 Paladin](docs/rotations/paladin.md) |
| **Hunter** | Beast Mastery, Marksmanship, Survival | Beast Mastery, Marksmanship, Survival | [📖 Hunter](docs/rotations/hunter.md) |
| **Rogue** | Assassination, Combat, Subtlety | Assassination, Combat, Subtlety | [📖 Rogue](docs/rotations/rogue.md) |
| **Priest** | Holy, Discipline, Shadow, Smite | Holy, Discipline, Shadow, Smite | [📖 Priest](docs/rotations/priest.md) |
| **Mage** | Arcane, Fire, Frost | Arcane, Fire, Frost | [📖 Mage](docs/rotations/mage.md) |
| **Warlock** | Affliction, Demonology, Destruction | Affliction, Demonology, Destruction | [📖 Warlock](docs/rotations/warlock.md) |
| **Druid** | Balance, Feral Cat, Feral Bear, Restoration | Balance, Feral Cat, Feral Bear, Restoration, Caster | [📖 Druid](docs/rotations/druid.md) |
| **Shaman** | Elemental, Enhancement, Restoration | Elemental, Enhancement, Restoration | [📖 Shaman](docs/rotations/shaman.md) |

**Total: 29 TBC specs + 31 vanilla variants**

### Architecture

```
EaxRotations/
├── main_sylvanas.lua          # Dispatcher + registry
├── core_sylvanas.lua          # NS helpers (buff_points, spell_ready, etc.)
├── core/                      # Domain-extracted modules
│   ├── cooldowns.lua          # Cooldown tracker
│   ├── diagnostics.lua        # API health + debug
│   ├── items.lua              # Item data helpers
│   ├── settings.lua           # Menu middleware
│   └── units.lua              # Unit queries (friendly target, etc.)
├── classes/<class>/           # One spec file per specialization
│   └── <spec>_sylvanas.lua    # Flat file: spells → state → strategies → register
├── shared/                    # ~55 reusable modules
│   ├── healer_deficit_sylvanas.lua      # Predictive deficit tracker
│   ├── interrupt_manager_sylvanas.lua   # Interrupt + school lockout
│   ├── trinket_manager_sylvanas.lua     # Trinket usage
│   ├── pvp_burst_window_sylvanas.lua    # Burst detection
│   ├── enemy_count_hysteresis_sylvanas.lua  # Smooth enemy count
│   ├── stopcast_sylvanas.lua            # Smart in-flight cast cancellation
│   ├── pet_heal_sylvanas.lua            # Party/raid pet healing target scan
│   ├── snap_threat_sylvanas.lua         # Immediate threat on combat entry
│   ├── combat_mode_sylvanas.lua         # Force ST/AoE/Auto rotation mode
│   └── ...
└── tests/                     # 171 rotation suites + 11 leveling suites
    ├── run_rotation_tests.lua
    └── run_leveling_tests.lua
```

### Key Features

- **Slam Weaving** — Arms Warrior: swing-timer-aware Slam casting (0.5s cast, resets swing)
- **Seal Twisting** — Retribution Paladin: Blood/Martyr seal twist window tracking
- **Predictive Healing** — All healers: `HealerDeficit` estimates future HP using per-unit damage-rate sampling
- **Smart Stop-Cast** — Cancel in-flight heals when target recovers above threshold (all 5 healers)
- **Pet Healing** — Include Hunter/Warlock pets in healing target scan with configurable weight
- **Tank HP Bias** — Configurable triage priority for tanks and focus targets
- **Snap Threat** — Immediate Judgement/Shield Slam on combat entry (Prot Pally/Prot Warrior)
- **Combat Mode Override** — Force Single Target, AoE, or Auto-detect mode
- **Friendly-Target Healing** — All 5 healers: manual friendly target override with emergency-safe gating
- **Overheal Protection** — `gate_overheal` skips heals when incoming heals + shields cover deficit
- **AuraCache** — 50ms TTL buff/debuff cache to avoid per-frame API thrash
- **IZI SDK Integration** — `izi.spell(id):cast_safe(target)` for clean casting

### Data Sources

- **Spell data**: Extracted directly from WoW 2.5.5.68101 client DBC → `wowheadScrape/dbc_extract/wowsims.db` (28,650 spells)
- **Item data**: cMaNGOS extraction → `wowhead_data/lua/item_db.lua` (29,881 items)
- **Cross-verification**: lexxer.org API + Wowhead scrape as supplementary detail

### Testing

```cmd
# Requires Lua 5.1 (not 5.4!)
validate.cmd
```

**Current status:**
- 176 rotation suites: **PASS**
- 11 leveling suites: **PASS**
- Spell audit (all IDs verified against DBC): **PASS**

---

## 🗺️ EaxAutoQuester

### What It Does

EaxAutoQuester is a **smart questing automation system** for TBC/Vanilla WoW. It reads quest databases, navigates to objectives, interacts with NPCs, and manages quest state automatically.

### Features

- **Quest State Machine** — Idle → Interact → Navigate → Do Action → Wait → Dead → coordinator
- **NPC Database** — 18,799 NPCs with spawn points, drops, vendors (cMaNGOS sourced)
- **Navigation** — Pathfinding with chunk-based waypoint system
- **Loot Management** — Auto-loot with bag-full detection and vendor trips
- **Combat Helper** — Handles unexpected aggro during questing
- **Death Recovery** — Corpse run + resurrection automation
- **Safe API Wrapper** — Nil-guards all game API calls to prevent crashes

### Architecture

```
EaxAutoQuester/
├── main.lua                   # Entry point + dispatcher
├── menu_sylvanas.lua          # UI menu
├── quest_state_sylvanas.lua   # State machine coordinator
├── quest_state/               # Individual states
│   ├── idle_state.lua
│   ├── interact_state.lua
│   ├── nav_state.lua
│   ├── do_action_state.lua
│   ├── waiting_state.lua
│   └── dead_state.lua
├── npc_db_sylvanas.lua        # NPC database (18,799 entries)
├── npc_manager_sylvanas.lua   # NPC lookup + nearest finding
├── navigation_sylvanas.lua    # Pathfinding
├── loot_manager_sylvanas.lua  # Auto-loot + bag management
├── vendor_manager_sylvanas.lua # Vendor interactions
├── object_scanner.lua         # Game object detection
├── safe_api_wrapper.lua       # API crash prevention
└── tests/                     # Test suites (28 tests, 21 passing)
    └── run_quester_tests.lua
```

### Testing

```cmd
"C:\Program Files (x86)\Lua\5.1\lua.exe" EaxAutoQuester/tests/run_quester_tests.lua
```

**Current status:** 21/28 passing (7 known failures documented in `plans/cleanup_inventory.md`)

---

## 🔧 Build Tools

| Tool | Purpose |
|------|---------|
| `json_to_lua_data.py` | PRIMARY: wowhead_data + DBC → `wowhead_data_bridge_sylvanas.lua` |
| `build_spell_resolver.py` | LEGACY: lexxer.org spell ID table generator |
| `fetch_all_lexxer_data.py` | LEGACY: downloads vanilla spell/item indexes |
| `status_audit_index.json` | Build status tracker |

---

## 🚀 Installation

1. Clone this repo
2. Copy `EaxRotations/` into your Sylvanas addon folder
3. (Optional) Copy `EaxAutoQuester/` for questing automation
4. In-game: select your class + spec from the rotation menu

---

## 📋 Version History

| Version | Date | Highlights |
|---------|------|------------|
| v2026.06.28 | 2026-06-28 | FrostByte Supremacy Phase 1: Stop-Cast, Pet Healing, Tank Bias, Snap Threat, Combat Mode |
| v2026.06.25.23e5496d | 2026-06-25 | APL fixes: Fury, Destro, Ele, Assassination + repo cleanup |
| v2026.06.25.b2abdecf | 2026-06-25 | Repo cleanup (176 files removed), new README |
| v2026.06.25.f78f33fd | 2026-06-25 | Vanilla healers B6 + DEBUG filter |
| v2026.06.25.46d06a6b | 2026-06-25 | Friendly-target healing (all 5 healers) |
| v2026.06.25.014e81c7 | 2026-06-25 | Fury APL fix + repo cleanup |

See [GitHub Releases](https://github.com/eaxiumnet/eaxrotations/releases) for zips.

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
5. Run `validate.cmd`

### Coding Standards
- Pattern 14: nil-guard ALL numeric state comparisons (`(state.rage or 0) < 25`)
- Pattern 15: every file has a What/When/Why/Safety header
- Squared distances: `dx*dx + dy*dy < 100` (never `math.sqrt`)
- Static table reuse in tight loops
- No banned APIs: `ffi.C`, `io.popen`, `os.execute`, `debug.*`

---

## 📄 License

This project is proprietary. All rights reserved.

---

## 🤝 Credits

- **Spell data**: WoW 2.5.5.68101 client DBC extraction
- **Item/NPC data**: cMaNGOS open-source database
- **Guide references**: Wowhead, IcyVeins, SimulationCraft APLs
- **Framework**: Project Sylvanas API

---

*Built with obsessive attention to frame-budget performance and nil-safety.*
