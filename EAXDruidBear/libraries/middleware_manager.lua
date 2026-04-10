-- EAXDruidBear Middleware Manager
-- Integrates libraries/middleware with Druid Bear Tank-specific registrations

local middleware_manager = {}

-- Load the middleware system (from libraries folder)
local middleware = require("libraries/middleware")
local spells = require("libraries/spells")

-- Spell IDs for TBC Druid Bear Tank
local DRUID_SPELLS = {
    -- Defensive cooldowns
    BARKSKIN = 22812,
    INNERVATE = 29166,
    FRENZIED_REGENERATION = 22842,
    THORNS = 26992,          -- Highest rank Thorns
    
    -- Racials
    WAR_STOMP = 20549,       -- Tauren racial stun
    
    -- Items (default IDs, will be resolved)
    HEALTHSTONE = 5512,      -- Minor Healthstone
    HEALING_POTION = 118,    -- Minor Healing Potion
}

-- Track if middleware has been initialized
local _initialized = false

--- Initialize and register all Druid Bear-specific middleware
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
    local healing_potion_threshold = (menu.healing_potion_hp_pct and menu.healing_potion_hp_pct:get()) or 40
    
    local use_barkskin = (menu.use_barkskin and menu.use_barkskin:get_state()) or false
    local barkskin_threshold = (menu.barkskin_hp_pct and menu.barkskin_hp_pct:get()) or 40
    
    local use_frenzied_regen = (menu.use_frenzied_regen and menu.use_frenzied_regen:get_state()) or false
    local frenzied_regen_threshold = (menu.frenzied_regen_hp_pct and menu.frenzied_regen_hp_pct:get()) or 35
    local frenzied_regen_rage_threshold = (menu.frenzied_regen_rage and menu.frenzied_regen_rage:get()) or 50
    
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
    if use_healing_potion then
        middleware.register(middleware.healing_potion(
            DRUID_SPELLS.HEALING_POTION,
            healing_potion_threshold,
            middleware.PRIORITY.RECOVERY_ITEMS - 10
        ))
    end
    
    -- Register Barkskin middleware (emergency defensive)
    if use_barkskin then
        local barkskin_mw = {
            name = "Barkskin",
            priority = middleware.PRIORITY.EMERGENCY_HEAL,
            is_burst = false,
            is_defensive = true,
            is_gcd_gated = true,
            setting_key = "use_barkskin",
            matches = function(ctx)
                if not ctx.in_combat then return false end
                if not ctx.me then return false end
                
                -- Check health percentage
                local hp_pct = 100
                if ctx.me.get_health and ctx.me.get_max_health then
                    local ok_hp, hp = pcall(function() return ctx.me:get_health() end)
                    local ok_max, max_hp = pcall(function() return ctx.me:get_max_health() end)
                    if not ok_hp then hp = 0 end
                    if not ok_max then max_hp = 100 end
                    if max_hp > 0 then
                        hp_pct = (hp / max_hp) * 100
                    end
                end
                
                if hp_pct > barkskin_threshold then return false end
                
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
    
    -- Register Frenzied Regeneration middleware (bear tank self-heal)
    if use_frenzied_regen then
        local frenzied_regen_mw = {
            name = "FrenziedRegeneration",
            priority = middleware.PRIORITY.EMERGENCY_HEAL - 5,
            is_burst = false,
            is_defensive = true,
            is_gcd_gated = true,
            setting_key = "use_frenzied_regen",
            matches = function(ctx)
                if not ctx.in_combat then return false end
                if not ctx.me then return false end
                
                -- Check health percentage
                local hp_pct = 100
                if ctx.me.get_health and ctx.me.get_max_health then
                    local ok_hp, hp = pcall(function() return ctx.me:get_health() end)
                    local ok_max, max_hp = pcall(function() return ctx.me:get_max_health() end)
                    if not ok_hp then hp = 0 end
                    if not ok_max then max_hp = 100 end
                    if max_hp > 0 then
                        hp_pct = (hp / max_hp) * 100
                    end
                end
                
                if hp_pct > frenzied_regen_threshold then return false end
                
                -- Check rage (requires rage to convert to health)
                local rage = 0
                if ctx.me.get_power then
                    local ok, r = pcall(function() return ctx.me:get_power(1) end)
                    if ok then rage = r end
                end
                
                if rage < frenzied_regen_rage_threshold then return false end
                
                -- Check if in bear form
                    local in_bear = core.buff_manager.has_buff(ctx.me, spells.BUFF_BEAR_FORM) or
                              core.buff_manager.has_buff(ctx.me, spells.BUFF_DIRE_BEAR_FORM)
                if not in_bear then return false end
                
                -- Check cooldown
                if core.spell_book and core.spell_book.get_spell_cooldown then
                    local cd = core.spell_book.get_spell_cooldown(DRUID_SPELLS.FRENZIED_REGENERATION)
                    if cd > 0 then return false end
                end
                
                return true
            end,
            execute = function(icon, ctx)
                if core.spell_queue and core.spell_queue.add then
                    core.spell_queue.add(DRUID_SPELLS.FRENZIED_REGENERATION, "frenzied_regen", 85)
                    return true, "[MW] Frenzied Regen queued"
                elseif icon and icon.cast then
                    icon:cast(DRUID_SPELLS.FRENZIED_REGENERATION)
                    return true, "[MW] Frenzied Regen"
                end
                return false
            end,
        }
        middleware.register(frenzied_regen_mw)
    end
    
    -- Register War Stomp (Tauren racial stun)
    if use_war_stomp then
        local war_stomp_threshold = (menu.war_stomp_hp_pct and menu.war_stomp_hp_pct:get()) or 30
        
        local war_stomp_mw = {
            name = "WarStomp",
            priority = middleware.PRIORITY.PVP_DEFENSIVE,
            is_burst = false,
            is_defensive = true,
            is_gcd_gated = true,
            setting_key = "use_war_stomp",
            matches = function(ctx)
                if not ctx.in_combat then return false end
                if not ctx.me then return false end
                
                -- Check health percentage
                local hp_pct = 100
                if ctx.me.get_health and ctx.me.get_max_health then
                    local ok_hp, hp = pcall(function() return ctx.me:get_health() end)
                    local ok_max, max_hp = pcall(function() return ctx.me:get_max_health() end)
                    if not ok_hp then hp = 0 end
                    if not ok_max then max_hp = 100 end
                    if max_hp > 0 then
                        hp_pct = (hp / max_hp) * 100
                    end
                end
                
                if hp_pct > war_stomp_threshold then return false end
                
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
