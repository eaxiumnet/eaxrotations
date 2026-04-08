-- powershift.lua
-- Druid Feral powershift automation library
-- Auto-detects Wolfshead Helm and manages energy-efficient shifting
--
-- Usage:
--   local powershift = require("libraries/powershift")
--   local energy_tick = require("libraries/energy_tick")
--   
--   if powershift:should_powershift(me, current_energy, energy_tick, settings) then
--       powershift:execute(me, target, energy_tick)
--   end

local powershift = {
    WOLFSHEAD_HELM_ID = 8345,
    INVSLOT_HEAD = 1,
    FUROR_ENERGY = 40,
    WOLFSHEAD_BONUS = 20,
    DEFAULT_THRESHOLD = 20,
    THRESHOLD_WITH_WOLFSHEAD = 25,
    MANA_COST_SHIFT = 0.07,  -- 7% of base mana
    MIN_MANA_PCT = 0.25,     -- 25% minimum mana to shift
}

-- ============================================================================
-- API Caching (at module load)
-- ============================================================================
local _core_time = core.time
local _get_item_cooldown = core.inventory and core.inventory.get_item_id

-- ============================================================================
-- Wolfshead Helm Detection
-- ============================================================================

---Check if Wolfshead Helm is equipped
---Uses cached check with 2-second refresh interval
---@param me userdata Player unit object
---@return boolean True if Wolfshead Helm is equipped
function powershift:has_wolfshead(me)
    if not me then
        return false
    end

    -- Try Sylvanas API: me:get_equipped_item(1) for head slot
    local success, head_item = pcall(function()
        if me.get_equipped_item then
            return me:get_equipped_item(self.INVSLOT_HEAD)
        end
        return nil
    end)

    if success and head_item then
        return head_item == self.WOLFSHEAD_HELM_ID
    end

    -- Fallback: Try core.inventory API
    if _get_item_cooldown then
        local ok, item_id = pcall(_get_item_cooldown, self.INVSLOT_HEAD)
        if ok and item_id then
            return item_id == self.WOLFSHEAD_HELM_ID
        end
    end

    -- Fallback: Try WoW API if available
    if _G.GetInventoryItemID then
        local ok, item_id = pcall(_G.GetInventoryItemID, "player", self.INVSLOT_HEAD)
        if ok and item_id then
            return item_id == self.WOLFSHEAD_HELM_ID
        end
    end

    return false
end

-- ============================================================================
-- Energy Calculations
-- ============================================================================

---Calculate energy gain from a powershift
---40 base from Furor talent + 20 if Wolfshead Helm equipped
---@param me userdata Player unit object
---@return number Total energy after shift (40 or 60)
function powershift:get_shift_energy(me)
    local has_wolfshead = self:has_wolfshead(me)
    return self.FUROR_ENERGY + (has_wolfshead and self.WOLFSHEAD_BONUS or 0)
end

---Get the appropriate energy threshold for powershifting
---Higher threshold with Wolfshead to account for greater energy gain
---@param me userdata Player unit object
---@param settings table|nil Optional settings override
---@return number Energy threshold value
function powershift:get_threshold(me, settings)
    -- Check for custom threshold in settings
    if settings and settings.powershift_threshold then
        local ok, custom = pcall(function() return settings.powershift_threshold:get() end)
        if ok and custom then
            return custom
        end
    end

    -- Default: 25 with Wolfshead, 20 without
    local has_wolfshead = self:has_wolfshead(me)
    return has_wolfshead and self.THRESHOLD_WITH_WOLFSHEAD or self.DEFAULT_THRESHOLD
end

-- ============================================================================
-- Safety Checks
-- ============================================================================

---Check if player has sufficient mana to powershift
---Shifting costs ~7% of base mana
---@param me userdata Player unit object
---@param settings table|nil Optional settings with min_mana override
---@return boolean True if safe to shift
function powershift:has_sufficient_mana(me, settings)
    if not me then
        return false
    end

    -- Get minimum mana percentage from settings or use default
    local min_mana_pct = self.MIN_MANA_PCT
    if settings and settings.powershift_min_mana then
        local ok, val = pcall(function() return settings.powershift_min_mana:get() end)
        if ok and val then
            min_mana_pct = val / 100
        end
    end

    -- Get current mana percentage
    local success, mana_pct = pcall(function()
        if me.get_power then
            local mana = me:get_power(0)  -- 0 = mana
            local max_mana_func = me.get_max_power
            local max_mana = max_mana_func and max_mana_func(0) or 100
            return (mana / max_mana) * 100
        end
        return 100
    end)

    if not success or not mana_pct then
        return true  -- Default to allowing if we can't check
    end

    return (mana_pct / 100) >= min_mana_pct
