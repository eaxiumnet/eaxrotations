-- EAXShamanEnhancement Middleware Manager
-- Integrates libraries/middleware with Enhancement Shaman-specific registrations

local middleware_manager = {}

-- Load the middleware system
local middleware = require("libraries/middleware")

-- Spell IDs for TBC Enhancement Shaman
local SHAMAN_SPELLS = {
    -- Racials
    BLOOD_FURY = 20572,      -- Orc attack power racial
    BERSERKING = 26297,      -- Troll offensive racial
    WAR_STOMP = 20549,       -- Tauren defensive racial
    GIFT_OF_THE_NAARU = 28880, -- Draenei heal racial
    
    -- Cooldowns
    SHAMANISTIC_RAGE = 30823,
    BLOODLUST = 2825,
    HEROISM = 32182,
    
    -- Items (default IDs, will be resolved)
    HEALTHSTONE = 5512,
    HEALING_POTION = 118,
    MANA_POTION = 22832,
}

-- Track if middleware has been initialized
local _initialized = false

--- Initialize and register all Enhancement Shaman-specific middleware
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
    local mana_potion_threshold = (menu.mana_potion_pct and menu.mana_potion_pct:get()) or 30
    
    local use_blood_fury = (menu.use_blood_fury and menu.use_blood_fury:get_state()) or false
    local use_berserking = (menu.use_berserking and menu.use_berserking:get_state()) or false
    local use_bloodlust = (menu.use_bloodlust and menu.use_bloodlust:get_state()) or false
    local use_shamanistic_rage = (menu.use_shamanistic_rage and menu.use_shamanistic_rage:get_state()) or false
    
    -- Register Healthstone middleware (off-GCD, defensive)
    if use_healthstone then
        middleware.register(middleware.healthstone(
            SHAMAN_SPELLS.HEALTHSTONE,
            healthstone_threshold,
            middleware.PRIORITY.RECOVERY_ITEMS
        ))
    end
    
    -- Register Healing Potion middleware (off-GCD, defensive)
    if use_health_potion then
        middleware.register(middleware.healing_potion(
            SHAMAN_SPELLS.HEALING_POTION,
            health_potion_threshold,
            middleware.PRIORITY.RECOVERY_ITEMS - 10
        ))
    end
    
    -- Register Mana Potion middleware (off-GCD, recovery)
    if use_mana_potion then
        local mana_mw = {
            name = "Mana Potion",
            priority = middleware.PRIORITY.RECOVERY_ITEMS - 5,
            is_burst = false,
            is_defensive = true,
            is_gcd_gated = false,
            setting_key = "use_mana_potion",
            matches = function(ctx)
                if not ctx.in_combat then return false end
                if not ctx.me then return false end
                
                local mana_pct = ctx.me:get_power_percentage() or 100
                if mana_pct > mana_potion_threshold then return false end
                
                -- Check cooldown
                if core.spell_book and core.spell_book.get_item_cooldown then
                    local cd = core.spell_book.get_item_cooldown(SHAMAN_SPELLS.MANA_POTION)
                    if cd > 0 then return false end
                end
                
                return true
            end,
            execute = function(icon, ctx)
                if icon and icon.cast then
                    icon:cast(SHAMAN_SPELLS.MANA_POTION)
                    return true, "[MW] Mana Potion"
                end
                return false
            end,
        }
        middleware.register(mana_mw)
    end
    
    -- Register Blood Fury (Orc offensive racial - attack power)
    if use_blood_fury then
        middleware.register(middleware.offensive_racial(
            SHAMAN_SPELLS.BLOOD_FURY,
            middleware.PRIORITY.OFFENSIVE_CDS
        ))
    end
    
    -- Register Berserking (Troll offensive racial)
    if use_berserking then
        middleware.register(middleware.offensive_racial(
            SHAMAN_SPELLS.BERSERKING,
            middleware.PRIORITY.OFFENSIVE_CDS - 5
        ))
    end
    
    -- Register Bloodlust/Heroism middleware
    if use_bloodlust then
        local bloodlust_mw = {
            name = "Bloodlust/Heroism",
            priority = middleware.PRIORITY.OFFENSIVE_CDS + 10,
            is_burst = true,
            is_defensive = false,
            is_gcd_gated = true,
            setting_key = "use_bloodlust",
            matches = function(ctx)
                if not ctx.in_combat then return false end
                if not ctx.target then return false end
                
                -- Check if already has Bloodlust buff
                local spells = require("libraries/spells")
                if ctx.me and spells.BUFF_BLOODLUST then
                    for _, id in ipairs(spells.BUFF_BLOODLUST) do
                        if ctx.me:has_buff(id) then return false end
                    end
                end
                
                -- Check cooldown
                local spell_id = SHAMAN_SPELLS.BLOODLUST
                if core.spell_book and core.spell_book.get_spell_cooldown then
                    local cd = core.spell_book.get_spell_cooldown(spell_id)
                    if cd > 0 then return false end
                end
                
                return true
            end,
            execute = function(icon, ctx)
                local spell_id = SHAMAN_SPELLS.BLOODLUST
                if icon and icon.cast then
                    icon:cast(spell_id)
                    return true, "[MW] Bloodlust"
                end
                return false
            end,
        }
        middleware.register(bloodlust_mw)
    end
    
    -- Register Shamanistic Rage middleware
    if use_shamanistic_rage then
        local rage_threshold = (menu.shamanistic_rage_mana_pct and menu.shamanistic_rage_mana_pct:get()) or 50
        local min_ttd = (menu.cd_min_ttd and menu.cd_min_ttd:get()) or 0
        local rage_mw = {
            name = "Shamanistic Rage",
            priority = middleware.PRIORITY.OFFENSIVE_CDS - 10,
            is_burst = true,
            is_defensive = false,
            is_gcd_gated = true,
            setting_key = "use_shamanistic_rage",
            matches = function(ctx)
                if not ctx.in_combat then return false end
                if not ctx.target then return false end
                if not ctx.me then return false end
                
                -- Check mana threshold
                local mana_pct = ctx.me:get_power_percentage() or 100
                if mana_pct > rage_threshold then return false end
                
                -- TTD gating for burst CDs
                if min_ttd > 0 and ctx.target then
                    ---@type combat_forecast
                    local forecast = require("libraries/combat_forecast")
                    if not forecast:is_valid_forecast_logic(min_ttd, ctx.target, false) then
                        return false
                    end
                end
                
                -- Check cooldown
                if core.spell_book and core.spell_book.get_spell_cooldown then
                    local cd = core.spell_book.get_spell_cooldown(SHAMAN_SPELLS.SHAMANISTIC_RAGE)
                    if cd > 0 then return false end
                end
                
                return true
            end,
            execute = function(icon, ctx)
                if icon and icon.cast then
                    icon:cast(SHAMAN_SPELLS.SHAMANISTIC_RAGE)
                    return true, "[MW] Shamanistic Rage"
                end
                return false
            end,
        }
        middleware.register(rage_mw)
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
