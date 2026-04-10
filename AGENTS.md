# EAX TBC Classic Rotations — Agent Context

**Repo**: https://github.com/eaxiumnet/eax-tbc-classic-rotations  
**Local Path**: `C:\newbot\scripts`  
**Last Updated**: 2026-04-09  
**Specs**: 29 TBC Classic class specializations  
**Pattern Compliance**: 99% menu guards, 95% API caching, 100% banned API compliance

---

## Project Identity

**What This Is**: 29 World of Warcraft: The Burning Crusade Classic rotation plugins for Project Sylvanas. Each plugin (`EAX<Class><Spec>/`) provides automated spell/ability sequencing for one class specialization with optimized DPS/HPS/TPS rotations.

**Primary Objective**: Deliver crash-free, TBC-accurate rotation logic with minimal API overhead and consistent patterns across all 29 specs.

**Hard Constraints**:
- TBC-era spells only — never add WotLK/Cata abilities
- Never ship `.toc` files
- All menu references must be nil-guarded to prevent crashes
- `luac -p` must pass on every modified file
- Only Project Sylvanas API (`api/`, `apidocs/`) — no external platforms

---

## Complete Project Structure

```
C:\newbot\scripts/
├── AGENTS.md                          # This file — agent operational context
├── README.md                          # Project overview
├── CHANGELOG.md                       # Version history
│
├── EAXDruidBalance/                   # 29 spec directories
├── EAXDruidBear/
├── EAXDruidFeral/
├── EAXDruidResto/
├── EAXHunterBM/
├── EAXHunterMM/
├── EAXHunterSurvival/
├── EAXMageArcane/
├── EAXMageFire/
├── EAXMageFrost/
├── EAXPaladinHoly/
├── EAXPaladinProtection/
├── EAXPaladinRetribution/
├── EAXPriestDiscipline/
├── EAXPriestHoly/
├── EAXPriestShadow/
├── EAXPriestSmite/
├── EAXRogueAssassination/
├── EAXRogueCombat/
├── EAXRogueSubtlety/
├── EAXShamanElemental/
├── EAXShamanEnhancement/
├── EAXShamanRestoration/
├── EAXWarlockAffliction/
├── EAXWarlockDemonology/
├── EAXWarlockDestruction/
├── EAXWarriorArms/
├── EAXWarriorFury/
└── EAXWarriorProtection/

    Each EAX<Class><Spec>/ contains:
    ├── main.lua                       # On-update loop, rotation engine (200-800 lines)
    ├── header.lua                     # Plugin metadata, load conditions
    ├── plugin_info.lua                # Name, version, spec_id
    └── libraries/                     # Per-spec libraries (15-30 files)
        ├── menu.lua                   # Settings UI (400+ lines typical)
        ├── spells.lua                 # Spell ID tables, talent gating
        ├── utils.lua                  # Helper functions
        ├── spell_resolver.lua         # Spell ID resolution caching
        ├── combat_context.lua         # Throttled combat data builder
        ├── ooc_manager.lua           # Out-of-combat rotation
        ├── defensive_manager.lua     # Defensive CD automation
        ├── interrupt_manager.lua     # Kick/interrupt logic
        ├── racial_manager.lua        # Racial ability usage
        ├── burst_manager.lua         # Burst CD timing
        ├── trinket_manager.lua       # Trinket automation
        ├── swing_manager.lua         # Swing timer tracking
        ├── middleware_manager.lua    # Middleware chain
        ├── anti_fake_manager.lua     # Anti-fake cast detection
        ├── dashboard.lua             # HUD/dashboard rendering
        ├── ps_theme.lua              # PS theme integration
        ├── cc_detector.lua           # CC detection
        ├── mana_manager.lua          # Mana tracking (casters)
        ├── heal_context.lua          # Healing context (healers)
        ├── energy_tick.lua           # Energy tick tracking (rogue)
        ├── powershift.lua            # Powershift management (druid)
        └── settings_framework.lua    # Settings persistence

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

├── tools/                            # Build/validation scripts
└── dist/                             # Build output (eax_ship)

Archive folders (not part of active specs):
├── archive_original_specs/          # Original spec implementations (legacy)
└── _archive_legacy/                 # Legacy code archive
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
izi.on_spell_fail(callback)

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

### Pattern 1: Menu Nil Guards (435 matches, 61 files)

**WRONG — Will crash if menu item nil**:
```lua
-- BAD: Direct access without nil check
local mode = menu.mode:get()
local threshold = menu.heal_threshold:get()
```

**CORRECT — Safe guarded access**:
```lua
-- GOOD: Always guard menu access (99% compliance)
local mode = (menu.mode and menu.mode:get()) or 1
local threshold = (menu.heal_threshold and menu.heal_threshold:get()) or 50
local enabled = (menu.enabled and menu.enabled:get()) or false

