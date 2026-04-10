--[[
    EAX Middleware System
     middleware pattern for cross-cutting rotation concerns
    
    Usage:
        local mw = require("libraries/middleware")
        
        -- Register healthstone middleware
        mw.register(mw.healthstone(5512, 30))
        
        -- In rotation update:
        local result, msg = mw.execute(icon, context)
        if result then return result, msg end
--]]

local middleware = {}

-- Priority constants (higher = executes first)
local PRIORITY = {
    FORM_RESHIFT = 500,
    EMERGENCY_HEAL = 400,
    RECOVERY_ITEMS = 300,
    MANA_RECOVERY = 280,
    SELF_BUFFS = 150,
    OFFENSIVE_CDS = 100,
    PVP_DEFENSIVE = 90,
    INTERRUPTS = 50,
}

-- Registry structure
local middleware_registry = {
    items = {},
    sorted = false,
}

-- Export priority table for external use
middleware.PRIORITY = PRIORITY

-- ============================================================================
-- Core Registry Functions
-- ============================================================================

--- Register a middleware
-- @param mw table: Middleware definition
--   name: string - Display name
--   priority: number - Execution priority (higher first)
--   is_burst: boolean - Can be forced via burst command
--   is_defensive: boolean - Can be forced via defensive command
--   is_gcd_gated: boolean|nil - true=requires GCD, false=off-GCD, nil=respect context.on_gcd
--   setting_key: string|nil - Menu setting key to check
--   matches: function(context) -> boolean - Condition check
--   execute: function(icon, context) -> result, message - Execution
function middleware.register(mw)
    if not mw or type(mw) ~= "table" then
        error("middleware.register: expected table, got " .. type(mw))
    end
    
    if not mw.name then
        error("middleware.register: middleware must have a name")
    end
    
    if not mw.priority then
        error("middleware.register: middleware must have a priority")
    end
    
    if type(mw.matches) ~= "function" then
        error("middleware.register: middleware must have matches function")
    end
    
    if type(mw.execute) ~= "function" then
        error("middleware.register: middleware must have execute function")
    end
    
    table.insert(middleware_registry.items, mw)
    middleware_registry.sorted = false
end

--- Unregister a middleware by name
-- @param name string: Name of middleware to remove
function middleware.unregister(name)
    for i = #middleware_registry.items, 1, -1 do
        if middleware_registry.items[i].name == name then
            table.remove(middleware_registry.items, i)
            middleware_registry.sorted = false
        end
    end
end

--- Clear all registered middleware
function middleware.clear()
    middleware_registry.items = {}
    middleware_registry.sorted = false
end

--- Get count of registered middleware
-- @return number
function middleware.count()
    return #middleware_registry.items
end

-- ============================================================================
-- Sorting and Execution
-- ============================================================================

-- Sort by priority (descending)
local function sort_middleware()
    if middleware_registry.sorted then return end
    
    table.sort(middleware_registry.items, function(a, b)
        return a.priority > b.priority
    end)
    
    middleware_registry.sorted = true
end

