# Eax's Fishing

Automated fishing addon for the Sylvanas runtime. Casts, catches, lures, navigates to pools, cooks, opens containers, tracks quests, and alerts on rare catches — all with human-like timing variance.

**Version**: 2.4.1 | **Tests**: 8 suites / 150+ assertions | **Code**: 6,500+ lines across 20 modules

---

## Features (18 total)

### Core Fishing
- **Auto-cast & auto-catch** — Detects bobber bites via documented game-object APIs with Z-dip fallback
- **Auto-equip** — Swaps to the best fishing pole in your bags, restores weapons on disable
- **Auto-lure** — Applies the highest-bonus lure available automatically
- **Cast jitter** — Small ±degrees angular offset so bobbers land in different spots (v2.3.2 fix: was yards, now degrees)
- **Bite detection** — Primary: `does_bobber_have_fish()` + Fallback: Z-dip splash detection (Sylvanas API fix pending)

### Pool Navigation
- **Pool tracking** — Walks to nearby fish pools when SentinelNavClient is available
- **Smart pool ranking** — Value-weighted scorer prefers high-value pools (Crawdad, Eel) over closer low-value pools
- **Bounding-radius safety** — Uses `get_bounding_radius()` + 2yd buffer to prevent pathing into pools
- **Pool depletion detection** — Skips pools after N casts with 0 catches (v2.4.0)
- **Quest fish targeting** — When a daily quest is detected, prefers pools that drop quest fish (v2.4.0)
- **Pool ESP** — Draws 3D lines and labels to pools in range

### Automation (v2.4.0)
- **Auto-open containers** — Opens clams, chests, supply crates between casts
- **Auto-cook raw fish** — Converts raw fish to cooked buff food when campfire nearby
- **Mr. Pinchy handler** — Auto-uses Mr. Pinchy charges, alerts on results
- **Auto-sell junk** — Sells gray items when vendor window is open
- **Auto-delete worthless** — Deletes gray items with no vendor value when bags full
- **Auto-hearth** — Hearthstones to inn when bags full, saves return position
- **Daily quest tracker** — Detects fishing dailies from quest items in bags

### Session Resilience (v2.4.0)
- **Whisper alert** — Alerts on incoming whispers (detection-only, no reply API)
- **Disconnect alert** — Detects server disconnect via nav client (detection-only)
- **Auto-relog** — Framework for relog when API becomes available
- **Time/weather awareness** — Framework for night-only fishing

### QoL (v2.4.1)
- **Sound alerts** — 8 configurable per-event sounds (rare, bags full, pool depleted, lure expiring, whisper, disconnect, catch)
- **Lure expiration timer** — Shows remaining lure time in HUD, plays warning sound
- **Catch streak tracker** — Shows current + best streak in HUD
- **Coordinate display** — Shows current X, Y in HUD
- **Low HP auto-pause** — Pauses fishing when HP drops below threshold
- **Cast success rate** — Shows cast success percentage in HUD

### Humanizer & Safety
- **Behavior profiles** — Shifts timing every 15–25 minutes so no two sessions look the same
- **Micro-breaks** — Random 10–30 second pauses mid-session
- **Stealth mode** — Slows cast rhythm when players nearby
- **Anti-AFK** — Periodic jumps to prevent idle-disconnect
- **Session time limit** — Hard-stop after N minutes
- **Auto-repair** — Repairs gear at vendors when enabled
- **Safety lock** — Toggle-off confirmation after bag-full stop

---

## Installation

Copy the `EAXFishing` folder into your `scripts/` directory. The addon loads automatically via `main.lua`.

## Control Panel

Enable/disable fishing from the control panel. All settings are persisted across sessions.

---

## Menu Reference (66 options, 7 collapsible sections)

### Gear & Lures
| Option | Default | Description |
|--------|---------|-------------|
| Auto-Equip Fishing Pole | ON | Equips best pole from bags |
| Auto-Apply Lure | ON | Uses highest-bonus lure |
| Auto-Cook Raw Fish | OFF | Cooks raw fish when campfire nearby |
| Show Lure Timer in HUD | ON | Shows remaining lure time |
| Lure Expiry Warning (s) | 60 | Sound warning before lure expires |

