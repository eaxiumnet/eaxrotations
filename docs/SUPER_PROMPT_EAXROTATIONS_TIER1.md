# SUPER PROMPT: Tier #1 Rotation Engine for EaxRotations
## Based on Flux AIO + Sonah Analysis → Sylvanas API Mapping

---

## SECTION 1: CORE ARCHITECTURE REQUIREMENTS

### 1.1 Priority-Ordered Strategy Registry (Flux Pattern)

**Requirement**: Implement a priority-ordered strategy registry where strategies are tried in sequence, first match wins.

**Sylvanas API Mapping**:
```lua
-- Use core.register_on_update_callback with throttling
local _core_time = core.time
local _last_update = 0
local UPDATE_INTERVAL = 0.05  -- 50ms = 20 FPS for rotation logic

core.register_on_update_callback(function()
    local now = _core_time()
    if now - _last_update < UPDATE_INTERVAL then return end
    _last_update = now
    
    -- Build context (see 1.2)
    -- Execute middleware (highest priority first)
    -- Execute playstyle strategies (priority order)
    -- First successful action wins
end)
```

**Key Pattern from Flux**:
- Middleware runs BEFORE strategies (defensives, interrupts, trinkets)
- Each strategy has: `matches(context, state)` → boolean, `execute(icon, context, state)` → result
- Priority is POSITIONAL in the array, not a numeric score

### 1.2 Context Object Pattern (Flux + Sonah)

**Requirement**: Build a reusable context table each frame with ALL game state needed for decisions.

**Sylvanas API Mapping**:
```lua
local _cached_context = {}
local _last_context_build = 0
local CONTEXT_CACHE_TTL = 0.05  -- 50ms

local function build_context()
    local now = _core_time()
    if now - _last_context_build < CONTEXT_CACHE_TTL then
        return _cached_context
    end
    _last_context_build = now
    
    local me = _get_local_player()
    if not me then return nil end
    
    local target = me:get_target()
    
    -- Core state (Sonah pattern)
    _cached_context.player_hp = me:get_health_percentage()
    _cached_context.player_mana = me:get_mana_percentage()
    _cached_context.in_combat = me:is_in_combat()
    _cached_context.on_gcd = _get_gcd() > 0.1
    _cached_context.ttd = NS.get_time_to_die(target)
    
    -- Sylvanas-specific (from AGENTS.md)
    _cached_context.target_range = target and me:get_distance(target) or 999
    _cached_context.in_melee = target and me:get_distance(target) <= 5
    _cached_context.has_aggro = me:get_threat_situation() >= 2
    
    return _cached_context
end
```

**Context Fields (from Flux/Sonah analysis)**:
- `player_hp`, `player_mana`, `player_rage`, `player_energy`, `player_combo_points`
- `in_combat`, `on_gcd`, `combat_time`
- `target_hp`, `target_range`, `in_melee_range`, `target_is_boss`, `ttd`
- `enemy_count` (AoE detection via izi.any_enemy())
- `has_breakable_cc_nearby` (Flux PvP pattern)
- `is_pvp`, `target_is_player` (Sonah pattern)
- `settings` (cached menu values, see 1.3)

### 1.3 Settings Schema Pattern (Flux + Sonah)

**Requirement**: ALL behavior controlled by settings, never hardcoded. Use menu nil guards.

**Sylvanas API Mapping**:
```lua
-- In schema_sylvanas.lua
menu.use_defensive = core.menu.checkbox(true, "eax<class><spec>_use_defensive")
menu.defensive_hp_threshold = core.menu.slider_int(0, 100, 35, "eax<class><spec>_def_hp")
menu.mode = core.menu.combobox(1, "eax<class><spec>_mode")  -- 1=Auto, 2=PVE, 3=PVP

-- In rotation (ALWAYS nil-guard)
local mode = (menu.mode and menu.mode:get()) or 1
local use_def = (menu.use_defensive and menu.use_defensive:get()) or false
local hp_threshold = (menu.defensive_hp_threshold and menu.defensive_hp_threshold:get()) or 35

-- Settings caching (Flux pattern - 50ms TTL)
local _cached_settings = {}
local _last_settings_refresh = 0

local function refresh_settings()
    local now = _core_time()
    if now - _last_settings_refresh > 0.05 then
        _cached_settings.use_defensive = (menu.use_defensive and menu.use_defensive:get()) or false
        _cached_settings.defensive_hp = (menu.defensive_hp_threshold and menu.defensive_hp_threshold:get()) or 35
        _last_settings_refresh = now
    end
    return _cached_settings
end
```