--- Build execution context from rotation state
-- @param me GameObject: Local player
-- @param target GameObject: Current target
-- @param settings table: Menu settings
-- @param force_commands table: Force command state {burst=false, defensive=false}
-- @return table: Context for middleware execution
function middleware.build_context(me, target, settings, force_commands)
    settings = settings or {}
    force_commands = force_commands or { burst = false, defensive = false }
    
    -- Get GCD state
    local on_gcd = false
    if core.spell_book and core.spell_book.get_global_cooldown then
        local gcd_remaining = core.spell_book.get_global_cooldown()
        on_gcd = gcd_remaining > 0
    end
    
    -- Get combat state
    local in_combat = false
    -- Get combat state (pcall protected)
    local in_combat = false
    if me and me.is_in_combat then
        local ok_combat, combat_result = pcall(function() return me:is_in_combat() end)
        if ok_combat then in_combat = combat_result end
    end
    
    -- Get health/mana percentages (pcall protected)
    local hp, max_hp, hp_pct = 100, 100, 100
    local mp, max_mp, mp_pct = 100, 100, 100
    
    if me then
        -- Health getters with pcall protection
        local ok_hp, hp_result = pcall(function()
            if me.get_health then return me:get_health() end
            return 100
        end)
        if ok_hp then hp = hp_result end
        
        local ok_max_hp, max_hp_result = pcall(function()
            if me.get_max_health then return me:get_max_health() end
            return 100
        end)
        if ok_max_hp then max_hp = max_hp_result end
        
        if max_hp > 0 then
            hp_pct = (hp / max_hp) * 100
        end
        
        -- Mana getters with pcall protection
        local ok_mp, mp_result = pcall(function()
            if me.get_mana then return me:get_mana() end
            return 100
        end)
        if ok_mp then mp = mp_result end
        
        local ok_max_mp, max_mp_result = pcall(function()
            if me.get_max_mana then return me:get_max_mana() end
            return 100
        end)
        if ok_max_mp then max_mp = max_mp_result end
        
        if max_mp > 0 then
            mp_pct = (mp / max_mp) * 100
        end
    end
    
    return {
        me = me,
        target = target,
        settings = settings,
        on_gcd = on_gcd,
        in_combat = in_combat,
        hp = hp,
        max_hp = max_hp,
        hp_pct = hp_pct,
        mp = mp,
        max_mp = max_mp,
        mp_pct = mp_pct,
        force_burst = force_commands.burst,
        force_defensive = force_commands.defensive,
    }
end

--- Execute all registered middleware in priority order
-- @param icon table: Icon object for casting
-- @param context table: Execution context from build_context()
-- @return result, message: First successful middleware result or nil
function middleware.execute(icon, context)
    sort_middleware()
    
    for _, mw in ipairs(middleware_registry.items) do
        -- Check GCD gating
        local can_execute = false
        if mw.is_gcd_gated == false then
            -- Off-GCD ability, can always execute
            can_execute = true
        elseif mw.is_gcd_gated == true then
            -- Requires GCD to be available
            can_execute = not context.on_gcd
        else
            -- Default: respect context.on_gcd
            can_execute = not context.on_gcd
        end
        
        if can_execute then
            -- Check setting if specified (nil-guarded)
            if mw.setting_key then
                local setting_enabled = context.settings[mw.setting_key]
                if not setting_enabled then
                    goto continue
                end
            end
            
            -- Check force commands
            local forced = false
            if mw.is_burst and context.force_burst then
                forced = true
            end
            if mw.is_defensive and context.force_defensive then
                forced = true
            end
            
            -- Check matches condition
            local matches = forced or mw.matches(context)
            if matches then
                local result, msg = mw.execute(icon, context)
                if result then
                    return result, msg or ("[MW] " .. mw.name)
                end
            end
        end
        
        ::continue::
    end
    
    return nil
end

-- ============================================================================
-- Pre-built Middleware Factories
-- ============================================================================

--- Healthstone middleware factory
-- @param spell_id number: Healthstone spell ID
-- @param threshold_pct number: Health threshold to trigger (0-100)
-- @param priority number: Optional priority override
-- @return table: Middleware definition
function middleware.healthstone(spell_id, threshold_pct, priority)
    spell_id = spell_id or 5512  -- Default healthstone
    threshold_pct = threshold_pct or 30
    priority = priority or PRIORITY.RECOVERY_ITEMS
    
    return {
        name = "Healthstone",
        priority = priority,
        is_burst = false,
        is_defensive = true,
        is_gcd_gated = false,  -- Items are off-GCD
        setting_key = "use_healthstone",
        matches = function(ctx)
            -- Check health threshold and combat
            if ctx.hp_pct >= threshold_pct then return false end
            if not ctx.in_combat then return false end
            
            -- Check if healthstone is available (cooldown)
            if core.spell_book and core.spell_book.get_spell_cooldown then
                local cd = core.spell_book.get_spell_cooldown(spell_id)
                if cd > 0 then return false end
            end
            
            return true
        end,
        execute = function(icon, ctx)
            -- Use spell_queue if available, otherwise direct cast
            if icon and icon.cast then
                icon:cast(spell_id)
                return true, "[MW] Healthstone"
            end
            return false
        end,
    }
end

