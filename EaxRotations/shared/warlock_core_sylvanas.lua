-- ============================================================================
-- Shared Helper: Warlock Core
-- Fire/shadow immunity detection, Soulshatter, cast-cancel, Life Tap, sustain
-- ============================================================================

local M = {}
local _G = _G
local NS = _G.EaxRotations
local _core_time = core.time
local _get_local_player = core.object_manager.get_local_player
local _cast_spell = core.input.cast_target_spell
local _get_spell_cd = core.spell_book.get_spell_cooldown
local _is_spell_learned = core.spell_book.is_spell_learned

local _data_ok, TBC = pcall(require, "shared/tbc_data_sylvanas")
if not _data_ok or type(TBC) ~= "table" then TBC = { ITEMS = {} } end
local TBC_ITEMS = TBC.ITEMS or {}

-- ============================================================================
-- Create Healthstone / Soulstone from inventory items
-- ============================================================================

local HEALTHSTONE_ITEMS = TBC_ITEMS.healthstones or {
    19004, -- Minor
    19005, -- Minor
    19006, -- Lesser
    19007, -- Lesser
    19008, -- Major
    19009, -- Major
    19010, -- Greater
    19011, -- Greater
    19012, -- Master
    19013, -- Master
}

-- ============================================================================
-- Fire/Shadow immunity check
-- ============================================================================

--- Checks if a target is immune to fire damage
---@param target game_object
---@return boolean immune
function M.is_fire_immune(target)
    if not target then return false end
    if not target.is_valid then return false end

    -- Check by NPC ID from known list
    local ok_id, npc_id = pcall(function() return target:get_npc_id() end)
    if ok_id and npc_id and FIRE_IMMUNE_MOBS[npc_id] then
        return true
    end

    -- Check for fire immunity buff
    local ok_buff, has_immune = pcall(function()
        return target:has_buff(15007)  -- Fire Resistance/Immunity buff
            or target:has_buff(7940)   -- Fire Shield immunity (certain elementals)
    end)
    if ok_buff and has_immune then
        return true
    end

    return false
end

--- Checks if a target is immune to shadow damage
---@param target game_object
---@return boolean immune
function M.is_shadow_immune(target)
    if not target then return false end
    if not target.is_valid then return false end

    local ok, has_immune = pcall(function()
        -- Shadow immunity buffs (various sources)
        return target:has_buff(36894)  -- Shadow Resistance
            or target:has_buff(37136)  -- Shadow Protection (Fel armor type)
    end)
    return ok and has_immune or false
end

--- Gets the effective school for a build (fire or shadow)
---@param build string \"fire\"|\"shadow\"
---@param target game_object
---@return string|nil Effective school, or nil if immune
function M.get_effective_school(build, target)
    if not target then return nil end

    if build == "fire" then
        if M.is_fire_immune(target) then
            return nil  -- Fire-immune, need shadow fallback
        end
        return "fire"
    elseif build == "shadow" then
        if M.is_shadow_immune(target) then
            return nil
        end
        return "shadow"
    end

    return nil
end

-- ============================================================================
-- Cast cancellation (smart interrupt for dying targets)
-- ============================================================================

local _cancel_lock_time = 0

--- Cancels current cast if target will die before it completes
---@param target game_object Target unit
---@param cast_time_ms number Remaining cast time in ms
---@param ttd number Target time-to-die in seconds (estimated)
---@param me game_object|nil Local player
---@return boolean cancelled True if cast was cancelled
function M.cancel_cast_on_dying(target, cast_time_ms, ttd, me)
    if not target or not cast_time_ms then return false end

    -- Only cancel if target has < 3 seconds to live
    if ttd and ttd > 3 then return false end

    -- Only cancel if cast will take longer than TTD
    local cast_remaining_s = cast_time_ms / 1000
    if ttd and cast_remaining_s > ttd then
        local now = _core_time()
        -- Throttle cancel spam to once per 500ms
        if now - _cancel_lock_time < 0.5 then return false end
        _cancel_lock_time = now

        pcall(core.input.cast_target_spell, 32747, me)  -- Spell_Cancel action
        return true
    end

    return false
end

-- ============================================================================
-- Life Tap management
-- ============================================================================

--- Checks if Life Tap should be used
---@param life_tap_ids table Life Tap spell ID table (highest ranks first)
---@param mana_threshold number Mana % below which to tap
---@param min_hp number Minimum HP % to allow tapping
---@param me game_object Local player
---@return boolean used True if Life Tap was cast
function M.use_life_tap(life_tap_ids, mana_threshold, min_hp, me)
    if not me then me = _get_local_player() end
    if not me then return false end

    if not mana_threshold then mana_threshold = 50 end
    if not min_hp then min_hp = 30 end

    local hp_pct = me:get_health_percentage()
    local mana_pct = me:get_mana_percentage()

    if mana_pct >= mana_threshold then return false end
    if hp_pct <= min_hp then return false end

    -- Find highest known Life Tap rank
    for _, id in ipairs(life_tap_ids) do
        if _is_spell_learned(id) then
            local cd = _get_spell_cd(id)
            if cd == 0 then
                _cast_spell(id, me)
                return true
            end
        end
    end

    return false
end

-- ============================================================================
-- Mana Gem usage
-- ============================================================================

