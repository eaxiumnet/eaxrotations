# EAX TBC Classic Rotations — Agent Context

**Repo**: https://github.com/eaxiumnet/eax-tbc-classic-rotations  
**Local Path**: `C:\newbot\scripts`  
**Last Updated**: 2026-04-03  

## Project Identity

**What This Is**: 27 World of Warcraft: The Burning Crusade Classic rotation plugins for the Sylvanas platform. Each plugin provides automated spell/ability sequencing for one class specialization (Druid Balance/Feral/Resto, Hunter BM/MM/Survival, etc.).

**Primary Objective**: Deliver crash-free, TBC-accurate rotation logic with minimal API overhead and consistent patterns across all 27 specs.

**Hard Constraints**:
- TBC-era spells only — never add WotLK/Cata abilities
- Never ship `.toc` files or vendor automation
- All menu references must be nil-guarded to prevent crashes
- `luac -p` must pass on every modified file

---

## Tech Stack

| Component | Version/Details |
|-----------|---------------|
| Platform | Project Sylvanas Lua runtime |
| Language | Lua 5.1 (WoW-compatible subset) |
| API Docs | `.api/` (Sylvanas runtime) + `sylvanas-dev-docs-llm/` (local docs) |
| File Pattern | `EAX<Class><Spec>/main.lua`, `utils.lua`, `spells.lua`, `menu.lua` |

## Common Commands

```bash
# Validate Lua syntax
luac -p EAXWarriorFury/main.lua

# Check all specs
lua tools/rotation_validation.lua

# Check API compliance (banned patterns)
lua tools/api_hard_gate.lua

# Build for release
python tools/export_eax_plugins.py --output dist/eax_ship

# Audit shared module drift
python tools/audit_shared_duplicates.py
```

---

## Project Structure

```
EAX<Class><Spec>/           # 27 spec directories
├── main.lua               # On-update loop, rotation engine
├── libraries/
│   ├── spells.lua         # Spell ID tables, talent gating
│   ├── utils.lua          # Helper functions, mana/health % checks
│   ├── menu.lua           # Menu toggle definitions
│   ├── ooc_manager.lua    # Out-of-combat rotation (if needed)
│   ├── defensive_manager.lua
│   ├── interrupt_manager.lua
│   ├── racial_manager.lua
│   └── esp_renderer.lua   # HUD/visuals
├── plugin_info.lua        # Metadata (name, version, spec_id)
└── header.lua             # Class validation, load conditions

libraries/                 # Shared runtime
├── spell_resolver.lua     # Persistent spell caching
├── combat_context.lua     # Throttled context builder
├── pvp_manager.lua        # PvP state detection
└── pull_optimizer.lua     # Pull timing logic

tools/                     # Build/validation scripts
sylvanas-dev-docs-llm/     # Local API documentation mirror
```

---

## Coding Conventions

### Naming
| Type | Pattern | Example |
|------|---------|---------|
| Spec directory | `EAX<Class><Spec>` | `EAXWarriorFury` |
| Files | lowercase_with_underscores | `main.lua`, `utils.lua` |
| Constants | UPPER_SNAKE_CASE | `BLOODTHIRST`, `BUFF_BATTLE_SHOUT` |
| Private vars | `_` prefix | `_core_time`, `_tracked_stance` |
| Spell IDs | ALL_CAPS | `EXECUTE = 5308` |

### Critical Patterns

**Menu Nil Guards (REQUIRED)**
```lua
-- WRONG - crashes if menu item nil
local mode = menu.mode:get()

-- CORRECT - safe guarded access
local mode = (menu.mode and menu.mode:get()) or 1
local threshold = (menu.heal_threshold and menu.heal_threshold:get()) or 50
```

**API Caching at Load**
```lua
-- At top of main.lua - never in on_update()
local _core_time = core.time
local _get_local_player = core.object_manager.get_local_player
local _get_gcd = core.spell_book.get_global_cooldown
```