--- Healing potion middleware factory
-- @param item_id number: Potion item ID
-- @param threshold_pct number: Health threshold to trigger (0-100)
-- @param priority number: Optional priority override
-- @return table: Middleware definition
function middleware.healing_potion(item_id, threshold_pct, priority)
    item_id = item_id or 118  -- Minor Healing Potion default
    threshold_pct = threshold_pct or 25
    priority = priority or PRIORITY.RECOVERY_ITEMS
    
    return {
        name = "HealingPotion",
        priority = priority,
        is_burst = false,
        is_defensive = true,
        is_gcd_gated = false,  -- Items are off-GCD
        setting_key = "use_healing_potion",
        matches = function(ctx)
            -- Check health threshold and combat
            if ctx.hp_pct >= threshold_pct then return false end
            if not ctx.in_combat then return false end
            
            
            -- Check potion cooldown (shared 1min CD)
            if core.spell_book and core.spell_book.get_spell_cooldown then
                local cd = core.spell_book.get_spell_cooldown(6615)  -- Potion cooldown spell
                if cd > 0 then return false end
            end
            
            return true
        end,
        execute = function(icon, ctx)
            if icon and icon.use_item then
                icon:use_item(item_id)
                return true, "[MW] Healing Potion"
            end
            return false
        end,
    }
end

--- Mana potion middleware factory
-- @param item_id number: Potion item ID
-- @param threshold_pct number: Mana threshold to trigger (0-100)
-- @param priority number: Optional priority override
-- @return table: Middleware definition
function middleware.mana_potion(item_id, threshold_pct, priority)
    item_id = item_id or 5996  -- Major Mana Potion default
    threshold_pct = threshold_pct or 20
    priority = priority or PRIORITY.MANA_RECOVERY
    
    return {
        name = "ManaPotion",
        priority = priority,
        is_burst = false,
        is_defensive = false,
        is_gcd_gated = false,
        setting_key = "use_mana_potion",
        matches = function(ctx)
            -- Check mana threshold and combat
            if ctx.mp_pct >= threshold_pct then return false end
            if not ctx.in_combat then return false end
            
            
            -- Check potion cooldown
            if core.spell_book and core.spell_book.get_spell_cooldown then
                local cd = core.spell_book.get_spell_cooldown(6615)
                if cd > 0 then return false end
            end
            
            return true
        end,
        execute = function(icon, ctx)
            if icon and icon.use_item then
                icon:use_item(item_id)
                return true, "[MW] Mana Potion"
            end
            return false
        end,
    }
end

--- Defensive racial middleware factory
-- @param spell_id number: Racial spell ID (e.g., 20594 for Stoneform)
-- @param threshold_pct number: Health threshold to trigger (0-100)
-- @param priority number: Optional priority override
-- @return table: Middleware definition
function middleware.defensive_racial(spell_id, threshold_pct, priority)
    threshold_pct = threshold_pct or 40
    priority = priority or PRIORITY.PVP_DEFENSIVE
    
    return {
        name = "DefensiveRacial",
        priority = priority,
        is_burst = false,
        is_defensive = true,
        is_gcd_gated = true,
        setting_key = "use_defensive_racial",
        matches = function(ctx)
            if not spell_id then return false end
            if ctx.hp_pct >= threshold_pct then return false end
            if not ctx.in_combat then return false end
            
            -- Check cooldown
            if core.spell_book and core.spell_book.get_spell_cooldown then
                local cd = core.spell_book.get_spell_cooldown(spell_id)
                if cd > 0 then return false end
            end
            
            return true
        end,
        execute = function(icon, ctx)
            if icon and icon.cast then
                icon:cast(spell_id)
                return true, "[MW] Defensive Racial"
            end
            return false
        end,
    }
end

--- Offensive racial middleware factory
-- @param spell_id number: Racial spell ID (e.g., 20572 for Blood Fury)
-- @param priority number: Optional priority override
-- @return table: Middleware definition
function middleware.offensive_racial(spell_id, priority)
    priority = priority or PRIORITY.OFFENSIVE_CDS
    
    return {
        name = "OffensiveRacial",
        priority = priority,
        is_burst = true,
        is_defensive = false,
        is_gcd_gated = true,
        setting_key = "use_offensive_racial",
        matches = function(ctx)
            if not spell_id then return false end
            if not ctx.in_combat then return false end
            if not ctx.target then return false end
            
            -- Check cooldown
            if core.spell_book and core.spell_book.get_spell_cooldown then
                local cd = core.spell_book.get_spell_cooldown(spell_id)
                if cd > 0 then return false end
            end
            
            return true
        end,
        execute = function(icon, ctx)
            if icon and icon.cast then
                icon:cast(spell_id)
                return true, "[MW] Offensive Racial"
            end
            return false
        end,
    }
