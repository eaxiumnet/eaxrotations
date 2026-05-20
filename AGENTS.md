# EAX TBC Classic Rotations — Agent Context

**Repo**: https://github.com/eaxiumnet/eax-tbc-classic-rotations  
**Local Path**: `C:\newbot\scripts`  
**Last Updated**: 2026-05-21  
**Specs**: 29 TBC Classic class specializations (all 29 completed)  
**Pattern Compliance**: 99% menu guards, 95% API caching, 100% banned API compliance

---

## Project Identity

**What This Is**: 29 World of Warcraft: The Burning Crusade Classic rotation plugins for Project Sylvanas. All 29 specs completed as flat `_sylvanas.lua` files under `EaxRotations/classes/<class>/`. Each spec file provides automated spell/ability sequencing for one class specialization with optimized DPS/HPS/TPS rotations. Shared logic lives in `EaxRotations/shared/`.

**Primary Objective**: Deliver crash-free, TBC-accurate rotation logic with minimal API overhead and consistent patterns across all 29 specs.

**Hard Constraints**:
- TBC-era spells only — never add WotLK/Cata abilities
- All menu references must be nil-guarded to prevent crashes
- `luac -p` must pass on every modified file
- All 29 specs must pass `lua EaxRotations/tests/run_rotation_tests.lua` and `lua EaxRotations/tests/run_leveling_tests.lua`
- Only Project Sylvanas API (`api/`, `apidocs/`) — no external platforms

## Research Context

- **Origin:** Jeremy Howard (Answer.AI) proposed llms.txt in September 2024 as "robots.txt for AI"
- **Google Statement:** John Mueller (Google Search): "No AI system currently uses llms.txt"
- **Adoption:** 844,000+ implementations across GitHub (per grep.app)
- **Industry Usage:** Fireworks AI uses llms.txt for their own docs at docs.fireworks.ai
- **Performance Testing:** Reddit r/opencodeCLI testing showed oh-my-opencode-slim decreased performance (73.1% → 69.2%)

---

## Complete Project Structure

```
C:\newbot\scripts/
├── AGENTS.md                          # This file — agent operational context
├── README.md                          # Project overview
├── CHANGELOG.md                       # Version history
│
├── EaxRotations/                      # Active rotation source (all 29 specs)
│   ├── main_sylvanas.lua              # Main rotation engine, dispatcher
│   ├── core_sylvanas.lua              # NS helpers (buff_points, spell_ready, etc.)
│   ├── common_sylvanas.lua            # Common constants / shared init
│   ├── header.lua                     # Plugin bootstrap / metadata
│   │
│   ├── classes/                       # 29 spec files (flat, one per spec)
│   │   ├── druid/
│   │   │   ├── balance_sylvanas.lua   # Druid Balance (ranged DPS, Innervate)
│   │   │   ├── bear_sylvanas.lua      # Druid Bear (tank)
│   │   │   ├── cat_sylvanas.lua       # Druid Cat (melee DPS)
│   │   │   ├── resto_sylvanas.lua     # Druid Restoration (healer)
│   │   │   ├── caster_sylvanas.lua    # Druid caster shared logic
│   │   │   ├── class_sylvanas.lua     # Druid class bootstrap
│   │   │   └── ...                    # healing, leveling, middleware, schema
│   │   ├── hunter/
│   │   │   ├── beast_mastery_sylvanas.lua
│   │   │   ├── marksmanship_sylvanas.lua
│   │   │   ├── survival_sylvanas.lua
│   │   │   └── ...
│   │   ├── mage/
│   │   │   ├── arcane_sylvanas.lua
│   │   │   ├── fire_sylvanas.lua
│   │   │   ├── frost_sylvanas.lua
│   │   │   └── ...
│   │   ├── paladin/
│   │   │   ├── holy_sylvanas.lua
│   │   │   ├── protection_sylvanas.lua
│   │   │   ├── retribution_sylvanas.lua
│   │   │   └── ...
│   │   ├── priest/
│   │   │   ├── discipline_sylvanas.lua
│   │   │   ├── holy_sylvanas.lua
│   │   │   ├── shadow_sylvanas.lua
│   │   │   ├── smite_sylvanas.lua
│   │   │   ├── healing_sylvanas.lua   # Cross-spec healing (pws_absorb_remaining, scan, etc.)
│   │   │   └── ...
│   │   ├── rogue/
│   │   │   ├── assassination_sylvanas.lua
│   │   │   ├── combat_sylvanas.lua
│   │   │   ├── subtlety_sylvanas.lua
│   │   │   └── ...
│   │   ├── shaman/
│   │   │   ├── elemental_sylvanas.lua
│   │   │   ├── enhancement_sylvanas.lua
│   │   │   ├── restoration_sylvanas.lua
│   │   │   └── ...
│   │   ├── warlock/
│   │   │   ├── affliction_sylvanas.lua
│   │   │   ├── demonology_sylvanas.lua
│   │   │   ├── destruction_sylvanas.lua
│   │   │   └── ...
│   │   └── warrior/
│   │       ├── arms_sylvanas.lua
│   │       ├── fury_sylvanas.lua
│   │       ├── protection_sylvanas.lua
│   │       └── ...
│   │
│   ├── shared/                        # Shared modules (~50 files)
│   │   ├── class_loader_sylvanas.lua  # Class-level bootstrapping
│   │   ├── healer_engine_sylvanas.lua # Healing scan / triage
│   │   ├── interrupt_manager_sylvanas.lua
│   │   ├── consumable_manager_sylvanas.lua
│   │   ├── racial_manager_sylvanas.lua
│   │   ├── trinket_manager_sylvanas.lua
│   │   ├── swing_timer_sylvanas.lua
│   │   ├── leveling_sylvanas.lua      # Leveling rotation dispatcher
│   │   ├── targeting_sylvanas.lua
│   │   ├── ooc_manager_sylvanas.lua
│   │   ├── threat_manager_sylvanas.lua
│   │   ├── dot_refresh_sylvanas.lua
│   │   └── ... (40+ more)
│   │
│   ├── tests/                         # Test suite (~110 files)
│   │   ├── run_rotation_tests.lua     # Rotation test runner (95 suites)
│   │   ├── run_leveling_tests.lua     # Leveling test runner (11 suites)
│   │   ├── test_fury_custom_matches.lua
│   │   ├── test_discipline_custom_matches.lua
│   │   └── ...
│   │
│   └── tools/                         # Build/validation scripts
│
├── api/                               # Sylvanas API definitions (runtime)
│   ├── core.lua                      # Core callbacks, time, logging (4374 lines)
│   ├── game_object.lua               # Unit/entity access (600+ lines)
│   ├── menu.lua                      # Menu API definitions
│   └── common/                       # Common modules & utilities
│       ├── buff_db.lua               # Buff/debuff database (578 entries)
│       ├── enums.lua                 # Game enums (394 definitions)
│       ├── izi_sdk.lua               # High-level SDK (1681 lines)
│       ├── color.lua                 # Color utilities
│       ├── geometry/                 # Geometry utilities
│       │   ├── geometry.lua
│       │   ├── vector_2.lua
│       │   └── vector_3.lua
│       ├── modules/                  # Core modules
│       │   ├── buff_manager.lua      # Cached buff/debuff data
│       │   ├── combat_forecast.lua   # Combat duration prediction
│       │   ├── health_prediction.lua # Incoming damage prediction
│       │   ├── profiler.lua          # Performance profiling
│       │   ├── settings_manager.lua  # Settings management
│       │   ├── spell_prediction.lua  # AoE positioning
│       │   ├── spell_queue.lua       # Priority spell queueing
│       │   └── target_selector.lua   # Weight-based targeting
│       └── utility/                  # Helper utilities (26 files)
│           ├── auto_attack_helper.lua
│           ├── cooldown_tracker.lua
│           ├── spell_helper.lua
│           ├── unit_helper.lua
│           ├── pvp_helper.lua
│           └── ...
│
├── apidocs/                          # Offline API documentation
│   ├── corpus.jsonl                  # LLM retrieval corpus (2877 chunks, 68 pages)
│   ├── pages_manifest.jsonl         # Page metadata
│   └── pages/dev/                    # API documentation
│       ├── api/                      # Core API docs
│       │   ├── core.md              # Core callbacks & utilities (680 lines)
│       │   ├── game-object.md       # Unit/entity API
│       │   ├── spellbook.md         # Spell casting
│       │   ├── buffs.md             # Buff/debuff queries
│       │   └── graphics.md          # Rendering
│       ├── modules/                  # Module documentation
│       ├── libraries/                # Library guides
│       │   └── izi/                 # IZI SDK sub-docs
│       │       ├── types.md
│       │       ├── callbacks.md
│       │       └── units.md
│       ├── examples/                 # Example implementations
│       │   └── tbc-warlock-affliction.md
│       └── guides/                   # Implementation guides
│
├── ClassResearchTBC/                 # Research & vetting
│   ├── AgentQueue/
│   │   ├── MANIFEST.md              # Queue state (29 completed, 1 blocked-non-job)
│   │   ├── completed/               # 29 completed spec jobs
│   │   └── blocked/                 # 1 non-job (SP_Breakpoints_Druid_Balance)
│   ├── ImplementationChecklists/    # Per-spec implementation checklists
│   └── VETTING_LOG.md               # Vetting pass history
│
├── tools/                            # Build/validation scripts
└── dist/                             # Build output (eax_ship)
```

