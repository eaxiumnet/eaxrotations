-- EAXPaladinHoly Middleware Manager
-- Integrates libraries/middleware with Paladin Holy-specific registrations

local middleware_manager = {}

-- Load the middleware system
local middleware = require("libraries/middleware")

-- Spell IDs for TBC Paladin Holy
local PALADIN_SPELLS = {
    -- Racials
    BERSERKING = 26297,      -- Troll offensive/defensive racial
    STONEFORM = 20594,       -- Dwarf defensive racial
    GIFT_OF_THE_NAARU = 28880, -- Draenei heal racial
    
    -- Paladin Holy spells
    DIVINE_PROTECTION = 5573,   -- Emergency defensive
    DIVINE_SHIELD = 642,        -- Full immunity
    LAY_ON_HANDS = 633,         -- Emergency heal
    DIVINE_FAVOR = 20216,       -- Guaranteed crit
    DIVINE_ILLUMINATION = 31842, -- Mana cost reduction
    AVENGING_WRATH = 31884,     -- Damage/healing boost
    HOLY_SHOCK = 20473,         -- Instant heal
    
    -- Items (default IDs, will be resolved)
    HEALTHSTONE = 5512,      -- Minor Healthstone
    HEALING_POTION = 118,    -- Minor Healing Potion
    MANA_POTION = 5996,      -- Major Mana Potion
}

-- Track if middleware has been initialized
local _initialized = false

