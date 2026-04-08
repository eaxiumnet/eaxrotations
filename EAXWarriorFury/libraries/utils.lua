---@type buff_manager
local buff_manager = require("common/modules/buff_manager")

local utils = {}

-- Spell resolver with persistent caching
local spell_resolver = require("libraries/spell_resolver")

---@type izi_sdk
local izi = require("common/izi_sdk")

local throttle_data = {}
local queue_request_timestamps = {}
local SPELL_QUEUE_INTERVAL_S = 0.25

function utils.throttle(key, interval)
    local now = core.time()
    if not throttle_data[key] or (now - throttle_data[key]) >= interval then
        throttle_data[key] = now
        return true
    end
    return false
end

-- Create IZI spell objects for common casting patterns
local cached_spells = {}

---Get or create an IZI spell object for a spell ID
---@param spell_id number
---@return table|nil
local function get_izi_spell(spell_id)
    if not spell_id then return nil end
    if not cached_spells[spell_id] then
        cached_spells[spell_id] = izi.spell(spell_id)
    end
    return cached_spells[spell_id]
end

function utils.resolve_spell_id(rank_table)
    if not rank_table then return nil end
    if type(rank_table) == "number" then
        return core.spell_book.is_spell_learned(rank_table) and rank_table or nil
    end
    for i = 1, #rank_table do
        local spell_id = rank_table[i]
        if spell_id and core.spell_book.is_spell_learned(spell_id) then
            return spell_id
        end
    end
    return nil
end

function utils.get_health_pct(unit)
    if not unit or not unit:is_valid() then return 0 end
    local hp = unit:get_health()
    local max = unit:get_max_health()
    if not max or max <= 0 then return 0 end
    return hp / max
end

function utils.get_distance_to_target(me, target)
    if not me or not target then return math.huge end
    local me_pos = me:get_position()
    local target_pos = target:get_position()
    if not me_pos or not target_pos then return math.huge end
    return me_pos:dist_to(target_pos)
end

function utils.is_valid_hostile_target(me, target)
    if not me or not target then return false end
    if not target:is_valid() or target:is_dead() then return false end
    return me:can_attack(target)
end

function utils.can_cast_target(spell_id, me, target)
    if not spell_id or not me or not target then return false end
    if not core.spell_book.is_spell_learned(spell_id) then return false end
    if core.spell_book.get_spell_cooldown(spell_id) > 0 then return false end
    if not core.spell_book.is_usable_spell(spell_id) then return false end
    if not core.spell_book.is_spell_in_range(spell_id, target, me) then return false end
    return true
end

function utils.same_unit(a, b)
    if not a or not b then return false end
    if a == b then return true end
    if not a.is_valid or not b.is_valid or not a:is_valid() or not b:is_valid() then return false end
    local function safe_guid(u)
        if type(u.get_guid) ~= "function" then return nil end
        local ok, g = pcall(function() return u:get_guid() end)
        return (ok and g ~= nil) and tostring(g) or nil
    end
    local ga, gb = safe_guid(a), safe_guid(b)
    if ga and gb then return ga == gb end
    return false
end

function utils.can_cast_hostile(spell_id, me, target)
    if not me or not target then return false end
    if utils.same_unit(me, target) then return false end
    if not me:can_attack(target) then return false end
    return utils.can_cast_target(spell_id, me, target)
end

function utils.has_buff(unit, buff_table)
    if not unit or not unit:is_valid() or not buff_table then return false end
    local entry = buff_manager:get_buff_data(unit, buff_table)
    if entry and entry.is_active then return true end
    entry = buff_manager:get_aura_data(unit, buff_table)
    return entry ~= nil and entry.is_active == true
end

function utils.has_debuff(unit, debuff_table)
    if not unit or not unit:is_valid() or not debuff_table then return false end
    local data = buff_manager:get_debuff_data(unit, debuff_table)
    if data and data.is_active then return true end
    data = buff_manager:get_aura_data(unit, debuff_table)
    return data ~= nil and data.is_active
end

function utils.log_debug(menu_module, message)
    if menu_module and menu_module.debug and menu_module.debug:get_state() then
        core.log("[EAX] " .. tostring(message))
    end
end

local function can_issue_queue_request(kind, spell_id, target, interval_s)
    local key = kind .. ":" .. tostring(spell_id) .. ":" .. tostring(target)
    local now = core.time()
    local last = queue_request_timestamps[key] or 0
    if (now - last) < interval_s then return false end
    queue_request_timestamps[key] = now
    return true
end