**Sonah Pattern**: Flat SavedVariables structure, not nested. EaxRotations already uses this via NS.settings.*

### 1.4 Middleware System (Flux Pattern)

**Requirement**: Shared cross-cutting concerns run before playstyle strategies.

**Sylvanas API Mapping**:
```lua
-- In middleware_sylvanas.lua
local middleware_registry = {}

function NS.register_middleware(name, priority, is_defensive, is_gcd_gated, matches_fn, execute_fn)
    table.insert(middleware_registry, {
        name = name,
        priority = priority,  -- Higher = runs first
        is_defensive = is_defensive,
        is_gcd_gated = is_gcd_gated,
        matches = matches_fn,
        execute = execute_fn
    })
    table.sort(middleware_registry, function(a, b) return a.priority > b.priority end)
end

function NS.execute_middleware(context)
    for _, mw in ipairs(middleware_registry) do
        if not mw.is_gcd_gated or not context.on_gcd then
            if mw.matches(context) then
                if mw.execute(context) then
                    return true  -- Middleware consumed the action
                end
            end
        end
    end
    return false
end
```

**Priority Ranges (Flux convention)**:
- 500+: Form/stance management
- 400+: Emergency defensives (< 20% HP)
- 300+: Recovery items (potions, healthstones)
- 200+: Interrupts
- 100+: Offensive cooldowns
- 0+: Trinkets

---

## SECTION 2: TIER-1 FEATURES TO IMPLEMENT

### 2.1 Force Command System (Flux Pattern) — PRIORITY 1

**Requirement**: Manual override commands for burst, defensive, gap-closer with 3-second duration.

**Sylvanas API Mapping**:
```lua
-- In core_sylvanas.lua
NS.force_burst = 0
NS.force_defensive = 0
NS.force_gap = 0
NS.FORCE_DURATION = 3.0

-- Register slash command handler
function NS.set_force_command(type)
    local now = _core_time()
    if type == "burst" then NS.force_burst = now + NS.FORCE_DURATION end
    if type == "defensive" then NS.force_defensive = now + NS.FORCE_DURATION end
    if type == "gap" then NS.force_gap = now + NS.FORCE_DURATION end
end

-- In rotation check
local function is_force_active(force_var)
    return _core_time() < force_var
end

-- Usage in strategy
local forced = (is_force_active(NS.force_burst) and strategy.is_burst) 
            or (is_force_active(NS.force_defensive) and strategy.is_defensive)
```

**Menu Integration**: Add keybind menus for force commands in schema_sylvanas.lua

### 2.2 PvP Situational Awareness (Sonah Pattern) — PRIORITY 1

**Requirement**: Detect PvP context and branch rotation accordingly.

**Sylvanas API Mapping**:
```lua
-- PvP detection
function NS.is_in_pvp()
    local map_id = core.get_map_id()
    return map_id == 489 or map_id == 529 or map_id == 559 or map_id == 562 or map_id == 572  -- Arena/BG map IDs
end

function NS.is_target_enemy_player(target)
    if not target then return false end
    return target:is_player() and target:is_enemy_with(NS.me)
end

-- PvP rotation branch
local function get_next_spell(context)
    if NS.is_in_pvp() and NS.is_target_enemy_player(context.target) then
        return get_next_spell_pvp(context)
    end
    return get_next_spell_pve(context)
end
```

