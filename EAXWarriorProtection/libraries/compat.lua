--[[
    _compat.lua - Legacy to Sylvanas Compatibility Layer
    
    Provides API wrappers that map legacy patterns to Sylvanas,
    enabling incremental migration of features to EAX specs.
    
    Usage: local _compat = require("libraries/rotation_compat")
--]]

-- ============================================================================
-- REQUIRES
-- ============================================================================

require("common/modules/buff_manager")
require("common/utility/spell_helper")

-- ============================================================================
-- API CACHING (at module load - never in on_update)
-- ============================================================================

local _core_time = core.time
local _core_object_manager = core.object_manager
local _core_spell_book = core.spell_book
local _get_local_player = _core_object_manager.get_local_player
local _get_gcd = _core_spell_book.get_global_cooldown
local _gcd_ready = _core_spell_book.is_global_cooldown_ready

-- ============================================================================
-- DEBUG LOGGING
-- ============================================================================

local DEBUG_ENABLED = false
local function debug_log(msg)
    if DEBUG_ENABLED then
        print("[] " .. tostring(msg))
    end
end

-- ============================================================================
-- SAFE MENU ACCESS
-- ============================================================================

--[[
    Safe menu access with nil guards
    Pattern: (menu.key and menu.key:get()) or default
    
    @param menu - The menu table
    @param key - The menu item key (string)
    @param default - Default value if menu item is nil
    @return The menu value or default
--]]
function _compat.get_menu_value(menu, key, default)
    if not menu then
        return default
    end
    
    local item = menu[key]
    if item and type(item.get) == "function" then
        return item:get()
    end
    
    return default
end

-- ============================================================================
-- CONTEXT BUILDER
-- ============================================================================

--[[
    Context builder (replaces  create_context)
    Returns a table with combat state, resources, and settings
    
    @param me - Local player object
    @param menu - Menu table for settings access
    @param utils - Utils module (optional, for helper functions)
    @return Context table
--]]
function _compat.build_context(me, menu, utils)
    local context = {}
    
    -- Player state
    me = me or _get_local_player()
    if not me then
        return context
    end
    
    -- GCD state
    context.on_gcd = not _gcd_ready()
    context.gcd_remains = _get_gcd()
    
    -- Combat state
    local ok_combat, in_combat = pcall(function() return me:is_in_combat() end)
    context.in_combat = (ok_combat and in_combat) or false
    context.combat_time = 0  -- Will be updated by caller if tracked
    
    -- Health and resources
    local ok_hp, hp = pcall(function() return me:get_health() end)
local ok_max, max_hp = pcall(function() return me:get_max_health() end)
context.hp = (ok_hp and ok_max and hp and max_hp and max_hp > 0) and ((hp / max_hp) * 100) or 100
    context.max_hp = (me.get_max_health and me:get_max_health()) or 0
    context.current_hp = (me.get_health and me:get_health()) or 0
    
    -- Mana/Energy/Rage/etc
    if me.get_power_percentage then
        local ok, mana_pct = pcall(function() return me:get_power_percentage() end)
        context.mana_pct = ok and mana_pct or 100
    elseif me.get_power and me.get_max_power then
        local ok_max_power, max_power = pcall(function() return me:get_max_power() end)
        max_power = (ok_max_power and max_power) or 0
        if max_power > 0 then
            local ok_power, power = pcall(function() return me:get_power() end)
        context.mana_pct = (ok_power and power and max_power > 0) and ((power / max_power) * 100) or 0
        else
            context.mana_pct = 0
        end
    else
        context.mana_pct = 100
    end
    
    -- Target information
    local ok_target, target = pcall(function() return (me.get_target and me:get_target()) or nil end)
    target = ok_target and target or nil
    if target then
        local ok_hp, hp = pcall(function() return target:get_health() end)