---

## Sylvanas API Deep Reference

### Core API (`api/core.lua`)

**Execution Model — Callbacks**:
```lua
-- Rotation logic (throttled to ~20-50ms, NOT every frame)
core.register_on_update_callback(callback)

-- Graphics rendering (every frame, NO game logic allowed)
core.register_on_render_callback(callback)

-- Menu rendering
core.register_on_render_menu_callback(callback)

-- Control panel rendering
core.register_on_render_control_panel_callback(callback)

-- Spell cast detection (triggers on any spell cast by anyone)
core.register_on_spell_cast_callback(function(data)
    -- data.spell_id, data.caster, data.target, data.spell_cast_time
end)

-- Legit spell cast (only when player manually casts)
core.register_on_legit_spell_cast_callback(callback)

-- Pre-tick callback (before each game tick)
core.register_on_pre_tick_callback(callback)
```

**Time & Profiling**:
```lua
core.time()                    -- Seconds since injection (cached: _core_time)
core.game_time()               -- Game time in milliseconds
core.cpu_time()                -- High-res CPU timestamp (nanoseconds)
core.cpu_ticks()               -- CPU tick counter
core.get_ping()                -- Current latency in ms
core.delta_time()              -- Seconds since last frame
```

**Game State**:
```lua
core.get_map_id()              -- Current zone/map ID
core.get_map_name()            -- Current map name
core.get_instance_id()         -- Instance/Dungeon ID
core.get_game_version()        -- "Tbc", "Vanilla", "Midnight", etc.
core.get_exact_game_version()  -- "tbc_cn", etc.
core.get_game_region()         -- "West", "China"
core.is_main_menu_open()       -- Is main menu open?
core.set_window_foremost()     -- Bring game window to front
```

**Logging**:
```lua
core.log(message)              -- Log to console
core.log_warning(message)      -- Log warning
core.log_error(message)        -- Log error
```

**Core Subsystems**:
| Namespace | Purpose | Key Functions |
|-----------|---------|---------------|
| `core.inventory.*` | Bag management | `get_bag_items()`, `get_gold()`, `get_repair_cost()` |
| `core.game_ui.*` | Game UI | `get_loot_list()`, `is_vendor_visible()`, `get_tooltip_info()` |
| `core.character.*` | Character stats | `get_combat_rating()`, `get_stat()` |
| `core.world.*` | World state | `is_flying()`, `get_encounter_info()` |
| `core.input.*` | Input/Actions | `cast_target_spell()`, `move_to()`, `loot()` |
| `core.object_manager.*` | Objects | `get_local_player()`, `get_enemy_list()`, `get_arena_frames()` |
| `core.spell_book.*` | Spells | `is_spell_learned()`, `get_spell_cooldown()`, `cancel_form()` |
| `core.graphics.*` | Rendering | `draw_circle()`, `draw_line()`, `load_texture()` |
| `core.menu.*` | UI Widgets | `checkbox()`, `slider_int()`, `keybind()`, `tree_node()` |
| `core.quests.*` | Quests | `get_quest_log()`, `accept_quest()` |

### Game Object API (`api/game_object.lua`)

**Unit Access**:
```lua
local me = core.object_manager.get_local_player()
local target = me:get_target()                    -- Current target
local focus = core.object_manager.get_focus()     -- Focus target
local enemies = core.object_manager.get_enemy_list()  -- Array of enemies
```

**Unit Properties**:
```lua
unit:get_health_percentage()      -- 0-100
unit:get_mana_percentage()        -- 0-100
unit:get_distance(other_unit)     -- Distance in yards
unit:get_position()               -- vec3 {x, y, z}
unit:is_alive()
unit:is_valid()
unit:is_casting()                 -- Is unit casting?
unit:is_channeling()              -- Is unit channeling?
unit:get_casting_spell_id()       -- Spell being cast
unit:get_casting_percent()        -- Cast progress 0-100
unit:is_in_combat()               -- Is unit in combat?
unit:can_attack(target)           -- Can attack target?
unit:is_enemy_with(other)         -- Is enemy with other unit?
unit:get_threat_situation()       -- Threat level (0-3)
```