**Sonah Burst Window Detection**:
```lua
function NS.calculate_burst_score(context)
    local score = 0
    if context.target_hp < 25 then score = score + 40 end
    if context.target_hp < 40 then score = score + 25 end
    if not context.target_has_defensives then score = score + 20 end
    if context.target_is_ccd then score = score + 15 end
    if context.target_is_healer then score = score + 15 end
    if context.target_is_casting then score = score + 10 end
    return score
end
```

### 2.3 Diminishing Returns (DR) Tracking (Sonah Pattern) — PRIORITY 2

**Requirement**: Track DR on targets to choose optimal CC.

**Sylvanas API Mapping**:
```lua
-- In shared/dr_tracker_sylvanas.lua
local dr_tracker = {
    targets = {},  -- [guid] = { stun = {expiry, level}, fear = {...} }
    categories = {
        STUN = 1, FEAR = 2, ROOT = 3, SILENCE = 4,
        DISORIENT = 5, HORROR = 6, SLEEP = 7, INCAP = 8
    }
}

-- Multipliers: 1.0, 0.5, 0.25, 0 (immune)
local DR_MULTIPLIERS = {1.0, 0.5, 0.25, 0}
local DR_RESET_TIME = 18  -- seconds

-- Called from combat log event
function NS.on_cc_applied(target_guid, category)
    local t = dr_tracker.targets[target_guid] or {}
    local cat = t[category] or {level = 0, expiry = 0}
    cat.level = math.min(cat.level + 1, 4)
    cat.expiry = _core_time() + DR_RESET_TIME
    t[category] = cat
    dr_tracker.targets[target_guid] = t
end

function NS.get_dr_multiplier(target_guid, category)
    local t = dr_tracker.targets[target_guid]
    if not t then return 1.0 end
    local cat = t[category]
    if not cat then return 1.0 end
    if _core_time() > cat.expiry then
        cat.level = 0
        return 1.0
    end
    return DR_MULTIPLIERS[math.min(cat.level, 4)]
end
```

### 2.4 Interrupt Priority System (Flux + Sonah) — PRIORITY 1

**Requirement**: Priority-ranked interrupt list with smart targeting.

**Sylvanas API Mapping**:
```lua
-- Interrupt priority table (higher = more important)
local INTERRUPT_PRIORITY = {
    -- Heals (highest priority)
    [25299] = 100,  -- Greater Heal
    [25235] = 95,   -- Flash Heal
    [25431] = 90,   -- Healing Touch
    -- CC
    [33786] = 85,   -- Cyclone
    [12826] = 80,   -- Polymorph
    [10912] = 75,   -- Fear
    -- Big damage
    [27263] = 60,   -- Shadowbolt
    [27074] = 55,   -- Fireball
    [27080] = 50,   -- Frostbolt
    -- Default
    ["default"] = 30
}

-- In interrupt_manager_sylvanas.lua
function NS.should_interrupt_target(target)
    if not target:is_casting() then return false, nil end
    local spell_id = target:get_casting_spell_id()
    local priority = INTERRUPT_PRIORITY[spell_id] or INTERRUPT_PRIORITY["default"]
    return true, priority
end

function NS.get_best_interrupt_target()
    local enemies = _get_enemies()
    local best_target = nil
    local best_priority = 0
    
    for _, enemy in ipairs(enemies) do
        local should, priority = NS.should_interrupt_target(enemy)
        if should and priority > best_priority then
            best_target = enemy
            best_priority = priority
        end
    end
    
    return best_target, best_priority
end
```

### 2.5 Heroic Strike Smart Queue/Dequeue (Flux Pattern) — PRIORITY 1 (Warrior)

**Requirement**: Queue HS before OH swing, dequeue before MH if rage insufficient.