end

---Check if player is in combat (required for powershifting)
---@param me userdata Player unit object
---@return boolean True if in combat
function powershift:is_in_combat(me)
    if not me then
        return false
    end

    local success, in_combat = pcall(function() return me:is_in_combat() end)
    return success and in_combat
end

-- ============================================================================
-- Powershift Decision
-- ============================================================================

---Check if powershift should be performed
---Considers: enabled setting, energy threshold, tick timing, mana, combat
---@param me userdata Player unit object
---@param current_energy number Current energy value
---@param energy_tick_module table Energy tick library instance
---@param settings table Settings table with menu toggles
---@return boolean True if powershift should be executed
function powershift:should_powershift(me, current_energy, energy_tick_module, settings)
    -- Validate inputs
    if not me or not energy_tick_module then
        return false
    end

    -- Check if powershifting is enabled
    if settings and settings.auto_powershift then
        local ok, enabled = pcall(function() return settings.auto_powershift:get_state() end)
        if not ok or not enabled then
            return false
        end
    end

    -- Must be in combat
    if not self:is_in_combat(me) then
        return false
    end

    -- Check mana sufficiency
    if not self:has_sufficient_mana(me, settings) then
        return false
    end

    -- Check energy threshold
    local threshold = self:get_threshold(me, settings)
    if current_energy > threshold then
        return false
    end

    -- Check if tick is imminent - wait if tick < 0.4s away
    -- This prevents clipping energy ticks
    if energy_tick_module.should_delay_shift then
        if energy_tick_module:should_delay_shift() then
            return false
        end
    elseif energy_tick_module.should_delay_action then
        if energy_tick_module:should_delay_action() then
            return false
        end
    end

    -- Check if we would actually gain energy from the shift
    local energy_after_shift = self:get_shift_energy(me)
    if energy_after_shift <= current_energy then
        return false
    end

    return true
end

-- ============================================================================
-- Powershift Execution
-- ============================================================================

---Execute powershift by casting Cat Form
---Resets energy tick tracking after shift
---@param me userdata Player unit object
---@param target userdata|nil Target unit (optional, for logging)
---@param energy_tick_module table Energy tick library instance
---@param cat_form_id number Spell ID for Cat Form
---@return boolean True if shift was attempted
function powershift:execute(me, target, energy_tick_module, cat_form_id)
    if not me or not cat_form_id then
        return false
    end

    -- Notify energy tick module about impending shift
    if energy_tick_module then
        if energy_tick_module.on_shift then
            energy_tick_module:on_shift()
        elseif energy_tick_module.on_powershift then
            energy_tick_module:on_powershift()
        end
    end

    -- Cast Cat Form (powershift)
    local success = pcall(function()
        if core.input and core.input.cast_target_spell then
            return core.input.cast_target_spell(cat_form_id, me)
        elseif core.spell_book and core.spell_book.cast_target_spell then
            return core.spell_book.cast_target_spell(cat_form_id, me)
        end
        return false
    end)

    return success
end

---Get debug information for HUD/display
---@param me userdata Player unit object
---@param current_energy number Current energy value
---@param energy_tick_module table Energy tick library instance
---@return table Debug info table
function powershift:get_debug_info(me, current_energy, energy_tick_module)
    local has_wolfshead = self:has_wolfshead(me)
    local threshold = self:get_threshold(me)
    local energy_after = self:get_shift_energy(me)

    local tick_info = {}
    if energy_tick_module then
        if energy_tick_module.time_until_next_tick then
            tick_info.time_until = energy_tick_module:time_until_next_tick()
        end
        if energy_tick_module.is_confident then
            tick_info.confident = energy_tick_module:is_confident()
        end
        if energy_tick_module.should_delay_shift then
            tick_info.should_delay = energy_tick_module:should_delay_shift()
        end
    end

    return {
        has_wolfshead = has_wolfshead,
        current_energy = current_energy,
        threshold = threshold,
        energy_after_shift = energy_after,
        would_gain = energy_after > current_energy,
        tick_info = tick_info,
        in_combat = self:is_in_combat(me),
        has_mana = self:has_sufficient_mana(me)
    }
end

-- ============================================================================
-- Module Export
-- ============================================================================

return powershift
