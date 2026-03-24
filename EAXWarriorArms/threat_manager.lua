-- threat_manager.lua
-- eax_shared/threat_manager.lua
-- Threat estimation and tank tracking for all TBC Classic specs.
-- Prevents aggro pulls by fading when threat exceeds tank's.
--
-- Usage:
--   local threat_manager = require("eax_shared/threat_manager")
--   if threat_manager.should_fade(me, target, menu) then
--       utils.cast_self(runtime.fade_id, me)
--   end
--
-- v1.0.0

local threat_manager = {}

-- --- Constants ----------------------------------------------------------------

-- TBC tank classes (can hold aggro)
threat_manager.TANK_CLASSES = {
    warrior = true,
    paladin = true,
    druid = true,   -- Bear form
    death_knight = true,  -- Added in WotLK, won't exist in TBC but safe to include
}

-- Class IDs in TBC
-- 1 = Warrior, 2 = Paladin, 3 = Hunter, 4 = Rogue, 5 = Priest
-- 6 = Druid, 7 = Shaman, 8 = Mage, 9 = Warlock, 11 = Death Knight (TBC doesn't have DK)
local CLASS_ID = {
    WARRIOR = 1,
    PALADIN = 2,
    HUNTER = 3,
    ROGUE = 4,
    PRIEST = 5,
    DRUID = 6,
    SHAMAN = 7,
    MAGE = 8,
    WARLOCK = 9,
}

-- Threat falloff multiplier when tank has > 100% threat
-- If tank has 130% threat (300% total effective), player can go to 110% safely
local THREAT_FALLOFF_TANK_THRESHOLD = 100

-- Default fade threshold: when player threat >= fade_threshold of tank threat
threat_manager.DEFAULT_FADE_THRESHOLD = 0.90  -- 90% of tank threat

-- Minimum threat gap before fading
local MIN_THREAT_GAP = 500

-- --- Internal State ------------------------------------------------------------

-- Cache tank unit for performance
local cached_tank = nil
local tank_cache_time = 0
local TANK_CACHE_TTL_S = 2.0  -- Refresh tank every 2s

-- --- Helpers ------------------------------------------------------------------

---Check if a unit is a tank class.
---@param class_id number
---@return boolean
local function is_tank_class(class_id)
    return class_id == CLASS_ID.WARRIOR
        or class_id == CLASS_ID.PALADIN
        or class_id == CLASS_ID.DRUID
end

---Check if a unit is in bear form (Druid tank).
---@param unit game_object
---@return boolean
local function is_in_bear_form(unit)
    if not unit then return false end
    -- Druid bear form buff IDs
    local BEAR_FORM_BUFFS = {
        [9634] = true,   -- Dire Bear Form
        [21178] = true,  -- Bear Form (old)
        [22856] = true,  -- Bear Form
        [22857] = true,  -- Bear Form (with talents)
    }
    return unit:has_any_buff_of(BEAR_FORM_BUFFS)
end

---Get the local player's unit.
---@return game_object|nil
local function get_local_player()
    local ok, player = pcall(function()
        return core.object_manager.get_local_player()
    end)
    if not ok or not player or not player:is_valid() then
        return nil
    end
    return player
end

---Get party members including local player.
---@return table
local function get_party()
    local ok, members = pcall(function()
        return core.object_manager.get_party_members()
    end)
    if not ok then
        return {}
    end
    return members or {}
end

---Get raid members.
---@return table
local function get_raid()
    local ok, members = pcall(function()
        return core.object_manager.get_raid_members()
    end)
    if not ok then
        return {}
    end
    return members or {}
end

-- --- Public API ---------------------------------------------------------------

---Get the tank unit for the current target.
---Finds the party/raid member with the highest threat on the target,
---or the highest-level warrior/paladin/druid in the party.
---@param target game_object|nil the target being evaluated
---@return game_object|nil tank_unit
function threat_manager.get_tank_unit(target)
    local now = core.time()

    -- Return cached tank if still valid
    if cached_tank and cached_tank:is_valid() and (now - tank_cache_time) < TANK_CACHE_TTL_S then
        return cached_tank
    end

    local best_tank = nil
    local best_threat = 0

    -- Method 1: Find highest threat holder on the target
    if target and target.is_valid then
        local highest_threat = 0
        local ok, highest_threat_val = pcall(function()
            return target:get_threat_or_highest_threat_on_target()
        end)
        if ok and highest_threat_val and highest_threat_val > 0 then
            -- Try to find who holds that threat
            local party = get_party()
            for _, member in ipairs(party) do
                if member and member:is_valid() and member:is_in_group_with(get_local_player()) then
                    local ok2, member_threat = pcall(function()
                        return target:get_threat(member)
                    end)
                    if ok2 and member_threat and member_threat > best_threat then
                        -- Check if this member is a tank class or has aggro
                        local class_id = member:get_class()
                        if is_tank_class(class_id) or member_threat >= highest_threat_val * 0.8 then
                            best_tank = member
                            best_threat = member_threat
                        end
                    end
                end
            end
        end
    end

    -- Method 2: Find highest-level tank in party as fallback
    if not best_tank then
        local party = get_party()
        local best_tank_level = 0
        for _, member in ipairs(party) do
            if member and member:is_valid() then
                local class_id = member:get_class()
                if is_tank_class(class_id) then
                    -- Druids: check bear form
                    if class_id == CLASS_ID.DRUID and not is_in_bear_form(member) then
                        goto continue
                    end
                    local level = member:get_level()
                    if level > best_tank_level then
                        best_tank_level = level
                        best_tank = member
                    end
                end
                ::continue::
            end
        end
    end

    -- Cache result
    cached_tank = best_tank
    tank_cache_time = now

    return best_tank
end

---Get the tank's threat on a specific target.
---@param target game_object
---@return number threat (0 if no tank found)
function threat_manager.get_tank_threat(target)
    local tank = threat_manager.get_tank_unit(target)
    if not tank or not target then
        return 0
    end

    local ok, threat = pcall(function()
        return target:get_threat(tank)
    end)

    if not ok or not threat then
        return 0
    end

    return threat
end

---Get the local player's threat on a specific target.
---@param target game_object
---@return number threat (0 if no target or error)
function threat_manager.get_player_threat(target)
    local me = get_local_player()
    if not me or not target or not target:is_valid() then
        return 0
    end

    local ok, threat = pcall(function()
        return target:get_threat(me)
    end)

    if not ok or not threat then
        return 0
    end

    return threat
end

---Check if the local player has aggro (is top threat on target).
---@param target game_object
---@return boolean
function threat_manager.has_aggro(target)
    if not target or not target:is_valid() then
        return false
    end

    local ok, highest = pcall(function()
        return target:get_threat_or_highest_threat_on_target()
    end)

    if not ok or not highest or highest <= 0 then
        return false
    end

    local player_threat = threat_manager.get_player_threat(target)

    -- Player has aggro if they have the highest threat
    return player_threat >= highest
end

---Check if the player should Fade (for casters and healers).
---Fade when: player threat >= fade_threshold * tank_threat, OR player threat too close.
---@param me game_object|nil optional local player
---@param target game_object|nil optional target
---@param menu table|nil optional menu for per-class settings
---@return boolean should_fade
function threat_manager.should_fade(me, target, menu)
    -- Optional parameters
    if not me then
        me = get_local_player()
    end
    if not me or not me:is_valid() then
        return false
    end

    -- Skip if no menu toggle
    if menu and menu.use_threat_management then
        if type(menu.use_threat_management.get_state) == "function" then
            if not menu.use_threat_management:get_state() then
                return false
            end
        end
    end

    -- Skip if no target
    if not target or not target:is_valid() or target:is_dead() then
        return false
    end

    -- Get player threat
    local player_threat = threat_manager.get_player_threat(target)
    if player_threat <= 0 then
        return false  -- No threat to worry about
    end

    -- Get tank threat
    local tank_threat = threat_manager.get_tank_threat(target)
    if tank_threat <= 0 then
        -- No tank found or tank has no threat
        -- In solo/no-tank situations, use conservative threshold
        -- Don't fade if we can't determine tank threat (might be the tank)
        return false
    end

    -- Get fade threshold from menu or use default
    local threshold = threat_manager.DEFAULT_FADE_THRESHOLD
    if menu and menu.threat_fade_threshold then
        if type(menu.threat_fade_threshold.get) == "function" then
            threshold = menu.threat_fade_threshold:get()
        end
    end

    -- Player should fade when they exceed threshold of tank's threat
    if player_threat >= tank_threat * threshold then
        -- Also check absolute gap to avoid fading at very low threat levels
        if (player_threat - tank_threat) >= MIN_THREAT_GAP then
            return true
        end
    end

    return false
end

---Get the threat percentage relative to the tank.
---Useful for UI display.
---@param target game_object
---@return number percentage (0 if no tank)
function threat_manager.get_threat_pct_of_tank(target)
    local tank_threat = threat_manager.get_tank_threat(target)
    if tank_threat <= 0 then
        return 0
    end
    local player_threat = threat_manager.get_player_threat(target)
    return (player_threat / tank_threat) * 100
end

---Clear the tank cache (force re-detection next call).
function threat_manager.clear_cache()
    cached_tank = nil
    tank_cache_time = 0
end

---Attempt to cast Fade spell to reduce threat.
---@param me game_object|nil optional local player
---@return boolean success
function threat_manager.try_fade(me)
    if not me then
        me = get_local_player()
    end
    if not me or not me:is_valid() then
        return false
    end
    
    -- Get fade spell ID from runtime or resolve it
    -- This assumes the calling spec has resolved the fade spell ID
    -- and passed it appropriately, or we can try to resolve it here
    local fade_spell_id = 29833  -- Fade spell ID in TBC (Priest spell, but used as example)
    
    -- Actually, we should let the spec handle the fade casting since
    -- different classes have different fade/spell mechanics
    -- For now, we'll return true to indicate the decision to fade was made
    -- The spec should implement the actual fade casting
    return true
end

---Initialize threat manager (no-op; module is self-initializing via core APIs).
---Called once per spec load to satisfy the init contract.
---@param me game_object|nil
function threat_manager.init(me)
    -- threat_manager resolves the local player internally via core.object_manager
    -- nothing to set up here
end

return threat_manager
