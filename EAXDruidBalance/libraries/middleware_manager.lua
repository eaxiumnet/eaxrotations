-- EAXDruidBalance Middleware Manager
-- Integrates libraries/middleware with Druid Balance-specific registrations

local middleware_manager = {}

-- Load the middleware system (from libraries folder)
local middleware = require("libraries/middleware")

-- Spell IDs for TBC Druid Balance
local DRUID_SPELLS = {
    -- Racials
    WAR_STOMP = 20549,       -- Tauren racial stun
    
    -- Druid spells
    INNERVATE = 29166,       -- Mana restoration
    BARKSKIN = 22812,        -- Emergency defensive
    THORNS = 26992,          -- Highest rank Thorns
    
    -- Items (default IDs, will be resolved)
    HEALTHSTONE = 5512,      -- Minor Healthstone
    HEALING_POTION = 118,    -- Minor Healing Potion
    MANA_POTION = 5996,      -- Major Mana Potion
}

-- Track if middleware has been initialized
local _initialized = false

--- Initialize and register all Druid Balance-specific middleware
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
    
    local use_mana_potion = (menu.use_mana_potion and menu.use_mana_potion:get_state()) or false
    local mana_potion_threshold = (menu.mana_potion_pct and menu.mana_potion_pct:get()) or 15
    
    local use_innervate = (menu.use_innervate and menu.use_innervate:get_state()) or false
    local innervate_threshold = (menu.innervate_mana_pct and menu.innervate_mana_pct:get()) or 20
    
    local use_barkskin = (menu.use_barkskin and menu.use_barkskin:get_state()) or false
    local barkskin_threshold = (menu.barkskin_hp_pct and menu.barkskin_hp_pct:get()) or 30
    
    local use_war_stomp = (menu.use_war_stomp and menu.use_war_stomp:get_state()) or false
    
    local use_thorns = (menu.use_thorns and menu.use_thorns:get_state()) or false
    local use_motw = (menu.use_motw and menu.use_motw:get_state()) or false
    
    -- Register Healthstone middleware (off-GCD, defensive)
    if use_healthstone then
        middleware.register(middleware.healthstone(
            DRUID_SPELLS.HEALTHSTONE,
            healthstone_threshold,
            middleware.PRIORITY.RECOVERY_ITEMS
        ))
    end
    
    -- Register Healing Potion middleware (off-GCD, defensive)
    if use_health_potion then
        middleware.register(middleware.healing_potion(
            DRUID_SPELLS.HEALING_POTION,
            health_potion_threshold,
            middleware.PRIORITY.RECOVERY_ITEMS - 10  -- Slightly lower priority than healthstone
        ))
    end
    
    -- Register Mana Potion middleware (off-GCD, mana recovery)
    if use_mana_potion then
        middleware.register(middleware.mana_potion(
            DRUID_SPELLS.MANA_POTION,
            mana_potion_threshold,
            middleware.PRIORITY.MANA_RECOVERY
        ))
    end
    
    -- Register Innervate middleware (mana recovery, in combat)
    if use_innervate then
        local innervate_mw = {
            name = "Innervate",
            priority = middleware.PRIORITY.MANA_RECOVERY - 5,
            is_burst = false,
            is_defensive = false,
            is_gcd_gated = true,
            setting_key = "use_innervate",
            matches = function(ctx)
                if not ctx.in_combat then return false end
                if ctx.mp_pct >= innervate_threshold then return false end
                
                -- Check cooldown
                if core.spell_book and core.spell_book.get_spell_cooldown then
                    local cd = core.spell_book.get_spell_cooldown(DRUID_SPELLS.INNERVATE)
                    if cd > 0 then return false end
                end
                
                return true
            end,
            execute = function(icon, ctx)
                if core.spell_queue and core.spell_queue.add then
                    core.spell_queue.add(DRUID_SPELLS.INNERVATE, "innervate", 85)
                    return true, "[MW] Innervate queued"
                elseif icon and icon.cast then
                    icon:cast(DRUID_SPELLS.INNERVATE)
                    return true, "[MW] Innervate"
                end
                return false
            end,
        }
        middleware.register(innervate_mw)
    end
    
    -- Register Barkskin middleware (emergency defensive)
    if use_barkskin then
        local barkskin_mw = {
            name = "Barkskin",
            priority = middleware.PRIORITY.PVP_DEFENSIVE,
            is_burst = false,
            is_defensive = true,
            is_gcd_gated = true,
            setting_key = "use_barkskin",
            matches = function(ctx)
                if ctx.hp_pct >= barkskin_threshold then return false end
                if not ctx.in_combat then return false end
                
                -- Check cooldown
                if core.spell_book and core.spell_book.get_spell_cooldown then
                    local cd = core.spell_book.get_spell_cooldown(DRUID_SPELLS.BARKSKIN)
                    if cd > 0 then return false end
                end
                
                return true
            end,
            execute = function(icon, ctx)
                if core.spell_queue and core.spell_queue.add then
                    core.spell_queue.add(DRUID_SPELLS.BARKSKIN, "barkskin", 90)
                    return true, "[MW] Barkskin queued"
                elseif icon and icon.cast then
                    icon:cast(DRUID_SPELLS.BARKSKIN)
                    return true, "[MW] Barkskin"
                end
                return false
            end,
        }
        middleware.register(barkskin_mw)
    end
    
    -- Register War Stomp (Tauren racial)
    if use_war_stomp then
        local war_stomp_mw = {
            name = "WarStomp",
            priority = middleware.PRIORITY.PVP_DEFENSIVE - 5,
            is_burst = false,
            is_defensive = true,
            is_gcd_gated = true,
            setting_key = "use_war_stomp",
            matches = function(ctx)
                if not ctx.in_combat then return false end
                -- Use as emergency defensive when HP is low
                if ctx.hp_pct >= 35 then return false end
                
                -- Check cooldown
                if core.spell_book and core.spell_book.get_spell_cooldown then
                    local cd = core.spell_book.get_spell_cooldown(DRUID_SPELLS.WAR_STOMP)
                    if cd > 0 then return false end
                end
                
                return true
            end,
            execute = function(icon, ctx)
                if core.spell_queue and core.spell_queue.add then
                    core.spell_queue.add(DRUID_SPELLS.WAR_STOMP, "war_stomp", 80)
                    return true, "[MW] War Stomp queued"
                elseif icon and icon.cast then
                    icon:cast(DRUID_SPELLS.WAR_STOMP)
                    return true, "[MW] War Stomp"
                end
                return false
            end,
        }
        middleware.register(war_stomp_mw)
    end
    
    -- Register Thorns self-buff middleware (OOC only)
    if use_thorns then
        middleware.register(middleware.self_buff(
            DRUID_SPELLS.THORNS,
            DRUID_SPELLS.THORNS,
            middleware.PRIORITY.SELF_BUFFS,
            true  -- OOC only
        ))
    end
    
    -- Register Mark of the Wild self-buff middleware (OOC only)
    if use_motw then
        middleware.register(middleware.self_buff(
            26990,  -- Highest rank MOTW
            26990,  -- MOTW buff ID
            middleware.PRIORITY.SELF_BUFFS - 5,
            true  -- OOC only
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
