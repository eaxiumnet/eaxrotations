-- emergency_handlers.lua
-- Flux Adaptation: Granular emergency healing strategies
-- Split from monolithic emergency handler into focused, testable functions

local emergency_handlers = {}

-- ============================================================================
-- CONSTANTS
-- ============================================================================
local EMERGENCY_HP_SWIFTMEND = 0.55     -- Swiftmend at <55%
local EMERGENCY_HP_NS = 0.40            -- NS combos at <40%
local EMERGENCY_HP_BARKSKIN_SELF = 0.35 -- Barkskin self at <35%
local LIFEBLOOM_SPELL_ID = 33763

-- ============================================================================
-- UTILITY FUNCTIONS
-- ============================================================================

local function is_hp_critical(unit, threshold)
    if not unit or not unit.is_valid or not unit:is_valid() then
        return false
    end
    local ok, hp_pct = pcall(function() return unit:get_health_percentage() end)
    return ok and hp_pct and (hp_pct / 100) <= threshold
end

local function has_rejuv_or_regrowth(unit, spells, utils)
    if not unit or not unit.is_valid or not unit:is_valid() then
        return false
    end
    
    local has_rejuv = utils.has_buff(unit, spells.BUFF_REJUVENATION)
    local has_regrowth = utils.has_buff(unit, spells.BUFF_REGROWTH)
    
    return has_rejuv or has_regrowth
end

-- ============================================================================
-- [1] EMERGENCY SWIFTMEND
-- Instant burst heal, consumes Rejuv or Regrowth
-- Priority: HIGH (instant, saves lives)
-- ============================================================================

--- Check if Emergency Swiftmend should fire
---@param me game_object Player
---@param target game_object Target to heal
---@param target_hp_pct number Current HP%
---@param menu table Menu settings
---@param runtime table Runtime state
---@param spells table Spell database
---@param utils table Utils library
---@return boolean should_execute
function emergency_handlers.should_swiftmend(me, target, target_hp_pct, menu, runtime, spells, utils)
    -- Menu toggle check
    if not menu.use_swiftmend then return false end
    local method = menu.use_swiftmend.get
    if type(method) ~= "function" or not method(menu.use_swiftmend) then
        return false
    end
    
    -- Spell availability
    if not runtime.swiftmend_id then return false end
    
    -- HP threshold (use menu setting or default)
    local threshold = EMERGENCY_HP_SWIFTMEND
    if menu.swiftmend_hp_pct then
        local method2 = menu.swiftmend_hp_pct.get
        if type(method2) == "function" then
            threshold = (method2(menu.swiftmend_hp_pct) or 50) / 100
        end
    end
    threshold = math.min(0.55, threshold)
    
    if target_hp_pct > threshold then return false end
    
    -- Must have HoT to consume
    if not has_rejuv_or_regrowth(target, spells, utils) then
        return false
    end
    
    return true
end

--- Execute Emergency Swiftmend
---@param me game_object Player
---@param target game_object Target
---@param runtime table Runtime state
---@param utils table Utils
---@param color table Color helper
---@return boolean success
function emergency_handlers.execute_swiftmend(me, target, runtime, utils, color)
    if not utils.can_cast_unit(runtime.swiftmend_id, me, target) then
        return false
    end
    
    if utils.cast_unit(runtime.swiftmend_id, me, target) then
        local target_name = ""
        local ok, name = pcall(function() return target:get_name() end)
        if ok and name then target_name = name end
        
        utils.log_debug(nil, "EMERGENCY Swiftmend on " .. target_name)
        
        if color and color.gold then
            esp_renderer.on_cast(runtime.swiftmend_id, "Swiftmend", color.gold(240))
        end
        return true
    end
    
    return false
end

-- ============================================================================
-- [2] EMERGENCY NATURE'S SWIFTNESS + HEALING TOUCH
-- Leaves Tree form for biggest instant heal
-- Sets reshift flag to return to Tree next frame
-- Priority: VERY HIGH (biggest heal possible)
-- ============================================================================

--- Check if NS+HT emergency should fire
---@param me game_object Player
---@param target game_object Target
---@param target_hp_pct number Current HP%
---@param menu table Menu settings
---@param runtime table Runtime state
---@return boolean should_execute
function emergency_handlers.should_ns_healing_touch(me, target, target_hp_pct, menu, runtime)
    -- Menu toggle check
    if not menu.use_natures_swiftness then return false end
    local method = menu.use_natures_swiftness.get
    if type(method) ~= "function" or not method(menu.use_natures_swiftness) then
        return false
    end
    
    -- Specific NS+HT toggle
    if menu.resto_ns_healing_touch then
        local method2 = menu.resto_ns_healing_touch.get
        if type(method2) == "function" and not method2(menu.resto_ns_healing_touch) then
            return false  -- NS+HT explicitly disabled
        end
    end
    
    -- Spell availability
    if not runtime.natures_swiftness_id or not runtime.healing_touch_id then
        return false
    end
    
    -- HP threshold
    local threshold = EMERGENCY_HP_NS
    if menu.emergency_hp_pct then
        local method3 = menu.emergency_hp_pct.get
        if type(method3) == "function" then
            threshold = math.min(0.40, (method3(menu.emergency_hp_pct) or 40) / 100)
        end
    end
    
    if target_hp_pct > threshold then return false end
    
    return true
