-- EAXHunterBM Middleware Manager
-- Integrates libraries/middleware with Hunter BM-specific registrations

local middleware_manager = {}

-- Load the middleware system
local middleware = require("libraries/middleware")

-- Spell IDs for TBC Hunter BM
local HUNTER_SPELLS = {
    -- Defensive cooldowns
    DETERRENCE = 19263,
    FEIGN_DEATH = 5384,
    
    -- Racials
    BLOOD_FURY = 20572,      -- Orc offensive racial
    BERSERKING = 26297,      -- Troll offensive/defensive racial
    STONEFORM = 20594,       -- Dwarf defensive racial
    ESCAPE_ARTIST = 20589,   -- Gnome defensive racial
    SHADOWMELD = 1784,       -- Night Elf defensive
    WAR_STOMP = 20549,       -- Tauren stun
    
    -- Items (default IDs, will be resolved)
    HEALTHSTONE = 5512,      -- Minor Healthstone
    HEALING_POTION = 118,    -- Minor Healing Potion
    MANA_POTION = 5996,      -- Major Mana Potion
}

-- Track if middleware has been initialized
local _initialized = false

--- Initialize and register all Hunter BM-specific middleware
-- @param menu table: Menu module for accessing settings
function middleware_manager.initialize(menu)
    if _initialized then return end
    if not menu then return end
    
    -- Clear any existing registrations to avoid duplicates
    middleware.clear()
    
    -- Get settings with nil guards
    local use_healthstone = (menu.use_healthstone and menu.use_healthstone:get_state()) or false
    local healthstone_threshold = (menu.healthstone_hp_pct and menu.healthstone_hp_pct:get()) or 30
    
    local use_healing_potion = (menu.use_healing_potion and menu.use_healing_potion:get_state()) or false
    local health_potion_threshold = (menu.health_potion_hp_pct and menu.health_potion_hp_pct:get()) or 40
    
    local use_mana_potion = (menu.use_mana_potion and menu.use_mana_potion:get_state()) or false
    local mana_potion_threshold = (menu.mana_potion_pct and menu.mana_potion_pct:get()) or 20
    
    local use_blood_fury = (menu.use_blood_fury and menu.use_blood_fury:get_state()) or false
    local use_berserking = (menu.use_berserking and menu.use_berserking:get_state()) or false
    local use_stoneform = (menu.use_stoneform and menu.use_stoneform:get_state()) or false
    
    local use_deterrence = (menu.use_deterrence_mw and menu.use_deterrence_mw:get_state()) or false
    local deterrence_threshold = (menu.deterrence_mw_hp and menu.deterrence_mw_hp:get()) or 15
    
    -- Register Healthstone middleware (off-GCD, defensive)
    if use_healthstone then
        middleware.register(middleware.healthstone(
            HUNTER_SPELLS.HEALTHSTONE,
            healthstone_threshold,
            middleware.PRIORITY.RECOVERY_ITEMS
        ))
    end
    
    -- Register Healing Potion middleware (off-GCD, defensive)
    if use_healing_potion then
        middleware.register(middleware.healing_potion(
            HUNTER_SPELLS.HEALING_POTION,
            health_potion_threshold,
            middleware.PRIORITY.RECOVERY_ITEMS - 10
        ))
    end
    
    -- Register Mana Potion middleware (off-GCD, for mana users)
    if use_mana_potion then
        middleware.register(middleware.mana_potion(
            HUNTER_SPELLS.MANA_POTION,
            mana_potion_threshold,
            middleware.PRIORITY.MANA_RECOVERY
        ))
    end
    
    -- Register Deterrence middleware (emergency defensive)
    if use_deterrence then
        local deterrence_mw = {
            name = "Deterrence",
            priority = middleware.PRIORITY.PVP_DEFENSIVE,
            is_burst = false,
            is_defensive = true,
            is_gcd_gated = true,
            setting_key = "use_deterrence_mw",
            matches = function(ctx)
                if not ctx.in_combat then return false end
                if not ctx.me then return false end
                
                -- Check health percentage
                local hp_pct = ctx.hp_pct or 100
                if hp_pct > deterrence_threshold then return false end
                
                -- Check cooldown
                if core.spell_book and core.spell_book.get_spell_cooldown then
                    local cd = core.spell_book.get_spell_cooldown(HUNTER_SPELLS.DETERRENCE)
                    if cd > 0 then return false end
                end
                
                return true
            end,
            execute = function(icon, ctx)
                if core.spell_queue and core.spell_queue.add then
                    core.spell_queue.add(HUNTER_SPELLS.DETERRENCE, "deterrence", 95)
                    return true, "[MW] Deterrence queued"
                elseif icon and icon.cast then
                    icon:cast(HUNTER_SPELLS.DETERRENCE)
                    return true, "[MW] Deterrence"
                end
                return false
            end,
        }
        middleware.register(deterrence_mw)
    end
    
    -- Register Blood Fury (Orc offensive racial)
    if use_blood_fury then
        middleware.register(middleware.offensive_racial(
            HUNTER_SPELLS.BLOOD_FURY,
            middleware.PRIORITY.OFFENSIVE_CDS
        ))
    end
    
    -- Register Berserking (Troll offensive/defensive hybrid)
    if use_berserking then
        local berserking_mw = {
            name = "Berserking",
            priority = middleware.PRIORITY.OFFENSIVE_CDS - 5,
            is_burst = true,
            is_defensive = true,
            is_gcd_gated = true,
            setting_key = "use_berserking",
            matches = function(ctx)
                if not ctx.in_combat then return false end
                if not ctx.target then return false end
                
                -- Check cooldown
                if core.spell_book and core.spell_book.get_spell_cooldown then
                    local cd = core.spell_book.get_spell_cooldown(HUNTER_SPELLS.BERSERKING)
                    if cd > 0 then return false end
                end
                
                return true
            end,
            execute = function(icon, ctx)
                if core.spell_queue and core.spell_queue.add then
                    core.spell_queue.add(HUNTER_SPELLS.BERSERKING, "berserking", 80)
                    return true, "[MW] Berserking queued"
                elseif icon and icon.cast then
                    icon:cast(HUNTER_SPELLS.BERSERKING)
                    return true, "[MW] Berserking"
                end
                return false
            end,
        }
        middleware.register(berserking_mw)
    end
    
    -- Register Stoneform (Dwarf defensive racial)
    if use_stoneform then
        local stoneform_threshold = (menu.stoneform_hp_pct and menu.stoneform_hp_pct:get()) or 40
        middleware.register(middleware.defensive_racial(
            HUNTER_SPELLS.STONEFORM,
            stoneform_threshold,
            middleware.PRIORITY.PVP_DEFENSIVE
        ))
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
