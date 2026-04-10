--[[
    form_consumables.lua
    Form-aware consumable management for Druid specs
    Wave 1: Flux feature porting
    
    Handles: Leave form → use consumable → return to form
    Supports: Healthstones, Healing Potions
    Forms: Cat, Bear, Dire Bear, Travel, Aquatic, Moonkin, Tree
--]]

local form_consumables = {}

-- ============================================================================
-- API Caching (at module load)
-- ============================================================================

local _get_local_player = core.object_manager.get_local_player

local _cancel_form = core.spell_book.cancel_form
local _cast_spell = core.input.cast_target_spell
-- STUB: core.inventory.* and core.item_manager.* APIs don't exist in Sylvanas
local _use_item = function(item_id, target) return false end
local _get_item_cooldown = function(item_id) return 0 end
local _get_item_count = function(item_id) return 0 end


-- ============================================================================
-- Constants
-- ============================================================================

local FORM_BUFFS = {
    CAT = { 768, 32357 },
    BEAR = { 9634, 5487 },  -- Dire Bear, Bear
    TRAVEL = { 783 },
    AQUATIC = { 1066 },
    MOONKIN = { 24858 },
    TREE = { 33891 },
}

local CONSUMABLES = {
    healthstone = {
        22116,  -- Master Healthstone (Warlock conjured)
        22105,  -- Major Healthstone
        22104,  -- Greater Healthstone
        22103,  -- Healthstone
        22102,  -- Lesser Healthstone
        22101,  -- Minor Healthstone
    },
    healing_potion = {
        22850,  -- Super Healing Potion
        22829,  -- Healing Potion (TBC)
        17348,  -- Major Healing Potion
        17347,  -- Greater Healing Potion
        17346,  -- Healing Potion
        17345,  -- Lesser Healing Potion
        17344,  -- Minor Healing Potion
    },
}

-- Combat forms that should be restored after consumable use
local COMBAT_FORMS = {
    CAT = true,
    BEAR = true,
    MOONKIN = true,
    TREE = true,
}

-- ============================================================================
-- Helper Functions
-- ============================================================================

--[[
    Check if player has any of the given buff IDs
--]]
local function has_any_buff(me, buff_ids)
    if not me or not me:is_valid() or not buff_ids then
        return false
    end
    
    for _, buff_id in ipairs(buff_ids) do
        local ok_buff, has_buff = pcall(function() return me:has_aura(buff_id) end)
        if ok_buff and has_buff then
            return true
        end
    end
    return false
end

--[[
    Get current Druid form name or nil if in caster form
--]]
function form_consumables.get_current_form(me)
    if not me or not me:is_valid() then
        return nil
    end
    
    for form_name, buff_ids in pairs(FORM_BUFFS) do
        if has_any_buff(me, buff_ids) then
            return form_name
        end
    end
    
    return nil  -- Caster form (no form)
end

--[[
    Check if currently in a combat form (Cat, Bear, Moonkin, Tree)
--]]
function form_consumables.is_in_combat_form(me)
    local form = form_consumables.get_current_form(me)
    return form and COMBAT_FORMS[form] or false
end

--[[
    Check if currently in any form
--]]
function form_consumables.is_in_any_form(me)
    return form_consumables.get_current_form(me) ~= nil
end

-- ============================================================================
-- Form Management
-- ============================================================================

--[[
    Leave current form (cancel form buff)
    Returns: success (boolean)
--]]
function form_consumables.leave_form(me)
    if not me or not me:is_valid() then
        return false
    end
    
    if not form_consumables.is_in_any_form(me) then
        return true  -- Already in caster form, consider it success
    end
    
    -- Use pcall for safety as cancel_form may not always be available
    local success, result = pcall(function()
        return _cancel_form()
    end)
    
    return success and result
end

--[[
    Return to a specific form by casting the form spell
    Returns: success (boolean)
--]]
function form_consumables.return_to_form(me, form_name, spell_ids)
    if not me or not me:is_valid() then
        return false
    end
    
    if not form_name or not spell_ids then
        return false
    end
    
    -- Already in the desired form
    local current_form = form_consumables.get_current_form(me)
    if current_form == form_name then
        return true
    end
    
    -- Try to cast the form spell
    -- spell_ids should be a table of {spell_id, priority} or just spell_id
    local spell_id = type(spell_ids) == "table" and spell_ids[1] or spell_ids
    
    if not spell_id then
        return false
    end
    
    local success, result = pcall(function()
        return _cast_spell(spell_id, me)
    end)
    
    return success and result
end

-- ============================================================================
-- Consumable Management
-- ============================================================================

--[[
    Get the first ready (off cooldown, in bags) consumable from item list
    Returns: item_id or nil
--]]
function form_consumables.get_ready_consumable(item_ids)
    if not item_ids or #item_ids == 0 then
        return nil
    end
    
    for _, item_id in ipairs(item_ids) do
        local cd = _get_item_cooldown(item_id)
        local count = _get_item_count(item_id)
        
        -- Ready if: cooldown is 0 (or very small) and we have at least 1
        if cd and cd <= 0.1 and count and count > 0 then
            return item_id
        end
    end
    
    return nil
end

--[[
    Use a consumable item
    Returns: success (boolean)
--]]
function form_consumables.use_consumable(item_id, target)
    if not item_id then
        return false
    end
    
    target = target or _get_local_player()
    
    local success, result = pcall(function()
        return _use_item(item_id, target)
    end)
    
    return success and result