-- Pattern for sliders with ranges
local hp_pct = (menu.defensive_hp and menu.defensive_hp:get()) or 30
local rage_threshold = (menu.heroic_strike_rage and menu.heroic_strike_rage:get()) or 50

-- Alternative with pcall (overkill, prefer nil guard)
local ok, v = pcall(function() return menu.leveling_mana_floor:get() end)
```

**Mode/Lane Values**:
- Mode 1 = Auto (PVE/PVP automatic detection)
- Mode 2 = PVE Only
- Mode 3 = PVP Only

### Pattern 2: API Caching at Load (587 matches, 257 files)

**WRONG — API call every frame (slow)**:
```lua
-- BAD: In on_update() callback
function on_update()
    local me = core.object_manager.get_local_player()  -- Expensive!
    local gcd = core.spell_book.get_global_cooldown()   -- Expensive!
end
```

**CORRECT — Cache at module load**:
```lua
-- GOOD: At top of main.lua (outside any function)
local _core_time = core.time
local _get_local_player = core.object_manager.get_local_player
local _get_gcd = core.spell_book.get_global_cooldown
local _get_enemies = core.object_manager.get_enemy_list
local _get_spell_cd = core.spell_book.get_spell_cooldown
local _cancel_form = core.spell_book.cancel_form
local _cast_spell = core.input.cast_target_spell

-- Then use cached references in callbacks
function on_update()
    local me = _get_local_player()
    local gcd = _get_gcd()
end
```

**Acceptable exceptions** (time-critical trackers only):
```lua
-- OK in time trackers (need fresh values)
totem_state.fire_remaining = (start_fire + dur_fire) - core.time()
```

### Pattern 3: Squared Distance Checks (74 matches, 24 files)

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

### Pattern 4: Static Table Reuse (24 matches, 24 files)

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

**Standard Menu Tree Structure**:
```lua
-- From EAXWarriorFury/libraries/menu.lua
local ps = require("libraries/ps_theme")

-- Tree nodes
local root_tree        = ps.tree_node()
local rotation_tree    = ps.tree_node()
local cooldowns_tree   = ps.tree_node()
local defensive_tree   = ps.tree_node()
local utility_tree     = ps.tree_node()
local pvp_tree         = ps.tree_node()
local automation_tree  = ps.tree_node()
local advanced_tree    = ps.tree_node()

-- Menu items (with proper prefix)
menu.enabled = core.menu.checkbox(true, "eaxwarriorfury_enabled")
menu.mode = core.menu.combobox(1, "eaxwarriorfury_mode")
menu.toggle_key = core.menu.keybind(7, false, "eaxwarriorfury_toggle_key")
menu.use_bloodthirst = core.menu.checkbox(true, "eaxwarriorfury_use_bloodthirst")
menu.heroic_strike_rage = core.menu.slider_int(20, 100, 50, "eaxwarriorfury_hs_rage")

-- Tree hierarchy
ps.add_sub_item(root_tree, rotation_tree, "Rotation")
ps.add_sub_item(root_tree, cooldowns_tree, "Cooldowns")
ps.add_sub_item(rotation_tree, menu.use_bloodthirst)
```

**Menu Rendering**:
```lua
function menu.render()
    if _win and root_tree:is_open() then
        ps.draw_space(_win, "eaxwarriorfury")
    end

    root_tree:render("Eax's Warrior Fury", function()
        ps.header("General")
        menu.enabled:render("Enabled", "Enable/disable rotation")
        menu.mode:render("Mode", {"Auto", "PvE", "PvP"})
        
        rotation_tree:render("Rotation", function()
            menu.use_bloodthirst:render("Bloodthirst", "Core Fury attack")
        end)
    end)
end
```

**Settings Framework Integration**:
```lua
local settings = require("libraries/settings_framework")

settings.setup_major_toggle_keybinds(menu, {
    { toggle = "use_rampage", label = "Rampage" },
    { toggle = "use_execute", label = "Execute" },
}, {
    namespace = "eaxwarriorfury",
    log_prefix = "[Eax Warrior Fury] ",
})
```

### Pattern 9: File Requires

**Standard Spec Requires (main.lua)**:
```lua
-- Local libraries (relative to spec directory)
local menu = require("libraries/menu")
local spells = require("libraries/spells")
local utils = require("libraries/utils")

-- Common API modules (absolute from api/)
---@type buff_manager
local buff_manager = require("common/modules/buff_manager")
---@type auto_attack_helper
local auto_attack = require("common/utility/auto_attack_helper")
---@type izi_sdk
local izi = require("common/izi_sdk")

