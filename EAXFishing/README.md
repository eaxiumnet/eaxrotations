# Eax's Fishing

Automated fishing addon for the Sylvanas runtime. Casts, catches, lures, navigates to pools, and tracks session stats — all with human-like timing variance.

## Features

- **Auto-cast & auto-catch** — Detects bobber bites via documented game-object APIs
- **Auto-equip** — Swaps to the best fishing pole in your bags, restores weapons on disable
- **Auto-lure** — Applies the highest-bonus lure available automatically
- **Pool navigation** — Walks to nearby fish pools when SentinelNavClient is available
- **Pool ESP** — Draws 3D lines and labels to pools in range
- **Humanizer** — Behavior profiles that shift timing every 15–25 minutes
- **Micro-breaks** — Random 10–30 second pauses mid-session
- **Session time limit** — Hard-stop after N minutes to avoid marathon sessions
- **Cast jitter** — Random facing offset before each cast so bobbers land differently
- **Anti-AFK** — Periodic jumps to prevent idle-disconnect
- **Auto-repair** — Repairs gear at vendors when enabled
- **Safety lock** — Toggle-off confirmation after bag-full stop
- **Session HUD** — Live stats: casts, catch rate, fish count, gold gained

## Installation

Copy the `EAXFishing` folder into your `scripts/` directory. The addon loads automatically via `main.lua`.

## Control Panel

Enable/disable fishing from the control panel. All settings are persisted across sessions.

## Menu Options

| Section | Option | Description |
|---|---|---|
| **Gear** | Auto-Equip Fishing Pole | Equips the best pole from bags |
| | Auto-Apply Lure | Uses highest-bonus lure |
| **Timing** | Natural Timing (master toggle) | Enables behavior profiles |
| | Ultra-Safe Mode | All delays pushed to maximum |
| | Cast Jitter | Random facing offset per cast |
| | Cast / Reaction delays | Configurable min/max ms |
| | Micro-break frequency | How often to pause 10–30s |
| | Anti-AFK Jump | Periodic jumps to stay online |
| | Stagger delays | Loot, equip, lure pauses |
| | Deliberate Misses | Occasional miss after catch streak |
| | Fish Escape Window | Click deadline after bite |
| | Auto-Stop After | Session time limit (0 = off) |
| **Pool Routing** | Navigate to Pools | Auto-walk to fish pools |
| | Only Cast at Pools | Skip open water |
| **Visuals** | Pool ESP | Draw lines to pools |
| | Session HUD | On-screen stats overlay |
| **Utility** | Stop When Bags Full | Auto-stop on full bags |
| | Auto Repair at Vendor | Repair when merchant open |
| **Debug** | Console Logging | Verbose API logging |

## API Truth Ledger

All runtime API calls are documented in `docs/openfishing-api-truth.md`. Approved, fallback, and banned APIs are listed with replacements.

## Architecture

```
EAXFishing/
├── core/
│   ├── api_surface.lua   # Single adapter for all runtime APIs
│   ├── app.lua           # Application bootstrap
│   ├── behavior.lua      # Humanizer profiles & timing
│   ├── context.lua       # Dependency injection container
│   └── state.lua         # Centralized runtime state
├── fishing/
│   ├── engine.lua        # Main fishing loop & bite detection
│   ├── gear.lua          # Pole equip / weapon restore
│   ├── loot.lua          # Loot window processing
│   ├── loot_db.lua       # Item category database
│   └── lures.lua         # Lure application
├── navigation/
│   ├── client.lua        # Nav client wrapper
│   ├── shoreline_solver.lua # Pool standoff position solver
│   └── terrain.lua       # Terrain height helpers
├── ui/
│   ├── control_panel.lua # Control panel rendering
│   ├── menu.lua          # Settings menu rendering
│   └── render.lua        # ESP / HUD / safety warnings
├── inventory/
│   ├── bags.lua          # Bag space checks
│   └── vendor.lua        # Auto-repair logic
├── config.lua            # Menu configuration
├── constants.lua         # Item / spell / pool constants
├── main.lua              # Entry point
└── docs/
    └── openfishing-api-truth.md
```

## Safety Features

- **Bite detection**: Uses `game_object:does_bobber_have_fish()`; when that API is broken on the runtime (returns false), falls back to **Z-dip splash detection** (baselines the bobber's resting Z, confirms a bite on a configurable dip below baseline) with a max bite-window last-resort click
- **Bobber ownership**: Only clicks your own bobber (creator object check)
- **No banned APIs**: All runtime calls go through `api_surface.lua` with `pcall` wrapping
- **State consolidation**: Single state table avoids Lua's 60-upvalue limit
- **PRNG seeding**: `math.randomseed()` on load for non-deterministic behavior

## Changelog

### v2.3.0
- **Auto-Cook Raw Fish** — when enabled, detects nearby campfires/cooking fires and casts DBC-verified cooking recipes to convert raw fish into cooked buff food. Frees bag slots mid-session and multiplies gold-per-slot value (Raw Spotted Feltail → Feltail Delight, etc.). Only cooks fish the bot itself caught; skips quest/stock fish. Gated by `is_spell_learned()` so no ghost-spell casts.
- **Smart Pool Ranker** — replaces "nearest pool" with a value-weighted scorer. High-value pools (Furious Crawdad, Sporefish, Stonescale Eel, etc.) are now preferred over closer low-value pools. Expected farm rate increases significantly in multi-pool zones. Pool values are heuristically ranked from DBC-verified drop data.
- **Session HUD v2** — shows "Cooked" count in the on-screen stats overlay when auto-cook fires.
- **4 test suites** (was 2), **144 assertions** (was 109) covering state machine, safe-menu contract, pool ranker, and cook module.

### v2.2.1
- **Fishing spell ranks DBC-verified** — removed ghost spell 13147 (does not exist in WoW 2.5.5 client). Rank lookup now uses verified IDs: 33095 Master → 18248 Artisan → 7732 Expert → 7731 Journeyman → 7620 Apprentice.
- All fishing poles, lures, and fish items cross-referenced against DBC + web sources. No gaps found.

### v2.2.0
- **Stealth Mode** — slows cast rhythm and takes longer breaks when another player is nearby. Configurable range (default 30y). Suppresses pool navigation while active.
- **Rare Catch Alert** — plays the Quest Complete fanfare + flashes a big colored message when you catch a blue item (Mr. Pinchy), green item worth ≥1g, or anything worth ≥3g.
- State machine expanded with `stealth` and `alert` subtables.

### v2.1.1
- Bumped version across all files (header, main, config, menu, README)
- Replaced `math.sqrt` distance checks with squared-distance comparisons (Pattern 3)

### v2.1.0
- Consolidated bite state into `state.bite` table
- Fixed safety lock after bag-full stop (dedicated boolean)
- Added `math.randomseed()` for non-deterministic timing
- Merged dual update callbacks to avoid runtime overwrite
- Wrapped menu creation with `pcall` + `DUMMY` fallback
- Single source of truth for fishing poles (derived from constants)
- O(1) loot DB name lookup
- Removed 100+ lines of dead code and zombie modules
- Added cast jitter and session time limit

## License

Internal use only — part of the EaxRotations ecosystem.