function utils.can_cast_self(spell_id, me)
    if not spell_id or not me or not me:is_valid() then return false end
    if not core.spell_book.is_spell_learned(spell_id) then return false end
    if core.spell_book.get_spell_cooldown(spell_id) > 0 then return false end
    if not core.spell_book.is_usable_spell(spell_id) then return false end
    return true
end

function utils.cast_self(spell_id, me)
    if not spell_id or not me or not me:is_valid() then return false end
    local izi_spell = get_izi_spell(spell_id)
    if not izi_spell then return false end
    if not can_issue_queue_request("spell_target", spell_id, me, SPELL_QUEUE_INTERVAL_S) then return false end

    -- Use IZI SDK cast_safe method
    if izi_spell:is_learned() and izi_spell:is_castable_to_unit(me) then
        local ok, result = pcall(function()
            return izi_spell:cast_safe(me, "[Self] Cast")
        end)
        if ok and result then
            return true
        end
    end
    return false
end

function utils.cast_target(spell_id, me, target)
    local can_cast, reason = utils.can_cast_target(spell_id, me, target)
    if not can_cast then return false, reason end
    local izi_spell = get_izi_spell(spell_id)
    if not izi_spell then return false end

    -- Use IZI SDK cast_safe method
    if izi_spell:is_learned() and izi_spell:is_castable_to_unit(target) then
        local ok, result = pcall(function()
            return izi_spell:cast_safe(target, "[Target] Cast")
        end)
        if ok and result then
            return true
        end
    end
    return false
end

function utils.get_energy(me)
    if me and me.get_power then
        local ok, e = pcall(function() return me:get_power(3) end)
        if ok and type(e) == "number" then return e end
    end
    return 0
end

function utils.get_max_energy(me)
    if me and me.get_max_power then
        local ok, e = pcall(function() return me:get_max_power(3) end)
        if ok and type(e) == "number" then return e end
    end
    return 100
end

function utils.get_combo_points(me)
    if me and me.get_combo_points then
        local ok, cp = pcall(function() return me:get_combo_points() end)
        if ok and type(cp) == "number" then return cp end
    end
    return 0
end

function utils.mana_pct(me)
    if me and me.get_power and me.get_max_power then
        local ok_mana, mana = pcall(function() return me:get_power(0) end)
        local ok_max, max_mana = pcall(function() return me:get_max_power(0) end)
        if ok_mana and ok_max and max_mana > 0 then
            return mana / max_mana
        end
    end
    return 0
end

-- Squared distance for performance (no sqrt)
function utils.dist_squared(me, target)
    if not me or not target then return 999999 end
    local p1, p2 = me:get_position(), target:get_position()
    if not p1 or not p2 then return 999999 end
    local dx, dy, dz = p1.x - p2.x, p1.y - p2.y, p1.z - p2.z
    return (dx * dx + dy * dy + dz * dz)
end

-- Get current warrior stance name
function utils.get_stance_name()
    local me = core.object_manager.get_local_player()
    if not me or not me:is_valid() then return "Unknown" end
    
    local spells = require("libraries/spells")
    if utils.has_buff(me, spells.BUFF_BERSERKER_STANCE) then
        return "Berserker"
    elseif utils.has_buff(me, spells.BUFF_BATTLE_STANCE) then
        return "Battle"
    elseif utils.has_buff(me, spells.BUFF_DEFENSIVE_STANCE) then
        return "Defensive"
    end
    return "Unknown"
end

-- Check if player has enrage buff active
function utils.get_enrage_status()
    local me = core.object_manager.get_local_player()
    if not me or not me:is_valid() then return false end
    
    local spells = require("libraries/spells")
    return utils.has_buff(me, spells.BUFF_ENRAGE)
end

-- Get rage amount (for dashboard)
function utils.get_rage(me)
    if not me or not me:is_valid() then return 0 end
    local ok, rage = pcall(function() return me:get_power(1) end)  -- 1 = rage
    if ok and type(rage) == "number" then return rage end
    return 0
end

-- Cached API references for PvP detection
local _is_in_instance = core.game_state.is_in_instance
local _get_unit_type = core.object_manager.get_unit_type
local _is_pvp_flagged = core.game_state.is_pvp_flagged
local _get_local_player = core.object_manager.get_local_player