**Buff/Debuff (via IZI SDK patches)**:
```lua
unit:has_buff(buff_id)             -- boolean
unit:buff_up(buff_id)              -- alias of has_buff
unit:buff_down(buff_id)            -- not has_buff
unit:get_buff_stacks(buff_id)      -- stack count
unit:buff_remains(buff_id)         -- seconds remaining
unit:buff_remains_ms(buff_id)      -- milliseconds remaining

unit:has_debuff(debuff_id)         -- boolean
unit:debuff_up(debuff_id)          -- alias
unit:get_debuff_stacks(debuff_id)
unit:debuff_remains(debuff_id)
```

### Spell System (`api/common/modules/`)

**Spell Queue** (`spell_queue.lua`):
```lua
require("common/modules/spell_queue")

-- Queue spell for casting (respects GCD, range, facing)
spell_queue.queue_spell(spell_id, target)
spell_queue.queue_spell(spell_id, target, opts)  -- with options

-- Check queue state
spell_queue.is_empty()             -- boolean
spell_queue.clear_queue()          -- Clear pending spells
spell_queue.get_next_spell()       -- Get next queued spell
```

**Spell Prediction** (`spell_prediction.lua`):
```lua
require("common/modules/spell_prediction")

-- Predict unit position after time_ahead seconds
local pos = spell_prediction.predict_position(unit, time_ahead)

-- Check if position is in AoE
local in_aoe = spell_prediction.is_in_aoe(source_pos, radius, target)

-- Find best AoE position for spell
local best_pos, hit_count = spell_prediction.find_best_aoe_position(
    source_unit, radius, min_hits, max_range
)
```

**Target Selector** (`target_selector.lua`):
```lua
require("common/modules/target_selector")

-- Find best target using scoring function
local target = target_selector.find_best_target(function(unit)
    return unit:get_health_percentage()  -- Lower HP = higher score
end)

-- Built-in selectors
local target = target_selector.get_nearest_enemy()
local target = target_selector.get_lowest_health_enemy()
local target = target_selector.get_highest_health_enemy()
local targets = target_selector.get_targets(max_count)
```

**Buff Manager** (`buff_manager.lua`):
```lua
require("common/modules/buff_manager")

-- Get buff data (cached, refreshed automatically)
local buff = buff_manager.get_buff(unit, buff_id)
if buff then
    local stacks = buff.stacks
    local remains = buff.remains
end

-- Check debuffs
local has_dot = buff_manager.has_debuff(unit, debuff_id)

-- Aura data with fake window support
local data = buff_manager.get_aura_data(unit, aura_spec)
```

### IZI SDK (`api/common/izi_sdk.lua`)

**Event-Driven Callbacks**:
```lua
require("common/izi_sdk")

-- Combat events
izi.on_combat_start(callback)
izi.on_combat_end(callback)
izi.on_target_changed(callback)

-- Buff/Debuff events
izi.on_buff_gain(callback)
izi.on_buff_lose(callback)
izi.on_debuff_gain(callback)
izi.on_debuff_lose(callback)

-- Spell events
izi.on_spell_success(callback)
-- NOTE: izi.on_spell_fail() does not exist in the IZI SDK

-- Input events
izi.on_key_release(key_code, callback)
```

**OO Spell Objects**:
```lua
local spell = izi.spell(spell_id)

-- Properties
spell.id                -- Spell ID
spell.name              -- Spell name
spell.cooldown          -- Current cooldown in seconds
spell.cooldown_up()     -- boolean (cooldown == 0)
spell.charges           -- Current charges
spell.max_charges       -- Maximum charges
spell.in_range(unit)    -- boolean
spell.usable            -- boolean (can cast)

-- Methods
spell:cast(unit)                -- Cast on unit
spell:cast_safe(unit)           -- Cast with safety checks
spell:cast_if(condition)        -- Cast if condition true
spell:queue(target)             -- Queue spell
spell:can_cast(unit, opts)    -- Check if castable
spell:in_facing(unit)           -- Check facing
spell:is_learned()              -- Check if spell is learned
spell:track_debuff(debuff_id)   -- Track specific debuff
```

**OO Item Objects**:
```lua
local item = izi.item(item_id)

-- Properties
item.id
item.name
item.count              -- Inventory count
item.equipped           -- boolean
item.cooldown

-- Methods
item:use()                      -- Use item
item:use_self()                 -- Use on self
item:use_self_safe()            -- Use with safety checks
item:use_on(unit)               -- Use on target
item:cooldown_up()              -- boolean
```

**Targeting Helpers**:
```lua
-- Pick enemy by scoring function
local target = izi.pick_enemy(function(unit)
    return score  -- Higher = better target
end)

-- Target selector shortcut
local ts = izi.ts()
local target = ts:find_best_target()

-- Check if any enemy matches condition
local has_low_hp = izi.any_enemy(function(u)
    return u:get_health_percentage() < 20
end)

-- Get filtered enemy lists
local enemies = izi.enemies()
local friends = izi.friends()
```

**Graphics**:
```lua
-- Draw spell icon (with auto-caching)
izi.draw_spell_icon(spell_id, x, y, width, height, alpha)

-- Draw icon by name
izi.draw_icon("icon_name", x, y, width, height)

-- Draw circle (AoE indicator)
izi.draw_circle(center_pos, radius, color, thickness)

-- Draw line
izi.draw_line(from_pos, to_pos, color, thickness)
```

### Buff Database (`api/common/buff_db.lua`)

Contains 578 buff/debuff spell ID definitions:
```lua
---@type buff_db
local buffs = require("common/buff_db")

-- Warrior buffs
buffs.BATTLE_SHOUT = {25289, 2048, 11551, 11550, 11549, 6673}
buffs.RECKLESSNESS = {1719, 13847}

-- Mage buffs
buffs.COMBUSTION = {11129}
buffs.ICE_BLOCK = {45438, 27619, 11958}

-- Rogue buffs
buffs.STEALTH = {1787, 1786, 1785, 1784, 1783}

-- Paladin buffs
buffs.DIVINE_SHIELD = {642, 1020}

-- Druid buffs
buffs.BERSERK = {50334}

-- Usage
local has_bs = player:has_buff(buffs.BATTLE_SHOUT)
```

### Enums (`api/common/enums.lua`)

394 game constant definitions:
```lua
---@type enums
local enums = require("common/enums")

-- Classes
enums.class_id.WARRIOR
enums.class_id.PALADIN
enums.class_id.HUNTER
enums.class_id.ROGUE
enums.class_id.PRIEST
enums.class_id.SHAMAN
enums.class_id.MAGE
enums.class_id.WARLOCK
enums.class_id.DRUID

-- Power types
enums.power_type.MANA
enums.power_type.RAGE
enums.power_type.ENERGY
enums.power_type.FOCUS

-- CC types
enums.cc_flags.STUN
enums.cc_flags.SILENCE
enums.cc_flags.FEAR
enums.cc_flags.ROOT

-- Spell schools
enums.spell_schools_flags.PHYSICAL
enums.spell_schools_flags.FIRE
enums.spell_schools_flags.FROST
enums.spell_schools_flags.SHADOW

-- Usage
local is_warrior = player:get_class() == enums.class_id.WARRIOR
```