local ok_max, max_hp = pcall(function() return target:get_max_health() end)
context.target_hp = (ok_hp and ok_max and hp and max_hp and max_hp > 0) and ((hp / max_hp) * 100) or 100
        context.ttd = target.time_to_death or 999  -- Time to death estimate
        
        -- Range check (squared distance for performance)
        local ok_pos, me_x, me_y, me_z = pcall(function() return me:get_position() end)
        if not ok_pos then me_x, me_y, me_z = nil, nil, nil end
        local ok_tgt_pos, tgt_x, tgt_y, tgt_z = pcall(function() return target:get_position() end)
        if not ok_tgt_pos then tgt_x, tgt_y, tgt_z = nil, nil, nil end
        if me_x and tgt_x then
            local dx = tgt_x - me_x
            local dy = tgt_y - me_y
            local dist_sq = dx * dx + dy * dy
            context.in_melee_range = dist_sq < 36  -- 6 yards squared
            context.distance_sq = dist_sq
        else
            context.in_melee_range = false
            context.distance_sq = 999999
        end
        
        -- Boss detection (health pool heuristic)
        local ok_tgt_max, tgt_max_hp = pcall(function() return (target.get_max_health and target:get_max_health()) or 0 end)
        tgt_max_hp = (ok_tgt_max and tgt_max_hp) or 0
        context.is_boss = tgt_max_hp > 1000000  -- 1M+ health = boss
    else
        context.target_hp = 100
        context.ttd = 999
        context.in_melee_range = false
        context.distance_sq = 999999
        context.is_boss = false
    end
    
    -- Buff queries via buff_manager
    context.has_buff = function(buff_id)
        return buff_manager.has_buff(me, buff_id)
    end
    
    context.buff_remains = function(buff_id)
        return buff_manager.buff_remains(me, buff_id)
    end
    
    context.has_debuff = function(target_obj, debuff_id)
        return buff_manager.has_buff(target_obj or target, debuff_id)
    end
    
    -- Settings from menu (with nil guards)
    context.settings = {}
    if menu then
        context.settings.mode = _compat.get_menu_value(menu, "mode", 1)
        context.settings.heal_threshold = _compat.get_menu_value(menu, "heal_threshold", 50)
        context.settings.defensive_threshold = _compat.get_menu_value(menu, "defensive_threshold", 30)
        context.settings.use_cds = _compat.get_menu_value(menu, "use_cds", true)
        context.settings.aoe_enabled = _compat.get_menu_value(menu, "aoe_enabled", true)
    end
    
    return context
end

-- ============================================================================
-- MIDDLEWARE REGISTRY
-- ============================================================================

_compat.middleware_registry = {}

--[[
    Register middleware with priority
    Higher priority = executed first
    
    @param mw - Middleware table with:
        - name: string identifier
        - priority: number (higher = earlier)
        - execute: function(icon, context) -> boolean, string
          Returns: should_block, message
--]]
function _compat.register_middleware(mw)
    if not mw or not mw.name or not mw.execute then
        debug_log("Invalid middleware registration attempt")
        return false
    end
    
    -- Check for duplicate
    for i, existing in ipairs(_compat.middleware_registry) do
        if existing.name == mw.name then
            debug_log("Middleware '" .. mw.name .. "' already registered, updating")
            _compat.middleware_registry[i] = mw
            -- Re-sort
            table.sort(_compat.middleware_registry, function(a, b)
                return (a.priority or 0) > (b.priority or 0)
            end)
            return true
        end
    end
    
    -- Add new
    table.insert(_compat.middleware_registry, mw)
    
    -- Sort by priority descending
    table.sort(_compat.middleware_registry, function(a, b)
        return (a.priority or 0) > (b.priority or 0)
    end)
    
    debug_log("Registered middleware: " .. mw.name .. " (priority: " .. tostring(mw.priority or 0) .. ")")
    return true
end

--[[
    Execute all registered middleware in priority order
    
    @param icon - The spell/ability icon being evaluated
    @param context - The combat context
    @return result (boolean - true if any middleware executed), message (string)
--]]
function _compat.execute_middleware(icon, context)
    for _, mw in ipairs(_compat.middleware_registry) do
        local should_block, message = mw.execute(icon, context)
        if should_block then
            debug_log("Middleware '" .. mw.name .. "' executed: " .. tostring(message))
            return true, message
        end
    end
    
    return false, nil
end

-- ============================================================================
-- FORCE COMMAND SYSTEM
-- ============================================================================

_compat.force_flags = {}