**Sylvanas API Mapping**:
```lua
-- In middleware_sylvanas.lua for Warrior
local HS_RAGE_THRESHOLD = 50
local HS_CANCEL_RAGE = 25

local function should_queue_heroic_strike(context)
    if context.rage < HS_RAGE_THRESHOLD then return false end
    if not context.swing_timer then return false end
    -- Queue if OH is about to land (0.5s window)
    local oh_remaining = context.swing_timer.oh_remaining
    return oh_remaining > 0 and oh_remaining < 0.5
end

local function should_dequeue_heroic_strike(context)
    if context.rage > HS_CANCEL_RAGE then return false end
    if not context.swing_timer then return false end
    -- Cancel if MH is about to land and rage is low
    local mh_remaining = context.swing_timer.mh_remaining
    return mh_remaining > 0 and mh_remaining < 0.3
end

-- Middleware implementation
NS.register_middleware("Warrior_HSQueue", 999, false, false,
    function(ctx)
        return ctx.stance == "berserker" and should_queue_heroic_strike(ctx)
    end,
    function(ctx)
        return NS.try_cast(ctx.spells.heroic_strike, ctx.target)
    end
)
```

### 2.6 DoT Refresh Optimization (Sonah Pattern) — PRIORITY 1

**Requirement**: Refresh DoTs based on haste breakpoints and pandemic windows.

**Sylvanas API Mapping**:
```lua
-- In shared/dot_refresh_sylvanas.lua
NS.DOT_REFRESH_THRESHOLD = 5.0  -- seconds
NS.DOT_PANDEMIC_PCT = 0.3       -- 30% of duration can be clipped

function NS.should_refresh_dot(unit, debuff_id, base_duration)
    local remains = unit:debuff_remains(debuff_id)
    local pandemic_threshold = base_duration * NS.DOT_PANDEMIC_PCT
    
    -- Refresh in pandemic window (last 30%)
    if remains > 0 and remains <= pandemic_threshold then
        return true
    end
    
    -- Refresh if completely expired
    if remains <= 0 then
        return true
    end
    
    return false
end

-- Haste-adjusted refresh (Sonah pattern)
function NS.get_optimal_refresh_window(spell_id, base_duration)
    local haste = NS.get_haste_percent()
    -- Simplified: adjust threshold based on haste
    return NS.DOT_REFRESH_THRESHOLD / (1 + haste/100)
end
```

### 2.7 Sticky Spell System (Sonah Pattern) — ALREADY EXISTS

**Requirement**: Prevent rapid flickering between suggestions.

**EaxRotations Current Implementation** (in core_sylvanas.lua):
```lua
NS.stickySpell = { name = nil, setTime = 0, minDuration = 0.3 }

function NS.set_sticky_spell(name, priority)
    local now = _core_time()
    if not NS.stickySpell.name or
       (now - NS.stickySpell.setTime) > NS.stickySpell.minDuration or
       (priority or 1) > NS.stickySpell.priority then
        NS.stickySpell.name = name
        NS.stickySpell.setTime = now
        NS.stickySpell.priority = priority or 1
    end
    return NS.stickySpell.name
end
```

**Verify this is working correctly** - already implemented.

### 2.8 Combat Dashboard (Flux Pattern) — ALREADY EXISTS

**Requirement**: Real-time overlay showing resources, CDs, buffs, action history.

**Sylvanas API Mapping**:
```lua
-- In dashboard_sylvanas.lua (already exists)
-- Uses core.register_on_render_callback for UI
-- Shows: resource bars, cooldown icons, buffs/debuffs, action history

-- Enhance with:
-- - Energy tick markers (rogue)
-- - Swing timer bars (warrior)
-- - Combo points (cat form)
-- - Threat percentage
```

### 2.9 Enemy Cooldown Tracking (Sonah Pattern) — PRIORITY 2

**Requirement**: Track enemy cooldowns for counter-play decisions.