end

--- Execute NS+Healing Touch emergency combo
---@param me game_object Player
---@param target game_object Target
---@param runtime table Runtime state
---@param utils table Utils
---@param tree_reshift_manager table Reshift manager
---@param color table Color helper
---@return boolean success
function emergency_handlers.execute_ns_healing_touch(me, target, runtime, utils, tree_reshift_manager, color)
    -- Check if NS buff already active
    local has_ns_buff = utils.has_buff(me, spells.BUFF_NATURES_SWIFTNESS)
    
    if has_ns_buff then
        -- Cast instant Healing Touch
        if not utils.can_cast_unit(runtime.healing_touch_id, me, target) then
            return false
        end
        
        if utils.cast_unit(runtime.healing_touch_id, me, target) then
            local target_name = ""
            local ok, name = pcall(function() return target:get_name() end)
            if ok and name then target_name = name end
            
            utils.log_debug(nil, "EMERGENCY NS -> Healing Touch on " .. target_name)
            
            -- Request Tree reshift (we just left Tree to cast HT)
            if tree_reshift_manager and tree_reshift_manager.request_reshift then
                tree_reshift_manager.request_reshift("ns_ht")
            end
            
            if color and color.gold then
                esp_renderer.on_cast(runtime.healing_touch_id, "NS Healing Touch", color.gold(240))
            end
            return true
        end
    else
        -- Cast Nature's Swiftness first (off-GCD)
        if not utils.can_cast_self(runtime.natures_swiftness_id, me) then
            return false
        end
        
        if utils.cast_self_fast(runtime.natures_swiftness_id, me) then
            utils.log_debug(nil, "Nature's Swiftness (NS+HT combo)")
            -- Next frame will cast HT with NS buff active
            return true
        end
    end
    
    return false
end

-- ============================================================================
-- [3] EMERGENCY NATURE'S SWIFTNESS + REGROWTH
-- Fallback when HT disabled or in Tree-only mode
-- Stays in Tree form (Regrowth castable in Tree)
-- Priority: HIGH (instant heal, stays in Tree)
-- ============================================================================

--- Check if NS+Regrowth emergency should fire
---@param me game_object Player
---@param target game_object Target
---@param target_hp_pct number Current HP%
---@param menu table Menu settings
---@param runtime table Runtime state
---@return boolean should_execute
function emergency_handlers.should_ns_regrowth(me, target, target_hp_pct, menu, runtime)
    -- NS must be enabled
    if not menu.use_natures_swiftness then return false end
    local method = menu.use_natures_swiftness.get
    if type(method) ~= "function" or not method(menu.use_natures_swiftness) then
        return false
    end
    
    -- NS+HT is preferred; only use NS+Regrowth if HT is disabled
    local ns_ht_enabled = true
    if menu.resto_ns_healing_touch then
        local method2 = menu.resto_ns_healing_touch.get
        if type(method2) == "function" then
            ns_ht_enabled = method2(menu.resto_ns_healing_touch)
        end
    end
    
    if ns_ht_enabled then
        return false  -- NS+HT takes priority
    end
    
    -- Check if NS+Regrowth explicitly enabled
    if menu.resto_ns_regrowth then
        local method3 = menu.resto_ns_regrowth.get
        if type(method3) == "function" and not method3(menu.resto_ns_regrowth) then
            return false
        end
    end
    
    -- Spell availability
    if not runtime.natures_swiftness_id or not runtime.regrowth_id then
        return false
    end
    
    -- HP threshold
    local threshold = EMERGENCY_HP_NS
    if target_hp_pct > threshold then return false end
    
    return true
end