--[[
    Set a force flag with duration
    
    @param flag_name - String identifier for the flag
    @param duration - Duration in seconds
--]]
function _compat.set_force_flag(flag_name, duration)
    if not flag_name then
        return
    end
    
    local expiry = _core_time() + (duration or 0)
    _compat.force_flags[flag_name] = expiry
    debug_log("Set force flag '" .. flag_name .. "' for " .. tostring(duration) .. "s")
end

--[[
    Check if a force flag is currently active
    
    @param flag_name - String identifier for the flag
    @return boolean - true if flag is active
--]]
function _compat.is_force_active(flag_name)
    if not flag_name then
        return false
    end
    
    local expiry = _compat.force_flags[flag_name]
    if not expiry then
        return false
    end
    
    local current_time = _core_time()
    if current_time > expiry then
        -- Clean up expired flag
        _compat.force_flags[flag_name] = nil
        return false
    end
    
    return true
end

--[[
    Clear a specific force flag
    
    @param flag_name - String identifier for the flag
--]]
function _compat.clear_force_flag(flag_name)
    _compat.force_flags[flag_name] = nil
end

--[[
    Clear all force flags
--]]
function _compat.clear_all_force_flags()
    _compat.force_flags = {}
end

-- ============================================================================
-- SETTINGS CACHE (50ms throttle)
-- ============================================================================

local settings_cache = {}
local last_refresh = 0

--[[
    Refresh settings from menu with 50ms throttle
    
    @param menu - The menu table
    @param schema - Table of {key, default} pairs defining expected settings
    @return Cached settings table
--]]
function _compat.refresh_settings(menu, schema)
    local current_time = _core_time()
    
    -- 50ms throttle check
    if (current_time - last_refresh) < 0.05 then
        return settings_cache
    end
    
    last_refresh = current_time
    
    -- Build cache from menu
    if menu and schema then
        for _, entry in ipairs(schema) do
            local key = entry.key
            local default = entry.default
            settings_cache[key] = _compat.get_menu_value(menu, key, default)
        end
    end
    
    return settings_cache
end

--[[
    Get a cached setting value
    
    @param key - Setting key
    @param default - Default if not in cache
    @return The cached value or default
--]]
function _compat.get_cached_setting(key, default)
    return settings_cache[key] or default
end

--[[
    Invalidate the settings cache (force refresh on next call)
--]]
function _compat.invalidate_settings_cache()
    last_refresh = 0
end

-- ============================================================================
-- UTILITY FUNCTIONS
-- ============================================================================

--[[
    Safe spell cast wrapper
    Checks if spell is learned and not on cooldown before casting
    
    @param spell_id - Spell ID to cast
    @param target - Target object (optional, defaults to current target)
    @return boolean - true if cast was attempted
--]]
function _compat.cast_safe(spell_id, target)
    if not spell_id then
        return false
    end
    
    -- Check if learned
    if not spell_helper.is_spell_learned(spell_id) then
        return false
    end
    
    -- Check cooldown
    if spell_helper.is_on_cooldown(spell_id) then
        return false
    end
    
    -- Get target
    local me = _get_local_player()
    local cast_target = target or (me and me:get_target())
    
    if not cast_target then
        return false
    end
    
    -- Attempt cast
    return core.input.cast_target_spell(spell_id, cast_target)
end

--[[
    Check if player has required talent points
    
    @param talent_id - Talent spell ID
    @param min_points - Minimum points required (default 1)
    @return boolean
--]]
function _compat.has_talent(talent_id, min_points)
    if not talent_id then
        return false
    end
    
    local points = spell_helper.get_talent_points(talent_id) or 0
    return points >= (min_points or 1)
end

--[[
    Get remaining cooldown for a spell
    
    @param spell_id - Spell ID
    @return number - Remaining cooldown in seconds (0 if ready)
--]]
function _compat.cooldown_remains(spell_id)
    if not spell_id then
        return 999
    end
    
    return spell_helper.cooldown_remains(spell_id) or 999
end

--[[
    Check if spell is ready (learned + not on cooldown + resources available)
    
    @param spell_id - Spell ID
    @return boolean
--]]
function _compat.is_spell_ready(spell_id)
    if not spell_id then
        return false
    end
    
    return spell_helper.is_spell_ready(spell_id)
end

-- ============================================================================
-- RETURN MODULE
-- ============================================================================

return _compat