---

## Critical Coding Patterns (with Code)

### Pattern 1: Menu Nil Guards

**Note**: In the current flat-file architecture, spec files access menu settings via `context.settings` or `NS.get_setting` (see Pattern 8) rather than direct `menu.x:get()` calls. The core nil-guard principle still applies to the underlying middleware that creates menu widgets.

**WRONG — Will crash if menu item nil**:
```lua
-- BAD: Direct access without nil check (old per-spec libraries/ pattern)
local mode = menu.mode:get()
local threshold = menu.heal_threshold:get()
```

**CORRECT — Safe guarded access**:
```lua
-- GOOD: Always guard menu access (99% compliance)
local mode = (menu.mode and menu.mode:get()) or 1
local threshold = (menu.heal_threshold and menu.heal_threshold:get()) or 50

-- Current pattern: via context.settings (spec files)
local function setting(context, key, fallback)
    local settings = context.settings
    if settings and settings[key] ~= nil then return settings[key] end
    if NS.get_setting then return NS.get_setting(key, fallback) end
    return fallback
end
```

**Mode/Lane Values**:
- Mode 1 = Auto (PVE/PVP automatic detection)
- Mode 2 = PVE Only
- Mode 3 = PVP Only

### Pattern 2: API Caching at Load

**Note**: In the current flat-file architecture, the NS namespace provides pre-cached wrappers (`NS.me`, `NS.gcd`, `NS.GetPlayer()`, etc.) that spec files use directly. See Pattern 10 for actual spec file usage. The raw API caching pattern below shows the underlying mechanism that core_sylvanas.lua uses to build these wrappers.

**WRONG — API call every frame (slow)**:
```lua
-- BAD: In on_update() callback
function on_update()
    local me = core.object_manager.get_local_player()  -- Expensive!
    local gcd = core.spell_book.get_global_cooldown()   -- Expensive!
end
```

**CORRECT — Cache at module load (used by core_sylvanas.lua)**:
```lua
-- GOOD: At top of core_sylvanas.lua (outside any function)
local _core_time = core.time
local _get_local_player = core.object_manager.get_local_player
local _get_gcd = core.spell_book.get_global_cooldown
local _get_enemies = core.object_manager.get_enemy_list
local _get_spell_cd = core.spell_book.get_spell_cooldown
local _cancel_form = core.spell_book.cancel_form
local _cast_spell = core.input.cast_target_spell

-- NS wrappers build on these cached references
function NS.GetPlayer()
    return _get_local_player()
end

-- Spec files then use: local me = context.me or NS.GetPlayer()
```

**Acceptable exceptions** (time-critical trackers only):
```lua
-- OK in time trackers (need fresh values)
totem_state.fire_remaining = (start_fire + dur_fire) - core.time()
```

### Pattern 3: Squared Distance Checks

**WRONG — sqrt() is expensive**:
```lua
-- BAD: math.sqrt allocates and is slow (found in legacy Hunter files)
local dist = math.sqrt(dx*dx + dy*dy)
if dist < 10 then ... end
```

**CORRECT — Compare squared**:
```lua
-- GOOD: No allocation, no sqrt
local dx = target.x - me.x
local dy = target.y - me.y
local dist_sq = dx*dx + dy*dy
if dist_sq < 100 then ... end  -- 10 yards squared = 100

-- OR via helper function
local dist_sq = dx*dx + dy*dy + dz*dz  -- 3D distance

-- Common squared values:
-- 5 yards = 25      (melee range)
-- 8 yards = 64     (Fury WW radius)
-- 10 yards = 100    (common AoE)
-- 15 yards = 225
-- 20 yards = 400
```

### Pattern 4: Static Table Reuse

**WRONG — Allocates every frame (GC pressure)**:
```lua
-- BAD: Creates new table every frame
function on_update()
    local tracked = {}  -- Allocates!
    for i, enemy in ipairs(enemies) do
        tracked[i] = enemy
    end
end
```

**CORRECT — Reuse static table**:
```lua
-- GOOD: Static table, reused every frame
local _tracked_enemies = { n = 0 }

function on_update()
    -- Clear by resetting count, not creating new table
    _tracked_enemies.n = 0
    
    for i, enemy in ipairs(enemies) do
        _tracked_enemies.n = _tracked_enemies.n + 1
        _tracked_enemies[_tracked_enemies.n] = enemy
    end
    
    -- Use n for iteration
    for i = 1, _tracked_enemies.n do
        local enemy = _tracked_enemies[i]
        -- ...
    end
end
```

### Pattern 5: Spell Casting

**Using IZI SDK (Modern Pattern)**:
```lua
local izi = require("common/izi_sdk")
local spell = izi.spell(spell_id)

-- Cast with validation
if spell:cast_safe(target) then
    return true
end

-- Check before cast
if spell:cooldown_up() and spell:can_cast(target) then
    spell:queue(target)
    return true
end
```

**Using Direct API (Legacy Pattern - Still Valid)**:
```lua
-- Cache at load
local _cast_spell = core.input.cast_target_spell

-- Cast in rotation
_cast_spell(spell_id, target)
```

**Using Spell Queue Module**:
```lua
local spell_queue = require("common/modules/spell_queue")

if spell:cooldown_up() and spell:can_cast(target) then
    spell_queue.queue_spell(spell.id, target)
    return true
end
```

**AoE Spell Casting**:
```lua
local sp = require("common/modules/spell_prediction")

-- Find best AoE position
local best_pos, hit_count = sp.get_cast_position(target, spell_data)

if best_pos and hit_count >= 3 then
    spell_queue.queue_spell(spell.id, best_pos)
end
```

### Pattern 6: Combat Context (Throttled)

**WRONG — Building context every frame (very expensive)**:
```lua
-- BAD: Never do this in on_update()
local ctx = combat_context.build(me)  -- Expensive!
```

**CORRECT — Use cached context with 2s throttle**:
```lua
-- In utils.lua or combat_context.lua
local _last_build_time = 0
local _cached_context = nil

function utils.get_cached_combat_context(me)
    local now = _core_time()
    if not _cached_context or (now - _last_build_time) > 2 then
        _cached_context = combat_context.build(me)
        _last_build_time = now
    end
    return _cached_context
end

-- Usage in main.lua
local ctx = utils.get_cached_combat_context(me)
local has_aggro = ctx.has_aggro
local incoming_dps = ctx.incoming_dps
```

### Pattern 7: Spell Resolution Caching

