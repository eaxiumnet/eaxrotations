-- EAXWarriorProtection Middleware Manager
-- Integrates libraries/middleware with Warrior Protection-specific registrations

local middleware_manager = {}

-- Load the middleware system
local middleware = require("libraries/middleware")

-- Spell IDs for TBC Warrior Protection
local WARRIOR_SPELLS = {
    -- Racials
    BLOOD_FURY = 20572,      -- Orc offensive racial
    BERSERKING = 26297,      -- Troll offensive/defensive racial
    STONEFORM = 20594,       -- Dwarf defensive racial
    ESCAPE_ARTIST = 20589,   -- Gnome defensive racial
    WAR_STOMP = 20549,       -- Tauren stun racial
    
    -- Items (default IDs, will be resolved)
    HEALTHSTONE = 5512,      -- Minor Healthstone
    HEALING_POTION = 118,    -- Minor Healing Potion
}

-- Track if middleware has been initialized
local _initialized = false

--- Initialize and register all Warrior Protection-specific middleware
-- @param menu table: Menu module for accessing settings
function middleware_manager.initialize(menu)
    if _initialized then return end
    if not menu then return end
    
    -- Clear any existing registrations to avoid duplicates
    middleware.clear()
    
    -- Get settings with nil guards
    local use_healthstone = (menu.use_healthstone and menu.use_healthstone:get_state()) or false
    local healthstone_threshold = (menu.healthstone_hp_pct and menu.healthstone_hp_pct:get()) or 25
    
    local use_health_potion = (menu.use_health_potion and menu.use_health_potion:get_state()) or false
    local health_potion_threshold = (menu.health_potion_hp_pct and menu.health_potion_hp_pct:get()) or 20
    
    local use_blood_fury = (menu.use_blood_fury and menu.use_blood_fury:get_state()) or false
    local use_berserking = (menu.use_berserking and menu.use_berserking:get_state()) or false
    local use_stoneform = (menu.use_stoneform and menu.use_stoneform:get_state()) or false
    local use_war_stomp = (menu.use_war_stomp_interrupt and menu.use_war_stomp_interrupt:get_state()) or false
    
    -- Register Healthstone middleware (off-GCD, defensive)
    if use_healthstone then
        middleware.register(middleware.healthstone(
            WARRIOR_SPELLS.HEALTHSTONE,
            healthstone_threshold,
            middleware.PRIORITY.RECOVERY_ITEMS
        ))
    end
    
    -- Register Healing Potion middleware (off-GCD, defensive)
    if use_health_potion then
        middleware.register(middleware.healing_potion(
            WARRIOR_SPELLS.HEALING_POTION,
            health_potion_threshold,
            middleware.PRIORITY.RECOVERY_ITEMS - 10  -- Slightly lower priority than healthstone
        ))
    end
    
    -- Register Blood Fury (Orc offensive racial) - lower priority for tanks
    if use_blood_fury then
        middleware.register(middleware.offensive_racial(
            WARRIOR_SPELLS.BLOOD_FURY,
            middleware.PRIORITY.OFFENSIVE_CDS - 20  -- Lower priority for tanks
        ))
    end
    
    -- Register Berserking (Troll offensive/defensive hybrid)
    if use_berserking then
        local berserking_mw = {
            name = "Berserking",
            priority = middleware.PRIORITY.OFFENSIVE_CDS - 25,
            is_burst = true,
            is_defensive = true,  -- Can be used defensively for attack speed = more rage
            is_gcd_gated = true,
            setting_key = "use_berserking",
            matches = function(ctx)
                if not ctx.in_combat then return false end
                if not ctx.target then return false end
                
                -- Check cooldown
                if core.spell_book and core.spell_book.get_spell_cooldown then
                    local cd = core.spell_book.get_spell_cooldown(WARRIOR_SPELLS.BERSERKING)
                    if cd > 0 then return false end
                end
                
                return true
            end,
            execute = function(icon, ctx)
                if core.spell_queue and core.spell_queue.add then
                    core.spell_queue.add(WARRIOR_SPELLS.BERSERKING, "berserking", 80)
                    return true, "[MW] Berserking queued"
                elseif icon and icon.cast then
                    icon:cast(WARRIOR_SPELLS.BERSERKING)
                    return true, "[MW] Berserking"
                end
                return false
            end,
        }
        middleware.register(berserking_mw)
    end
    
    -- Register Stoneform (Dwarf defensive racial) - high priority for tanks
    if use_stoneform then
        local stoneform_threshold = (menu.stoneform_hp_pct and menu.stoneform_hp_pct:get()) or 40
        middleware.register(middleware.defensive_racial(
            WARRIOR_SPELLS.STONEFORM,
            stoneform_threshold,
            middleware.PRIORITY.PVP_DEFENSIVE + 10  -- Higher priority for tanks
        ))
    end
    
    -- Register War Stomp (Tauren stun racial) - as interrupt fallback
    if use_war_stomp then
        local war_stomp_mw = {
            name = "War Stomp",
            priority = middleware.PRIORITY.INTERRUPTS - 5,
            is_defensive = true,
            is_gcd_gated = true,
            setting_key = "use_war_stomp_interrupt",
            matches = function(ctx)
                if not ctx.in_combat then return false end
                if not ctx.target then return false end
                
                -- Only use if target is casting
                if not ctx.target.is_casting or not ctx.target:is_casting() then return false end
                
                -- Check cooldown
                if core.spell_book and core.spell_book.get_spell_cooldown then
                    local cd = core.spell_book.get_spell_cooldown(WARRIOR_SPELLS.WAR_STOMP)
                    if cd > 0 then return false end
                end
                
                return true
            end,
            execute = function(icon, ctx)
                if core.spell_queue and core.spell_queue.add then
                    core.spell_queue.add(WARRIOR_SPELLS.WAR_STOMP, "war_stomp", 85)
                    return true, "[MW] War Stomp queued"
                elseif icon and icon.cast then
                    icon:cast(WARRIOR_SPELLS.WAR_STOMP)
                    return true, "[MW] War Stomp"
                end
                return false
            end,
        }
        middleware.register(war_stomp_mw)
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