### Timing & Humanizer
| Option | Default | Description |
|--------|---------|-------------|
| Natural Timing | ON | Master toggle for behavior profiles |
| Ultra-Safe Mode | OFF | All delays to maximum |
| Cast Jitter | ON | Random facing offset per cast |
| Jitter Range (degrees) | 5 | ±degrees from current facing |
| Min/Max cast delay | 900/2200ms | Pause before next cast |
| Min/Max reaction time | 150/400ms | Click speed after bite |
| Micro-break Frequency | 10 | 0=off, higher=more breaks |
| Anti-AFK Jump | ON | Periodic jumps |
| Jump interval | 60-180s | Range between jumps |
| Stagger Loot/Equip/Lure | ON | Small delays for humanization |
| Deliberate Misses | ON | Random miss after 5+ streak |
| Fish Escape Window | ON | Click deadline after bite |
| Z-Dip Splash Detection | ON | Fallback bite detection |
| Dip Sensitivity | 10 | 0.10yd dip threshold |
| Auto-Stop After (min) | 0 | Session time limit (0=off) |

### Pool Routing
| Option | Default | Description |
|--------|---------|-------------|
| Navigate to Pools | OFF | Auto-walk to fish pools |
| Smart Pool Ranking | ON | Value-weighted pool selection |
| Only Cast at Pools | OFF | Skip open water |
| Scan Range | 250y | Pool search radius |
| Stand Distance | 15y | Distance from pool edge |
| Shore Depth Tolerance | 0 | Allow slightly underwater spots |
| Pool Depletion Threshold | 5 | Skip pool after N casts, 0 catches |
| Show Cast Success Rate | ON | Cast % in HUD |

### Automation (v2.4.0)
| Option | Default | Description |
|--------|---------|-------------|
| Auto-Open Containers | ON | Opens clams, chests between casts |
| Auto-Sell Junk at Vendor | OFF | Sells gray items to vendor |
| Auto-Delete Worthless Items | OFF | Deletes no-value gray items when full |
| Auto-Hearth When Bags Full | OFF | Hearthstones to inn for vendoring |
| Stop When Bags Full | ON | Hard-stop after 3 full-bag checks |
| Auto-Use Mr. Pinchy | ON | Auto-uses Mr. Pinchy charges |
| Auto Repair at Vendor | OFF | Repairs when merchant open |
| Disconnect Alert | OFF | Detects server disconnect |
| Night-Only Fishing | OFF | Framework (API not yet available) |
| Whisper Alert | OFF | Alerts on incoming whispers |

### Sound Alerts (v2.4.1)
| Option | Default | Description |
|--------|---------|-------------|
| Enable Sound Alerts | ON | Master toggle |
| Rare Catch Sound | ON | Quest Complete fanfare |
| Bags Full Sound | ON | PvP warning |
| Pool Depleted Sound | OFF | Subtle "done" sound |
| Lure Expiring Sound | ON | Soft chime |
| Whisper Sound | ON | Whisper notification |
| Disconnect Sound | ON | Error buzzer |
| Catch Sound | OFF | Soft splash per catch |

### Stealth
| Option | Default | Description |
|--------|---------|-------------|
| Slow Down When Players Near | ON | Slows cast rhythm near players |
| Stealth Range | 30y | Player proximity trigger distance |

### Visuals & HUD
| Option | Default | Description |
|--------|---------|-------------|
| Pool ESP | ON | Draws 3D lines to pools |
| ESP Range | 150y | Line draw distance |
| Session HUD | ON | On-screen stats overlay |
| Show Catch Streak | ON | Current + best streak |
| Show Coordinates | ON | X, Y in HUD |
| Rare Catch Alert | ON | Sound + overlay for valuable catches |
| Auto-Pause on Low HP | OFF | Pauses when HP < threshold |
| Low HP Threshold % | 20% | Pause threshold |

### Debug
| Option | Default | Description |
|--------|---------|-------------|
| Console Logging | OFF | Verbose API logging |

