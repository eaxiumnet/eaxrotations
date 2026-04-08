-- EAXPaladinRetribution Middleware Manager
-- Integrates libraries/middleware with Retribution Paladin-specific registrations

local middleware_manager = {}

-- Load the middleware system
local middleware = require("libraries/middleware")

-- Spell IDs for TBC Retribution Paladin
local PALADIN_SPELLS = {
    -- Racials
    BERSERKING = 26297,      -- Troll offensive racial
    STONEFORM = 20594,       -- Dwarf defensive racial
    GIFT_OF_THE_NAARU = 28880, -- Draenei heal racial
    ARCANE_TORRENT = 28730,  -- Blood Elf mana racial
    
    -- Items (default IDs, will be resolved)
    HEALTHSTONE = 5512,      -- Minor Healthstone
    HEALING_POTION = 118,    -- Minor Healing Potion
    SUPER_MANA_POTION = 22832,
    
    -- Paladin abilities
    AVENGING_WRATH = 31884,
    DIVINE_FAVOR = 20216,
    DIVINE_SHIELD = 642,
    LAY_ON_HANDS = 27154,
    CRUSADER_STRIKE = 35395,
}

-- Track if middleware has been initialized
local _initialized = false

--- Initialize and register all Retribution Paladin-specific middleware
-- @param menu table: Menu module for accessing settings
function middleware_manager.initialize(menu)
    if _initialized then return end
    if not menu then return end
    
    -- Clear any existing registrations to avoid duplicates
    middleware.clear()
    
    -- Get settings with nil guards
    local use_healthstone = (menu.use_healthstone and menu.use_healthstone:get_state()) or false
    local healthstone_threshold = (menu.healthstone_hp_pct and menu.healthstone_hp_pct:get()) or 30
    
    local use_health_potion = (menu.use_health_potion and menu.use_health_potion:get_state()) or false
    local health_potion_threshold = (menu.health_potion_hp_pct and menu.health_potion_hp_pct:get()) or 40
    
    local use_berserking = (menu.use_berserking and menu.use_berserking:get_state()) or false
    local use_stoneform = (menu.use_stoneform and menu.use_stoneform:get_state()) or false
    local use_arcane_torrent = (menu.use_arcane_torrent and menu.use_arcane_torrent:get_state()) or false
    
    -- Register Healthstone middleware (off-GCD, defensive)
    if use_healthstone then
        middleware.register(middleware.healthstone(
            PALADIN_SPELLS.HEALTHSTONE,
            healthstone_threshold,
            middleware.PRIORITY.RECOVERY_ITEMS
        ))
    end
    
    -- Register Healing Potion middleware (off-GCD, defensive)
    if use_health_potion then
        middleware.register(middleware.healing_potion(
            PALADIN_SPELLS.HEALING_POTION,
            health_potion_threshold,
            middleware.PRIORITY.RECOVERY_ITEMS - 10
        ))
    end
    
    -- Register Berserking (Troll offensive racial)
    if use_berserking then
        middleware.register(middleware.offensive_racial(
            PALADIN_SPELLS.BERSERKING,
            middleware.PRIORITY.OFFENSIVE_CDS
        ))
    end
    
    -- Register Stoneform (Dwarf defensive racial)
    if use_stoneform then
        local stoneform_threshold = (menu.stoneform_hp_pct and menu.stoneform_hp_pct:get()) or 40
        middleware.register(middleware.defensive_racial(
            PALADIN_SPELLS.STONEFORM,
            stoneform_threshold,
            middleware.PRIORITY.PVP_DEFENSIVE
        ))
    end
    
    -- Register Arcane Torrent (Blood Elf mana racial)
    if use_arcane_torrent then
        local arcane_torrent_mw = {
            name = "Arcane Torrent",
            priority = middleware.PRIORITY.RECOVERY_ITEMS - 5,
            is_burst = false,
            is_defensive = false,
            is_gcd_gated = true,
            setting_key = "use_arcane_torrent",
            matches = function(ctx)
                if not ctx.in_combat then return false end
                
                local mana_pct = ctx.mana_pct or 100
                if mana_pct > 30 then return false end
                
                if core.spell_book and core.spell_book.get_spell_cooldown then
                    local cd = core.spell_book.get_spell_cooldown(PALADIN_SPELLS.ARCANE_TORRENT)
                    if cd > 0 then return false end
                end
                
                return true
            end,
            execute = function(icon, ctx)
                if icon and icon.cast then
                    icon:cast(PALADIN_SPELLS.ARCBE_TORRENT)
                    return true, "[MW] Arcane Torrent"
                end
                return false
            end,
        }
        middleware.register(arcane_torrent_mw)
    end
    
    _initialized = true
end

--- Re-initialize middleware (call when settings change)
-- @param menu table: Menu module for accessing settings
function middleware_manager.reinitialize(menu)
    _initialized = false
    middleware_manager.initialize(menu)
end

--- Execute middleware chain
-- @param icon table: Icon object for casting
-- @param context table: Execution context
-- @return result, message: First successful middleware result or nil
function middleware_manager.execute(icon, context)
    return middleware.execute(icon, context)
end

--- Build context from rotation state
-- @param me GameObject: Local player
-- @param target GameObject: Current target
-- @param settings table: Menu settings table
-- @return table: Context for middleware execution
function middleware_manager.build_context(me, target, settings)
    return middleware.build_context(me, target, settings)
end

--- Get debug information about registered middleware
-- @return table: Debug info
function middleware_manager.debug_info()
    return middleware.debug_info()
end

--- Print debug information to console
function middleware_manager.print_debug()
    middleware.print_debug()
end

--- Check if middleware is initialized
-- @return boolean
function middleware_manager.is_initialized()
    return _initialized
end

return middleware_manager