**Pattern in spell_resolver.lua (per-spec)**:
```lua
-- Runtime spell ID resolution with caching
local _spell_cache = {}

function utils.resolve_spell_id(spell_ranks)
    -- spell_ranks = {30335, 25251, 23894, ...} (newest to oldest)
    local cache_key = tostring(spell_ranks)
    
    if _spell_cache[cache_key] then
        return _spell_cache[cache_key]
    end
    
    -- Find highest known rank
    for _, spell_id in ipairs(spell_ranks) do
        if core.spell_book.is_spell_learned(spell_id) then
            _spell_cache[cache_key] = spell_id
            return spell_id
        end
    end
    
    return nil  -- Not learned
end

-- Usage in main.lua runtime init
function resolve_spells()
    runtime.bloodthirst_id = utils.resolve_spell_id(spells.BLOODTHIRST)
    runtime.whirlwind_id = utils.resolve_spell_id(spells.WHIRLWIND)
    -- ... etc
end
```

### Pattern 8: Menu Structure

**Note**: As of the flat-file restructure (2026-04), menu creation is handled by the NS middleware and `shared/` modules rather than per-spec `libraries/menu.lua` files. Spec files access settings via `context.settings` or `NS.get_setting` and do not create menu widgets directly.

**Standard Menu Tree Structure** (handled by middleware, not spec files):
```lua
-- Menu is constructed in shared/middleware modules, not in spec _sylvanas.lua files.
-- Spec files access settings through the context table:
local function setting(context, key, fallback)
    local settings = context.settings
    if settings and settings[key] ~= nil then return settings[key] end
    if NS.get_setting then return NS.get_setting(key, fallback) end
    return fallback
end

-- Usage in match functions:
local auto_charge = setting(context, "auto_charge", true)
local hs_rage = setting(context, "heroic_strike_rage", 60)
```

**Menu ID Naming Convention** (still used by middleware):
```lua
-- Pattern: eax<class><spec>_<feature>_<subfeature>
"eaxwarriorfury_use_bloodthirst"
"eaxwarriorfury_heroic_strike_rage"
"eaxdruidferal_powershift_enabled"
"eaxpriestshadow_vampiric_touch_refresh"
```

**Common Menu Categories**:
```lua
-- Rotation abilities
menu.use_[spellname]              -- Enable/disable spell
menu.[spell]_threshold            -- HP/Rage/Mana threshold
menu.[spell]_refresh              -- Refresh time

-- Defensives
menu.use_defensive_[name]         -- Enable defensive CD
menu.defensive_[name]_hp          -- HP threshold to trigger

-- Cooldowns (burst)
menu.use_cooldowns                -- Global CD usage
menu.use_[cd_name]                -- Individual CDs
menu.cooldown_phase               -- When to use (opener/execute/etc)

-- Automation
menu.auto_[feature]               -- Auto-enable features
menu.auto_potions                 -- Auto-use potions
menu.auto_trinkets                -- Auto-use trinkets
```

### Pattern 9: File Requires

**Spec files** use a flat namespace pattern — no per-spec `libraries/` directories. Everything comes from the global `NS` (EaxRotations) namespace or is loaded from `shared/`:
```lua
-- Global namespace access (all spec files start with this)
local NS = _G.EaxRotations
if not NS then return nil end

-- Spell tables via NS class-specific exports
local SPELLS = NS.WarriorSpells or {}
local CONSTANTS = NS.WarriorConstants or {}

-- Cross-spec modules (e.g., healing shared between discipline + holy)
local Healing = NS.PriestHealing or require("classes/priest/healing_sylvanas")

-- Shared modules via pcall (optional, graceful degradation)
local _swing_ok, SwingTimer = pcall(require, "shared/swing_timer_sylvanas")
if not _swing_ok or type(SwingTimer) ~= "table" then SwingTimer = nil end

-- Common API modules (absolute from api/)
---@type buff_manager
local buff_manager = require("common/modules/buff_manager")
---@type izi_sdk
local izi = require("common/izi_sdk")
```

**Middleware / Bootstrap files** load shared modules directly:
```lua
-- From classes/druid/middleware_sylvanas.lua
local consumable_manager = require("shared/consumable_manager_sylvanas")
local interrupt_manager = require("shared/interrupt_manager_sylvanas")

-- From classes/druid/class_sylvanas.lua
local cl = require("shared/class_loader_sylvanas")

-- Leveling dispatcher
local leveling = require("shared/leveling_sylvanas")
```

**Key principle**: Spec `_sylvanas.lua` files do NOT load shared modules with bare `require()` (unless via pcall for optionals). They rely on the NS namespace populated by the middleware/class loader, which is the single point of shared module loading.

### Pattern 10: Spec File Structure (Flat _sylvanas.lua)

**Typical `classes/<class>/<spec>_sylvanas.lua` organization**:
```lua
-- 1. Namespace access (ALL spec files start here)
local NS = _G.EaxRotations
if not NS then return nil end
local SPELLS = NS.WarriorSpells or {}
local CONSTANTS = NS.WarriorConstants or {}

-- 2. Optional shared modules (pcall for graceful degradation)
local _swing_ok, SwingTimer = pcall(require, "shared/swing_timer_sylvanas")
if not _swing_ok or type(SwingTimer) ~= "table" then SwingTimer = nil end

-- 3. Action definitions (spell IDs resolved from SPELLS table)
local ACTION = {
    Bloodthirst = SPELLS.Bloodthirst,
    Whirlwind = SPELLS.Whirlwind,
    Execute = SPELLS.Execute,
}

-- 4. Buff/debuff ID tables
local BATTLE_SHOUT_BUFF = CONSTANTS.BATTLE_SHOUT_IDS or { 25289, 2048, ... }
local SUNDER_DEBUFF = CONSTANTS.SUNDER_DEBUFF or { 25225, ... }

-- 5. Constants
local EXECUTE_DEFAULT_RAGE = 25
local BLOODTHIRST_RESERVE = 30

-- 6. State table
local fury_state = {
    rage = 0,
    hp = 100,
    target_hp = 100,
    -- ... spell readiness, buffs, debuffs, CD states
}

-- 7. Helper functions (nil-safe, pcall-guarded)
local function setting(context, key, fallback)
    local settings = context.settings
    if settings and settings[key] ~= nil then return settings[key] end
    if NS.get_setting then return NS.get_setting(key, fallback) end
    return fallback
end

local function buff_up(unit, ids)
    if NS.buff_up then return NS.buff_up(unit, ids) or false end
    return false
end

-- 8. State builder (called every tick by strategy matches)
local function build_state(context)
    local target = context.target
    local me = context.me or NS.GetPlayer()
    -- Populate state from context + NS API calls
    fury_state.rage = context.rage or 0
    fury_state.has_battle_shout = buff_up(me, BATTLE_SHOUT_BUFF)
    -- ...
    return fury_state
end

-- 9. Match functions (one per strategy; receive context + state)
local function bt_matches(context, state)
    return NS.action_matches(context, build_action("Bloodthirst", ...))
end

-- 10. Strategy table (ordered priority list)
local strategies = {
    { name = "Healthstone", matches = healthstone_matches, ... },
    { name = "Bloodthirst", matches = bt_matches, ... },
    { name = "Whirlwind", matches = whirlwind_matches, ... },
    -- ... more strategies in priority order
}

-- 11. Register with rotation registry
NS.rotation_registry:register("fury", strategies, { get_state = build_state })
NS.log("Warrior fury rotation registered")
return strategies
```

