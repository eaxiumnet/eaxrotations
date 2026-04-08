-- racial_manager.lua
-- Protection Paladin racial ability manager
-- Handles Stoneform (Dwarf) and Gift of the Naaru (Draenei)

local racial_manager = {}

-- ============================================================================
-- Dependencies
-- ============================================================================
local spells = require("libraries/spells")
local utils = require("libraries/utils")
local menu = require("libraries/menu")

-- ============================================================================
-- API Caching (at module load)
-- ============================================================================
local _get_local_player = core.object_manager.get_local_player
local _get_spell_cooldown = core.spell_book.get_spell_cooldown
local _is_spell_learned = core.spell_book.is_spell_learned
local _cast_spell = core.input.cast_target_spell
local _core_time = core.time

-- ============================================================================
-- Throttling
-- ============================================================================
local _last_attempt_time = 0
local ATTEMPT_THROTTLE_S = 1.5

-- ============================================================================
-- Utility Functions
-- ============================================================================

---Get current health percentage for a unit
---@param me userdata Player unit object
---@return number Health percentage (0-100)
local function get_health_pct(me)
    if not me then
        return 100
    end
    
    local success, result = pcall(function() return me:get_health_percentage() end)
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
        local remaining = (start_time + duration) - _core_time()
        return remaining <= 0
    end
    
    return false
end

---Cast a spell by ID on self
---@param me userdata Player unit object
---@param spell_id number Spell ID to cast
---@return boolean True if spell was cast successfully
local function cast_spell_self(me, spell_id)
    if not me or not spell_id then
        return false
    end
    
    local success = pcall(_cast_spell, spell_id, me)
    return success
end

---Check if we should throttle attempts
---@return boolean True if we should skip this attempt
local function should_throttle()
    local now = _core_time()
    if (now - _last_attempt_time) < ATTEMPT_THROTTLE_S then
        return true
    end
    _last_attempt_time = now
    return false
end

-- ============================================================================
-- Racial Handlers
-- ============================================================================

---Try to use Stoneform (Dwarf racial)
---Cleanses poison/disease and provides 10% armor buff
---@param me userdata Player unit object
---@return boolean True if Stoneform was used
local function try_stoneform(me)
    -- Resolve spell ID
    local stoneform_id = utils.resolve_spell_id(spells.STONEFORM)
    if not stoneform_id then
        return false
    end
    
    -- Check if ready
    if not is_spell_ready(stoneform_id) then
        return false
    end
    
    -- Get menu settings with nil guards
    local use_stoneform = (menu and menu.use_stoneform and menu.use_stoneform:get_state()) or false
    if not use_stoneform then
        return false
    end
    
    local stoneform_threshold = (menu and menu.stoneform_hp_pct and menu.stoneform_hp_pct:get()) or 40
    
    -- Check health threshold
    local hp_pct = get_health_pct(me)
    if hp_pct > stoneform_threshold then
        return false
    end
    
    -- Only use in combat
    if not is_in_combat() then
        return false
    end
    
    -- Cast Stoneform
    if cast_spell_self(me, stoneform_id) then
        return true
    end
    
    return false
end

---Try to use Gift of the Naaru (Draenei racial)
---Heal over time effect
---@param me userdata Player unit object
---@return boolean True if Gift of the Naaru was used
local function try_gift_of_the_naaru(me)
    -- Resolve spell ID
    local naaru_id = utils.resolve_spell_id(spells.GIFT_OF_THE_NAARU)
    if not naaru_id then
        return false
    end
    
    -- Check if ready
    if not is_spell_ready(naaru_id) then
        return false
    end
    
    -- Get menu settings with nil guards
    local use_naaru = (menu and menu.use_gift_of_the_naaru and menu.use_gift_of_the_naaru:get_state()) or false
    if not use_naaru then
        return false
    end
    
    local naaru_threshold = (menu and menu.gift_of_the_naaru_hp_pct and menu.gift_of_the_naaru_hp_pct:get()) or 50
    
    -- Check health threshold
    local hp_pct = get_health_pct(me)
    if hp_pct > naaru_threshold then
        return false
    end
    
    -- Only use in combat
    if not is_in_combat() then
        return false
    end
    
    -- Cast Gift of the Naaru
    if cast_spell_self(me, naaru_id) then
        return true
    end
    
    return false
end

-- ============================================================================
-- Main Entry Point
-- ============================================================================

---Try to use defensive racial abilities
---Called from main.lua line 704
---@param me userdata Player unit object
---@return boolean True if any racial was used, false otherwise
function racial_manager.try_defensive(me)
    -- Validate input
    if not me then
        return false
    end
    
    -- Throttle to prevent spam
    if should_throttle() then
        return false
    end
    
    -- Try Stoneform first (Dwarf defensive)
    if try_stoneform(me) then
        return true
    end
    
    -- Try Gift of the Naaru (Draenei heal)
    if try_gift_of_the_naaru(me) then
        return true
    end
    
    return false
end

-- ============================================================================
-- Module Export
-- ============================================================================

return racial_manager