**Sylvanas API Mapping**:
```lua
-- In shared/enemy_cd_tracker_sylvanas.lua
local enemy_cds = {}

-- Called from combat log when enemy casts
function NS.on_enemy_spell_cast(enemy_guid, spell_id, duration)
    if NS.is_major_cd(spell_id) then
        enemy_cds[enemy_guid] = enemy_cds[enemy_guid] or {}
        enemy_cds[enemy_guid][spell_id] = _core_time() + duration
    end
end

function NS.is_enemy_cd_ready(enemy_guid, spell_id)
    local cds = enemy_cds[enemy_guid]
    if not cds then return true end
    local expiry = cds[spell_id]
    if not expiry then return true end
    return _core_time() > expiry
end

-- Major CDs to track
NS.MAJOR_CDS = {
    WARRIOR = { 1719, 12292, 2687 },  -- Recklessness, Death Wish, Bloodrage
    MAGE = { 12043, 12472, 12042 },  -- Presence of Mind, Icy Veins, AP
    -- ... etc for all classes
}
```

### 2.10 Predictive Healing (Sonah Pattern) — PRIORITY 2

**Requirement**: Pre-heal based on damage prediction.

**Sylvanas API Mapping**:
```lua
-- In shared/predictive_heal_sylvanas.lua
local damage_history = {}
local HISTORY_WINDOW = 10  -- seconds

function NS.track_incoming_damage(target_guid, amount)
    local now = _core_time()
    damage_history[target_guid] = damage_history[target_guid] or {}
    table.insert(damage_history[target_guid], { time = now, amount = amount })
end

function NS.get_predicted_damage(target_guid, window_seconds)
    local history = damage_history[target_guid]
    if not history then return 0 end
    
    local total = 0
    local now = _core_time()
    for _, entry in ipairs(history) do
        if now - entry.time <= HISTORY_WINDOW then
            total = total + entry.amount
        end
    end
    
    return total / HISTORY_WINDOW * window_seconds
end

function NS.should_preemptive_heal(target, threshold)
    local predicted = NS.get_predicted_damage(target:get_guid(), 3.0)
    local future_hp = target:get_health() - predicted
    return future_hp / target:get_max_health() * 100 < threshold
end
```

---

## SECTION 3: SYLVANAS API EQUIVALENTS TABLE

