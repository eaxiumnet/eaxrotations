-- EAXDruidResto Middleware Manager
-- Integrates libraries/middleware with Druid Restoration-specific registrations
-- Healer-specific thresholds: higher HP thresholds for defensive abilities

local middleware_manager = {}

-- Load the middleware system (from libraries folder)
local middleware = require("libraries/middleware")
local spells = require("libraries/spells")
local utils = require("libraries/utils")

-- Spell IDs for TBC Druid Restoration
local DRUID_SPELLS = {
    -- Racials
    WAR_STOMP = 20549,       -- Tauren defensive racial (stun)
    BLOOD_FURY = 20572,      -- Orc offensive racial
    BERSERKING = 26297,      -- Troll offensive/defensive racial
    STONEFORM = 20594,       -- Dwarf defensive racial
    ESCAPE_ARTIST = 20589,   -- Gnome defensive racial
    
    -- Druid abilities
    INNERVATE = 29166,       -- Mana restoration
    BARKSKIN = 22812,        -- Defensive cooldown
    THORNS = 26992,          -- Highest rank Thorns
    
    -- Items (default IDs, will be resolved)
    HEALTHSTONE = 5512,      -- Minor Healthstone
    HEALING_POTION = 118,    -- Minor Healing Potion
    MANA_POTION = 5996,      -- Major Mana Potion
}

-- Buff IDs
local BUFF_INNERVATE = 29166

-- Track if middleware has been initialized
local _initialized = false

--- Check if player has a specific buff
local function has_buff_self(buff_id)
    local me = core.object_manager.get_local_player()
    if not me or not me:is_valid() then return false end
    return false
end

--- Get lowest mana party member (for Innervate targeting)
local function get_lowest_mana_party_member()
    local me = core.object_manager.get_local_player()
    if not me then return nil, 100 end
    
    local lowest = nil
    local lowest_mana = 100
    
    for _, o in ipairs(core.object_manager.get_all_objects()) do
        if o and o:is_valid() and o:is_unit() and not o:is_dead() then
            if o:is_party_member() or utils.same_unit(o, me) then
                -- Check if unit uses mana
                local mana = 0
                local max_mana = 1
                if o.get_power and o.get_max_power then
                    local ok_mana, m = pcall(function() return o:get_power(0) end)
                    local ok_max, max_m = pcall(function() return o:get_max_power(0) end)
                    if ok_mana and ok_max and max_m > 0 then
                        mana = m
                        max_mana = max_m
                    end
                end
                local mana_pct = (mana / max_mana) * 100
                if mana_pct < lowest_mana then
                    lowest_mana = mana_pct
                    lowest = o
                end
            end
        end
    end
    
    return lowest, lowest_mana
end