--- Initialize and register all Paladin Holy-specific middleware
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
    
    local use_divine_protection = (menu.use_divine_protection and menu.use_divine_protection:get_state()) or false
    local divine_protection_threshold = (menu.divine_protection_hp_pct and menu.divine_protection_hp_pct:get()) or 30
    
    local use_divine_shield = (menu.use_divine_shield and menu.use_divine_shield:get_state()) or false
    local divine_shield_threshold = (menu.divine_shield_hp_pct and menu.divine_shield_hp_pct:get()) or 20
    
    local use_lay_on_hands = (menu.use_lay_on_hands and menu.use_lay_on_hands:get_state()) or false
    local lay_on_hands_threshold = (menu.lay_on_hands_hp_pct and menu.lay_on_hands_hp_pct:get()) or 15
    
    local use_divine_illumination = (menu.use_divine_illumination and menu.use_divine_illumination:get_state()) or false
    local divine_illumination_threshold = (menu.divine_illumination_pct and menu.divine_illumination_pct:get()) or 60
    
    local use_berserking = (menu.use_berserking and menu.use_berserking:get_state()) or false
    local use_stoneform = (menu.use_stoneform and menu.use_stoneform:get_state()) or false
    
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
    
    -- Register Mana Potion middleware (off-GCD, mana recovery)
    if use_mana_potion then
        middleware.register(middleware.mana_potion(
            PALADIN_SPELLS.MANA_POTION,
            mana_potion_threshold,
            middleware.PRIORITY.MANA_RECOVERY
        ))
    end
    
    -- Register Divine Protection middleware (emergency defensive)
    if use_divine_protection then
        local divine_protection_mw = {
            name = "DivineProtection",
            priority = middleware.PRIORITY.PVP_DEFENSIVE,
            is_burst = false,
            is_defensive = true,
            is_gcd_gated = true,
            setting_key = "use_divine_protection",
            matches = function(ctx)
                if ctx.hp_pct >= divine_protection_threshold then return false end
                if not ctx.in_combat then return false end
                
                -- Check Forbearance
                if ctx.me and ctx.me.has_aura then
                    local ok, has_forbearance = pcall(function() return ctx.me:has_aura(25771) end)
                    if ok and has_forbearance then return false end
                end
                
                -- Check cooldown
                if core.spell_book and core.spell_book.get_spell_cooldown then
                    local cd = core.spell_book.get_spell_cooldown(PALADIN_SPELLS.DIVINE_PROTECTION)
                    if cd > 0 then return false end
                end
                
                return true
            end,
            execute = function(icon, ctx)
                if icon and icon.cast then
                    icon:cast(PALADIN_SPELLS.DIVINE_PROTECTION)
                    return true, "[MW] Divine Protection"
                end
                return false
            end,
        }
        middleware.register(divine_protection_mw)
    end
    
    -- Register Divine Shield middleware (emergency immunity)
    if use_divine_shield then
        local divine_shield_mw = {
            name = "DivineShield",
            priority = middleware.PRIORITY.EMERGENCY_HEAL,
            is_burst = false,
            is_defensive = true,
            is_gcd_gated = true,
            setting_key = "use_divine_shield",
            matches = function(ctx)
                if ctx.hp_pct >= divine_shield_threshold then return false end
                if not ctx.in_combat then return false end
                
                -- Check Forbearance
                if ctx.me and ctx.me.has_aura then
                    local ok, has_forbearance = pcall(function() return ctx.me:has_aura(25771) end)
                    if ok and has_forbearance then return false end
                end
                
                -- Check cooldown
                if core.spell_book and core.spell_book.get_spell_cooldown then
                    local cd = core.spell_book.get_spell_cooldown(PALADIN_SPELLS.DIVINE_SHIELD)
                    if cd > 0 then return false end
                end
                
                return true
            end,
            execute = function(icon, ctx)
                if icon and icon.cast then
                    icon:cast(PALADIN_SPELLS.DIVINE_SHIELD)
                    return true, "[MW] Divine Shield"
                end
                return false
            end,
        }
        middleware.register(divine_shield_mw)
    end
    
    -- Register Lay on Hands middleware (emergency heal)
    if use_lay_on_hands then
        local lay_on_hands_mw = {
            name = "LayOnHands",
            priority = middleware.PRIORITY.EMERGENCY_HEAL - 5,
            is_burst = false,
            is_defensive = true,
            is_gcd_gated = true,
            setting_key = "use_lay_on_hands",
            matches = function(ctx)
                if ctx.hp_pct >= lay_on_hands_threshold then return false end
                if not ctx.in_combat then return false end
                
                -- Check Forbearance
                if ctx.me and ctx.me.has_aura then
                    local ok, has_forbearance = pcall(function() return ctx.me:has_aura(25771) end)
                    if ok and has_forbearance then return false end
                end
                
                -- Check cooldown
                if core.spell_book and core.spell_book.get_spell_cooldown then
                    local cd = core.spell_book.get_spell_cooldown(PALADIN_SPELLS.LAY_ON_HANDS)
                    if cd > 0 then return false end
                end
                
                return true
            end,
            execute = function(icon, ctx)
                if icon and icon.cast then
                    icon:cast(PALADIN_SPELLS.LAY_ON_HANDS)
                    return true, "[MW] Lay on Hands"
                end
                return false
            end,
        }
        middleware.register(lay_on_hands_mw)
    end
    
    -- Register Divine Illumination middleware (mana recovery)
    if use_divine_illumination then
        local divine_illumination_mw = {
            name = "DivineIllumination",
            priority = middleware.PRIORITY.MANA_RECOVERY - 5,
            is_burst = false,
            is_defensive = false,
            is_gcd_gated = true,
            setting_key = "use_divine_illumination",
            matches = function(ctx)
                if not ctx.in_combat then return false end
                if ctx.mp_pct >= divine_illumination_threshold then return false end
                
                -- Check cooldown
                if core.spell_book and core.spell_book.get_spell_cooldown then
                    local cd = core.spell_book.get_spell_cooldown(PALADIN_SPELLS.DIVINE_ILLUMINATION)
                    if cd > 0 then return false end
                end
                
                return true
            end,
            execute = function(icon, ctx)
                if icon and icon.cast then
                    icon:cast(PALADIN_SPELLS.DIVINE_ILLUMINATION)
                    return true, "[MW] Divine Illumination"
                end
                return false
            end,
        }
        middleware.register(divine_illumination_mw)
    end
    
    -- Register Berserking (Troll racial)
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
                    local cd = core.spell_book.get_spell_cooldown(PALADIN_SPELLS.BERSERKING)
                    if cd > 0 then return false end
                end
                
                return true
            end,
            execute = function(icon, ctx)
                if icon and icon.cast then
                    icon:cast(PALADIN_SPELLS.BERSERKING)
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
            PALADIN_SPELLS.STONEFORM,
            stoneform_threshold,
            middleware.PRIORITY.PVP_DEFENSIVE - 5
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
