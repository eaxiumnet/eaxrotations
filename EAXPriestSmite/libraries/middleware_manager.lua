-- EAXPriestSmite Middleware Manager
-- Integrates libraries/middleware with Smite Priest-specific registrations

local middleware_manager = {}

-- Load the middleware system
local middleware = require("libraries/middleware")

-- Spell IDs for TBC Smite Priest
local PRIEST_SPELLS = {
    -- Defensive cooldowns
    INNER_FOCUS = 14751,
    POWER_INFUSION = 10060,
    
    -- Mana recovery
    SHADOWFIEND = 34433,
    
    -- Racials
    BERSERKING = 26297,
    ARCANE_TORRENT = 28730,
    DESPERATE_PRAYER = 25437,
    
    -- Items
    HEALTHSTONE = 5512,
    HEALING_POTION = 118,
    SUPER_MANA_POTION = 22832,
}

-- Track if middleware has been initialized
local _initialized = false

--- Initialize and register all Smite Priest-specific middleware
-- @param menu table: Menu module for accessing settings
function middleware_manager.initialize(menu)
    if _initialized then return end
    if not menu then return end
    
    -- Clear any existing registrations
    middleware.clear()
    
    -- Get settings with nil guards
    local use_healthstone = (menu.use_healthstone and menu.use_healthstone:get_state()) or false
    local healthstone_threshold = (menu.healthstone_hp_pct and menu.healthstone_hp_pct:get()) or 30
    
    local use_healing_potion = (menu.use_healing_potion and menu.use_healing_potion:get_state()) or false
    local healing_potion_threshold = (menu.healing_potion_hp_pct and menu.healing_potion_hp_pct:get()) or 40
    
    local use_mana_potion = (menu.use_mana_potion and menu.use_mana_potion:get_state()) or false
    local mana_potion_threshold = (menu.mana_potion_pct and menu.mana_potion_pct:get()) or 20
    
    local use_shadowfiend = (menu.use_shadowfiend and menu.use_shadowfiend:get_state()) or false
    local shadowfiend_threshold = (menu.shadowfiend_mana_pct and menu.shadowfiend_mana_pct:get()) or 30
    
    local use_power_infusion = (menu.use_power_infusion and menu.use_power_infusion:get_state()) or false
    
    local use_berserking = (menu.use_berserking and menu.use_berserking:get_state()) or false
    local use_desperate_prayer = (menu.use_desperate_prayer and menu.use_desperate_prayer:get_state()) or false
    
    -- Register Healthstone middleware
    if use_healthstone then
        middleware.register(middleware.healthstone(
            PRIEST_SPELLS.HEALTHSTONE,
            healthstone_threshold,
            middleware.PRIORITY.RECOVERY_ITEMS
        ))
    end
    
    -- Register Healing Potion middleware
    if use_healing_potion then
        middleware.register(middleware.healing_potion(
            PRIEST_SPELLS.HEALING_POTION,
            healing_potion_threshold,
            middleware.PRIORITY.RECOVERY_ITEMS - 10
        ))
    end
    
    -- Register Mana Potion middleware
    if use_mana_potion then
        local mana_potion_mw = {
            name = "Mana Potion",
            priority = middleware.PRIORITY.MANA_RECOVERY,
            is_burst = false,
            is_defensive = true,
            is_gcd_gated = false,
            setting_key = "use_mana_potion",
            matches = function(ctx)
                if not ctx.in_combat then return false end
                if not ctx.me then return false end
                
                local mana_pct = 100
                if ctx.me.get_power and ctx.me.get_max_power then
                    local ok_mana, mana = pcall(function() return ctx.me:get_power(0) end)
                    local ok_max, max_mana = pcall(function() return ctx.me:get_max_power(0) end)
                    if ok_mana and ok_max and max_mana > 0 then
                        mana_pct = (mana / max_mana) * 100
                    end
                end
                
                if mana_pct > mana_potion_threshold then return false end
                return true
            end,
            execute = function(icon, ctx)
                if core.spell_queue and core.spell_queue.add then
                    core.spell_queue.add(PRIEST_SPELLS.SUPER_MANA_POTION, "mana_potion", 85)
                    return true, "[MW] Mana potion queued"
                elseif icon and icon.cast then
                    icon:cast(PRIEST_SPELLS.SUPER_MANA_POTION)
                    return true, "[MW] Mana potion"
                end
                return false
            end,
        }
        middleware.register(mana_potion_mw)
    end
    
    -- Register Shadowfiend middleware (mana recovery)
    if use_shadowfiend then
        local shadowfiend_mw = {
            name = "Shadowfiend",
            priority = middleware.PRIORITY.MANA_RECOVERY,
            is_burst = false,
            is_defensive = true,
            is_gcd_gated = true,
            setting_key = "use_shadowfiend",
            matches = function(ctx)
                if not ctx.in_combat then return false end
                if not ctx.me then return false end
                if not ctx.target then return false end
                
                local mana_pct = 100
                if ctx.me.get_power and ctx.me.get_max_power then
                    local ok_mana, mana = pcall(function() return ctx.me:get_power(0) end)
                    local ok_max, max_mana = pcall(function() return ctx.me:get_max_power(0) end)
                    if ok_mana and ok_max and max_mana > 0 then
                        mana_pct = (mana / max_mana) * 100
                    end
                end
                
                if mana_pct > shadowfiend_threshold then return false end
                
                if core.spell_book and core.spell_book.get_spell_cooldown then
                    local cd = core.spell_book.get_spell_cooldown(PRIEST_SPELLS.SHADOWFIEND)
                    if cd > 0 then return false end
                end
                
                return true
            end,
            execute = function(icon, ctx)
                if core.spell_queue and core.spell_queue.add then
                    core.spell_queue.add(PRIEST_SPELLS.SHADOWFIEND, "shadowfiend", 80)
                    return true, "[MW] Shadowfiend queued"
                elseif icon and icon.cast then
                    icon:cast(PRIEST_SPELLS.SHADOWFIEND)
                    return true, "[MW] Shadowfiend"
                end
                return false
            end,
        }
        middleware.register(shadowfiend_mw)
    end
    
    -- Register Power Infusion middleware (offensive CD)
    if use_power_infusion then
        local min_ttd = (menu.cd_min_ttd and menu.cd_min_ttd:get()) or 0
        local power_infusion_mw = {
            name = "Power Infusion",
            priority = middleware.PRIORITY.OFFENSIVE_CDS,
            is_burst = true,
            is_defensive = false,
            is_gcd_gated = true,
            setting_key = "use_power_infusion",
            matches = function(ctx)
                if not ctx.in_combat then return false end
                if not ctx.target then return false end
                
                -- TTD gating for burst CDs
                if min_ttd > 0 and ctx.target then
                    ---@type combat_forecast
                    local forecast = require("libraries/combat_forecast")
                    if not forecast:is_valid_forecast_logic(min_ttd, ctx.target, false) then
                        return false
                    end
                end
                
                if core.spell_book and core.spell_book.get_spell_cooldown then
                    local cd = core.spell_book.get_spell_cooldown(PRIEST_SPELLS.POWER_INFUSION)
                    if cd > 0 then return false end
                end
                
                return true
            end,
            execute = function(icon, ctx)
                if core.spell_queue and core.spell_queue.add then
                    core.spell_queue.add(PRIEST_SPELLS.POWER_INFUSION, "power_infusion", 85)
                    return true, "[MW] Power Infusion queued"
                elseif icon and icon.cast then
                    icon:cast(PRIEST_SPELLS.POWER_INFUSION)
                    return true, "[MW] Power Infusion"
                end
                return false
            end,
        }
        middleware.register(power_infusion_mw)
    end
    
    -- Register Berserking (Troll racial)
    if use_berserking then
        middleware.register(middleware.offensive_racial(
            PRIEST_SPELLS.BERSERKING,
            middleware.PRIORITY.OFFENSIVE_CDS
        ))
    end
    
    -- Register Desperate Prayer (Dwarf/Human racial heal)
    if use_desperate_prayer then
        local desperate_threshold = (menu.desperate_prayer_hp_pct and menu.desperate_prayer_hp_pct:get()) or 30
        local desperate_prayer_mw = {
            name = "Desperate Prayer",
            priority = middleware.PRIORITY.EMERGENCY_HEAL - 5,
            is_burst = false,
            is_defensive = true,
            is_gcd_gated = true,
            setting_key = "use_desperate_prayer",
            matches = function(ctx)
                if not ctx.in_combat then return false end
                if not ctx.me then return false end
                
                local hp_pct = 100
                if ctx.me.get_health and ctx.me.get_max_health then
                    local hp = ctx.me:get_health()
                    local max_hp = ctx.me:get_max_health()
                    if max_hp > 0 then
                        hp_pct = (hp / max_hp) * 100
                    end
                end
                
                if hp_pct > desperate_threshold then return false end
                
                if core.spell_book and core.spell_book.get_spell_cooldown then
                    local cd = core.spell_book.get_spell_cooldown(PRIEST_SPELLS.DESPERATE_PRAYER)
                    if cd > 0 then return false end
                end
                
                return true
            end,
            execute = function(icon, ctx)
                if core.spell_queue and core.spell_queue.add then
                    core.spell_queue.add(PRIEST_SPELLS.DESPERATE_PRAYER, "desperate_prayer", 90)
                    return true, "[MW] Desperate Prayer queued"
                elseif icon and icon.cast then
                    icon:cast(PRIEST_SPELLS.DESPERATE_PRAYER)
                    return true, "[MW] Desperate Prayer"
                end
                return false
            end,
        }
        middleware.register(desperate_prayer_mw)
    end
    
    _initialized = true
end

--- Re-initialize middleware
function middleware_manager.reinitialize(menu)
    _initialized = false
    middleware_manager.initialize(menu)
end

--- Execute middleware chain
function middleware_manager.execute(icon, context)
    return middleware.execute(icon, context)
end

--- Build context from rotation state
function middleware_manager.build_context(me, target, settings)
    return middleware.build_context(me, target, settings)
end

--- Get debug information
function middleware_manager.debug_info()
    return middleware.debug_info()
end

--- Print debug information
function middleware_manager.print_debug()
    middleware.print_debug()
end

--- Check if middleware is initialized
function middleware_manager.is_initialized()
    return _initialized
end

return middleware_manager