---

## HUD Display (31 rows)

| Row | Description |
|-----|-------------|
| Session | Elapsed time (Xm Ys) |
| Casts | Total cast attempts |
| Catches | Total successful catches |
| Catch rate | Percentage |
| Catches/hr | Hourly rate |
| Misses | Deliberate misses (humanizer) |
| Escaped | Fish that got away |
| Fish | Total fish items looted |
| Fish/hr | Hourly fish rate |
| Junk | Gray items looted |
| Lures | Remaining lure count in bags |
| Lure | Remaining lure time (Xm Ys) |
| Cooked | Cooked food count |
| Opened | Containers opened |
| Pinchy | Mr. Pinchy uses |
| Sold | Items auto-sold |
| Deleted | Items auto-deleted |
| Cast % | Cast success rate |
| Depleted | Pools skipped as depleted |
| Quest | Active quest fish name |
| Whispers | Whisper alerts received |
| Hearth | Hearth state (hearth/returning) |
| Status | DC'd! when disconnected |
| Window | Closed when outside fishing window |
| Streak | Current catch streak (best: N) |
| Coords | Current X, Y position |
| Paused | YES when paused |
| Vendorfish | Goldenscale Vendorfish value |
| Gold gained | Total gold earned |
| Gold / hr | Hourly gold rate |
| Items caught | Top 6 items by count |

---

## Architecture

```
EAXFishing/
├── core/
│   ├── api_surface.lua     # Single adapter for all runtime APIs (1111 lines)
│   ├── app.lua             # Application bootstrap + game event handler
│   ├── behavior.lua        # Humanizer profiles & timing
│   ├── conditions.lua      # Time/weather awareness framework
│   ├── context.lua         # Dependency injection container
│   ├── relog.lua           # Disconnect detection
│   ├── responder.lua       # Whisper detection
│   ├── sound_manager.lua   # Configurable per-event sound alerts
│   ├── state.lua           # Centralized runtime state (395 lines)
│   └── stealth.lua         # Player proximity slowdown
├── fishing/
│   ├── engine.lua          # Main fishing loop & bite detection (995 lines)
│   ├── containers.lua      # Auto-open clams/chests
│   ├── cook.lua            # Auto-cook raw fish
│   ├── gear.lua            # Pole equip / weapon restore
│   ├── loot.lua            # Loot window processing
│   ├── loot_db.lua         # Item category database
│   ├── lures.lua           # Lure application + stack count
│   ├── mr_pinchy.lua       # Mr. Pinchy charge handler
│   ├── pool_ranker.lua     # Value-weighted pool scorer
│   └── quest_tracker.lua   # Daily fishing quest detection
├── navigation/
│   ├── client.lua          # Nav client wrapper
│   ├── hearth.lua          # Auto-hearth + return
│   ├── shoreline_solver.lua # Pool standoff position solver
│   └── terrain.lua         # Terrain height helpers
├── inventory/
│   ├── auto_delete.lua     # Delete worthless junk when full
│   ├── auto_sell.lua       # Sell gray items to vendor
│   ├── bags.lua            # Bag space checks
│   └── vendor.lua          # Auto-repair logic
├── ui/
│   ├── control_panel.lua   # Control panel rendering
│   ├── menu.lua            # Settings menu (7 collapsible sections)
│   └── render.lua          # ESP / HUD / safety warnings
├── tests/
│   ├── run_fishing_tests.lua    # Test runner (8 suites)
│   ├── test_state_machine.lua   # State creation + reset
│   ├── test_config_safe_menu.lua # Menu nil-guard contract
│   ├── test_pool_ranker.lua     # Pool scoring logic
│   ├── test_cook.lua            # Cook module
│   ├── test_containers.lua      # Container detection
│   ├── test_mr_pinchy.lua       # Mr. Pinchy handler
│   ├── test_quest_tracker.lua   # Quest fish detection
│   └── test_sound_manager.lua   # Sound alert system
├── config.lua              # Menu configuration (66 options)
├── constants.lua           # Item / spell / pool constants
├── main.lua                # Entry point
└── docs/
    └── openfishing-api-truth.md
```