--- Execute NS+Regrowth emergency combo
---@param me game_object Player
---@param target game_object Target
---@param runtime table Runtime state
---@param utils table Utils
---@param color table Color helper
---@return boolean success
function emergency_handlers.execute_ns_regrowth(me, target, runtime, utils, color)
    local has_ns_buff = utils.has_buff(me, spells.BUFF_NATURES_SWIFTNESS)
    
    if has_ns_buff then
        -- Cast instant Regrowth (castable in Tree)
        if not utils.can_cast_unit(runtime.regrowth_id, me, target) then
            return false
        end
        
        if utils.cast_unit(runtime.regrowth_id, me, target) then
            local target_name = ""
            local ok, name = pcall(function() return target:get_name() end)
            if ok and name then target_name = name end
            
            utils.log_debug(nil, "EMERGENCY NS -> Regrowth on " .. target_name)
            
            if color and color.gold then
                esp_renderer.on_cast(runtime.regrowth_id, "NS Regrowth", color.green(220))
            end
            return true
        end
    else
        -- Cast Nature's Swiftness
        if not utils.can_cast_self(runtime.natures_swiftness_id, me) then
            return false
        end
        
        if utils.cast_self_fast(runtime.natures_swiftness_id, me) then
            utils.log_debug(nil, "Nature's Swiftness (NS+Regrowth combo)")
            return true
        end
    end
    
    return false
end

-- ============================================================================
-- [4] EMERGENCY BARKSKIN
-- Self-defensive cooldown, off-GCD
-- Priority: MEDIUM (self-preservation)
-- ============================================================================

--- Check if Emergency Barkskin should fire
---@param me game_object Player
---@param menu table Menu settings
---@param runtime table Runtime state
---@return boolean should_execute
function emergency_handlers.should_barkskin(me, menu, runtime)
    -- Menu toggle check
    if not menu.use_barkskin then return false end
    local method = menu.use_barkskin.get
    if type(method) ~= "function" or not method(menu.use_barkskin) then
        return false
    end
    
    -- Spell availability
    if not runtime.barkskin_id then return false end
    
    -- HP threshold
    local threshold = EMERGENCY_HP_BARKSKIN_SELF
    if menu.barkskin_hp_pct then
        local method2 = menu.barkskin_hp_pct.get
        if type(method2) == "function" then
            threshold = (method2(menu.barkskin_hp_pct) or 40) / 100
        end
    end
    
    if not is_hp_critical(me, threshold) then return false end
    
    -- Check if already has Barkskin
    if utils.has_buff(me, spells.BUFF_BARKSKIN) then
        return false
    end
    
    return true
end

--- Execute Emergency Barkskin
---@param me game_object Player
---@param runtime table Runtime state
---@param utils table Utils
---@return boolean success
function emergency_handlers.execute_barkskin(me, runtime, utils)
    if not utils.can_cast_self(runtime.barkskin_id, me) then
        return false
    end
    
    if utils.cast_self_fast(runtime.barkskin_id, me) then
        local hp_pct = 0
        local ok, val = pcall(function() return me:get_health_percentage() end)
        if ok and val then hp_pct = val end
        
        utils.log_debug(nil, string.format("EMERGENCY Barkskin at %.0f%% HP", hp_pct))
        return true
    end
    
    return false
end

-- ============================================================================
-- MASTER EXECUTION (Priority Order)
-- 1. Barkskin (self, off-GCD)
-- 2. Swiftmend (instant with HoT)
-- 3. NS+HT (biggest heal, leaves Tree)
-- 4. NS+Regrowth (fallback, stays in Tree)
-- ============================================================================

--- Execute all emergency handlers in priority order
---@param me game_object Player
---@param target game_object Emergency target
---@param target_hp_pct number Target HP%
---@param menu table Menu settings
---@param runtime table Runtime state
---@param spells table Spell database
---@param utils table Utils library
---@param tree_reshift_manager table Reshift manager
---@param color table Color helper
---@return boolean handled Whether any emergency was handled
function emergency_handlers.execute_all(me, target, target_hp_pct, menu, runtime, spells, utils, tree_reshift_manager, color)
    -- [1] Emergency Barkskin (off-GCD, self only)
    if emergency_handlers.should_barkskin(me, menu, runtime) then
        if emergency_handlers.execute_barkskin(me, runtime, utils) then
            return true  -- Handled
        end
    end
    
    -- Need target for other emergencies
    if not target or not target:is_valid() or target:is_dead() then
        return false
    end
    
    -- [2] Emergency Swiftmend
    if emergency_handlers.should_swiftmend(me, target, target_hp_pct, menu, runtime, spells, utils) then
        if emergency_handlers.execute_swiftmend(me, target, runtime, utils, color) then
            return true  -- Handled
        end
    end
    
    -- [3] Emergency NS+HT
    if emergency_handlers.should_ns_healing_touch(me, target, target_hp_pct, menu, runtime) then
        if emergency_handlers.execute_ns_healing_touch(me, target, runtime, utils, tree_reshift_manager, color) then
            return true  -- Handled
        end
    end
    
    -- [4] Emergency NS+Regrowth (fallback)
    if emergency_handlers.should_ns_regrowth(me, target, target_hp_pct, menu, runtime) then
        if emergency_handlers.execute_ns_regrowth(me, target, runtime, utils, color) then
            return true  -- Handled
        end
    end
    
    return false  -- No emergency handled
end

return emergency_handlers