end

--- Emergency heal middleware factory (for classes with self-heals)
-- @param spell_id number: Heal spell ID
-- @param threshold_pct number: Health threshold to trigger (0-100)
-- @param priority number: Optional priority override
-- @param requires_combo_points boolean: Whether heal requires combo points
-- @return table: Middleware definition
function middleware.emergency_heal(spell_id, threshold_pct, priority, requires_combo_points)
    threshold_pct = threshold_pct or 35
    priority = priority or PRIORITY.EMERGENCY_HEAL
    requires_combo_points = requires_combo_points or false
    
    return {
        name = "EmergencyHeal",
        priority = priority,
        is_burst = false,
        is_defensive = true,
        is_gcd_gated = true,
        setting_key = "use_emergency_heal",
        matches = function(ctx)
            if not spell_id then return false end
            if ctx.hp_pct >= threshold_pct then return false end
            if not ctx.in_combat then return false end
            
            -- Check combo points if required
            if requires_combo_points then
                local cp = 0
                if ctx.me and ctx.me.get_combo_points then
                    local ok_cp, cp_result = pcall(function() return ctx.me:get_combo_points() end)
                    if ok_cp then cp = cp_result end
                end
                if cp < 1 then return false end
            end
            
            -- Check cooldown
            if core.spell_book and core.spell_book.get_spell_cooldown then
                local cd = core.spell_book.get_spell_cooldown(spell_id)
                if cd > 0 then return false end
            end
            
            return true
        end,
        execute = function(icon, ctx)
            if icon and icon.cast then
                icon:cast(spell_id)
                return true, "[MW] Emergency Heal"
            end
            return false
        end,
    }
end

--- Self-buff middleware factory
-- @param spell_id number: Buff spell ID
-- @param buff_id number: Buff aura ID to check
-- @param priority number: Optional priority override
-- @param ooc_only boolean: Only cast out of combat
-- @return table: Middleware definition
function middleware.self_buff(spell_id, buff_id, priority, ooc_only)
    priority = priority or PRIORITY.SELF_BUFFS
    ooc_only = ooc_only or false
    
    return {
        name = "SelfBuff",
        priority = priority,
        is_burst = false,
        is_defensive = false,
        is_gcd_gated = true,
        setting_key = "maintain_self_buff",
        matches = function(ctx)
            if not spell_id then return false end
            if ooc_only and ctx.in_combat then return false end
            
            -- Check if buff is already active
            if buff_id and ctx.me then
                local has_buff = false
                if ctx.me.has_aura then
                    has_buff = ctx.me:has_aura(buff_id)
                    end
                if has_buff then return false end
            end
            
            -- Check cooldown
            if core.spell_book and core.spell_book.get_spell_cooldown then
                local cd = core.spell_book.get_spell_cooldown(spell_id)
                if cd > 0 then return false end
            end
            
            return true
        end,
        execute = function(icon, ctx)
            if icon and icon.cast then
                icon:cast(spell_id)
                return true, "[MW] Self Buff"
            end
            return false
        end,
    }
end

-- ============================================================================
-- Integration Helpers
-- ============================================================================

