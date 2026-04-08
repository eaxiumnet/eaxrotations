-- mana_manager.lua
-- Unified mana recovery library for all caster specs
-- Wave 1: Flux feature porting

local mana_manager = {}

-- ============================================================================
-- API Caching (at module load)
-- ============================================================================
local _get_local_player = core.object_manager.get_local_player
-- STUB: core.inventory.* APIs don't exist in Sylvanas
local _get_item_cooldown = function(item_id) return 0, 0 end
local _use_item = function(item_id, target) return false end
local _get_spell_cooldown = core.spell_book.get_spell_cooldown
local _cast_spell = core.input.cast_target_spell
local _is_spell_learned = core.spell_book.is_spell_learned

-- Get health/mana from game_object methods (not core.unit.*)
local function _get_health_percentage(unit)
    if unit and unit.get_health_percentage then
        return unit:get_health_percentage()
    end
    return 100
end

local function _get_mana_percentage(unit)
    if unit and unit.get_mana_percentage then
        return unit:get_mana_percentage()
    end
    return 100
end

-- ============================================================================
-- Item ID Tables
-- ============================================================================

-- Mana gem IDs (highest to lowest rank)
local MANA_GEMS = { 22044, 8008, 8007, 5514, 5513 }

-- Mana potion IDs (highest to lowest rank)
local MANA_POTIONS = { 28499, 22832, 22829 }

-- Dark/Demonic Rune IDs
local DARK_RUNES = { 20520, 12662 }

-- ============================================================================
-- Class Recovery Configurations
-- ============================================================================

mana_manager.CLASS_RECOVERY = {
    MAGE = {
        gems = true,
        potions = true,
        runes = true,
        evocation = 12051
    },
    PRIEST = {
        potions = true,
        runes = true,
        shadowfiend = 34433
    },
    DRUID = {
        potions = true,
        runes = true,
        innervate = 29166
    },
    WARLOCK = {
        potions = true,
        runes = true,
        life_tap = { 1454, 1455, 1456, 11687, 11688, 11689, 27222, 27223, 27224 }
    },
    SHAMAN = {
        potions = true,
        runes = true,
        mana_tide_totem = 16190
    }
}

-- ============================================================================
-- Utility Functions
-- ============================================================================

---Get current mana percentage for a unit
---@param me userdata Player unit object
---@return number Mana percentage (0-100)
function mana_manager.get_mana_pct(me)
    if not me then
        return 100
    end
    
    local success, result = pcall(_get_mana_percentage, me)
    if success then
        return result or 100
    end
    return 100
end

---Get current health percentage for a unit
---@param me userdata Player unit object
---@return number Health percentage (0-100)
local function get_health_pct(me)
    if not me then
        return 100
    end
    
    local success, result = pcall(_get_health_percentage, me)
    if success then
        return result or 100
    end
    return 100
end

---Check if player is in combat
---@return boolean True if in combat
local function is_in_combat()
    local me = _get_local_player()
    if not me then
        return false
    end
    
    local success, result = pcall(function() return me:is_in_combat() end)
    if success then
        return result or false
    end
    return false
end

---Get the first ready item from a list of item IDs
---@param item_ids table Array of item IDs to check
---@return number|nil Item ID if found ready, nil otherwise
function mana_manager.get_first_ready_item(item_ids)
    if not item_ids or type(item_ids) ~= "table" then
        return nil
    end
    
    for _, item_id in ipairs(item_ids) do
        local success, start_time, duration = pcall(_get_item_cooldown, item_id)
        if success and start_time and duration then
            -- Item is ready if cooldown is 0 or expired
            local remaining = (start_time + duration) - core.time()
            if remaining <= 0 then
                return item_id
            end
        end
    end
    
    return nil
end

---Use a consumable item by ID
---@param me userdata Player unit object
---@param item_id number Item ID to use
---@return boolean True if item was used successfully
function mana_manager.use_consumable(me, item_id)
    if not me or not item_id then
        return false
    end
    
    -- Only use consumables in combat
    if not is_in_combat() then
        return false
    end
    
    local success = pcall(_use_item, item_id, me)
    return success
end

---Cast a spell by ID
---@param me userdata Player unit object
---@param spell_id number Spell ID to cast
---@return boolean True if spell was cast successfully
local function cast_spell(me, spell_id)
    if not me or not spell_id then
        return false
    end
    
    local success = pcall(_cast_spell, spell_id, me)
    return success
end

---Check if a spell is learned and off cooldown
---@param spell_id number Spell ID to check
---@return boolean True if spell is ready to cast
local function is_spell_ready(spell_id)
    if not spell_id then
        return false
    end
    
    -- Check if learned
    local learned_success, is_learned = pcall(_is_spell_learned, spell_id)
    if not learned_success or not is_learned then
        return false
    end
    
    -- Check cooldown
    local cd_success, start_time, duration = pcall(_get_spell_cooldown, spell_id)
    if cd_success and start_time and duration then
        local remaining = (start_time + duration) - core.time()
        return remaining <= 0
    end
    
    return false
