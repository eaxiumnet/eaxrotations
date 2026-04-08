-- EAXRogueSubtlety Middleware Manager
-- Integrates libraries/middleware with Subtlety Rogue-specific registrations

local middleware_manager = {}

-- Load the middleware system
local middleware = require("libraries/middleware")

-- Spell IDs for TBC Subtlety Rogue
local ROGUE_SPELLS = {
    -- Offensive cooldowns
    COLD_BLOOD = 14177,
    PREMEDITATION = 14183,
    
    -- Defensive/Utility
    VANISH = 26889,
    EVASION = 26669,
    CLOAK_OF_SHADOWS = 31224,
    PREPARATION = 14185,
    SHADOWSTEP = 36554,
    
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

--- Initialize and register all Subtlety Rogue-specific middleware
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
    
    local use_cold_blood = (menu.use_cold_blood and menu.use_cold_blood:get_state()) or false
    local use_premeditation = (menu.use_premeditation and menu.use_premeditation:get_state()) or false
    local use_shadowstep = (menu.use_shadowstep and menu.use_shadowstep:get_state()) or false
    
    local use_vanish = (menu.use_vanish and menu.use_vanish:get_state()) or false
    local vanish_threshold = (menu.vanish_hp_pct and menu.vanish_hp_pct:get()) or 20
    
    local use_evasion = (menu.use_evasion and menu.use_evasion:get_state()) or false
    local evasion_threshold = (menu.evasion_hp_pct and menu.evasion_hp_pct:get()) or 30
    
    local use_cloak_of_shadows = (menu.use_cloak_of_shadows and menu.use_cloak_of_shadows:get_state()) or false
    local use_preparation = (menu.use_preparation and menu.use_preparation:get_state()) or false
    
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
    
    -- Register Cold Blood middleware (offensive burst)
    if use_cold_blood then
        local cold_blood_mw = {
            name = "Cold Blood",
            priority = middleware.PRIORITY.OFFENSIVE_CDS,
            is_burst = true,
            is_defensive = false,
            is_gcd_gated = true,
            setting_key = "use_cold_blood",
            matches = function(ctx)
                if not ctx.in_combat then return false end
                if not ctx.target then return false end
                
                -- Only use if we have combo points for a finisher
                local cp = 0
                if ctx.me and ctx.me.get_power then
                    local ok, power = pcall(function() return ctx.me:get_power(4) end)
                    if ok then cp = power end
                end
                if cp < 4 then return false end
                
                if core.spell_book and core.spell_book.get_spell_cooldown then
                    local cd = core.spell_book.get_spell_cooldown(ROGUE_SPELLS.COLD_BLOOD)
                    if cd > 0 then return false end
                end
                
                return true
            end,
            execute = function(icon, ctx)
                if icon and icon.cast then
                    icon:cast(ROGUE_SPELLS.COLD_BLOOD)
                    return true, "[MW] Cold Blood"
                end
                return false
            end,
        }
        middleware.register(cold_blood_mw)
    end
    
    -- Register Shadowstep middleware (gap closer)
    if use_shadowstep then
        local shadowstep_mw = {
            name = "Shadowstep",
            priority = middleware.PRIORITY.MOBILITY,
            is_burst = false,
            is_defensive = false,
            is_gcd_gated = true,
            setting_key = "use_shadowstep",
            matches = function(ctx)
                if not ctx.in_combat then return false end
                if not ctx.target then return false end
                
                -- Check distance to target
                local dist_sq = 0
                if ctx.me and ctx.me.get_position and ctx.target.get_position then
                    local ok1, x1, y1 = pcall(function() return ctx.me:get_position() end)
                    local ok2, x2, y2 = pcall(function() return ctx.target:get_position() end)
                    if ok1 and ok2 then
                        local dx, dy = x1 - x2, y1 - y2
                        dist_sq = dx * dx + dy * dy
                    end
                end
                
                -- Only use if target is 10-25 yards away (Shadowstep range)
                if dist_sq < 100 or dist_sq > 625 then return false end
                
                if core.spell_book and core.spell_book.get_spell_cooldown then
                    local cd = core.spell_book.get_spell_cooldown(ROGUE_SPELLS.SHADOWSTEP)
                    if cd > 0 then return false end
                end
                
                return true
            end,
            execute = function(icon, ctx)
                if icon and icon.cast then
                    icon:cast(ROGUE_SPELLS.SHADOWSTEP)
                    return true, "[MW] Shadowstep"
                end
                return false
            end,
        }
        middleware.register(shadowstep_mw)
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
    
    -- Register Preparation middleware (cooldown reset)
    if use_preparation then
        local prep_threshold = (menu.preparation_hp_pct and menu.preparation_hp_pct:get()) or 25
        local preparation_mw = {
            name = "Preparation",
            priority = middleware.PRIORITY.EMERGENCY_HEAL - 10,
            is_burst = false,
            is_defensive = true,
            is_gcd_gated = false,  -- Off-GCD
            setting_key = "use_preparation",
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
                
                if hp_pct > prep_threshold then return false end
                
                -- Check if Vanish or Evasion is on cooldown
                local vanish_cd = 0
                local evasion_cd = 0
                if core.spell_book and core.spell_book.get_spell_cooldown then
                    vanish_cd = core.spell_book.get_spell_cooldown(ROGUE_SPELLS.VANISH)
                    evasion_cd = core.spell_book.get_spell_cooldown(ROGUE_SPELLS.EVASION)
                end
                
                -- Only use if we have meaningful cooldowns to reset
                if vanish_cd == 0 and evasion_cd == 0 then return false end
                
                if core.spell_book and core.spell_book.get_spell_cooldown then
                    local cd = core.spell_book.get_spell_cooldown(ROGUE_SPELLS.PREPARATION)
                    if cd > 0 then return false end
                end
                
                return true
            end,
            execute = function(icon, ctx)
                if icon and icon.cast then
                    icon:cast(ROGUE_SPELLS.PREPARATION)
                    return true, "[MW] Preparation"
                end
                return false
            end,
        }
        middleware.register(preparation_mw)
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