| Flux/Sonah Feature | Flux/Sonah API | Sylvanas Equivalent | File |
|-------------------|----------------|---------------------|------|
| **Unit State** ||||
| Player unit | `Unit("player")` | `core.object_manager.get_local_player()` | api/core.lua |
| Target unit | `Unit("target")` | `me:get_target()` | api/game_object.lua |
| Health % | `:HealthPercent()` | `:get_health_percentage()` | api/game_object.lua |
| Mana/Energy % | `:ManaPercent()` | `:get_mana_percentage()` | api/game_object.lua |
| Distance | `:GetRange()` | `:get_distance(other)` | api/game_object.lua |
| In combat | `:InCombat()` | `:is_in_combat()` | api/game_object.lua |
| Is casting | `:IsCasting()` | `:is_casting()` | api/game_object.lua |
| Cast spell ID | `:GetCastingSpell()` | `:get_casting_spell_id()` | api/game_object.lua |
| Cast progress | `:GetCastingPercent()` | `:get_casting_percent()` | api/game_object.lua |
| **Buffs/Debuffs** ||||
| Has buff | `:HasBuffs(id)` | `:has_buff(id)` | via IZI SDK |
| Buff remains | `:HasBuffs(id)` | `:buff_remains(id)` | via IZI SDK |
| Buff stacks | `:HasBuffsStacks(id)` | `:get_buff_stacks(id)` | via IZI SDK |
| Has debuff | `:HasDeBuffs(id)` | `:has_debuff(id)` | via IZI SDK |
| Debuff remains | `:HasDeBuffs(id)` | `:debuff_remains(id)` | via IZI SDK |
| **Cooldowns** ||||
| Spell cooldown | `spell:GetCooldown()` | `core.spell_book.get_spell_cooldown(id)` | api/core.lua |
| GCD | `Player:GetGCD()` | `core.spell_book.get_global_cooldown()` | api/core.lua |
| Is spell ready | `Sonah:IsSpellReady()` | `spell:cooldown_up()` | izi_sdk.lua |
| **Spell Casting** ||||
| Cast spell | `spell:Cast()` | `core.input.cast_target_spell(id, target)` | api/core.lua |
| Queue spell | `spell_queue.queue_spell()` | `spell_queue.queue_spell(id, target)` | modules/spell_queue.lua |
| Safe cast | `spell:CastSafe()` | `NS.try_cast()` (with checks) | core_sylvanas.lua |
| **Timing** ||||
| Current time | `GetTime()` | `core.time()` | api/core.lua |
| Register callback | `eventFrame:SetScript("OnEvent")` | `core.register_on_update_callback(fn)` | api/core.lua |
| Delta time | `GetTime() - last` | `core.delta_time()` | api/core.lua |
| **Target Selection** ||||
| Get enemies | `MultiUnits:GetByRange()` | `core.object_manager.get_enemy_list()` | api/core.lua |
| Pick enemy | `izi.pick_enemy()` | `target_selector.find_best_target()` | modules/target_selector.lua |
| Best AoE pos | `sp.find_best_aoe_position()` | `spell_prediction.find_best_aoe_position()` | modules/spell_prediction.lua |
| **UI** ||||
| Checkbox | `CreateFrame("CheckButton")` | `core.menu.checkbox(default, id)` | api/menu.lua |
| Slider | `CreateFrame("Slider")` | `core.menu.slider_int(min, max, default, id)` | api/menu.lua |
| Keybind | custom | `core.menu.keybind(key, shift, id)` | api/menu.lua |
| Combobox | `UIDropDownMenu` | `core.menu.combobox(default, id)` | api/menu.lua |
| Render callback | `OnUpdate` | `core.register_on_render_callback(fn)` | api/core.lua |
| **Graphics** ||||
| Draw circle | N/A | `core.graphics.draw_circle(pos, radius, color, thickness)` | api/core.lua |
| Draw line | N/A | `core.graphics.draw_line(from, to, color, thickness)` | api/core.lua |
| Draw icon | `izi.draw_spell_icon()` | `izi.draw_spell_icon(spell_id, x, y, w, h, alpha)` | izi_sdk.lua |
| **Combat Log** ||||
| CLEU event | `COMBAT_LOG_EVENT_UNFILTERED` | `core.register_on_spell_cast_callback(fn)` | api/core.lua |
| **Resources** ||||
| Rage | `Player:Rage()` | `me:get_power(enums.power_type.RAGE)` | api/enums.lua |
| Energy | `Player:Energy()` | `me:get_power(enums.power_type.ENERGY)` | api/enums.lua |
| Combo points | `Player:ComboPoints()` | `me:get_combo_points()` | api/game_object.lua |
| **Threat** ||||
| Threat situation | `UnitThreatSituation()` | `me:get_threat_situation()` | api/game_object.lua |
| **Position** ||||
| Get position | `Unit:GetPosition()` | `me:get_position()` | api/game_object.lua |
| **Buff Database** ||||
| Buff IDs | Manual tables | `require("common/buff_db")` | api/common/buff_db.lua |
| Enums | Manual | `require("common/enums")` | api/common/enums.lua |

---

## SECTION 4: IMPLEMENTATION PATTERNS

### 4.1 Menu Nil Guard Pattern (MANDATORY)

**From AGENTS.md**: 99% compliance required. NEVER access menu values without nil guards.

```lua
-- WRONG — Will crash if menu item nil
local mode = menu.mode:get()
local threshold = menu.heal_threshold:get()

-- CORRECT — Safe guarded access
local mode = (menu.mode and menu.mode:get()) or 1
local threshold = (menu.heal_threshold and menu.heal_threshold:get()) or 50
local enabled = (menu.enabled and menu.enabled:get()) or false

-- For sliders with ranges
local hp_pct = (menu.defensive_hp and menu.defensive_hp:get()) or 30
local rage_threshold = (menu.heroic_strike_rage and menu.heroic_strike_rage:get()) or 50
```

### 4.2 API Caching Pattern (MANDATORY)

**From AGENTS.md**: 95% compliance. Cache hot-path APIs at module load.

