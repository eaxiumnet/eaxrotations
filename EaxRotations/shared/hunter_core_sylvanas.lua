-- ============================================================================
-- Shared Hunter Core: auto-shot timer, shot weaving, sting/aspect/pet helpers
-- ============================================================================
local M = {}
local _G = _G
local NS = _G.EaxRotations
if not NS then return M end

-- ============================================================================
-- Auto-shot timer state (prevents clipping)
-- ============================================================================
local shot_state = {
    last_auto_time = 0,
    weapon_speed = 0,
    last_instant_time = 0,
    steady_start_time = 0,
    steady_casting = false,
    auto_shot_active = false,
    initial_sync_done = false,
}

local AUTO_SHOT_ID = 75
local DEFAULT_WEAPON_SPEED = 2.9

local function now()
    return NS and NS.time_now and NS.time_now() or 0
end

--- Get the player's ranged weapon speed.
function M.get_weapon_speed()
    if shot_state.weapon_speed > 0 then return shot_state.weapon_speed end
    -- Fallback: try to get from player object
    local me = NS.GetPlayer and NS.GetPlayer()
    if me and me.GetRangedWeaponSpeed then
        local speed = pcall(me.GetRangedWeaponSpeed, me)
        if speed then
            shot_state.weapon_speed = speed
            return speed
        end
    end
    return DEFAULT_WEAPON_SPEED
end

--- Record an auto-shot event (called from spell cast callback).
function M.record_auto_shot()
    shot_state.last_auto_time = now()
    shot_state.auto_shot_active = true
    shot_state.initial_sync_done = true
end

--- Record an instant shot (Arcane Shot, Multi-Shot, etc).
function M.record_instant_shot()
    shot_state.last_instant_time = now()
end

--- Record the start of a Steady Shot cast.
function M.record_steady_start()
    shot_state.steady_start_time = now()
    shot_state.steady_casting = true
end

--- Record the end of a Steady Shot cast.
function M.record_steady_end()
    shot_state.steady_casting = false
end

--- Milliseconds until the next auto-shot.
--- Returns 0 if no auto is queued/pending.
function M.ms_until_auto()
    if not shot_state.auto_shot_active or shot_state.weapon_speed == 0 then
        return 0
    end
    local elapsed = (now() - shot_state.last_auto_time) * 1000
    local total_ms = shot_state.weapon_speed * 1000
    local remaining = total_ms - elapsed
    return math.max(0, remaining)
end

--- Can cast a non-instant shot (like Steady Shot) without clipping auto-shot?
function M.can_cast_steady(buffer_ms)
    buffer_ms = buffer_ms or 150  -- Default latency buffer
    local remain = M.ms_until_auto()
    local steady_cast_ms = 1500
    local needed = steady_cast_ms + buffer_ms
    return remain == 0 or remain > needed
end

--- Can cast an instant shot (Arcane/Multi/Sting) without clipping auto-shot?
function M.can_cast_instant(cast_ms, buffer_ms)
    cast_ms = cast_ms or 500  -- Multi-Shot GCD-ish window
    buffer_ms = buffer_ms or 100
    local remain = M.ms_until_auto()
    return remain == 0 or remain > cast_ms + buffer_ms
end

--- Initialize auto-shot tracking via spell cast callback.
function M.init()
    if NS.register_on_spell_cast then
        NS.register_on_spell_cast(function(spell_id, target, data)
            if spell_id == AUTO_SHOT_ID then
                M.record_auto_shot()
            end
        end)
    elseif core and core.register_on_spell_cast_callback then
        core.register_on_spell_cast_callback(function(data)
            if data and data.spell_id == AUTO_SHOT_ID then
                M.record_auto_shot()
            end
        end)
    end
end

-- ============================================================================
-- Sting debuff IDs
-- ============================================================================
local STING_IDS = {
    serpent = { 27016, 25295, 13555, 13554, 13553, 13552, 13551, 13550, 13549, 1978 },
    scorpid = { 27015, 14601, 14600, 14599, 14598, 14597, 14596, 14595 },
    viper   = { 27018, 14280, 14279, 3034 },
}

--- Check if any sting is active on target.
---@param target game_object
---@param sting_type string|nil 'serpent', 'scorpid', 'viper', or nil for any
---@return boolean
function M.has_sting(target, sting_type)
    if not target then return false end
    local types = sting_type and { STING_IDS[sting_type] } or STING_IDS
    for _, ids in pairs(types) do
        for _, id in ipairs(ids) do
            if NS.debuff_up and NS.debuff_up(target, id) then
                return true
            end
        end
    end
    return false
end

--- Get remaining time for a specific sting type.
---@param target game_object
---@param sting_type string 'serpent', 'scorpid', 'viper'
---@return number seconds
function M.sting_remains(target, sting_type)
    if not target then return 0 end
    local ids = STING_IDS[sting_type]
    if not ids then return 0 end
    for _, id in ipairs(ids) do
        if NS.debuff_up and NS.debuff_up(target, id) then
            return NS.debuff_remains and NS.debuff_remains(target, id) or 0
        end
    end
    return 0
end

-- ============================================================================
-- Aspect helpers
-- ============================================================================
--- Should we switch to Aspect of the Viper based on mana %?
---@param mana_pct number (0-100)
---@param viper_threshold number (default 30)
---@return boolean
function M.should_viper(mana_pct, viper_threshold)
    viper_threshold = viper_threshold or 30
    return mana_pct < viper_threshold
end

--- Should we switch back to Aspect of the Hawk based on mana %?
---@param mana_pct number
---@param hawk_threshold number (default 50)
---@return boolean
function M.should_hawk(mana_pct, hawk_threshold)
    hawk_threshold = hawk_threshold or 50
    return mana_pct > hawk_threshold
end

-- ============================================================================
-- Threat helpers
-- ============================================================================
--- Should we Feign Death?
---@param threat_level number (0-3 from get_threat_situation)
---@param fd_mode string 'off', 'high_threat', 'aggro_only'
---@return boolean
function M.should_feign_death(threat_level, fd_mode)
    if fd_mode == 'off' or not fd_mode then return false end
    if fd_mode == 'high_threat' and threat_level >= 2 then return true end
    if fd_mode == 'aggro_only' and threat_level >= 3 then return true end
    return false
end

-- ============================================================================
-- Pet management helpers
-- ============================================================================
local _last_mend_time = 0
local _last_pet_scan = 0
local _cached_pet = nil

function M.get_pet()
    if now() - _last_pet_scan > 1 then
        _last_pet_scan = now()
        _cached_pet = NS.GetPet and NS.GetPet() or nil
    end
    return _cached_pet
end

function M.pet_alive()
    local pet = M.get_pet()
    if not pet then return false end
    local ok, alive = pcall(function() return pet:is_alive() end)
    return ok and alive
end

function M.pet_hp_pct()
    local pet = M.get_pet()
    if not pet then return 0 end
    local ok, hp = pcall(function() return pet:get_health_percentage() end)
    return ok and hp or 0
end

--- Should we Mend Pet?
function M.should_mend_pet(hp_threshold)
    hp_threshold = hp_threshold or 45
    if not M.pet_alive() then return false end
    if now() - _last_mend_time < 2 then return false end
    return M.pet_hp_pct() < hp_threshold
end

function M.record_mend()
    _last_mend_time = now()
end

-- ============================================================================
-- Exposure
-- ============================================================================
M.STING_IDS = STING_IDS
M.AUTO_SHOT_ID = AUTO_SHOT_ID

if NS then
    NS.HunterCore = M
end

return M