-- PvP context detection
-- Returns table with: is_pvp, is_arena, is_battleground, target_is_player
function utils.detect_pvp_context(me, target)
    me = me or _get_local_player()
    if not me then
        return {is_pvp = false, is_arena = false, is_battleground = false, target_is_player = false}
    end

    local is_battleground = false
    local is_arena = false
    local is_pvp = false
    local target_is_player = false

    -- Check instance type for BG/Arena
    if _is_in_instance then
        local ok, instance_type = pcall(_is_in_instance)
        if ok and instance_type then
            is_battleground = (instance_type == "battleground")
            is_arena = (instance_type == "arena")
        end
    end

    -- Check PvP flag status
    if _is_pvp_flagged then
        local ok, flagged = pcall(_is_pvp_flagged)
        if ok then
            is_pvp = flagged or false
        end
    end

    -- Check target type
    if target and _get_unit_type then
        local ok, unit_type = pcall(function() return _get_unit_type(target) end)
        if ok then
            target_is_player = (unit_type == "player")
        end
    end

    -- Combined PvP detection
    is_pvp = is_pvp or is_battleground or is_arena

    return {
        is_pvp = is_pvp,
        is_arena = is_arena,
        is_battleground = is_battleground,
        target_is_player = target_is_player
    }
end

-- Check if PvP mode is active based on menu settings and context
-- Usage: if utils.is_pvp_active(menu, pvp_context) then ... end
function utils.is_pvp_active(menu, context)
    if not menu then return false end

    -- Check if PvP is enabled at all
    local enabled = (menu.pvp_enabled and menu.pvp_enabled:get())
    if enabled == false then
        return false
    end

    -- Check mode selection (1=Auto, 2=PvE Only, 3=PvP Only)
    local mode = (menu.pvp_mode and menu.pvp_mode:get()) or 1
    if mode == 2 then return false end  -- PvE only
    if mode == 3 then return true end   -- PvP only

    -- Auto mode - use context
    return context and context.is_pvp or false
end

-- Check if a specific PvP setting is enabled
-- Usage: if utils.is_pvp_setting_enabled(menu, "pvp_hamstring") then ... end
function utils.is_pvp_setting_enabled(menu, setting_key)
    if not menu then return false end
    local setting = menu[setting_key]
    if not setting then return false end
    local ok, value = pcall(function() return setting:get() end)
    if not ok then return false end
    return value == true or value == 1
end

-- Get PvP slider value with default
-- Usage: local threshold = utils.get_pvp_value(menu, "pvp_burst_threshold", 60)
function utils.get_pvp_value(menu, setting_key, default_value)
    if not menu then return default_value end
    local setting = menu[setting_key]
    if not setting then return default_value end
    local ok, value = pcall(function() return setting:get() end)
    if not ok or value == nil then return default_value end
    return value
end

-- Predefined class detection for anti-stealth logic
utils.PVP_STEALTH_CLASSES = {
    ["ROGUE"] = true,
    ["DRUID"] = true,
}

-- Predefined healer specs for focus targeting
utils.PVP_HEALER_SPECS = {
    ["PRIEST_HOLY"] = true,
    ["PRIEST_DISCIPLINE"] = true,
    ["PALADIN_HOLY"] = true,
    ["SHAMAN_RESTORATION"] = true,
    ["DRUID_RESTORATION"] = true,
}

-- Check if target class can stealth
function utils.can_stealth(class_name)
    return utils.PVP_STEALTH_CLASSES[class_name] or false
end

-- Check if target spec is a healer
function utils.is_healer_spec(spec_name)
    return utils.PVP_HEALER_SPECS[spec_name] or false
end

-- Crowd Control Detection
-- Uses get_loss_of_control_info() to detect if player cannot cast spells

-- Loss of Control Type Enum Values (from Sylvanas API)
local LOC_NONE = 0
local LOC_POSSESS = 1
local LOC_CONFUSE = 2
local LOC_CHARM = 3
local LOC_FEAR = 4
local LOC_STUN = 5
local LOC_PACIFY = 6
local LOC_ROOT = 7
local LOC_SILENCE = 8
local LOC_PACIFY_SILENCE = 9
local LOC_DISARM = 10
local LOC_SCHOOL_INTERRUPT = 11
local LOC_STUN_MECHANIC = 12
local LOC_FEAR_MECHANIC = 13

-- CC types that prevent spell casting
local CAST_PREVENTING_CC_TYPES = {
    [LOC_STUN] = true,
    [LOC_PACIFY] = true,
    [LOC_SILENCE] = true,
    [LOC_PACIFY_SILENCE] = true,
    [LOC_SCHOOL_INTERRUPT] = true,
    [LOC_STUN_MECHANIC] = true,
    [LOC_CONFUSE] = true,
    [LOC_CHARM] = true,
    [LOC_FEAR] = true,
    [LOC_FEAR_MECHANIC] = true,
    [LOC_DISARM] = true,
}