```lua
-- At top of main_sylvanas.lua (outside any function)
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

### 4.3 Context Throttling Pattern

**From Flux**: Context rebuild every frame is expensive. Use throttling.

```lua
local _last_context_build = 0
local CONTEXT_BUILD_INTERVAL = 0.05  -- 50ms

local function get_context()
    local now = _core_time()
    if now - _last_context_build >= CONTEXT_BUILD_INTERVAL then
        _cached_context = build_context()
        _last_context_build = now
    end
    return _cached_context
end
```

### 4.4 Spell Resolver Pattern (ALREADY EXISTS)

**From AGENTS.md**: Runtime spell ID resolution with caching.

```lua
-- In libraries/spell_resolver_sylvanas.lua (already exists)
local _spell_cache = {}

function NS.resolve_spell_id(spell_ranks)
    -- spell_ranks = {30335, 25251, 23894, ...} (newest to oldest)
    local cache_key = tostring(spell_ranks)
    if _spell_cache[cache_key] then
        return _spell_cache[cache_key]
    end
    for _, spell_id in ipairs(spell_ranks) do
        if core.spell_book.is_spell_learned(spell_id) then
            _spell_cache[cache_key] = spell_id
            return spell_id
        end
    end
    return nil
end
```

### 4.5 Static Table Reuse Pattern

**From AGENTS.md**: Avoid GC pressure in tight loops.

```lua
-- WRONG — Allocates every frame
function on_update()
    local tracked = {}
    for i, enemy in ipairs(enemies) do
        tracked[i] = enemy
    end
end

-- CORRECT — Reuse static table
local _tracked_enemies = { n = 0 }

function on_update()
    _tracked_enemies.n = 0
    for i, enemy in ipairs(enemies) do
        _tracked_enemies.n = _tracked_enemies.n + 1
        _tracked_enemies[_tracked_enemies.n] = enemy
    end
    for i = 1, _tracked_enemies.n do
        local enemy = _tracked_enemies[i]
        -- ...
    end
end
```

### 4.6 Squared Distance Pattern

**From AGENTS.md**: Avoid math.sqrt() for range checks.

```lua
-- WRONG — sqrt allocates and is slow
local dist = math.sqrt(dx*dx + dy*dy)
if dist < 10 then ... end

-- CORRECT — Compare squared
local dist_sq = dx*dx + dy*dy
if dist_sq < 100 then ... end  -- 10 yards squared = 100