**Squared Distance Checks**
```lua
-- WRONG - sqrt() is expensive
local dist = math.sqrt(dx*dx + dy*dy)

-- CORRECT - compare squared
local dist_sq = dx*dx + dy*dy
if dist_sq < 100 then ... end  -- 10 yards squared
```

**Static Table Reuse**
```lua
-- WRONG - allocates every frame
local tracked = {}

-- CORRECT - reuse static table
local _tracked_auras = { n = 0 }
-- clear with _tracked_auras.n = 0, not {}
```

---

## Testing Rules

- Run `luac -p` on every modified file before commit
- `lsp_diagnostics` must show 0 errors on changed files
- Build with `python tools/export_eax_plugins.py` must succeed
- Never commit `.toc` files (delete if found)
- Verify syntax passes before marking any task complete

---

## Boundaries

### ✅ Always
- Cache hot-path APIs at module load
- Throttle expensive calls (`combat_context.build()` → 2s, `detect_mode()` → 5s)
- Use `spell_resolver.lua` for `is_spell_learned()` caching
- Limit target scan to 50 objects with early exit

### ⚠️ Ask First
- Add new shared libraries to `libraries/`
- Modify `combat_context.lua` or `spell_resolver.lua`
- Add new menu items that require utils.lua changes
- Refactor multiple specs simultaneously

### 🚫 Never
- `ffi.C`, `io.popen`, `os.execute`, `debug.*` — banned APIs
- Commit `.toc`, `.zip`, or vendor automation files
- Add WotLK/Cata spells (see TBC Accuracy list in full docs)
- Suppress type errors with `as any` or `@ts-ignore`
- Use `sqrt()` for distance comparisons

---

## Non-Obvious Patterns

**Mode/Lane Detection via menu.mode:get()**
- Mode 1 = Auto (PVE/PVP automatic)
- Mode 2 = PVE Only
- Mode 3 = PVP Only
- Always guard: `(menu.mode and menu.mode:get()) or 1`

**Spell Resolution Caching**
`spell_resolver.lua` caches `is_spell_learned()` results persistently. On first load it builds a cache; on subsequent ticks it returns cached values. Cache invalidates on talent changes automatically.

**Combat Context Throttling**
`combat_context.build()` is throttled to 2-second refresh. Don't call it per-frame — use the cached context from `utils.lua`:
```lua
local ctx = utils.get_cached_combat_context(me)
```

**Menu Item Defaults**
| Menu Type | Sensible Default |
|-----------|------------------|
| Mode/Lane | 1 (Auto) |
| Percentages | 50 (or 20/30/40 for specific contexts) |
| Combo Points | 5 |
| Boolean toggles | false |
| Time/seconds | 2-3 seconds |

---

## Sylvanas API Quick Ref

**Local API**: `.api/` folder (auto-updated by Sylvanas runtime)  
**Local Docs**: `sylvanas-dev-docs-llm/pages/dev/api/` (offline documentation mirror)

### Using the API

The Sylvanas runtime maintains the latest API definitions in the `.api/` folder at runtime. These are automatically updated when you run the loader.

For offline reference, use the local documentation mirror in `sylvanas-dev-docs-llm/`.

### New Namespaces (April 2026)
| Namespace | Key Functions |
|-----------|---------------|
| `core.mail.*` | `check_inbox()`, `send_mail()`, `take_inbox_money()` |
| `core.quests.*` | `accept_quest()`, `complete_quest()`, `get_gossip_options()` |
| `core.auction_house.*` | `replicate_items()`, `post_item()`, `place_bid()` |
| `core.pet_battle.*` | `is_in_battle()`, `use_ability()`, `get_journal()` |
| `core.addons.*` | `zygor.get_current_step()`, `bigwigs.get_bars()`, `tsm.get_item_prices()` |

### Core Updates
| Category | Functions |
|----------|-----------|
| Profiling | `core.cpu_time()`, `core.cpu_ticks()` |
| Window | `core.set_window_foremost()`, `core.is_textbox_focused()` |
| Input | `core.input.is_key_pressed()`, `core.input.mount()`, `core.input.join_dungeon()` |
| Graphics | `core.graphics.load_font()`, `core.graphics.load_texture()`, `core.graphics.cone_3d()` |
| Game UI | `core.game_ui.get_tooltip_info()`, `core.game_ui.add_tooltip_line()` |

