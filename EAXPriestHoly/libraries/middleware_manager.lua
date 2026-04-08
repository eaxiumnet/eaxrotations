--[[
    middleware_manager.lua - Middleware Manager for Priest Holy
    
    Manages middleware registration and execution for:
    - Healthstones, Healing Potions, Mana Potions
    - Defensive racials (Stoneform, etc.)
    - Emergency self-heal (Flash Heal)
    
    Usage:
        local mw = require("libraries/middleware_manager")
        mw.setup(menu, spells)  -- Call once in on_load()
        
        -- In rotation:
        local result, msg = mw.execute_middleware(icon, me, target)
        if result then return result, msg end
--]]

local middleware_manager = {}

-- Stored menu reference for execute_middleware
local _menu = nil

-- ============================================================================
-- REQUIRES
-- ============================================================================

local middleware = require("libraries/middleware")
local _compat = require("libraries/compat")

-- ============================================================================
-- API CACHING
-- ============================================================================

local _core_time = core.time
local _get_local_player = core.object_manager.get_local_player

-- ============================================================================
-- CONFIGURATION
-- ============================================================================

-- TBC Item IDs
local ITEM_IDS = {
    HEALTHSTONE = 22105,        -- Master Healthstone
    HEALING_POTION = 22829,     -- Super Healing Potion
    MANA_POTION = 22832,        -- Super Mana Potion
}

-- ============================================================================
-- SETUP
-- ============================================================================

--- Setup middleware for Priest Holy
-- @param menu table: Menu module with settings
-- @param spells table: Spells module with spell IDs
function middleware_manager.setup(menu, spells)
    -- Store menu reference for later use
    _menu = menu
    
    -- Clear any existing middleware
    middleware.clear()
    
    -- Healthstone (Priority: RECOVERY_ITEMS = 300)
    if menu.use_healthstone ~= nil then
        middleware.register(middleware.healthstone(
            ITEM_IDS.HEALTHSTONE,
            (menu.healthstone_threshold and menu.healthstone_threshold:get()) or 30
        ))
    end
    
    -- Healing Potion (Priority: RECOVERY_ITEMS = 300)
    if menu.use_healing_potion ~= nil then
        middleware.register(middleware.healing_potion(
            ITEM_IDS.HEALING_POTION,
            (menu.healing_potion_threshold and menu.healing_potion_threshold:get()) or 25
        ))
    end
    
    -- Mana Potion (Priority: MANA_RECOVERY = 280)
    if menu.use_mana_potion ~= nil then
        middleware.register(middleware.mana_potion(
            ITEM_IDS.MANA_POTION,
            (menu.mana_potion_threshold and menu.mana_potion_threshold:get()) or 20
        ))
    end
    
    -- Emergency Heal - Flash Heal (Priority: EMERGENCY_HEAL = 400)
    if menu.use_emergency_heal ~= nil and spells.FLASH_HEAL then
        local flash_heal_id = spells.FLASH_HEAL[1]
        middleware.register(middleware.emergency_heal(
            flash_heal_id,
            (menu.emergency_heal_threshold and menu.emergency_heal_threshold:get()) or 30,
            middleware.PRIORITY.EMERGENCY_HEAL,
            false  -- Does not require combo points
        ))
    end
    
    -- Defensive Racial (Priority: PVP_DEFENSIVE = 90)
    if menu.use_defensive_racial ~= nil then
        local defensive_racial_id = nil
        
        -- Check for racial spells
        if spells.STONEFORM then
            defensive_racial_id = spells.STONEFORM[1]  -- Dwarf
        elseif spells.WILL_OF_THE_FORSAKEN then
            defensive_racial_id = spells.WILL_OF_THE_FORSAKEN[1]  -- Undead
        elseif spells.ESCAPE_ARTIST then
            defensive_racial_id = spells.ESCAPE_ARTIST[1]  -- Gnome
        end
        
        if defensive_racial_id then
            middleware.register(middleware.defensive_racial(
                defensive_racial_id,
                (menu.defensive_racial_threshold and menu.defensive_racial_threshold:get()) or 40
            ))
        end
    end
    
    print("[EAX Holy] Middleware registered: " .. middleware.count() .. " items")
end

-- ============================================================================
-- EXECUTION
-- ============================================================================

--- Execute all registered middleware
-- @param icon table: Icon object for casting
-- @param me table: Local player object
-- @param target table: Current target object
-- @return result, message: First successful middleware result or nil
function middleware_manager.execute_middleware(icon, me, target)
    -- Build context with nil-guarded menu access
    local settings = {}
    
    -- Healthstone setting
    if _menu and _menu.use_healthstone and _menu.use_healthstone.get_state then
        settings.use_healthstone = _menu.use_healthstone:get_state()
    else
        settings.use_healthstone = false
    end
    
    -- Healing potion setting
    if _menu and _menu.use_healing_potion and _menu.use_healing_potion.get_state then
        settings.use_healing_potion = _menu.use_healing_potion:get_state()
    else
        settings.use_healing_potion = false
    end
    
    -- Mana potion setting
    if _menu and _menu.use_mana_potion and _menu.use_mana_potion.get_state then
        settings.use_mana_potion = _menu.use_mana_potion:get_state()
    else
        settings.use_mana_potion = false
    end
    
    -- Emergency heal setting
    if _menu and _menu.use_emergency_heal and _menu.use_emergency_heal.get_state then
        settings.use_emergency_heal = _menu.use_emergency_heal:get_state()
    else
        settings.use_emergency_heal = false
    end
    
    -- Defensive racial setting
    if _menu and _menu.use_defensive_racial and _menu.use_defensive_racial.get_state then
        settings.use_defensive_racial = _menu.use_defensive_racial:get_state()
    else
        settings.use_defensive_racial = false
    end
    
    local context = middleware.build_context(me, target, settings)
    return middleware.execute(icon, context)
end

--- Get middleware debug info
-- @return table: Debug information
function middleware_manager.get_debug_info()
    return middleware.debug_info()
end

--- Print middleware debug info to console
function middleware_manager.print_debug()
    middleware.print_debug()
end

-- ============================================================================

-- ============================================================================

--- Set burst force flag
-- @param duration number: Duration in seconds
function middleware_manager.set_burst(duration)
    _compat.set_force_flag("burst", duration or 3.0)
end

--- Set defensive force flag
-- @param duration number: Duration in seconds
function middleware_manager.set_defensive(duration)
    _compat.set_force_flag("defensive", duration or 3.0)
end

--- Check if burst is forced
-- @return boolean
function middleware_manager.is_burst_forced()
    return _compat.is_force_active("burst")
end

--- Check if defensive is forced
-- @return boolean
function middleware_manager.is_defensive_forced()
    return _compat.is_force_active("defensive")
end

return middleware_manager