-- Common values: 5y=25, 8y=64, 10y=100, 15y=225, 20y=400
```

---

## SECTION 5: SUCCESS CRITERIA

A tier #1 rotation engine must:

1. **Priority-Ordered Strategies**: First-match-wins priority system with middleware pre-execution
2. **Nil-Guarded Menus**: 100% menu access uses `(menu.x and menu.x:get()) or default`
3. **API Caching**: All hot-path API calls cached at module load
4. **Force Commands**: Working `/eax burst`, `/eax def`, `/eax gap` with 3s duration
5. **PvP Branch**: Detect PvP context and branch to PvP-specific rotation
6. **DR Tracking**: Track diminishing returns on CC for optimal targeting
7. **Interrupt Priority**: Priority-ranked interrupt list (heals > CC > damage)
8. **Smart HS Queue**: Warrior HS queue/dequeue based on swing timers
9. **DoT Optimization**: Refresh DoTs in pandemic windows with haste adjustment
10. **Sticky Spell**: 0.3s minimum display time to prevent flickering
11. **Combat Dashboard**: Real-time overlay with resources, CDs, buffs
12. **Settings-Driven**: ALL thresholds/toggles configurable, none hardcoded
13. **Cross-Class Shared**: Interrupt, trinket, burst, racial, OOC managers work across all 9 classes
14. **Debug Mode**: Scrollable log window showing every decision with reasoning
15. **Sim Integration**: Export to simc, optimizer bridge for gear recommendations

---

## SECTION 6: IMPLEMENTATION ROADMAP

### Phase 1: Foundation (Week 1)
- [ ] Verify middleware system is working
- [ ] Verify sticky spell system is working
- [ ] Verify dashboard is rendering correctly
- [ ] Add force command keybinds to schema
- [ ] Add PvP detection helper

### Phase 2: PvP Infrastructure (Week 2)
- [ ] Implement DR tracker (shared/dr_tracker_sylvanas.lua)
- [ ] Implement enemy CD tracker (shared/enemy_cd_tracker_sylvanas.lua)
- [ ] Implement arena priority (shared/arena_priority_sylvanas.lua)
- [ ] Implement burst window scoring
- [ ] Add interrupt priority table

### Phase 3: Class Utilities (Week 3-4)
- [ ] Hunter: Viper Sting, trap rules, aspect swap, Misdirection
- [ ] Druid: Form-aware consumables, party dispel
- [ ] Rogue: Emergency Vanish, Evasion, Cloak
- [ ] Priest: Party Dispel, Abolish Disease
- [ ] Paladin: Divine Shield, Lay On Hands, Cleanse, HoJ
- [ ] Warlock: Death Coil, Healthstone, Dark Pact, Life Tap
- [ ] Mage: Ice Barrier, Remove Curse, Evocation, Mana Gem
- [ ] Warrior: HS smart dequeue, Spell Reflection
- [ ] Shaman: Auto Tremor, Purge, self-dispel

### Phase 4: Polish (Week 5)
- [ ] Combat stats tracking (APM, downtime, DoT uptime)
- [ ] Consumable audit (flask, elixir, food, weapon)
- [ ] Center-screen notifications
- [ ] Profile system (save/load settings)
- [ ] Regression test suite (40+ tests)

---

## APPENDIX: REFERENCE FILES

### Flux Reference
- `flux/rotation/source/aio/core.lua` — Strategy registry, priority system
- `flux/rotation/source/aio/main.lua` — Context building, dispatch loop
- `flux/rotation/source/aio/middleware.lua` — Middleware pattern
- `flux/rotation/source/aio/warrior/fury.lua` — Fury strategies (13 priorities)
- `flux/rotation/source/aio/dashboard.lua` — Combat dashboard

### Sonah Reference
- `Sonah/Core/Core.lua` — Aura cache, event system, interrupt logic
- `Sonah/Core/CustomRotation.lua` — Custom rotation engine (14 conditions)
- `Sonah/Classes/Warrior/Fury.lua` — Fury rotation with slam weaving
- `Sonah/Classes/Priest/Shadow.lua` — DoT management, haste breakpoints
- `Sonah/Config/Config.lua` — Settings UI (~4200 lines)

### EaxRotations Current
- `EaxRotations/core_sylvanas.lua` — Runtime boundary, sticky spell
- `EaxRotations/main_sylvanas.lua` — Dispatcher
- `EaxRotations/shared/interrupt_manager_sylvanas.lua` — Interrupt system
- `EaxRotations/shared/burst_logic_sylvanas.lua` — Burst logic
- `EaxRotations/SONAH_FLUX_GAP_ANALYSIS.md` — Complete gap list

### Sylvanas API
- `api/core.lua` — Core callbacks, time, input casting
- `api/game_object.lua` — Unit methods (health, mana, position, combat)
- `api/common/izi_sdk.lua` — High-level SDK (spell objects, targeting)
- `api/common/modules/spell_queue.lua` — Spell queueing
- `api/common/modules/target_selector.lua` — Target selection
- `api/common/modules/buff_manager.lua` — Cached buff/debuff data
- `api/common/buff_db.lua` — 578 buff/debuff definitions
- `api/common/enums.lua` — 394 game constants
- `apidocs/pages/dev/api/core.md` — Core API documentation
- `apidocs/pages/dev/api/game-object.md` — Unit API documentation
- `apidocs/pages/dev/api/spellbook.md` — Spell casting documentation

---

*Super Prompt Version 1.0*
*Based on: Flux AIO analysis + Sonah analysis + EaxRotations gap analysis*
*Target: Tier #1 rotation engine using strict Sylvanas API*