--- Initialize and register all Druid Restoration-specific middleware
-- @param menu table: Menu module for accessing settings
function middleware_manager.initialize(menu)
    if _initialized then return end
    if not menu then return end
    
    -- Clear any existing registrations to avoid duplicates
    middleware.clear()
    
    -- Get settings with nil guards (healer-specific thresholds)
    local use_healthstone = (menu.use_healthstone and menu.use_healthstone:get_state()) or true
    local healthstone_threshold = (menu.healthstone_hp_pct and menu.healthstone_hp_pct:get()) or 35  -- Higher for healer
    
    local use_healing_potion = (menu.use_healing_potion and menu.use_healing_potion:get_state()) or true
    local health_potion_threshold = (menu.health_potion_hp_pct and menu.health_potion_hp_pct:get()) or 45  -- Higher for healer
    
    local use_mana_potion = (menu.use_mana_potion and menu.use_mana_potion:get_state()) or true
    local mana_potion_threshold = (menu.mana_potion_pct and menu.mana_potion_pct:get()) or 10  -- Low, conserve for heals
    
    local use_innervate = (menu.use_innervate and menu.use_innervate:get_state()) or true
    local innervate_threshold = (menu.innervate_mana_pct and menu.innervate_mana_pct:get()) or 15
    local innervate_target_mode = (menu.innervate_target and menu.innervate_target:get()) or 1
    
    local use_barkskin = (menu.use_barkskin and menu.use_barkskin:get_state()) or true
    local barkskin_threshold = (menu.barkskin_hp_pct and menu.barkskin_hp_pct:get()) or 40
    
    local use_war_stomp = (menu.use_war_stomp and menu.use_war_stomp:get_state()) or true
    local use_thorns = (menu.use_thorns and menu.use_thorns:get_state()) or true
    local use_motw = (menu.use_motw and menu.use_motw:get_state()) or true
    
    -- Register Healthstone middleware (off-GCD, defensive) - healer priority
    if use_healthstone then
        middleware.register(middleware.healthstone(
            DRUID_SPELLS.HEALTHSTONE,
            healthstone_threshold,
            middleware.PRIORITY.RECOVERY_ITEMS
        ))
    end
    
    -- Register Healing Potion middleware (off-GCD, defensive) - healer priority
    if use_healing_potion then
        middleware.register(middleware.healing_potion(
            DRUID_SPELLS.HEALING_POTION,
            health_potion_threshold,
            middleware.PRIORITY.RECOVERY_ITEMS - 5
        ))
    end
    
    -- Register Mana Potion middleware (off-GCD, mana recovery) - conserve for heals
    if use_mana_potion then
        middleware.register(middleware.mana_potion(
            DRUID_SPELLS.MANA_POTION,
            mana_potion_threshold,
            middleware.PRIORITY.MANA_RECOVERY
        ))
    end
    
    -- Register Innervate middleware (custom for healer logic)
    if use_innervate then
        local innervate_mw = {
            name = "Innervate",
            priority = middleware.PRIORITY.MANA_RECOVERY + 10,
            is_burst = false,
            is_defensive = true,  -- Mana = survival for healer
            is_gcd_gated = true,
            setting_key = "use_innervate",
            matches = function(ctx)
                if not DRUID_SPELLS.INNERVATE then return false end
                if not ctx.in_combat then 
                    -- OOC: use on self if mana low
                    if ctx.mp_pct < innervate_threshold then
                        return true
                    end
                    return false
                end
                
                -- In combat: check self mana first
                if ctx.mp_pct < innervate_threshold then
                    return true
                end
                
                -- Check if should cast on party member
                if innervate_target_mode ~= 1 then  -- Not "Self only"
                    local lowest, lowest_mana = get_lowest_mana_party_member()
                    if lowest and lowest_mana < 10 then  -- Emergency threshold for others
                        return true
                    end
                end
                
                return false
            end,
            execute = function(icon, ctx)
                local target = ctx.me
                
                -- Determine target based on mode
                if innervate_target_mode == 2 then  -- "Lowest mana healer"
                    local lowest, lowest_mana = get_lowest_mana_party_member()
                    if lowest and lowest_mana < ctx.mp_pct then
                        target = lowest
                    end
                elseif innervate_target_mode == 3 then  -- "Focus target"
                    if core.object_manager and core.object_manager.get_focus_target then
                        local focus = core.object_manager.get_focus_target()
                        if focus and focus:is_valid() and not focus:is_dead() then
                            target = focus
                        end
                    end
                end
                
                -- Check cooldown
                if core.spell_book and core.spell_book.get_spell_cooldown then
                    local cd = core.spell_book.get_spell_cooldown(DRUID_SPELLS.INNERVATE)
                    if cd > 0 then return false end
                end
                
                -- Check if already has Innervate buff
                if target and utils.same_unit(target, ctx.me) then
                    if has_buff_self(BUFF_INNERVATE) then return false end
                end
                
                if core.spell_queue and core.spell_queue.add then
                    core.spell_queue.add(DRUID_SPELLS.INNERVATE, "innervate", 85)
                    return true, "[MW] Innervate queued"
                elseif icon and icon.cast then
                    if target and not utils.same_unit(target, ctx.me) then
                        icon:cast(DRUID_SPELLS.INNERVATE, target)
                    else
                        icon:cast(DRUID_SPELLS.INNERVATE)
                    end
                    return true, "[MW] Innervate"
                end
                return false
            end,
        }
        middleware.register(innervate_mw)
    end
    
    -- Register Barkskin middleware (defensive cooldown)
    if use_barkskin then
        local barkskin_mw = {
            name = "Barkskin",
            priority = middleware.PRIORITY.PVP_DEFENSIVE + 10,
            is_burst = false,
            is_defensive = true,
            is_gcd_gated = true,
            setting_key = "use_barkskin",
            matches = function(ctx)
                if not DRUID_SPELLS.BARKSKIN then return false end
                if ctx.hp_pct >= barkskin_threshold then 
                    -- Also trigger if being attacked even at higher HP
                    if not ctx.in_combat then return false end
                    -- Check if target of enemy
                    local being_attacked = false
                    if ctx.me and ctx.me.is_target_of then
                        being_attacked = ctx.me:is_target_of()
                    end
                    if not being_attacked then return false end
                end
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
                    core.spell_queue.add(DRUID_SPELLS.BARKSKIN, "barkskin", 80)
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
    
    -- Register War Stomp (Tauren defensive racial - stun attackers)
    if use_war_stomp then
        local war_stomp_mw = {
            name = "WarStomp",
            priority = middleware.PRIORITY.PVP_DEFENSIVE,
            is_burst = false,
            is_defensive = true,
            is_gcd_gated = true,
            setting_key = "use_war_stomp",
            matches = function(ctx)
                if not DRUID_SPELLS.WAR_STOMP then return false end
                if not ctx.in_combat then return false end
                
                -- Use when being attacked and HP is concerning
                local being_attacked = false
                if ctx.me and ctx.me.is_target_of then
                    being_attacked = ctx.me:is_target_of()
                end
                if not being_attacked and ctx.hp_pct > 50 then return false end
                
                -- Check cooldown
                if core.spell_book and core.spell_book.get_spell_cooldown then
                    local cd = core.spell_book.get_spell_cooldown(DRUID_SPELLS.WAR_STOMP)
                    if cd > 0 then return false end
                end
                
                return true
            end,
            execute = function(icon, ctx)
                if core.spell_queue and core.spell_queue.add then
                    core.spell_queue.add(DRUID_SPELLS.WAR_STOMP, "war_stomp", 75)
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
