-- EAXRogueCombat Middleware Manager
-- Integrates libraries/middleware with Combat Rogue-specific registrations

local middleware_manager = {}

-- Load the middleware system
local middleware = require("libraries/middleware")

-- Spell IDs for TBC Combat Rogue
local ROGUE_SPELLS = {
    -- Offensive cooldowns
    BLADE_FLURRY = 13877,
    ADRENALINE_RUSH = 13750,
    
    -- Defensive/Utility
    VANISH = 26889,
    EVASION = 26669,
    CLOAK_OF_SHADOWS = 31224,
    PREPARATION = 14185,
    
    -- Racials
    BLOOD_FURY = 20572,
    BERSERKING = 26297,
    STONEFORM = 20594,
    ESCAPE_ARTIST = 20589,
    
    -- Items
    HEALTHSTONE = 5512,
    HEALING_POTION = 118,
}

-- Track if middleware has been initialized
local _initialized = false

--- Initialize and register all Combat Rogue-specific middleware
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
    
    local use_blade_flurry = (menu.use_blade_flurry and menu.use_blade_flurry:get_state()) or false
    local use_adrenaline_rush = (menu.use_adrenaline_rush and menu.use_adrenaline_rush:get_state()) or false
    
    local use_vanish = (menu.use_vanish and menu.use_vanish:get_state()) or false
    local vanish_threshold = (menu.vanish_hp_pct and menu.vanish_hp_pct:get()) or 20
    
    local use_evasion = (menu.use_evasion and menu.use_evasion:get_state()) or false
    local evasion_threshold = (menu.evasion_hp_pct and menu.evasion_hp_pct:get()) or 30
    
    local use_cloak_of_shadows = (menu.use_cloak_of_shadows and menu.use_cloak_of_shadows:get_state()) or false
    
    local use_blood_fury = (menu.use_blood_fury and menu.use_blood_fury:get_state()) or false
    local use_berserking = (menu.use_berserking and menu.use_berserking:get_state()) or false
    local use_stoneform = (menu.use_stoneform and menu.use_stoneform:get_state()) or false
    
    -- Register Healthstone middleware
    if use_healthstone then
        middleware.register(middleware.healthstone(
            ROGUE_SPELLS.HEALTHSTONE,
            healthstone_threshold,
            middleware.PRIORITY.RECOVERY_ITEMS
        ))
    end
    
    -- Register Healing Potion middleware
    if use_healing_potion then
        middleware.register(middleware.healing_potion(
            ROGUE_SPELLS.HEALING_POTION,
            healing_potion_threshold,
            middleware.PRIORITY.RECOVERY_ITEMS - 10
        ))
    end
    
    -- Register Blade Flurry middleware (offensive cleave)
    if use_blade_flurry then
        local blade_flurry_mw = {
            name = "Blade Flurry",
            priority = middleware.PRIORITY.OFFENSIVE_CDS,
            is_burst = true,
            is_defensive = false,
            is_gcd_gated = true,
            setting_key = "use_blade_flurry",
            matches = function(ctx)
                if not ctx.in_combat then return false end
                if not ctx.target then return false end
                
                if core.spell_book and core.spell_book.get_spell_cooldown then
                    local cd = core.spell_book.get_spell_cooldown(ROGUE_SPELLS.BLADE_FLURRY)
                    if cd > 0 then return false end
                end
                
                return true
            end,
            execute = function(icon, ctx)
                if icon and icon.cast then
                    icon:cast(ROGUE_SPELLS.BLADE_FLURRY)
                    return true, "[MW] Blade Flurry"
                end
                return false
            end,
        }
        middleware.register(blade_flurry_mw)
    end
    
    -- Register Adrenaline Rush middleware (energy regen)
    if use_adrenaline_rush then
        local adrenaline_rush_mw = {
            name = "Adrenaline Rush",
            priority = middleware.PRIORITY.OFFENSIVE_CDS - 5,
            is_burst = true,
            is_defensive = false,
            is_gcd_gated = true,
            setting_key = "use_adrenaline_rush",
            matches = function(ctx)
                if not ctx.in_combat then return false end
                if not ctx.target then return false end
                
                if core.spell_book and core.spell_book.get_spell_cooldown then
                    local cd = core.spell_book.get_spell_cooldown(ROGUE_SPELLS.ADRENALINE_RUSH)
                    if cd > 0 then return false end
                end
                
                return true
            end,
            execute = function(icon, ctx)
                if icon and icon.cast then
                    icon:cast(ROGUE_SPELLS.ADRENALINE_RUSH)
                    return true, "[MW] Adrenaline Rush"
                end
                return false
            end,
        }
        middleware.register(adrenaline_rush_mw)
    end
    
    -- Register Vanish middleware (emergency defensive)
    if use_vanish then
        local vanish_mw = {
            name = "Vanish",
            priority = middleware.PRIORITY.EMERGENCY_HEAL,
            is_burst = false,
            is_defensive = true,
            is_gcd_gated = true,
            setting_key = "use_vanish",
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
                
                if hp_pct > vanish_threshold then return false end
                
                if core.spell_book and core.spell_book.get_spell_cooldown then
                    local cd = core.spell_book.get_spell_cooldown(ROGUE_SPELLS.VANISH)
                    if cd > 0 then return false end
                end
                
                return true
            end,
            execute = function(icon, ctx)
                if icon and icon.cast then
                    icon:cast(ROGUE_SPELLS.VANISH)
                    return true, "[MW] Vanish"
                end
                return false
            end,
        }
        middleware.register(vanish_mw)
    end
    
    -- Register Evasion middleware (defensive)
    if use_evasion then
        local evasion_mw = {
            name = "Evasion",
            priority = middleware.PRIORITY.PVP_DEFENSIVE,
            is_burst = false,
            is_defensive = true,
            is_gcd_gated = true,
            setting_key = "use_evasion",
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
                
                if hp_pct > evasion_threshold then return false end
                
                if core.spell_book and core.spell_book.get_spell_cooldown then
                    local cd = core.spell_book.get_spell_cooldown(ROGUE_SPELLS.EVASION)
                    if cd > 0 then return false end
                end
                
                return true
            end,
            execute = function(icon, ctx)
                if icon and icon.cast then
                    icon:cast(ROGUE_SPELLS.EVASION)
                    return true, "[MW] Evasion"
                end
                return false
            end,
        }
        middleware.register(evasion_mw)
    end
    
    -- Register Cloak of Shadows middleware (spell immunity)
    if use_cloak_of_shadows then
        local cloak_threshold = (menu.cloak_hp_pct and menu.cloak_hp_pct:get()) or 35
        local cloak_mw = {
            name = "Cloak of Shadows",
            priority = middleware.PRIORITY.PVP_DEFENSIVE - 5,
            is_burst = false,
            is_defensive = true,
            is_gcd_gated = true,
            setting_key = "use_cloak_of_shadows",
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
                
                if hp_pct > cloak_threshold then return false end
                
                if core.spell_book and core.spell_book.get_spell_cooldown then
                    local cd = core.spell_book.get_spell_cooldown(ROGUE_SPELLS.CLOAK_OF_SHADOWS)
                    if cd > 0 then return false end
                end
                
                return true
            end,
            execute = function(icon, ctx)
                if icon and icon.cast then
                    icon:cast(ROGUE_SPELLS.CLOAK_OF_SHADOWS)
                    return true, "[MW] Cloak of Shadows"
                end
                return false
            end,
        }
        middleware.register(cloak_mw)
    end
    
    -- Register Blood Fury (Orc offensive racial)
    if use_blood_fury then
        middleware.register(middleware.offensive_racial(
            ROGUE_SPELLS.BLOOD_FURY,
            middleware.PRIORITY.OFFENSIVE_CDS - 5
        ))
    end
    
    -- Register Berserking (Troll racial)
    if use_berserking then
        middleware.register(middleware.offensive_racial(
            ROGUE_SPELLS.BERSERKING,
            middleware.PRIORITY.OFFENSIVE_CDS - 5
        ))
    end
    
    -- Register Stoneform (Dwarf defensive racial)
    if use_stoneform then
        local stoneform_threshold = (menu.stoneform_hp_pct and menu.stoneform_hp_pct:get()) or 40
        middleware.register(middleware.defensive_racial(
            ROGUE_SPELLS.STONEFORM,
            stoneform_threshold,
            middleware.PRIORITY.PVP_DEFENSIVE
        ))
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
