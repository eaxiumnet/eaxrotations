-- EAXPaladinProtection Middleware Manager
-- Integrates libraries/middleware with Protection Paladin-specific registrations

local middleware_manager = {}

-- Load the middleware system
local middleware = require("libraries/middleware")

-- Spell IDs for TBC Protection Paladin
local PALADIN_SPELLS = {
    -- Racials
    BERSERKING = 26297,      -- Troll offensive racial
    STONEFORM = 20594,       -- Dwarf defensive racial
    GIFT_OF_THE_NAARU = 28880, -- Draenei heal racial
    
    -- Items (default IDs, will be resolved)
    HEALTHSTONE = 5512,      -- Minor Healthstone
    HEALING_POTION = 118,    -- Minor Healing Potion
    SUPER_MANA_POTION = 22832,
    
    -- Paladin abilities
    AVENGING_WRATH = 31884,
    DIVINE_SHIELD = 642,
    DIVINE_PROTECTION = 5573,
    LAY_ON_HANDS = 27154,
    HOLY_SHIELD = 27179,
}

-- Track if middleware has been initialized
local _initialized = false

--- Initialize and register all Protection Paladin-specific middleware
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
    
    local use_stoneform = (menu.use_stoneform and menu.use_stoneform:get_state()) or false
    local use_gift_of_the_naaru = (menu.use_gift_of_the_naaru and menu.use_gift_of_the_naaru:get_state()) or false
    
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
    
    -- Register Stoneform (Dwarf defensive racial)
    if use_stoneform then
        local stoneform_threshold = (menu.stoneform_hp_pct and menu.stoneform_hp_pct:get()) or 40
        middleware.register(middleware.defensive_racial(
            PALADIN_SPELLS.STONEFORM,
            stoneform_threshold,
            middleware.PRIORITY.PVP_DEFENSIVE
        ))
    end
    
    -- Register Gift of the Naaru (Draenei heal racial)
    if use_gift_of_the_naaru then
        local naaru_threshold = (menu.gift_of_the_naaru_hp_pct and menu.gift_of_the_naaru_hp_pct:get()) or 50
        local naaru_mw = {
            name = "Gift of the Naaru",
            priority = middleware.PRIORITY.PVP_DEFENSIVE - 5,
            is_burst = false,
            is_defensive = true,
            is_gcd_gated = true,
            setting_key = "use_gift_of_the_naaru",
            matches = function(ctx)
                if not ctx.in_combat then return false end
                
                local hp_pct = ctx.hp_pct or 100
                if hp_pct > naaru_threshold then return false end
                
                if core.spell_book and core.spell_book.get_spell_cooldown then
                    local cd = core.spell_book.get_spell_cooldown(PALADIN_SPELLS.GIFT_OF_THE_NAARU)
                    if cd > 0 then return false end
                end
                
                return true
            end,
            execute = function(icon, ctx)
                if core.spell_queue and core.spell_queue.add then
                    core.spell_queue.add(PALADIN_SPELLS.GIFT_OF_THE_NAARU, "gift_of_the_naaru", 75)
                    return true, "[MW] Gift of the Naaru queued"
                elseif icon and icon.cast then
                    icon:cast(PALADIN_SPELLS.GIFT_OF_THE_NAARU)
                    return true, "[MW] Gift of the Naaru"
                end
                return false
            end,
        }
        middleware.register(naaru_mw)
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