**Key architectural differences from the old `EAX<Class><Spec>/` layout**:
- No `libraries/` subdirectory — all logic is in one flat `_sylvanas.lua` file
- No `menu.lua`, `spells.lua`, `utils.lua` per spec — spells come from NS class tables, settings from context
- Strategies are registered via `NS.rotation_registry:register()` not via `core.register_on_update_callback()`
- The main dispatcher (`main_sylvanas.lua`) iterates registered strategies in priority order
- Cross-cutting concerns (interrupts, consumables, racials) live in `shared/` modules

### Pattern 11: Aura Points — buff_points / debuff_points

**Purpose**: Read variable values (`points`) from aura data — e.g., absorb remaining on shields, Holy Shield charges, or any buff/debuff with numeric state beyond stacks.

**API (core_sylvanas.lua, lines ~3130-3170)**:
```lua
--- Returns the points array from buff aura data.
--- Useful for variable-value buffs like absorb shields.
---@param unit game_object The unit to check.
---@param ids table Array of spell IDs (highest rank first).
---@return number[]|nil points The points array from active buff data, or nil.
function NS.buff_points(unit, ids)
    if not unit then return nil end
    local data = aura_data(unit, ids, "buff")
    if not data then return nil end
    local points = data.points
    if type(points) == "table" then return points end
    return nil
end

--- Returns the points array from debuff aura data.
---@param unit game_object The unit to check.
---@param ids table Array of spell IDs.
---@return number[]|nil points The points array from active debuff data, or nil.
function NS.debuff_points(unit, ids)
    if not unit then return nil end
    local data = aura_data(unit, ids, "debuff")
    if not data then return nil end
    local points = data.points
    if type(points) == "table" then return points end
    return nil
end
```

**Example — Holy Shield charges (protection_sylvanas.lua)**:
```lua
local HOLY_SHIELD_BUFF = { 27179, 27178, 27177, 20925 }

-- In build_state():
prot_state.holy_shield_charges = 0
if prot_state.has_holy_shield and type(NS.buff_points) == "function" then
    local pts = NS.buff_points(me, HOLY_SHIELD_BUFF)
    prot_state.holy_shield_charges = (pts and pts[1]) or 0
end

-- In strategy matches (skip refresh if charges remain):
local charges = state.holy_shield_charges or 0
if charges > 2 then return false end  -- Still has meaningful charges
```

**Notes**:
- `points` is an array of numbers — `points[1]` is typically the primary variable value
- Always nil-guard the result: `(pts and pts[1]) or 0`
- Falls through to nil if no matching aura found
- Distinct from `get_buff_stacks()` — stacks are integer counts, points are arbitrary numeric values
- Used by: protection_sylvanas.lua (Holy Shield), healing_sylvanas.lua (PW:S absorb)

### Pattern 12: PW:S Absorb Tracking (healing + discipline)

**Purpose**: Prevent overwriting a healthy Power Word: Shield by tracking the remaining absorb value via `NS.buff_points`.

**Helper — healing_sylvanas.lua**:
```lua
local POWER_WORD_SHIELD_BUFF_IDS = { 25348, 25347, 25346, 25345, 25344,
                                      25343, 25342, 25341, 25340, 25339,
                                      25338, 25337, 25336, 25335, 25334, 25333 }

local function pws_absorb_remaining(unit)
    if not unit then return 0 end
    if type(NS.buff_points) ~= "function" then
        -- Fallback: buff_points not yet available (core loaded after this module)
        -- has_pws(unit) checks NS.buff_up on POWER_WORD_SHIELD_BUFF_IDS (local helper)
        return has_pws(unit) and 1 or 0
    end
    local points = NS.buff_points(unit, POWER_WORD_SHIELD_BUFF_IDS)
    if not points then return 0 end
    return points[1] or 0
end

-- Export for cross-spec use
NS.PriestHealing.pws_absorb_remaining = pws_absorb_remaining
```

**Consumer — discipline_sylvanas.lua (emergency_pws_matches)**:
```lua
-- Import healing module
local Healing = NS.PriestHealing or require("classes/priest/healing_sylvanas")

local function emergency_pws_matches(context, s)
    if not s.lowest then return false end
    if (s.lowest.effective_hp or 100) > (context.settings.discipline_pws_hp or 35) then return false end
    if s.lowest.has_weakened_soul then return false end
    if not s.pws_ready then return false end
    -- Respect existing absorb: don't overwrite a healthy PW:S shield
    if Healing.pws_absorb_remaining then
        local absorb = Healing.pws_absorb_remaining(s.lowest.unit)
        -- Threshold 200 (~16% of a fresh ~1265 absorb): shield is nearly depleted
        if absorb > 200 then return false end
    end
    return NS.action_matches(context, EMERGENCY_PWS_ACTION)
end
```

**Design rationale**:
- **200 threshold**: TBC PW:S (rank 12, spell ID 25348) absorbs ~1265 base; with +healing bonus, a fresh shield is 1500-2000. At 200 remaining, the shield is nearly depleted (10-16%) and safe to refresh.
- **Nil-guard on `Healing.pws_absorb_remaining`**: If the healing module hasn't loaded (rare, core-load-order edge case), the absorb check is skipped and PW:S proceeds as before — no regression.
- **Fallback in pws_absorb_remaining**: If `NS.buff_points` isn't available, returns `has_pws(unit) and 1 or 0`. Since 1 ≤ 200, PW:S would still cast, matching old behavior.

### Pattern 13: Smart Innervate Targeting (balance + resto)

**Purpose**: Prefer low-mana healer-class party members over self for Innervate, falling back to self when no healer needs it. Ported from Resto spec to Balance spec.

**Shared constant — HEALER_CLASS_IDS**:
```lua
-- Healer class IDs for Innervate priority: Paladin(2), Priest(5), Shaman(7), Druid(11)
-- Present in both balance_sylvanas.lua and resto_sylvanas.lua
local HEALER_CLASS_IDS = { [2] = true, [5] = true, [7] = true, [11] = true }
```

**State field**:
```lua
local balance_state = {
    -- ... other fields ...
    innervate_target = nil,  -- game_object: best Innervate target (healer or self)
}
```