--- Uses a mana gem if mana is below threshold
---@param mana_gem_ids table Mana Gem item IDs
---@param threshold number Mana % threshold
---@param me game_object Local player
---@return boolean used
function M.use_mana_gem(mana_gem_ids, threshold, me)
    if not me then me = _get_local_player() end
    if not me then return false end

    if not threshold then threshold = 40 end
    local mana_pct = me:get_mana_percentage()
    if not mana_pct or mana_pct >= threshold then return false end

    for _, item_id in ipairs(mana_gem_ids) do
        local ok, count = pcall(core.inventory.get_item_count, item_id)
        if ok and count and count > 0 then
            local ok2 = pcall(core.input.use_item, item_id, me)
            if ok2 then return true end
        end
    end

    return false
end

-- ============================================================================
-- Fel Armor / Demon Armor maintenance
-- ============================================================================

--- Maintains Fel Armor or Demon Armor buff
---@param fel_armor_ids table Fel Armor spell IDs
---@param demon_armor_ids table Demon Armor spell IDs
---@param prefer_fel boolean Prefer Fel Armor if available
---@param me game_object|nil Local player
---@return boolean used
function M.maintain_armor(fel_armor_ids, demon_armor_ids, prefer_fel, me)
    if not me then me = _get_local_player() end
    if not me then return false end

    local armors = prefer_fel and fel_armor_ids or demon_armor_ids

    -- Check if any armor buff is already up
    for _, id in ipairs(fel_armor_ids) do
        local ok, has = pcall(function() return me:has_buff(id) end)
        if ok and has then return false end
    end
    for _, id in ipairs(demon_armor_ids) do
        local ok, has = pcall(function() return me:has_buff(id) end)
        if ok and has then return false end
    end

    -- Try preferred first
    for _, id in ipairs(armors) do
        if _is_spell_learned(id) then
            local cd = _get_spell_cd(id)
            if cd == 0 then
                _cast_spell(id, me)
                return true
            end
        end
    end

    -- Fallback to other armor type
    local other = prefer_fel and demon_armor_ids or fel_armor_ids
    for _, id in ipairs(other) do
        if _is_spell_learned(id) then
            local cd = _get_spell_cd(id)
            if cd == 0 then
                _cast_spell(id, me)
                return true
            end
        end
    end

    return false
end

-- ============================================================================
-- Pet sacrifice management
-- ============================================================================

---@class sacrifice_config
---@field imp_buff_id number Demonic Sacrifice buff for Imp
---@field succubus_buff_id number Demonic Sacrifice buff for Succubus
---@field felhunter_buff_id number Demonic Sacrifice buff for Felhunter
---@field voidwalker_buff_id number Demonic Sacrifice buff for Voidwalker
---@field sacrifice_spell_id integer Demonic Sacrifice spell ID

local _current_sacrifice_buff = nil

--- Checks if Demonic Sacrifice buff is active for a specific pet type
---@param config sacrifice_config Buff IDs
---@param me game_object Local player
---@return string|nil Pet type that is sacrificed, or nil
function M.get_sacrifice_buff_type(config, me)
    if not config or not me then return nil end

    if config.imp_buff_id then
        local ok, has = pcall(function() return me:has_buff(config.imp_buff_id) end)
        if ok and has then return "imp" end
    end
    if config.succubus_buff_id then
        local ok, has = pcall(function() return me:has_buff(config.succubus_buff_id) end)
        if ok and has then return "succubus" end
    end
    if config.felhunter_buff_id then
        local ok, has = pcall(function() return me:has_buff(config.felhunter_buff_id) end)
        if ok and has then return "felhunter" end
    end
    if config.voidwalker_buff_id then
        local ok, has = pcall(function() return me:has_buff(config.voidwalker_buff_id) end)
        if ok and has then return "voidwalker" end
    end

    return nil
end

--- Sacrifices the current pet
---@param config sacrifice_config
---@param me game_object Local player
---@return boolean sacrificed
function M.sacrifice_pet(config, me)
    if not config or not me then return false end
    if not config.sacrifice_spell_id then return false end

    -- Check if we have a pet active
    local ok, pet = pcall(function() return me:get_pet() end)
    if not ok or not pet then return false end

    -- Check if sacrifice buff is already up
    local buff = M.get_sacrifice_buff_type(config, me)
    if buff then return false end

    local cd = _get_spell_cd(config.sacrifice_spell_id)
    if cd == 0 then
        _cast_spell(config.sacrifice_spell_id, me)
        return true
    end

    return false
end

--- Determines the best pet type for a warlock build
---@param build string \"fire\"|\"shadow\"|\"affliction\"|\"demo\"
---@return string pet_type \"imp\"|\"succubus\"|\"felhunter\"|\"voidwalker\"
function M.recommend_pet_for_build(build)
    if build == "fire" then
        return "imp"
    elseif build == "shadow" then
        return "succubus"
    elseif build == "affliction" then
        return "felhunter"
    elseif build == "demo" then
        return "voidwalker"
    end
    return "imp"
end

-- ============================================================================
-- Create Healthstone / Soulstone from inventory items
-- ============================================================================

--- Creates a Healthstone if none exists in bags
---@param create_spell_id integer Create Healthstone spell ID
---@return boolean created
function M.create_healthstone(create_spell_id)
    if not create_spell_id then return false end

    -- Check if we already have one
    for _, item_id in ipairs(HEALTHSTONE_ITEMS) do
        local ok, count = pcall(core.inventory.get_item_count, item_id)
        if ok and count and count > 0 then return false end
    end

    local cd = _get_spell_cd(create_spell_id)
    if cd == 0 then
        local me = _get_local_player()
        if me then
            _cast_spell(create_spell_id, me)
            return true
        end
    end

    return false
end

-- ============================================================================
-- Export
-- ============================================================================

NS.WarlockCore = M

return M