### Helper Libraries
```lua
require("common/modules/buff_manager")        -- Cached buff/debuff data
require("common/modules/spell_queue")           -- Priority spell queueing
require("common/modules/spell_prediction")      -- AoE positioning
require("common/modules/target_selector")       -- Weight-based targeting
require("common/modules/combat_forecast")       -- Combat duration prediction
require("common/utility/cooldown_tracker")      -- Enemy cooldown tracking
require("common/utility/spell_helper")          -- Spell validation
```

### IZI SDK (High-Level Wrapper)
```lua
require("common/izi_sdk")

-- Event callbacks (event-driven)
izi.on_buff_gain(callback)      -- Also: on_buff_lose, on_spell_success, on_combat_start

-- OO spell/item objects
local spell = izi.spell(id)      -- :cast_safe(), :cooldown_up(), :charges()
local item = izi.item(id)        -- :use_self_safe(), :equipped, :count

-- Smart targeting
izi.pick_enemy(scoring_fn)       -- Scoring-based selection
izi.ts()                         -- Target selector integration

-- Graphics with auto-caching
izi.draw_icon(name)               -- Wowhead icon auto-resolution
izi.draw_spell_icon(spell_id)     -- Spell icon with caching

-- Game object extensions (auto-applied)
unit:buff_up(buff_id)             -- 60+ methods auto-added
unit:distance_to(target)
unit:get_health_percentage()
```

---

## Key Files

| File | Purpose |
|------|---------|
| `EAX<Class><Spec>/main.lua` | On-update loop, priority engine, callbacks |
| `EAX<Class><Spec>/libraries/spells.lua` | Spell tables, talent gating |
| `EAX<Class><Spec>/libraries/utils.lua` | Helper functions (get_mana_pct, etc.) |
| `libraries/spell_resolver.lua` | Persistent spell caching |
| `libraries/combat_context.lua` | Throttled context builder |
| `AGENTS.md` | This file — agent operational context |
| `codemap.md` | Architecture overview per directory |

---

## Confidence & Freshness

| Section | Confidence | Notes |
|---------|------------|-------|
| Project Structure | ✅ High | Verified 2026-04-03 |
| Menu Guard Pattern | ✅ High | 263+ fixes applied and verified |
| Sylvanas API | ⚠️ Medium | Live docs authoritative; check for updates |
| IZI SDK | ⚠️ Medium | New — verify `common/izi_sdk` exists in Sylvanas runtime |
| TBC Spell Lists | ✅ High | Validated against TBC sim data |

---

## Continuation: Where We Left Off

**Last Major Work** (2026-04-03): Comprehensive wiring fixes across all 27 specs — applied 263+ nil guards to menu references, fixed 6 utils.lua unguarded patterns, verified all files pass `luac -p` with 0 LSP errors.

**Open Threads**:
- In-game validation still needed for all specs (user requirement: confirm rotation feel)
- IZI SDK integration opportunity — event callbacks could replace polling in specs
- New April 2026 APIs (tooltip, graphics, mail) available but not yet integrated

**Current Blockers**: None. All 27 specs syntax-clean and ready for testing.

**What NOT to Touch**:
- Menu guard patterns (the `(menu.x and menu.x:get()) or default` pattern) — these are battle-tested
- `spell_resolver.lua` caching logic — working correctly
- `combat_context.lua` 2-second throttle — verified optimal

---

## Session Start Protocol

1. Work from `C:\newbot\scripts`
2. Check Sylvanas runtime issues first:
   ```bash
   # Via MCP or manual:
   git status --short --branch
   git log --oneline -5
   ```
3. Read `codemap.md` for architecture context
4. For spec-specific work, read that spec's `codemap.md`
5. Run `luac -p` on any file before editing
6. Verify with `lsp_diagnostics` after changes

---

*This file is human-curated. Update when patterns change or new APIs are adopted.*