--[[
    Checks if the unit has a loss of control effect that prevents casting
    
    @param unit: game_object - The player or unit to check
    @return boolean: true if unit cannot cast spells, false otherwise
--]]
function utils.is_cced(unit)
    if not unit or not unit.is_valid or not unit:is_valid() then
        return false
    end
    
    -- Check if method exists (API compatibility)
    if not unit.get_loss_of_control_info then
        return false
    end
    
    local loc_info = unit:get_loss_of_control_info()
    if not loc_info or not loc_info.valid then
        return false
    end
    
    return CAST_PREVENTING_CC_TYPES[loc_info.type] or false
end

--[[
    CC Break Helper Functions
    These functions attempt to break crowd control effects using class-specific abilities
--]]

-- Spell IDs for CC break abilities
local BERSERKER_RAGE = 18499
local BLINK = 1953
local DIVINE_SHIELD = 642
local CLOAK_OF_SHADOWS = 31224
local BEAR_FORM = 5487
local CAT_FORM = 768

-- Root spell IDs for Druid shapeshift break
local ROOT_SPELL_IDS = {
    [339] = true,    -- Entangling Roots (Rank 1)
    [1062] = true,   -- Entangling Roots (Rank 2)
    [5195] = true,   -- Entangling Roots (Rank 3)
    [5196] = true,   -- Entangling Roots (Rank 4)
    [9852] = true,   -- Entangling Roots (Rank 5)
    [9853] = true,   -- Entangling Roots (Rank 6)
    [26989] = true,  -- Entangling Roots (Rank 7)
    [19970] = true,  -- Entangling Roots (Rank 7 - Nature's Grasp proc)
    [19971] = true,  -- Entangling Roots (Rank 6 - Nature's Grasp proc)
    [19972] = true,  -- Entangling Roots (Rank 5 - Nature's Grasp proc)
    [19973] = true,  -- Entangling Roots (Rank 4 - Nature's Grasp proc)
    [19974] = true,  -- Entangling Roots (Rank 3 - Nature's Grasp proc)
    [19975] = true,  -- Entangling Roots (Rank 2 - Nature's Grasp proc)
    [19976] = true,  -- Entangling Roots (Rank 1 - Nature's Grasp proc)
    [122] = true,    -- Frost Nova (Rank 1)
    [865] = true,    -- Frost Nova (Rank 2)
    [6131] = true,   -- Frost Nova (Rank 3)
    [10230] = true,  -- Frost Nova (Rank 4)
    [27088] = true,  -- Frost Nova (Rank 5)
    [33395] = true,  -- Freeze (Water Elemental)
    [39965] = true,  -- Frost Grenade
    [55536] = true,  -- Frostweave Net
}

-- Magic CC types for Cloak of Shadows (not physical like stun/sap/gouge/disarm)
local MAGIC_CC_TYPES = {
    [LOC_FEAR] = true,
    [LOC_FEAR_MECHANIC] = true,
    [LOC_CHARM] = true,
    [LOC_CONFUSE] = true,
    [LOC_SILENCE] = true,
    [LOC_PACIFY_SILENCE] = true,
    [LOC_SCHOOL_INTERRUPT] = true,
    [LOC_ROOT] = true,
}

-- Fast self-cast helper for CC breaks (no queue throttling)
function utils.cast_self_fast(spell_id, me)
    if not spell_id or not me or not me:is_valid() then return false end
    local izi_spell = get_izi_spell(spell_id)
    if not izi_spell then return false end
    
    if izi_spell:is_learned() and izi_spell:is_castable_to_unit(me) then
        local ok, result = pcall(function()
            return izi_spell:cast_safe(me, "[CC Break] Cast")
        end)
        if ok and result then
            return true
        end
    end
    return false
end

--[[
    Warrior: Try to break fear/incapacitate with Berserker Rage
    @param me: game_object - The player unit
    @param menu: table - Menu module (optional, for future use)
    @return boolean: true if successfully cast, false otherwise
--]]
function utils.try_berserker_rage_fear_break(me, menu)
    if not me or not me:is_valid() then return false end
    
    -- Check if Berserker Rage is available
    if not utils.can_cast_self(BERSERKER_RAGE, me) then return false end
    
    -- Check if feared or incapacitated
    local is_feared = false
    local is_incapacitated = false
    
    if me.is_feared then
        local ok, result = pcall(function() return me:is_feared() end)
        if ok then is_feared = result end
    end
    
    if me.is_incapacitated then
        local ok, result = pcall(function() return me:is_incapacitated() end)
        if ok then is_incapacitated = result end
    end
    
    -- Also check loss of control for fear types
    local is_fear_cc = false
    if me.get_loss_of_control_info then
        local ok, loc_info = pcall(function() return me:get_loss_of_control_info() end)
        if ok and loc_info and loc_info.valid then
            is_fear_cc = (loc_info.type == LOC_FEAR or loc_info.type == LOC_FEAR_MECHANIC)
        end
    end
    
    if is_feared or is_incapacitated or is_fear_cc then
        return utils.cast_self_fast(BERSERKER_RAGE, me)
    end
    
    return false
end

--[[
    Mage: Try to break stun with Blink
    @param me: game_object - The player unit
    @param menu: table - Menu module (optional, for future use)
    @return boolean: true if successfully cast, false otherwise
--]]
function utils.try_blink_stun_break(me, menu)
    if not me or not me:is_valid() then return false end
    
    -- Check if Blink is available
    if not utils.can_cast_self(BLINK, me) then return false end
    
    -- Check if stunned using loss of control info
    local is_stunned = false
    if me.get_loss_of_control_info then
        local ok, loc_info = pcall(function() return me:get_loss_of_control_info() end)
        if ok and loc_info and loc_info.valid then
            is_stunned = (loc_info.type == LOC_STUN or loc_info.type == LOC_STUN_MECHANIC)
        end
    end
    
    if is_stunned then
        return utils.cast_self_fast(BLINK, me)
    end
    
    return false
end

--[[
    Paladin: Try to break CC with Divine Shield
    @param me: game_object - The player unit
    @param menu: table - Menu module (optional, for future use)
    @return boolean: true if successfully cast, false otherwise
--]]
function utils.try_divine_shield_cc_break(me, menu)
    if not me or not me:is_valid() then return false end
    
    -- Check if Divine Shield is available
    if not utils.can_cast_self(DIVINE_SHIELD, me) then return false end
    
    -- Check if CC'd (any loss of control that stops rotation)
    local should_stop = utils.is_cced(me)
    
    if should_stop then
        return utils.cast_self_fast(DIVINE_SHIELD, me)
    end
    
    return false
end

--[[
    Rogue: Try to break magic CC with Cloak of Shadows
    @param me: game_object - The player unit
    @param menu: table - Menu module (optional, for future use)
    @return boolean: true if successfully cast, false otherwise
--]]
function utils.try_cloak_of_shadows_cc_break(me, menu)
    if not me or not me:is_valid() then return false end
    
    -- Check if Cloak of Shadows is available
    if not utils.can_cast_self(CLOAK_OF_SHADOWS, me) then return false end
    
    -- Check if under magic CC (not physical like stun/sap/gouge/disarm)
    local is_magic_cc = false
    if me.get_loss_of_control_info then
        local ok, loc_info = pcall(function() return me:get_loss_of_control_info() end)
        if ok and loc_info and loc_info.valid then
            is_magic_cc = MAGIC_CC_TYPES[loc_info.type] or false
        end
    end
    
    if is_magic_cc then
        return utils.cast_self_fast(CLOAK_OF_SHADOWS, me)
    end
    
    return false
end

--[[
    Druid: Try to break roots by shapeshifting
    @param me: game_object - The player unit
    @param menu: table - Menu module (optional, for future use)
    @return boolean: true if successfully cast, false otherwise
--]]
function utils.try_shapeshift_root_break(me, menu)
    if not me or not me:is_valid() then return false end
    
    -- Check if rooted by checking debuff data
    local is_rooted = false
    if me.get_loss_of_control_info then
        local ok, loc_info = pcall(function() return me:get_loss_of_control_info() end)
        if ok and loc_info and loc_info.valid then
            is_rooted = (loc_info.type == LOC_ROOT)
        end
    end
    
    -- Also check for root debuffs directly
    if not is_rooted then
        for spell_id, _ in pairs(ROOT_SPELL_IDS) do
            local data = buff_manager:get_debuff_data(me, {spell_id})
            if data and data.is_active then
                is_rooted = true
                break
            end
        end
    end
    
    if is_rooted then
        -- Try Bear Form first (usually available to all druids)
        if utils.can_cast_self(BEAR_FORM, me) then
            return utils.cast_self_fast(BEAR_FORM, me)
        end
        
        -- Try Cat Form as fallback
        if utils.can_cast_self(CAT_FORM, me) then
            return utils.cast_self_fast(CAT_FORM, me)
        end
    end
    
    return false
end

return utils