end

---Resolve the highest learned Life Tap rank for Warlocks
---@param me userdata Player unit object
---@param ranks table Array of Life Tap spell IDs (lowest to highest rank)
---@return number|nil Highest learned rank spell ID, or nil if none learned
function mana_manager.resolve_life_tap_rank(me, ranks)
    if not me or not ranks or type(ranks) ~= "table" then
        return nil
    end
    
    -- Iterate from highest rank to lowest
    for i = #ranks, 1, -1 do
        local spell_id = ranks[i]
        local success, is_learned = pcall(_is_spell_learned, spell_id)
        if success and is_learned then
            return spell_id
        end
    end
    
    return nil
end

-- ============================================================================
-- Main Recovery Function
-- ============================================================================

---Check mana levels and execute recovery if needed
---@param me userdata Player unit object
---@param menu table Menu configuration object
---@param class_recovery table Class-specific recovery config from CLASS_RECOVERY
---@return boolean True if a recovery action was taken
function mana_manager.check_and_recover(me, menu, class_recovery)
    -- Nil guards on all parameters
    if not me then
        return false
    end
    
    if not class_recovery or type(class_recovery) ~= "table" then
        return false
    end
    
    -- Get current mana percentage
    local mana_pct = mana_manager.get_mana_pct(me)
    
    -- Get menu thresholds with defaults
    local gem_threshold = (menu and menu.gem_threshold and menu.gem_threshold:get()) or 70
    local potion_threshold = (menu and menu.potion_threshold and menu.potion_threshold:get()) or 50
    local rune_threshold = (menu and menu.rune_threshold and menu.rune_threshold:get()) or 30
    local evocation_threshold = (menu and menu.evocation_threshold and menu.evocation_threshold:get()) or 20
    local shadowfiend_threshold = (menu and menu.shadowfiend_threshold and menu.shadowfiend_threshold:get()) or 50
    local innervate_threshold = (menu and menu.innervate_threshold and menu.innervate_threshold:get()) or 50
    local life_tap_threshold = (menu and menu.life_tap_threshold and menu.life_tap_threshold:get()) or 60
    local life_tap_hp_safety = (menu and menu.life_tap_hp_safety and menu.life_tap_hp_safety:get()) or 50
    
    -- Only use consumables in combat
    local in_combat = is_in_combat()
    
    -- MAGE: Mana gems → Potions → Runes → Evocation
    if class_recovery.gems and mana_pct <= gem_threshold then
        local gem_id = mana_manager.get_first_ready_item(MANA_GEMS)
        if gem_id and in_combat then
            return mana_manager.use_consumable(me, gem_id)
        end
    end
    
    -- PRIEST: Shadowfiend (before consumables)
    if class_recovery.shadowfiend and mana_pct <= shadowfiend_threshold then
        if is_spell_ready(class_recovery.shadowfiend) then
            return cast_spell(me, class_recovery.shadowfiend)
        end
    end
    
    -- DRUID: Innervate (before consumables)
    if class_recovery.innervate and mana_pct <= innervate_threshold then
        if is_spell_ready(class_recovery.innervate) then
            return cast_spell(me, class_recovery.innervate)
        end
    end
    
    -- WARLOCK: Life Tap (with HP safety check)
    if class_recovery.life_tap and mana_pct <= life_tap_threshold then
        local health_pct = get_health_pct(me)
        if health_pct >= life_tap_hp_safety then
            local tap_spell = mana_manager.resolve_life_tap_rank(me, class_recovery.life_tap)
            if tap_spell and is_spell_ready(tap_spell) then
                return cast_spell(me, tap_spell)
            end
        end
    end
    
    -- Potions (for all classes that use them)
    if class_recovery.potions and mana_pct <= potion_threshold then
        local potion_id = mana_manager.get_first_ready_item(MANA_POTIONS)
        if potion_id and in_combat then
            return mana_manager.use_consumable(me, potion_id)
        end
    end
    
    -- Runes (for all classes that use them)
    if class_recovery.runes and mana_pct <= rune_threshold then
        local rune_id = mana_manager.get_first_ready_item(DARK_RUNES)
        if rune_id and in_combat then
            return mana_manager.use_consumable(me, rune_id)
        end
    end
    
    -- MAGE: Evocation (last resort)
    if class_recovery.evocation and mana_pct <= evocation_threshold then
        if is_spell_ready(class_recovery.evocation) then
            return cast_spell(me, class_recovery.evocation)
        end
    end
    
    return false
end

-- ============================================================================
-- Module Export
-- ============================================================================

return mana_manager