-- Optional managers
local interrupt_manager = require("libraries/interrupt_manager")
local racial_manager = require("libraries/racial_manager")
local ooc_manager = require("libraries/ooc_manager")
local middleware_manager = require("libraries/middleware_manager")
local dashboard = require("libraries/dashboard")
local burst_manager = require("libraries/burst_manager")
local trinket_manager = require("libraries/trinket_manager")
```

### Pattern 10: Main.lua Structure

**Typical main.lua organization**:
```lua
-- 1. Requires
local menu = require("libraries/menu")
local spells = require("libraries/spells")
local utils = require("libraries/utils")
local buff_manager = require("common/modules/buff_manager")

-- 2. API caching (CRITICAL)
local _core_time = core.time
local _get_local_player = core.object_manager.get_local_player
local _get_gcd = core.spell_book.get_global_cooldown

-- 3. Constants
local EXECUTE_HP_THRESHOLD = 20
local FURY_AOE_RADIUS = 8

-- 4. Runtime spell storage
local runtime = {
    bloodthirst_id = nil,
    whirlwind_id = nil,
}

-- 5. Spell resolution specs
local RUNTIME_SPELL_SPECS = {
    { field = "bloodthirst_id", ranks = spells.BLOODTHIRST },
    { field = "whirlwind_id", ranks = spells.WHIRLWIND },
}

-- 6. Init function
local function init()
    for i = 1, #RUNTIME_SPELL_SPECS do
        local spec = RUNTIME_SPELL_SPECS[i]
        runtime[spec.field] = utils.resolve_spell_id(spec.ranks)
    end
end

-- 7. Update callback
local function on_update()
    local me = _get_local_player()
    if not me then return end
    
    -- Menu guards
    local mode = (menu.mode and menu.mode:get()) or 1
    if not (menu.enabled and menu.enabled:get()) then return end
    
    -- Rotation logic here
end

-- 8. Register callbacks
core.register_on_update_callback(on_update)
core.register_on_render_callback(menu.on_render)
core.register_on_render_menu_callback(menu.on_menu_render)
init()
```

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
- `lsp_diagnostics` must show 0 errors on changed files
- Build with `python tools/export_eax_plugins.py` must succeed
- Never commit `.toc` files (delete if found)
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
- Add new shared libraries to spec `libraries/`
- Modify `spell_resolver.lua` or `combat_context.lua` patterns
- Add new menu items that require `utils.lua` changes
- Refactor multiple specs simultaneously
- Use APIs outside `api/` or `apidocs/`
- Change menu tree structure (affects all specs)

### 🚫 Never
- `ffi.C`, `io.popen`, `os.execute`, `debug.*` — banned APIs (100% compliance verified)
- Commit `.toc`, `.zip`, or vendor automation files (100% compliance verified)
- Add WotLK/Cata spells (TBC-era only: spells up to patch 2.4.3)
- Suppress type errors with `as any` or `@ts-ignore`
- Use `math.sqrt()` for distance comparisons (only legacy Hunter files violate)
- Reference external platform APIs
- Call expensive APIs in `on_update()` without caching
- Create garbage in tight loops (use static tables)
- Access `menu.x:get()` without nil guard (only `.orig` backup files violate)

---

## Pattern Adoption Statistics (Verified)

| Pattern | Adoption Rate | Violations | Notes |
|---------|---------------|------------|-------|
| Menu nil guards | 99% | 1 file (.orig backups) | Excellent compliance |
| API caching | 95% | Legacy trackers only | Acceptable exceptions |
| Squared distance | 80% | Hunter archive files | Legacy code only |
| Static table reuse | 100% | None | Perfect compliance |
| Buff/debuff checks | 100% | None | Widely used |
| Banned APIs | 100% | None | Perfect compliance |
| No TOC files | 100% | None | Perfect compliance |

---

## Key Files Quick Reference

| File | Purpose | Lines (typical) |
|------|---------|-----------------|
| `EAX<Class><Spec>/main.lua` | On-update loop, priority engine | 200-800 |
| `EAX<Class><Spec>/libraries/spells.lua` | Spell ID tables, talent gating | 50-150 |
| `EAX<Class><Spec>/libraries/utils.lua` | Helper functions | 100-300 |
| `EAX<Class><Spec>/libraries/menu.lua` | Settings UI | 300-500 |
| `EAX<Class><Spec>/libraries/spell_resolver.lua` | Spell ID resolution | 50-100 |
| `EAX<Class><Spec>/libraries/combat_context.lua` | Throttled context builder | 100-200 |
| `EAX<Class><Spec>/libraries/middleware_manager.lua` | Middleware integration | 100-200 |
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
| Project Structure | ✅ High | Verified 2026-04-09 — 29 specs confirmed |
| Menu Guard Pattern | ✅ High | 435 matches in 61 files — 99% compliance |
| API Caching Pattern | ✅ High | 587 matches in 257 files — 95% compliance |
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
3. Read target spec's files: `main.lua`, `libraries/menu.lua`, `libraries/utils.lua`
4. Run `luac -p` on any file before editing
5. Verify with `lsp_diagnostics` after changes

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