---

## Safety Features

- **Bite detection**: Primary `does_bobber_have_fish()` + Z-dip fallback with max bite-window last-resort click
- **Bobber ownership**: Only clicks your own bobber (creator object check)
- **No banned APIs**: All runtime calls go through `api_surface.lua` with `pcall` wrapping
- **Nil-guard contract**: Every menu reference uses `menu.X and menu.X:get_state()` pattern
- **State consolidation**: Single state table avoids Lua's 60-upvalue limit
- **PRNG seeding**: `math.randomseed()` on load for non-deterministic behavior
- **Lure re-check**: Defensive `has_active_lure()` re-check before consuming lure item (prevents duplicate)
- **Cooking guards**: Blocked while casting, channeling, or moving

---

## Changelog

### v2.4.2 (2026-07-05)
- **Auto-Water Walking** — Auto-applies Water Walking (Shaman), Levitate (Priest), or Path of Frost (DK) before casting. Falls back to Elixir of Water Walking consumable (item 8827). Disabled by default — opt-in for water fishing.

### v2.4.1 (2026-07-05)
- **Sound alerts system** — 8 configurable per-event sounds with master toggle + individual toggles
- **Lure expiration timer** — HUD shows remaining lure time, plays warning sound at configurable threshold
- **Catch streak tracker** — Shows current + best consecutive catch streak in HUD
- **Coordinate display** — Shows current X, Y in HUD
- **Low HP auto-pause** — Pauses fishing when HP drops below configurable threshold
- **Menu reorganization** — 66 options grouped into 7 collapsible tree sections
- **4 new test suites** — containers, mr_pinchy, quest_tracker, sound_manager (8 total, 150+ assertions)

### v2.4.0 (2026-07-05)
- **Auto-open containers** — Opens clams, chests, supply crates between casts to free bag space
- **Mr. Pinchy handler** — Auto-uses Mr. Pinchy (27436) charges, alerts on each use
- **Auto-sell junk** — Sells gray items when vendor window is open
- **Auto-delete worthless** — Deletes gray items with no vendor value when bags full
- **Pool depletion detection** — Skips pools after N casts with 0 catches
- **Cast reliability telemetry** — Tracks and displays cast success rate
- **Daily quest tracker** — Detects TBC fishing dailies, targets quest fish pools
- **Whisper responder** — Alerts on incoming whispers (detection-only)
- **Auto-hearth** — Hearthstones to inn when bags full, saves return position
- **Auto-relog** — Disconnect detection with alert (detection-only)
- **Time/weather awareness** — Framework for night-only fishing
- 12 new menu options, 12 new state subtables, 8 new modules

### v2.3.2 (2026-07-05)
- **Cast jitter fix** — Was treating jitter_deg as YARDS of position offset (could face beach). Now applies proper ±degrees angular offset to current facing.

### v2.3.1 (2026-07-05)
- **Lure stack HUD** — Shows remaining lure count in bags
- **Bounding-radius pool safety** — Uses `get_bounding_radius()` + 2yd buffer to prevent pathing into pools
- **Lure re-check** — Defensive `has_active_lure()` before consuming lure item
- **Cook while moving guard** — Blocks cooking when player is moving

### v2.3.0
- **Auto-Cook Raw Fish** — DBC-verified cooking recipes, campfire detection
- **Smart Pool Ranker** — Value-weighted pool scoring
- **Session HUD v2** — Cooked count in HUD

### v2.2.1
- **Fishing spell ranks DBC-verified** — Removed ghost spell 13147

### v2.2.0
- **Stealth Mode** — Slows near players
- **Rare Catch Alert** — Sound + overlay for valuable catches

### v2.1.0–v2.1.1
- State consolidation, safety lock, PRNG seeding, cast jitter, session time limit

---

## API Truth Ledger

All runtime API calls are documented in `docs/openfishing-api-truth.md`. Approved, fallback, and banned APIs are listed with replacements.

## License

Internal use only — part of the EaxRotations ecosystem.