end

-- ============================================================================
-- Main Entry Point
-- ============================================================================

--[[
    Check if consumables should be used and handle form logic
    
    Parameters:
        me - Local player object
        menu - Menu object with toggle settings
        form_spells - Table mapping form names to spell IDs { CAT = 768, BEAR = 5487, ... }
        saved_form - Form name from previous tick (if we need to restore)
    
    Returns:
        used (boolean) - Whether a consumable was used this tick
        saved_form (string|nil) - Form to restore next tick (if we left form)
        reason (string) - Debug reason for the action taken
--]]
function form_consumables.check_and_use(me, menu, form_spells, saved_form)
    -- Nil guards
    if not me or not me:is_valid() then
        return false, nil, "invalid_player"
    end
    
    -- Only use consumables in combat
    local ok_combat, in_combat = pcall(function() return me:is_in_combat() end)
    if not ok_combat or not in_combat then
        return false, nil, "not_in_combat"
    end
    
    -- Get menu settings with defaults
    local use_healthstone = (menu.use_healthstone and menu.use_healthstone:get_state()) or false
    local use_healing_potion = (menu.use_healing_potion and menu.use_healing_potion:get_state()) or false
    local health_threshold = (menu.consumable_health_threshold and menu.consumable_health_threshold:get()) or 35
    
    -- If no consumables enabled, skip
    if not use_healthstone and not use_healing_potion then
        return false, nil, "consumables_disabled"
    end
    
    -- Check health percentage
    local ok_hp, hp = pcall(function() return me:get_health() end)
local ok_max, max_hp = pcall(function() return me:get_max_health() end)
local health_pct = (ok_hp and ok_max and hp and max_hp and max_hp > 0) and ((hp / max_hp) * 100) or 100
    if not health_pct or health_pct > health_threshold then
        return false, nil, "health_above_threshold"
    end
    
    local current_form = form_consumables.get_current_form(me)
    
    -- PHASE 2: Restore form from previous tick
    if saved_form then
        -- We have a pending form to restore
        if not current_form then
            -- We're in caster form, try to return to saved form
            local spell_id = form_spells and form_spells[saved_form]
            if spell_id then
                local restored = form_consumables.return_to_form(me, saved_form, spell_id)
                if restored then
                    return false, nil, "form_restored"
                else
                    -- Failed to restore, keep saved_form for next tick
                    return false, saved_form, "form_restore_pending"
                end
            else
                -- No spell ID for this form, clear saved form
                return false, nil, "no_form_spell"
            end
        else
            -- Already in a form (maybe user shifted manually), clear saved
            return false, nil, "already_in_form"
        end
    end
    
    -- PHASE 1: Check if we need to use consumables
    local consumable_to_use = nil
    local consumable_type = nil
    
    -- Priority: Healthstone > Healing Potion
    if use_healthstone then
        consumable_to_use = form_consumables.get_ready_consumable(CONSUMABLES.healthstone)
        if consumable_to_use then
            consumable_type = "healthstone"
        end
    end
    
    if not consumable_to_use and use_healing_potion then
        consumable_to_use = form_consumables.get_ready_consumable(CONSUMABLES.healing_potion)
        if consumable_to_use then
            consumable_type = "healing_potion"
        end
    end
    
    -- No consumables available
    if not consumable_to_use then
        return false, nil, "no_consumables_available"
    end
    
    -- If we're in a form, we need to leave it first
    local need_to_restore = false
    if current_form then
        -- Leave the form
        local left = form_consumables.leave_form(me)
        if not left then
            return false, nil, "failed_to_leave_form"
        end
        
        -- Mark that we need to restore this form next tick
        need_to_restore = COMBAT_FORMS[current_form]
    end
    
    -- Use the consumable
    local used = form_consumables.use_consumable(consumable_to_use, me)
    
    if used then
        return true, need_to_restore and current_form or nil, "used_" .. consumable_type
    else
        -- Failed to use, but we already left form - need to restore
        return false, need_to_restore and current_form or nil, "failed_to_use_" .. consumable_type
    end
end

-- ============================================================================
-- Utility Functions
-- ============================================================================

--[[
    Get available consumable counts for UI/debug
    Returns: table with counts for each consumable type
--]]
function form_consumables.get_consumable_counts()
    local counts = {}
    
    for type_name, item_ids in pairs(CONSUMABLES) do
        counts[type_name] = 0
        for _, item_id in ipairs(item_ids) do
            local count = _get_item_count(item_id)
            if count then
                counts[type_name] = counts[type_name] + count
            end
        end
    end
    
    return counts
end

--[[
    Check if any consumables are ready (for pre-combat prep)
    Returns: boolean
--]]
function form_consumables.has_any_ready()
    for _, item_ids in pairs(CONSUMABLES) do
        if form_consumables.get_ready_consumable(item_ids) then
            return true
        end
    end
    return false
end

--[[
    Get cooldown info for all consumables
    Returns: table with cooldown status
--]]
function form_consumables.get_cooldowns()
    local cds = {}
    
    for type_name, item_ids in pairs(CONSUMABLES) do
        cds[type_name] = {}
        for _, item_id in ipairs(item_ids) do
            local cd = _get_item_cooldown(item_id)
            if cd and cd > 0 then
                table.insert(cds[type_name], { item_id = item_id, cooldown = cd })
            end
        end
    end
    
    return cds
end

-- ============================================================================
-- Module Export
-- ============================================================================

return form_consumables