**Party scan in build_state()** (balance_sylvanas.lua):
```lua
-- Smart Innervate target: prefer low-mana healers, fall back to self
local healer_mana_floor = (context.settings and context.settings.balance_innervate_mana) or 30
if context.in_combat and context.is_group and context.me and NS.GetPartyMembers then
    local party = NS.GetPartyMembers()
    if party and type(party) == "table" then
        for _, u in ipairs(party) do
            if u then
                local is_self = NS.same_unit and NS.same_unit(u, context.me)
                if not is_self then
                    -- pcall-safe class check
                    local class_id = nil
                    if NS.safe_field then
                        local getter = NS.safe_field(u, "get_class")
                        if getter then
                            local ok, val = pcall(getter, u)
                            if ok and type(val) == "number" then class_id = val end
                        end
                    end
                    if class_id and HEALER_CLASS_IDS[class_id] then
                        local mana = NS.mana_pct(u)
                        if mana <= (healer_mana_floor + 5) then
                            balance_state.innervate_target = u
                            break  -- First low-mana healer wins
                        end
                    end
                end
            end
        end
    end
end
-- Fallback: cast on self if own mana is low
if not balance_state.innervate_target then
    if (balance_state.mana_pct or 100) <= healer_mana_floor then
        balance_state.innervate_target = context.me
    end
end
```

**Split strategy — InnervateHealer + InnervateSelf**:
```lua
-- Strategy: InnervateHealer (prefer healer)
{
    name = "InnervateHealer",
    matches = function(context, state)
        if not context.in_combat then return false end
        if not state.innervate_target then return false end
        -- Only match if target is NOT self (healer found)
        if context.me and NS.same_unit and NS.same_unit(state.innervate_target, context.me) then
            return false
        end
        return NS.spell_ready(LOCAL_SPELLS.Innervate, state.innervate_target)
    end,
    execute = function(_, state)
        return NS.try_cast(LOCAL_SPELLS.Innervate, state.innervate_target, "[BALANCE] Innervate → healer")
    end,
},
-- Strategy: InnervateSelf (fallback)
{
    name = "InnervateSelf",
    matches = function(context, state)
        if not context.in_combat then return false end
        if not state.innervate_target then return false end
        -- Only match if target IS self
        if not context.me or not NS.same_unit or not NS.same_unit(state.innervate_target, context.me) then
            return false
        end
        return NS.spell_ready(LOCAL_SPELLS.Innervate, context.me)
    end,
    execute = function(context)
        return NS.try_cast(LOCAL_SPELLS.Innervate, context.me, "[BALANCE] Innervate self")
    end,
},
```

**Performance notes**:
- Party scan runs every tick in `build_state()`, but is gated behind `context.in_combat` and `context.is_group` — zero overhead in solo play
- Uses `break` after finding first matching healer ("first low-mana healer wins") — no full party iteration when target found early
- pcall-guarded `unit:get_class()` prevents crashes on invalid unit objects
- `NS.mana_pct()` nil-safe (returns nil for invalid units, handled by `<=` returning false)

---

## Menu Item Reference

### Menu Types & Defaults

| Menu Type | Constructor | Default | Range | Example |
|-----------|-------------|---------|-------|---------|
| Checkbox | `core.menu.checkbox(true, id)` | true/false | - | `menu.use_bt = core.menu.checkbox(true, "eaxwarr_use_bt")` |
| Slider (int) | `core.menu.slider_int(min, max, default, id)` | varies | 0-100 | `menu.hp_threshold = core.menu.slider_int(0, 100, 30, "eaxwarr_hp")` |
| Combobox | `core.menu.combobox(1, id)` | 1 (Auto) | 1-3 | `menu.mode = core.menu.combobox(1, "eaxwarr_mode")` |
| Keybind | `core.menu.keybind(key, shift, id)` | 7 (F8) | - | `menu.toggle = core.menu.keybind(7, false, "eaxwarr_toggle")` |
| Color | `core.menu.color(default, id)` | - | RGBA | `menu.color = core.menu.color({255,0,0,255}, "eaxwarr_color")` |
| Text | `core.menu.text(default, id)` | "" | string | `menu.name = core.menu.text("Default", "eaxwarr_name")` |

### Menu ID Naming Convention

```lua
-- Pattern: eax<class><spec>_<feature>_<subfeature>
"eaxwarriorfury_use_bloodthirst"
"eaxwarriorfury_heroic_strike_rage"
"eaxdruidferal_powershift_enabled"
"eaxpriestshadow_vampiric_touch_refresh"
```

### Common Menu Categories

```lua
-- Rotation abilities
menu.use_[spellname]              -- Enable/disable spell
menu.[spell]_threshold            -- HP/Rage/Mana threshold
menu.[spell]_refresh              -- Refresh time

-- Defensives
menu.use_defensive_[name]         -- Enable defensive CD
menu.defensive_[name]_hp          -- HP threshold to trigger

-- Cooldowns (burst)
menu.use_cooldowns                -- Global CD usage
menu.use_[cd_name]                -- Individual CDs
menu.cooldown_phase               -- When to use (opener/execute/etc)

-- Automation
menu.auto_[feature]               -- Auto-enable features
menu.auto_potions                 -- Auto-use potions
menu.auto_trinkets                -- Auto-use trinkets
```

---

## Testing Rules

- Run `luac -p` on every modified file before commit
- Run `lua EaxRotations/tests/run_rotation_tests.lua` — all 95 rotation suites must pass
- Run `lua EaxRotations/tests/run_leveling_tests.lua` — all 11 leveling suites must pass
- `lsp_diagnostics` must show 0 errors on changed files
- Verify syntax passes before marking any task complete

---

## Boundaries

### ✅ Always
- Cache hot-path APIs at module load (`local _core_time = core.time`)
- Throttle expensive calls (`combat_context.build()` → 2s, `detect_mode()` → 5s)
- Use `spell_resolver.lua` for `is_spell_learned()` caching
- Limit target scan to 50 objects with early exit
- Use Project Sylvanas API (`api/`, `apidocs/`) exclusively
- Nil-guard ALL menu references: `(menu.x and menu.x:get()) or default`
- Use squared distance for range checks (not `math.sqrt`)
- Reuse static tables with `{ n = 0 }` pattern

### ⚠️ Ask First
- Add new shared modules to `EaxRotations/shared/`
- Modify `core_sylvanas.lua` NS helper patterns
- Add new menu items (handled by middleware, not spec files)
- Refactor multiple specs simultaneously
- Use APIs outside `api/` or `apidocs/`
- Change strategy registration patterns (`NS.rotation_registry:register()`)