--- Create standard middleware set for a class
-- @param class_name string: Class name (e.g., "Warrior", "Mage")
-- @param menu_config table: Menu configuration with setting keys
-- @return table: Array of middleware instances
function middleware.create_class_set(class_name, menu_config)
    menu_config = menu_config or {}
    local set = {}
    
    class_name = string.lower(class_name or "")
    
    -- Common recovery items for all classes
    if menu_config.use_healthstone ~= false then
        table.insert(set, middleware.healthstone(
            menu_config.healthstone_id or 5512,
            menu_config.healthstone_threshold or 30
        ))
    end
    
    if menu_config.use_healing_potion ~= false then
        table.insert(set, middleware.healing_potion(
            menu_config.healing_potion_id or 118,
            menu_config.healing_potion_threshold or 25
        ))
    end
    
    -- Class-specific middleware
    if class_name == "druid" then
        -- Druid: Rejuvenation emergency heal
        if menu_config.use_emergency_heal ~= false then
            table.insert(set, middleware.emergency_heal(
                menu_config.emergency_heal_id or 774,  -- Rejuvenation
                menu_config.emergency_heal_threshold or 35,
                PRIORITY.EMERGENCY_HEAL,
                false
            ))
        end
        
    elseif class_name == "paladin" then
        -- Paladin: Holy Light emergency heal
        if menu_config.use_emergency_heal ~= false then
            table.insert(set, middleware.emergency_heal(
                menu_config.emergency_heal_id or 635,  -- Holy Light
                menu_config.emergency_heal_threshold or 30,
                PRIORITY.EMERGENCY_HEAL,
                false
            ))
        end
        
    elseif class_name == "shaman" then
        -- Shaman: Healing Wave emergency heal
        if menu_config.use_emergency_heal ~= false then
            table.insert(set, middleware.emergency_heal(
                menu_config.emergency_heal_id or 331,  -- Healing Wave
                menu_config.emergency_heal_threshold or 30,
                PRIORITY.EMERGENCY_HEAL,
                false
            ))
        end
        
    elseif class_name == "hunter" then
        -- Hunter: Mana potion for mana users
        if menu_config.use_mana_potion ~= false then
            table.insert(set, middleware.mana_potion(
                menu_config.mana_potion_id or 5996,
                menu_config.mana_potion_threshold or 20
            ))
        end
        
    elseif class_name == "mage" or class_name == "warlock" or class_name == "priest" then
        -- Mana users: Mana potion
        if menu_config.use_mana_potion ~= false then
            table.insert(set, middleware.mana_potion(
                menu_config.mana_potion_id or 5996,
                menu_config.mana_potion_threshold or 20
            ))
        end
    end
    
    -- Register all middleware in the set
    for _, mw in ipairs(set) do
        middleware.register(mw)
    end
    
    return set
end

--- Quick setup function - register common middleware
-- @param config table: Configuration for common middleware
function middleware.setup_common(config)
    config = config or {}
    
    if config.healthstone ~= false then
        middleware.register(middleware.healthstone(
            config.healthstone_id,
            config.healthstone_threshold
        ))
    end
    
    if config.healing_potion ~= false then
        middleware.register(middleware.healing_potion(
            config.healing_potion_id,
            config.healing_potion_threshold
        ))
    end
    
    if config.defensive_racial and config.defensive_racial.spell_id then
        middleware.register(middleware.defensive_racial(
            config.defensive_racial.spell_id,
            config.defensive_racial.threshold,
            config.defensive_racial.priority
        ))
    end
    
    if config.offensive_racial and config.offensive_racial.spell_id then
        middleware.register(middleware.offensive_racial(
            config.offensive_racial.spell_id,
            config.offensive_racial.priority
        ))
    end
end

-- ============================================================================
-- Debug Helpers
-- ============================================================================

--- Get debug info about registered middleware
-- @return table: Debug information
function middleware.debug_info()
    local info = {
        count = #middleware_registry.items,
        sorted = middleware_registry.sorted,
        items = {},
    }
    
    for _, mw in ipairs(middleware_registry.items) do
        table.insert(info.items, {
            name = mw.name,
            priority = mw.priority,
            is_burst = mw.is_burst,
            is_defensive = mw.is_defensive,
            setting_key = mw.setting_key,
        })
    end
    
    return info
end

--- Print debug info to console
function middleware.print_debug()
    local info = middleware.debug_info()
    print(string.format("[Middleware] Registered: %d (sorted: %s)", 
        info.count, tostring(info.sorted)))
    
    for _, item in ipairs(info.items) do
        print(string.format("  - %s (prio: %d, burst: %s, def: %s)",
            item.name, item.priority,
            tostring(item.is_burst), tostring(item.is_defensive)))
    end
end

return middleware