### 🚫 Never
- `ffi.C`, `io.popen`, `os.execute`, `debug.*` — banned APIs (100% compliance verified)
- Commit `.zip` or vendor automation files (100% compliance verified)
- Add WotLK/Cata spells (TBC-era only: spells up to patch 2.4.3)
- Suppress type errors with `as any` or `@ts-ignore`
- Use `math.sqrt()` for distance comparisons (only legacy Hunter files violate)
- Reference external platform APIs
- Call expensive APIs in `on_update()` without caching
- Create garbage in tight loops (use static tables)
- Access `menu.x:get()` without nil guard (only `.orig` backup files violate)

---

## Pattern Adoption Statistics (Verified 2026-05-21)

| Pattern | Adoption Rate | Violations | Notes |
|---------|---------------|------------|-------|
| Menu nil guards | 100% | None | Via context.settings + NS.get_setting |
| API caching (NS wrappers) | 100% | None | NS.me, NS.gcd, NS.GetPlayer() pre-cached |
| Squared distance | 100% | None | All distance checks use squared comparison |
| Static table reuse | 100% | None | Perfect compliance |
| Buff/debuff checks | 100% | None | Widely used |
| Aura points (buff_points) | 100% | None | 3 specs (protection, healing, discipline) |
| PW:S absorb tracking | 100% | None | healing + discipline cross-spec |
| Smart Innervate targeting | 100% | None | balance + resto (healer-class party scan) |
| Banned APIs | 100% | None | Perfect compliance |
| No TOC files | 100% | None | N/A under flat-file architecture |

---

## Key Files Quick Reference

| File | Purpose | Lines (typical) |
|------|---------|-----------------|
| `EaxRotations/classes/<class>/<spec>_sylvanas.lua` | Spec rotation (strategies, state, matches, execute) | 200-600 |
| `EaxRotations/main_sylvanas.lua` | Main rotation engine, dispatcher | 500+ |
| `EaxRotations/core_sylvanas.lua` | Core NS helpers (buff_points, spell_ready, etc.) | 5000+ |
| `EaxRotations/shared/healer_engine_sylvanas.lua` | Healing scan / triage engine | 300+ |
| `EaxRotations/shared/class_loader_sylvanas.lua` | Class-level bootstrapping | 200+ |
| `EaxRotations/shared/consumable_manager_sylvanas.lua` | Healthstone/potion automation | 100+ |
| `EaxRotations/shared/swing_timer_sylvanas.lua` | Melee swing timer (Slam weaving) | 200+ |
| `EaxRotations/shared/leveling_sylvanas.lua` | Leveling rotation dispatcher | 300+ |
| `EaxRotations/classes/priest/healing_sylvanas.lua` | Priest healing helpers (pws_absorb_remaining, etc.) | 100+ |
| `EaxRotations/classes/priest/discipline_sylvanas.lua` | Priest Discipline spec (absorbs, PW:S) | 500+ |
| `EaxRotations/classes/druid/balance_sylvanas.lua` | Druid Balance spec (Innervate targeting, SP breakpoints) | 300+ |
| `EaxRotations/classes/paladin/protection_sylvanas.lua` | Paladin Protection spec (Holy Shield charges) | 200+ |
| `EaxRotations/tests/run_rotation_tests.lua` | Rotation test runner (95 suites) | 100+ |
| `EaxRotations/tests/run_leveling_tests.lua` | Leveling test runner (11 suites) | 50+ |
| `api/core.lua` | Core Sylvanas API | 4374 |
| `api/common/izi_sdk.lua` | High-level SDK | 1681 |
| `api/common/modules/spell_queue.lua` | Spell queueing | 200+ |
| `api/common/modules/target_selector.lua` | Target selection | 150+ |
| `api/common/buff_db.lua` | Buff/debuff database | 578 |
| `api/common/enums.lua` | Game enums | 394 |
| `apidocs/pages/dev/api/core.md` | Core API docs | 680 |
| `AGENTS.md` | This file | 700+ |

---

## API Documentation Usage

**Quick Reference**:
- `apidocs/pages/dev/api/core.md` — Callbacks, logging, time, HTTP
- `apidocs/pages/dev/api/game-object.md` — Unit methods
- `apidocs/pages/dev/api/spellbook.md` — Spell casting
- `apidocs/pages/dev/api/buffs.md` — Buff/debuff queries
- `apidocs/pages/dev/modules/` — Helper modules

**LLM Corpus**:
- `apidocs/corpus.jsonl` — 2877 chunks for retrieval
- `apidocs/pages_manifest.jsonl` — Page metadata

---

## Confidence & Freshness

| Section | Confidence | Notes |
|---------|------------|-------|
| Project Structure | ✅ High | Verified 2026-05-21 — 29 specs confirmed, flat-file architecture |
| Menu Guard Pattern | ✅ High | 100% compliance via context.settings |
| API Caching Pattern | ✅ High | 100% compliance via NS namespace wrappers |
| Sylvanas API | ✅ High | From `api/` and `apidocs/` — source of truth |
| IZI SDK | ✅ High | `api/common/izi_sdk.lua` — fully documented |
| TBC Spell Lists | ✅ High | Validated against TBC sim data |
| Spell Resolver | ✅ High | Per-spec implementation confirmed |
| Combat Context | ✅ High | Per-spec with 2s throttle pattern |
| Pattern Statistics | ✅ High | Verified via grep across all files |

---

## Session Start Protocol

1. Work from `C:\newbot\scripts`
2. Check Sylvanas runtime status:
   ```bash
   git status --short --branch
   git log --oneline -5
   ```
3. Read target spec's file: `EaxRotations/classes/<class>/<spec>_sylvanas.lua` and related `shared/` modules if needed
4. Run `luac -p` on any file before editing
5. Validate with test suite: `lua EaxRotations/tests/run_rotation_tests.lua` and `lua EaxRotations/tests/run_leveling_tests.lua`
6. Verify with `lsp_diagnostics` after changes

---

## Orchestration Defaults (Performance)

**User Preference: Maximum speed + quality. Apply automatically.**

### Parallel Execution
- Always fire 3-5 agents simultaneously for multi-file searches
- Default to `run_in_background=true` unless blocking truly required
- Batch file reads - never sequential

### Token Efficiency  
- Use `smart_search`/`smart_outline` instead of reading full files
- Use `smart_unfold` only for specific symbols that need full source
- Apply `head_limit` to glob results to avoid over-reading

### Category Matching
| Task Type | Category |
|---|---|
| UI/styling/animations | `visual-engineering` |
| Complex logic/algorithms | `ultrabrain` |
| Multi-file refactor | `deep` |
| Single file fix | `quick` |
| Documentation | `writing` |

### Session Continuity
- Always capture `session_id` from task outputs
- Reuse `session_id` for all follow-ups to same agent
- Never start fresh conversations with agents mid-task

### Delegation Pattern
- Decompose all non-trivial tasks before acting
- Delegate to specialized agents rather than implementing directly
- Include explicit MUST DO / MUST NOT DO in all prompts

---

*This file is agent-curated. Update when patterns change or APIs are adopted.*
